import { json, serviceClient, sha256Hex } from "../_shared/utils.ts";

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return json(405, { error: "Method not allowed" });
    const { ring_id, visitor_session_token, message_text } = await req.json();
    if (!ring_id || !visitor_session_token || !message_text) {
      return json(400, { error: "ring_id, visitor_session_token, message_text required" });
    }

    const admin = serviceClient();
    const sessionHash = await sha256Hex(visitor_session_token);
    const { data: ring, error: ringErr } = await admin
      .from("rings")
      .select("id, door_id, status, visitor_session_token_hash, visitor_session_expires_at")
      .eq("id", ring_id)
      .maybeSingle();

    if (ringErr) return json(500, { error: ringErr.message });
    if (!ring) return json(404, { error: "Ring not found" });
    if (ring.visitor_session_token_hash !== sessionHash) return json(403, { error: "Invalid visitor session" });
    if (!ring.visitor_session_expires_at || new Date(ring.visitor_session_expires_at).getTime() < Date.now()) {
      return json(410, { error: "Visitor session expired" });
    }

    const { data, error } = await admin
      .from("chat_messages")
      .insert({ ring_id, sender_type: "visitor", message_text })
      .select("id, created_at")
      .single();

    if (error) return json(500, { error: error.message });
    await admin.from("rings").update({ visitor_last_seen_at: new Date().toISOString() }).eq("id", ring_id);

    return json(200, { message_id: data.id, created_at: data.created_at });
  } catch (e) {
    return json(500, { error: e.message ?? "Unexpected error" });
  }
});
