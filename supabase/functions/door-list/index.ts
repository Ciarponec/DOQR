import { json, requireUser, serviceClient } from "../_shared/utils.ts";

Deno.serve(async (req) => {
  try {
    if (req.method !== "GET") return json(405, { error: "Method not allowed" });
    const user = await requireUser(req.headers.get("Authorization") ?? undefined);
    const admin = serviceClient();

    const { data: ownerDoors, error: ownerErr } = await admin
      .from("doors")
      .select("id,label,address_text")
      .eq("owner_user_id", user.id)
      .order("label");
    if (ownerErr) return json(500, { error: ownerErr.message });

    const { data: sharedRows, error: sharedErr } = await admin
      .from("door_shared_users")
      .select("door_id")
      .eq("user_id", user.id);
    if (sharedErr) return json(500, { error: sharedErr.message });

    const sharedIds = (sharedRows ?? []).map((r) => r.door_id);
    let sharedDoors: Array<{ id: string; label: string; address_text: string | null }> = [];
    if (sharedIds.length > 0) {
      const { data, error } = await admin
        .from("doors")
        .select("id,label,address_text")
        .in("id", sharedIds)
        .order("label");
      if (error) return json(500, { error: error.message });
      sharedDoors = data ?? [];
    }

    const map = new Map<string, { id: string; label: string; address_text: string | null }>();
    for (const d of ownerDoors ?? []) map.set(d.id, d);
    for (const d of sharedDoors) map.set(d.id, d);

    return json(200, { doors: Array.from(map.values()) });
  } catch (e) {
    return json(401, { error: e.message ?? "Unauthorized" });
  }
});
