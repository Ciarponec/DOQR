import { json, randomSecret, serviceClient, sha256Hex } from "../_shared/utils.ts";

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return json(405, { error: "Method not allowed" });
    const { qr_token, visitor_alias } = await req.json();
    if (!qr_token || typeof qr_token !== "string") return json(400, { error: "qr_token required" });

    const tokenHash = await sha256Hex(qr_token);
    const admin = serviceClient();

    const { data: tokenRow, error: tokenErr } = await admin
      .from("door_public_tokens")
      .select("door_id, revoked_at, expires_at")
      .eq("token_hash", tokenHash)
      .maybeSingle();
    if (tokenErr) return json(500, { error: tokenErr.message });
    if (!tokenRow) return json(404, { error: "Invalid QR" });
    if (tokenRow.revoked_at) return json(410, { error: "QR revoked" });
    if (tokenRow.expires_at && new Date(tokenRow.expires_at).getTime() < Date.now()) {
      return json(410, { error: "QR expired" });
    }

    const visitorSessionToken = randomSecret(24);
    const visitorSessionHash = await sha256Hex(visitorSessionToken);
    const sessionExpiresAt = new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString();

    const { data: ring, error: ringErr } = await admin
      .from("rings")
      .insert({
        door_id: tokenRow.door_id,
        visitor_alias: visitor_alias ?? null,
        source_token_hash: tokenHash,
        visitor_session_token_hash: visitorSessionHash,
        visitor_session_expires_at: sessionExpiresAt,
        status: "pending",
      })
      .select("id, door_id, status, created_at")
      .single();

    if (ringErr) return json(500, { error: ringErr.message });

    await admin.functions.invoke("notify-ring", { body: { ring_id: ring.id } });

    return json(200, {
      ring_id: ring.id,
      door_id: ring.door_id,
      chat_session: ring.id,
      visitor_session_token: visitorSessionToken,
      visitor_session_expires_at: sessionExpiresAt,
      status: ring.status,
      created_at: ring.created_at,
    });
  } catch (e) {
    return json(500, { error: e.message ?? "Unexpected error" });
  }
});
