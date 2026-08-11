import { enabledModes, getOwnerPlan } from "../_shared/plans.ts";
import { getTurnServiceStatus } from "../_shared/turn.ts";
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

type Action =
  | "accept"
  | "decline"
  | "request_media"
  | "accept_media"
  | "decline_media"
  | "cancel"
  | "end"
  | "reveal_note";
type MediaMode = "audio" | "video";

function ownerIdOf(doors: unknown): string {
  const relation = doors as { owner_user_id?: string } | { owner_user_id?: string }[];
  const owner = Array.isArray(relation) ? relation[0]?.owner_user_id : relation.owner_user_id;
  if (!owner) throw new Error("Door owner missing");
  return owner;
}

async function validateHostMode(
  admin: ReturnType<typeof serviceClient>,
  doorId: string,
  ownerUserId: string,
  mode: "text" | MediaMode,
) {
  const [{ data: settings, error: settingsError }, plan] = await Promise.all([
    admin.from("door_settings")
      .select("text_enabled, audio_enabled, video_enabled")
      .eq("door_id", doorId)
      .single(),
    getOwnerPlan(admin, ownerUserId),
  ]);
  if (settingsError || !settings) {
    throw new Error(settingsError?.message ?? "Door settings missing");
  }
  if (enabledModes(settings, plan)[mode] !== true) {
    throw new HttpError(
      403,
      "Bu görüşme seçeneği bu dijital zil için açık değil",
      "MODE_DISABLED",
    );
  }
  if (mode === "text") return;

  const turnStatus = await getTurnServiceStatus(admin);
  if (!turnStatus.enabled) {
    throw new HttpError(
      503,
      turnStatus.reason === "monthly_limit"
        ? "Sesli ve görüntülü görüşme bu ayki altyapı sınırına ulaştı"
        : "Sesli ve görüntülü görüşme geçici olarak kullanılamıyor",
      turnStatus.reason === "monthly_limit"
        ? "TURN_MONTHLY_LIMIT"
        : "TURN_UNAVAILABLE",
    );
  }
  const { error } = await admin.rpc("assert_doorbell_media_available", {
    _owner_user_id: ownerUserId,
    _mode: mode,
  });
  if (!error) return;
  if (error.message.includes("PRO_REQUIRED")) {
    throw new HttpError(402, "Bu görüşme türü Pro planı gerektiriyor", "PRO_REQUIRED");
  }
  if (error.message.includes("MONTHLY_AUDIO_LIMIT") || error.message.includes("MONTHLY_VIDEO_LIMIT")) {
    throw new HttpError(429, "Bu ayki adil kullanım süresi doldu", "MEDIA_FAIR_USE_LIMIT");
  }
  throw new Error(error.message);
}

Deno.serve(async (req) => {
  const preflight = options(req);
  if (preflight) return preflight;
  try {
    if (req.method !== "POST") {
      return json(405, { error: "Method not allowed" }, req);
    }
    const user = await requireUser(req.headers.get("Authorization") ?? undefined);
    const body = await readJson<{ ring_id?: unknown; action?: unknown; mode?: unknown }>(req);
    const ringId = cleanText(body.ring_id, 36, true)!;
    const action = cleanText(body.action, 20, true)! as Action;
    const mode = cleanText(body.mode, 10) as MediaMode | null;
    if (![
      "accept", "decline", "request_media", "accept_media", "decline_media",
      "cancel", "end", "reveal_note",
    ].includes(action)) {
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
    const ownerUserId = ownerIdOf(ring.doors);
    const isVisitor = user.is_anonymous === true;

    if (isVisitor) {
      if (ring.visitor_user_id !== user.id) {
        throw new HttpError(403, "Bu görüşmeye erişiminiz yok", "FORBIDDEN");
      }
      if (!ring.session_expires_at || new Date(ring.session_expires_at).getTime() <= Date.now()) {
        throw new HttpError(410, "Ziyaretçi oturumunun süresi dolmuş", "SESSION_EXPIRED");
      }
      const validVisitorAction =
        (action === "cancel" && ring.status === "pending") ||
        (action === "end" && ring.status === "accepted") ||
        (["accept_media", "decline_media"].includes(action) && ring.status === "media_requested");
      if (!validVisitorAction) {
        throw new HttpError(409, "Bu işlem mevcut görüşme durumunda yapılamaz", "INVALID_TRANSITION");
      }
      if (
        action === "accept_media" &&
        !["audio", "video"].includes(ring.accepted_mode ?? "")
      ) {
        throw new HttpError(409, "Geçerli bir medya isteği bulunamadı", "INVALID_TRANSITION");
      }
    } else {
      await requireDoorHost(admin, ring.door_id, user.id);
      if (action === "reveal_note") {
        if (!["pending", "accepted"].includes(ring.status)) {
          throw new HttpError(409, "Sona ermiş görüşmeye not gönderilemez", "RING_CLOSED");
        }
        if (!ring.courier_note_id) {
          throw new HttpError(404, "Bu kurye için hazır not yok", "COURIER_NOTE_NOT_FOUND");
        }
        const { data: previous } = await admin.from("ring_events")
          .select("id").eq("ring_id", ringId)
          .eq("event_type", "courier_note_revealed").maybeSingle();
        if (previous) {
          throw new HttpError(409, "Kurye notu zaten paylaşıldı", "COURIER_NOTE_ALREADY_SHARED");
        }
        const { data: note, error: noteError } = await admin.from("courier_notes")
          .select("delivery_code, is_active")
          .eq("id", ring.courier_note_id).maybeSingle();
        if (noteError) throw new Error(noteError.message);
        if (!note?.is_active) {
          throw new HttpError(410, "Hazır kurye notu artık aktif değil", "COURIER_NOTE_INACTIVE");
        }
        const code = await decryptCourierCode(note.delivery_code);
        if (!code) {
          throw new HttpError(409, "Bu kurye notunda teslimat kodu yok", "COURIER_CODE_NOT_FOUND");
        }
        const message = `Teslimat kodu: ${code}`;
        const { error: shareError } = await admin.rpc("share_courier_note_message", {
          _ring_id: ringId,
          _actor_user_id: user.id,
          _message_text: message,
        });
        if (shareError?.code === "23505") {
          throw new HttpError(409, "Kurye notu zaten paylaşıldı", "COURIER_NOTE_ALREADY_SHARED");
        }
        if (shareError) throw new Error(shareError.message);
        // A delivery code is intended to be disclosed only once.  Keeping the
        // note itself active lets the host prepare the next delivery later.
        const { error: consumeCodeError } = await admin.from("courier_notes")
          .update({ delivery_code: null, updated_at: new Date().toISOString() })
          .eq("id", ring.courier_note_id);
        if (consumeCodeError) throw new Error(consumeCodeError.message);
        return json(200, { shared: true }, req);
      }

      const validHostAction =
        (["accept", "decline", "request_media"].includes(action) && ring.status === "pending") ||
        (action === "end" && ["pending", "media_requested", "accepted"].includes(ring.status));
      if (!validHostAction) {
        throw new HttpError(409, "Bu işlem mevcut görüşme durumunda yapılamaz", "INVALID_TRANSITION");
      }
      if (action === "accept") {
        await validateHostMode(admin, ring.door_id, ownerUserId, "text");
      }
      if (action === "request_media") {
        if (mode !== "audio" && mode !== "video") {
          throw new HttpError(400, "Geçersiz görüşme türü", "VALIDATION_ERROR");
        }
        await validateHostMode(admin, ring.door_id, ownerUserId, mode);
      }
    }

    const now = new Date().toISOString();
    let nextStatus: string;
    let eventType: string;
    switch (action) {
      case "accept":
        nextStatus = "accepted";
        eventType = "accepted";
        break;
      case "decline":
        nextStatus = "declined";
        eventType = "declined";
        break;
      case "request_media":
        nextStatus = "media_requested";
        eventType = "media_requested";
        break;
      case "accept_media":
        nextStatus = "accepted";
        eventType = "media_accepted";
        break;
      case "decline_media":
        nextStatus = "accepted";
        eventType = "media_declined";
        break;
      case "cancel":
        nextStatus = "cancelled";
        eventType = "cancelled";
        break;
      case "end":
        nextStatus = "ended";
        eventType = "ended";
        break;
      default:
        throw new HttpError(400, "Geçersiz görüşme işlemi", "VALIDATION_ERROR");
    }

    const updates: Record<string, unknown> = { status: nextStatus };
    if (action === "accept") {
      updates.accepted_mode = "text";
      updates.answered_at = now;
    }
    if (action === "request_media") updates.accepted_mode = mode;
    if (action === "accept_media") updates.answered_at = now;
    if (action === "decline_media") {
      updates.accepted_mode = "text";
      updates.answered_at = now;
    }
    if (["decline", "cancel", "end"].includes(action)) updates.closed_at = now;

    const { data: updated, error: updateError } = await admin.from("rings")
      .update(updates).eq("id", ringId).eq("status", ring.status)
      .select("id, status, requested_mode, accepted_mode, answered_at, closed_at")
      .maybeSingle();
    if (updateError) throw new Error(updateError.message);
    if (!updated) {
      throw new HttpError(409, "Görüşme durumu başka bir cihazda değişti", "STATE_CONFLICT");
    }

    await admin.from("ring_events").insert({
      ring_id: ringId,
      event_type: eventType,
      actor_type: isVisitor ? "visitor" : "host",
      actor_user_id: user.id,
      metadata: { mode: updated.accepted_mode ?? ring.requested_mode },
    });
    if (action === "decline_media") {
      await admin.from("chat_messages").insert({
        ring_id: ringId,
        sender_type: "system",
        message_text: "Ziyaretçi sesli/görüntülü görüşme isteğini reddetti. Mesajlaşma açık.",
      });
    }

    if (action === "end" && ring.answered_at && ["audio", "video"].includes(ring.accepted_mode ?? "")) {
      const seconds = Math.max(
        0,
        Math.min(
          ring.accepted_mode === "video" ? 60 : 7200,
          Math.floor((Date.now() - new Date(ring.answered_at).getTime()) / 1000),
        ),
      );
      const periodStart = new Date();
      periodStart.setUTCDate(1);
      periodStart.setUTCHours(0, 0, 0, 0);
      await admin.from("usage_monthly").upsert({
        user_id: ownerUserId,
        period_start: periodStart.toISOString().slice(0, 10),
      }, { onConflict: "user_id,period_start", ignoreDuplicates: true });
      const field = ring.accepted_mode === "video" ? "video_seconds" : "audio_seconds";
      const { data: usage } = await admin.from("usage_monthly")
        .select("audio_seconds, video_seconds").eq("user_id", ownerUserId)
        .eq("period_start", periodStart.toISOString().slice(0, 10)).single();
      await admin.from("usage_monthly").update({
        [field]: Number(usage?.[field] ?? 0) + seconds,
        updated_at: now,
      }).eq("user_id", ownerUserId).eq("period_start", periodStart.toISOString().slice(0, 10));
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
