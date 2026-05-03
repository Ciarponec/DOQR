import { json, requireUser, serviceClient, sha256Hex } from "../_shared/utils.ts";

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return json(405, { error: "Method not allowed" });
    const user = await requireUser(req.headers.get("Authorization") ?? undefined);
    const { share_token, pin } = await req.json();
    if (!share_token) return json(400, { error: "share_token required" });

    const admin = serviceClient();
    const tokenHash = await sha256Hex(share_token);
    const { data: tokenRow, error: tokenErr } = await admin
      .from("door_share_tokens")
      .select("id, door_id, pin_hash, expires_at, revoked_at, used_count, max_uses")
      .eq("token_hash", tokenHash)
      .maybeSingle();
    if (tokenErr) return json(500, { error: tokenErr.message });
    if (!tokenRow) return json(404, { error: "Token invalid" });
    if (tokenRow.revoked_at) return json(410, { error: "Token revoked" });
    if (new Date(tokenRow.expires_at).getTime() < Date.now()) return json(410, { error: "Token expired" });
    if (tokenRow.used_count >= tokenRow.max_uses) return json(409, { error: "Token usage exceeded" });

    if (tokenRow.pin_hash) {
      if (!pin) return json(400, { error: "PIN required" });
      const inHash = await sha256Hex(String(pin));
      if (inHash !== tokenRow.pin_hash) return json(403, { error: "PIN invalid" });
    }

    const { error: upsertErr } = await admin
      .from("door_shared_users")
      .upsert({
        door_id: tokenRow.door_id,
        user_id: user.id,
        permission: "notify_chat",
        granted_by: user.id,
      }, { onConflict: "door_id,user_id" });
    if (upsertErr) return json(500, { error: upsertErr.message });

    const { error: usageErr } = await admin
      .from("door_share_tokens")
      .update({ used_count: tokenRow.used_count + 1 })
      .eq("id", tokenRow.id);
    if (usageErr) return json(500, { error: usageErr.message });

    return json(200, { door_id: tokenRow.door_id, accepted: true });
  } catch (e) {
    return json(401, { error: e.message ?? "Unauthorized" });
  }
});
