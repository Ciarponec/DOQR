import { json, serviceClient, sha256Hex } from "../_shared/utils.ts";

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

    const { data: ring, error: ringErr } = await admin
      .from("rings")
      .insert({
        door_id: tokenRow.door_id,
        visitor_alias: visitor_alias ?? null,
        source_token_hash: tokenHash,
        status: "pending",
      })
      .select("id, door_id, status, created_at")
      .single();

    if (ringErr) return json(500, { error: ringErr.message });

    await admin.functions.invoke("notify-ring", {
      body: { ring_id: ring.id },
    });

    return json(200, {
      ring_id: ring.id,
      door_id: ring.door_id,
      chat_session: ring.id,
      status: ring.status,
      created_at: ring.created_at,
    });
  } catch (e) {
    return json(500, { error: e.message ?? "Unexpected error" });
  }
});
