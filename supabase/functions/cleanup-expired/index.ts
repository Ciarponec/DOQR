import { json, serviceClient } from "../_shared/utils.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "Method not allowed" });
  try {
    const admin = serviceClient();
    const nowIso = new Date().toISOString();

    const { error: qrErr } = await admin
      .from("door_public_tokens")
      .update({ revoked_at: nowIso })
      .is("revoked_at", null)
      .lt("expires_at", nowIso);
    if (qrErr) return json(500, { error: qrErr.message });

    const { error: shareErr } = await admin
      .from("door_share_tokens")
      .update({ revoked_at: nowIso })
      .is("revoked_at", null)
      .lt("expires_at", nowIso);
    if (shareErr) return json(500, { error: shareErr.message });

    const { error: ringErr } = await admin
      .from("rings")
      .update({ status: "missed", closed_at: nowIso })
      .eq("status", "pending")
      .lt("created_at", new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString());
    if (ringErr) return json(500, { error: ringErr.message });

    return json(200, { cleaned: true, at: nowIso });
  } catch (e) {
    return json(500, { error: e.message ?? "Unexpected error" });
  }
});
