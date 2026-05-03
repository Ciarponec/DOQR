import { json, requireUser, serviceClient } from "../_shared/utils.ts";

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return json(405, { error: "Method not allowed" });
    const user = await requireUser(req.headers.get("Authorization") ?? undefined);
    const { door_id, reason, ttl_seconds = 30, idempotency_key } = await req.json();

    if (!door_id) return json(400, { error: "door_id required" });
    const admin = serviceClient();

    const { data: ownerDoor, error: ownerErr } = await admin
      .from("doors")
      .select("id")
      .eq("id", door_id)
      .eq("owner_user_id", user.id)
      .maybeSingle();
    if (ownerErr) return json(500, { error: ownerErr.message });

    let canOpen = !!ownerDoor;
    if (!canOpen) {
      const { data: sharedPerm, error: sharedErr } = await admin
        .from("door_shared_users")
        .select("id")
        .eq("door_id", door_id)
        .eq("user_id", user.id)
        .eq("permission", "notify_chat_unlock")
        .maybeSingle();
      if (sharedErr) return json(500, { error: sharedErr.message });
      canOpen = !!sharedPerm;
    }
    if (!canOpen) return json(403, { error: "Not allowed" });

    const expiresAt = new Date(Date.now() + Number(ttl_seconds) * 1000).toISOString();
    const { data, error } = await admin
      .from("door_unlock_requests")
      .insert({
        door_id,
        requested_by: user.id,
        reason: reason ?? null,
        expires_at: expiresAt,
        idempotency_key: idempotency_key ?? null,
      })
      .select("id, state, expires_at, created_at")
      .single();

    if (error) return json(500, { error: error.message });

    await admin.from("door_unlock_logs").insert({
      unlock_request_id: data.id,
      door_id,
      actor_type: "user",
      actor_user_id: user.id,
      event_type: "unlock_requested",
      details: { reason: reason ?? null },
    });

    return json(200, data);
  } catch (e) {
    return json(401, { error: e.message ?? "Unauthorized" });
  }
});
