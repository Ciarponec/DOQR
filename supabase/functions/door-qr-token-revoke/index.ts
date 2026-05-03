import { json, requireUser, serviceClient } from "../_shared/utils.ts";

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return json(405, { error: "Method not allowed" });
    const user = await requireUser(req.headers.get("Authorization") ?? undefined);
    const { token_id } = await req.json();
    if (!token_id) return json(400, { error: "token_id required" });

    const admin = serviceClient();
    const { data: token, error: tErr } = await admin.from("door_public_tokens").select("id, door_id").eq("id", token_id).single();
    if (tErr || !token) return json(404, { error: "Token not found" });

    const { data: door, error: dErr } = await admin.from("doors").select("owner_user_id").eq("id", token.door_id).single();
    if (dErr || !door) return json(404, { error: "Door not found" });
    if (door.owner_user_id !== user.id) return json(403, { error: "Forbidden" });

    const { error } = await admin.from("door_public_tokens").update({ revoked_at: new Date().toISOString() }).eq("id", token_id);
    if (error) return json(500, { error: error.message });

    return json(200, { revoked: true });
  } catch (e) {
    return json(401, { error: e.message ?? "Unauthorized" });
  }
});
