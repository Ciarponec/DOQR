import { json, requireUser, serviceClient } from "../_shared/utils.ts";

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return json(405, { error: "Method not allowed" });
    const user = await requireUser(req.headers.get("Authorization") ?? undefined);
    const { door_id, expires_minutes = 43200 } = await req.json();
    if (!door_id) return json(400, { error: "door_id required" });

    const admin = serviceClient();
    const { data: door, error: dErr } = await admin.from("doors").select("id, owner_user_id").eq("id", door_id).single();
    if (dErr || !door) return json(404, { error: "Door not found" });
    if (door.owner_user_id !== user.id) return json(403, { error: "Only owner can generate QR tokens" });

    const { randomSecret, sha256Hex } = await import("../_shared/utils.ts");
    const raw = randomSecret(24);
    const hash = await sha256Hex(raw);
    const exp = new Date(Date.now() + Number(expires_minutes) * 60_000).toISOString();

    const { data, error } = await admin
      .from("door_public_tokens")
      .insert({ door_id, token_hash: hash, expires_at: exp })
      .select("id, expires_at")
      .single();
    if (error) return json(500, { error: error.message });

    return json(200, { qr_token: raw, token_id: data.id, expires_at: data.expires_at });
  } catch (e) {
    return json(401, { error: e.message ?? "Unauthorized" });
  }
});
