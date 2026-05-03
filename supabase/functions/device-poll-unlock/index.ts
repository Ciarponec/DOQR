import { json, serviceClient, sha256Hex } from "../_shared/utils.ts";

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return json(405, { error: "Method not allowed" });
    const { device_identifier, device_token } = await req.json();
    if (!device_identifier || !device_token) return json(400, { error: "device credentials required" });

    const admin = serviceClient();
    const tokenHash = await sha256Hex(device_token);

    const { data: device, error: devErr } = await admin
      .from("door_devices")
      .select("id, door_id, is_active")
      .eq("device_identifier", device_identifier)
      .eq("device_token_hash", tokenHash)
      .maybeSingle();
    if (devErr) return json(500, { error: devErr.message });
    if (!device || !device.is_active) return json(403, { error: "Device unauthorized" });

    const nowIso = new Date().toISOString();
    await admin.from("door_devices").update({ last_seen_at: nowIso }).eq("id", device.id);
    await admin.from("device_heartbeats").insert({ device_id: device.id, status: "online", metadata: {} });

    const { data: pending, error: reqErr } = await admin
      .from("door_unlock_requests")
      .select("id, door_id, expires_at, state")
      .eq("door_id", device.door_id)
      .eq("state", "pending")
      .gt("expires_at", nowIso)
      .order("created_at", { ascending: true })
      .limit(1)
      .maybeSingle();

    if (reqErr) return json(500, { error: reqErr.message });
    if (!pending) return json(200, { pending: false });

    const { error: claimErr } = await admin
      .from("door_unlock_requests")
      .update({ state: "claimed", claimed_by_device_id: device.id })
      .eq("id", pending.id)
      .eq("state", "pending");
    if (claimErr) return json(500, { error: claimErr.message });

    await admin.from("door_unlock_logs").insert({
      unlock_request_id: pending.id,
      door_id: pending.door_id,
      actor_type: "device",
      actor_device_id: device.id,
      event_type: "unlock_claimed",
      details: {},
    });

    return json(200, { pending: true, unlock_request_id: pending.id, door_id: pending.door_id, expires_at: pending.expires_at });
  } catch (e) {
    return json(500, { error: e.message ?? "Unexpected error" });
  }
});
