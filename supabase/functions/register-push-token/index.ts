import { json, requireUser, serviceClient } from "../_shared/utils.ts";

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return json(405, { error: "Method not allowed" });
    const user = await requireUser(req.headers.get("Authorization") ?? undefined);
    const { fcm_token, platform } = await req.json();
    if (!fcm_token) return json(400, { error: "fcm_token required" });

    const admin = serviceClient();
    const { error } = await admin.from("user_push_tokens").upsert({
      user_id: user.id,
      fcm_token,
      platform: platform ?? null,
      updated_at: new Date().toISOString(),
    }, { onConflict: "user_id,fcm_token" });

    if (error) return json(500, { error: error.message });
    return json(200, { saved: true });
  } catch (e) {
    return json(401, { error: e.message ?? "Unauthorized" });
  }
});
