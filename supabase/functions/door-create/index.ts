import { json, requireUser, serviceClient } from "../_shared/utils.ts";

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return json(405, { error: "Method not allowed" });
    const user = await requireUser(req.headers.get("Authorization") ?? undefined);
    const { label, address_text } = await req.json();

    if (!label || typeof label !== "string") {
      return json(400, { error: "label required" });
    }

    const admin = serviceClient();

    const { error: upsertErr } = await admin
      .from("users")
      .upsert({ id: user.id }, { onConflict: "id" });
    if (upsertErr) return json(500, { error: `users upsert failed: ${upsertErr.message}` });

    const { data, error } = await admin
      .from("doors")
      .insert({
        owner_user_id: user.id,
        label: label.trim(),
        address_text: typeof address_text === "string" ? address_text.trim() || null : null,
      })
      .select("id, label, address_text")
      .single();

    if (error) return json(500, { error: `door create failed: ${error.message}` });
    return json(200, data);
  } catch (e) {
    return json(401, { error: e.message ?? "Unauthorized" });
  }
});
