import { json, requireUser, serviceClient } from "../_shared/utils.ts";

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return json(405, { error: "Method not allowed" });
    const user = await requireUser(req.headers.get("Authorization") ?? undefined);
    const { door_id, label, address_text } = await req.json();
    if (!door_id) return json(400, { error: "door_id required" });
    if (!label || typeof label !== "string") return json(400, { error: "label required" });

    const admin = serviceClient();
    const { data: door, error: doorErr } = await admin
      .from("doors")
      .select("id, owner_user_id")
      .eq("id", door_id)
      .single();
    if (doorErr || !door) return json(404, { error: "Door not found" });
    if (door.owner_user_id !== user.id) return json(403, { error: "Only owner can edit door" });

    const { data, error } = await admin
      .from("doors")
      .update({ label: label.trim(), address_text: typeof address_text === "string" ? (address_text.trim() || null) : null })
      .eq("id", door_id)
      .select("id,label,address_text")
      .single();

    if (error) return json(500, { error: error.message });
    return json(200, data);
  } catch (e) {
    return json(401, { error: e.message ?? "Unauthorized" });
  }
});
