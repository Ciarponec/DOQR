import {
  cleanText,
  errorResponse,
  HttpError,
  json,
  options,
  readJson,
  requireDoorHost,
  requireUser,
  serviceClient,
} from "../_shared/utils.ts";
import { decryptCourierCode } from "../_shared/secrets.ts";

type Action = "accept" | "decline" | "cancel" | "end" | "reveal_note";

Deno.serve(async (req) => {
  const preflight = options(req);
  if (preflight) return preflight;
  try {
    if (req.method !== "POST") {
      return json(405, { error: "Method not allowed" }, req);
    }
    const user = await requireUser(
      req.headers.get("Authorization") ?? undefined,
    );
    const body = await readJson<{ ring_id?: unknown; action?: unknown }>(req);
    const ringId = cleanText(body.ring_id, 36, true)!;
    const action = cleanText(body.action, 12, true)! as Action;
    if (
      !["accept", "decline", "cancel", "end", "reveal_note"].includes(action)
    ) {
      throw new HttpError(400, "Geçersiz görüşme işlemi", "VALIDATION_ERROR");
    }

    const admin = serviceClient();
    const { data: ring, error: ringError } = await admin
      .from("rings")
      .select(
        "id, door_id, visitor_user_id, status, requested_mode, accepted_mode, answered_at, session_expires_at, courier_note_id, doors!inner(owner_user_id)",
      )
      .eq("id", ringId)
      .maybeSingle();
    if (ringError) throw new Error(ringError.message);
    if (!ring) throw new HttpError(404, "Ziyaret bulunamadı", "RING_NOT_FOUND");

    const isVisitor = user.is_anonymous === true;
    if (isVisitor) {
      if (ring.visitor_user_id !== user.id) {
        throw new HttpError(403, "Bu görüşmeye erişiminiz yok", "FORBIDDEN");
      }
      if (
        !ring.session_expires_at ||
        new Date(ring.session_expires_at).getTime() <= Date.now()
      ) {
        throw new HttpError(
          410,
          "Ziyaretçi oturumunun süresi dolmuş",
          "SESSION_EXPIRED",
        );
      }
      if (
        !((action === "cancel" && ring.status === "pending") ||
          (action === "end" && ring.status === "accepted"))
      ) {
        throw new HttpError(
          409,
          "Bu işlem mevcut görüşme durumunda yapılamaz",
          "INVALID_TRANSITION",
        );
      }
    } else {
      await requireDoorHost(admin, ring.door_id, user.id);
      if (action === "reveal_note") {
        if (!["pending", "accepted"].includes(ring.status)) {
          throw new HttpError(
            409,
            "Sona ermiş görüşmeye not gönderilemez",
            "RING_CLOSED",
          );
        }
        if (!ring.courier_note_id) {
          throw new HttpError(
            404,
            "Bu kurye için hazır not yok",
            "COURIER_NOTE_NOT_FOUND",
          );
        }
        const { data: previous } = await admin
          .from("ring_events")
          .select("id")
          .eq("ring_id", ringId)
          .eq("event_type", "courier_note_revealed")
          .maybeSingle();
        if (previous) {
          throw new HttpError(
            409,
            "Kurye notu zaten paylaşıldı",
            "COURIER_NOTE_ALREADY_SHARED",
          );
        }
        const { data: note, error: noteError } = await admin
          .from("courier_notes")
          .select("title, message_text, delivery_code, is_active")
          .eq("id", ring.courier_note_id)
          .maybeSingle();
        if (noteError) throw new Error(noteError.message);
        if (!note?.is_active) {
          throw new HttpError(
            410,
            "Hazır kurye notu artık aktif değil",
            "COURIER_NOTE_INACTIVE",
          );
        }
        const code = await decryptCourierCode(note.delivery_code);
        const message = [
          note.title,
          note.message_text,
          ...(code ? [`Teslimat kodu: ${code}`] : []),
        ].join("\n");
        const { error: shareError } = await admin.rpc(
          "share_courier_note_message",
          {
            _ring_id: ringId,
            _actor_user_id: user.id,
            _message_text: message,
          },
        );
        if (shareError?.code === "23505") {
          throw new HttpError(
            409,
            "Kurye notu zaten paylaşıldı",
            "COURIER_NOTE_ALREADY_SHARED",
          );
        }
        if (shareError) throw new Error(shareError.message);
        return json(200, { shared: true }, req);
      }
      if (
        !(
          (["accept", "decline"].includes(action) &&
            ring.status === "pending") ||
          (action === "end" && ["pending", "accepted"].includes(ring.status))
        )
      ) {
        throw new HttpError(
          409,
          "Bu işlem mevcut görüşme durumunda yapılamaz",
          "INVALID_TRANSITION",
        );
      }
    }

    const nextStatus = action === "accept"
      ? "accepted"
      : action === "decline"
      ? "declined"
      : action === "cancel"
      ? "cancelled"
      : "ended";
    const now = new Date().toISOString();
    const updates: Record<string, unknown> = { status: nextStatus };
    if (action === "accept") {
      updates.accepted_mode = ring.requested_mode;
      updates.answered_at = now;
    }
    if (["decline", "cancel", "end"].includes(action)) updates.closed_at = now;

    const { data: updated, error: updateError } = await admin
      .from("rings")
      .update(updates)
      .eq("id", ringId)
      .eq("status", ring.status)
      .select(
        "id, status, requested_mode, accepted_mode, answered_at, closed_at",
      )
      .maybeSingle();
    if (updateError) throw new Error(updateError.message);
    if (!updated) {
      throw new HttpError(
        409,
        "Görüşme durumu başka bir cihazda değişti",
        "STATE_CONFLICT",
      );
    }

    await admin.from("ring_events").insert({
      ring_id: ringId,
      event_type: nextStatus,
      actor_type: isVisitor ? "visitor" : "host",
      actor_user_id: user.id,
      metadata: { mode: updated.accepted_mode ?? updated.requested_mode },
    });

    if (
      action === "end" && ring.answered_at &&
      ["audio", "video"].includes(ring.accepted_mode ?? "")
    ) {
      const doorRelation = ring.doors as unknown as
        | { owner_user_id: string }
        | { owner_user_id: string }[];
      const owner = Array.isArray(doorRelation)
        ? doorRelation[0]?.owner_user_id
        : doorRelation.owner_user_id;
      const seconds = Math.max(
        0,
        Math.min(
          ring.accepted_mode === "video" ? 60 : 7200,
          Math.floor(
            (Date.now() - new Date(ring.answered_at).getTime()) / 1000,
          ),
        ),
      );
      const periodStart = new Date();
      periodStart.setUTCDate(1);
      periodStart.setUTCHours(0, 0, 0, 0);
      await admin.from("usage_monthly").upsert({
        user_id: owner,
        period_start: periodStart.toISOString().slice(0, 10),
      }, { onConflict: "user_id,period_start", ignoreDuplicates: true });
      const field = ring.accepted_mode === "video"
        ? "video_seconds"
        : "audio_seconds";
      const { data: usage } = await admin
        .from("usage_monthly")
        .select("audio_seconds, video_seconds")
        .eq("user_id", owner)
        .eq("period_start", periodStart.toISOString().slice(0, 10))
        .single();
      await admin.from("usage_monthly").update({
        [field]: Number(usage?.[field] ?? 0) + seconds,
        updated_at: now,
      }).eq("user_id", owner).eq(
        "period_start",
        periodStart.toISOString().slice(0, 10),
      );
      await admin.from("ring_events").insert({
        ring_id: ringId,
        event_type: "media_ended",
        actor_type: isVisitor ? "visitor" : "host",
        actor_user_id: user.id,
        metadata: { mode: ring.accepted_mode, duration_seconds: seconds },
      });
    }

    return json(200, updated, req);
  } catch (error) {
    return errorResponse(error, req);
  }
});
