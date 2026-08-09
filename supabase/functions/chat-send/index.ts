import {
  cleanText,
  errorResponse,
  HttpError,
  json,
  options,
  readJson,
  requireDoorHost,
  requirePermanentUser,
  serviceClient,
} from "../_shared/utils.ts";

Deno.serve(async (req) => {
  const preflight = options(req);
  if (preflight) return preflight;
  try {
    if (req.method !== "POST") {
      return json(405, { error: "Method not allowed" }, req);
    }
    const user = await requirePermanentUser(
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
      .select("id, door_id, status")
      .eq("id", ringId)
      .maybeSingle();
    if (ringError) throw new Error(ringError.message);
    if (!ring) throw new HttpError(404, "Ziyaret bulunamadı", "RING_NOT_FOUND");
    await requireDoorHost(admin, ring.door_id, user.id);
    if (!["pending", "accepted"].includes(ring.status)) {
      throw new HttpError(409, "Bu görüşme sona ermiş", "RING_CLOSED");
    }

    const { data, error } = await admin
      .from("chat_messages")
      .insert({
        ring_id: ringId,
        sender_type: "host",
        sender_user_id: user.id,
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
        .eq("sender_user_id", user.id)
        .eq("client_message_id", clientMessageId)
        .single();
      if (existingError) throw new Error(existingError.message);
      return json(200, existing, req);
    }
    if (error) throw new Error(error.message);
    return json(201, data, req);
  } catch (error) {
    return errorResponse(error, req);
  }
});
