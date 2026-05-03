import { json, randomSecret, requireUser, serviceClient, sha256Hex } from "../_shared/utils.ts";

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return json(405, { error: "Method not allowed" });
    const user = await requireUser(req.headers.get("Authorization") ?? undefined);
    const { door_id, expires_minutes = 1440, pin, max_uses = 1 } = await req.json();
    if (!door_id) return json(400, { error: "door_id required" });

    const admin = serviceClient();
    const { data: door, error: doorErr } = await admin
      .from("doors")
      .select("id, owner_user_id")
      .eq("id", door_id)
      .single();
    if (doorErr || !door) return json(404, { error: "Door not found" });
    if (door.owner_user_id !== user.id) return json(403, { error: "Only owner can create share token" });

    const rawToken = randomSecret(24);
    const tokenHash = await sha256Hex(rawToken);
    const pinHash = pin ? await sha256Hex(String(pin)) : null;
    const expiresAt = new Date(Date.now() + Number(expires_minutes) * 60_000).toISOString();

    const { data, error } = await admin
      .from("door_share_tokens")
      .insert({
        door_id,
        token_hash: tokenHash,
        pin_hash: pinHash,
        expires_at: expiresAt,
        max_uses,
        created_by: user.id,
      })
      .select("id, expires_at, max_uses")
      .single();
    if (error) return json(500, { error: error.message });

    return json(200, { share_token: rawToken, share_token_id: data.id, expires_at: data.expires_at, max_uses: data.max_uses });
  } catch (e) {
    return json(401, { error: e.message ?? "Unauthorized" });
  }
});
