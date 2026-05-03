import { json, requireUser, serviceClient } from "../_shared/utils.ts";

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return json(405, { error: "Method not allowed" });
    const auth = req.headers.get("Authorization") ?? undefined;
    const user = await requireUser(auth);

    const { ring_id, message_text } = await req.json();
    if (!ring_id || !message_text) return json(400, { error: "ring_id and message_text required" });

    const admin = serviceClient();
    const { data: ring, error: ringErr } = await admin
      .from("rings")
      .select("id, door_id")
      .eq("id", ring_id)
      .single();
    if (ringErr || !ring) return json(404, { error: "Ring not found" });

    const { data: member, error: memberErr } = await admin
      .rpc("is_door_member", { _door_id: ring.door_id, _user_id: user.id });
    if (memberErr) return json(500, { error: memberErr.message });
    if (!member) return json(403, { error: "Not authorized" });

    const { data, error } = await admin
      .from("chat_messages")
      .insert({
        ring_id,
        sender_type: "owner",
        sender_user_id: user.id,
        message_text,
      })
      .select("id, created_at")
      .single();

    if (error) return json(500, { error: error.message });
    return json(200, { message_id: data.id, created_at: data.created_at });
  } catch (e) {
    return json(401, { error: e.message ?? "Unauthorized" });
  }
});
