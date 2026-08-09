import {
  cleanText,
  errorResponse,
  HttpError,
  json,
  options,
  readJson,
  requireAnonymousUser,
  serviceClient,
} from "../_shared/utils.ts";

Deno.serve(async (req) => {
  const preflight = options(req);
  if (preflight) return preflight;
  try {
    if (req.method !== "POST") {
      return json(405, { error: "Method not allowed" }, req);
    }
    const visitor = await requireAnonymousUser(
      req.headers.get("Authorization") ?? undefined,
    );
    const body = await readJson<
      { ring_id?: unknown; message_text?: unknown; client_message_id?: unknown }
    >(req);
    const ringId = cleanText(body.ring_id, 36, true)!;
    const message = cleanText(body.message_text, 2000, true)!;
    const clientMessageId = cleanText(body.client_message_id, 36);
    const admin = serviceClient();
    const { data: ring, error: ringError } = await admin
      .from("rings")
      .select("id, status, visitor_user_id, session_expires_at")
      .eq("id", ringId)
      .maybeSingle();
    if (ringError) throw new Error(ringError.message);
    if (!ring) throw new HttpError(404, "Ziyaret bulunamadı", "RING_NOT_FOUND");
    if (ring.visitor_user_id !== visitor.id) {
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
    if (!["pending", "accepted"].includes(ring.status)) {
      throw new HttpError(409, "Bu görüşme sona ermiş", "RING_CLOSED");
    }

    const { data, error } = await admin
      .from("chat_messages")
      .insert({
        ring_id: ringId,
        sender_type: "visitor",
        sender_user_id: visitor.id,
        message_text: message,
        client_message_id: clientMessageId,
      })
      .select("id, ring_id, sender_type, message_text, created_at")
      .single();
    if (error?.code === "23505" && clientMessageId) {
      const { data: existing, error: existingError } = await admin
        .from("chat_messages")
        .select("id, ring_id, sender_type, message_text, created_at")
        .eq("ring_id", ringId)
        .eq("sender_user_id", visitor.id)
        .eq("client_message_id", clientMessageId)
        .single();
      if (existingError) throw new Error(existingError.message);
      return json(200, existing, req);
    }
    if (error) throw new Error(error.message);
    await admin.from("rings").update({
      visitor_last_seen_at: new Date().toISOString(),
    }).eq("id", ringId);
    return json(201, data, req);
  } catch (error) {
    return errorResponse(error, req);
  }
});
