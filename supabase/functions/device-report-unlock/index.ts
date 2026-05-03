import { json, serviceClient, sha256Hex } from "../_shared/utils.ts";

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return json(405, { error: "Method not allowed" });
    const { device_identifier, device_token, unlock_request_id, result } = await req.json();
    if (!device_identifier || !device_token || !unlock_request_id || !result) {
      return json(400, { error: "device credentials, unlock_request_id, result required" });
    }

    const allowed = new Set(["success", "failed", "timeout"]);
    if (!allowed.has(result)) return json(400, { error: "Invalid result" });

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

    const { data: reqRow, error: reqErr } = await admin
      .from("door_unlock_requests")
      .select("id, door_id, claimed_by_device_id, state")
      .eq("id", unlock_request_id)
      .maybeSingle();
    if (reqErr) return json(500, { error: reqErr.message });
    if (!reqRow) return json(404, { error: "Unlock request not found" });
    if (reqRow.door_id !== device.door_id) return json(403, { error: "Cross-door access blocked" });
    if (reqRow.claimed_by_device_id !== device.id) return json(409, { error: "Request not claimed by this device" });
    if (reqRow.state !== "claimed") return json(409, { error: "Request not claimable" });

    const nowIso = new Date().toISOString();
    const { error: updErr } = await admin
      .from("door_unlock_requests")
      .update({ state: result, resolved_at: nowIso })
      .eq("id", unlock_request_id)
      .eq("state", "claimed");
    if (updErr) return json(500, { error: updErr.message });

    await admin.from("door_unlock_logs").insert({
      unlock_request_id,
      door_id: reqRow.door_id,
      actor_type: "device",
      actor_device_id: device.id,
      event_type: `unlock_${result}`,
      details: {},
    });

    return json(200, { updated: true, state: result });
  } catch (e) {
    return json(500, { error: e.message ?? "Unexpected error" });
  }
});
