import {
  cleanText,
  errorResponse,
  HttpError,
  json,
  options,
  readJson,
  requirePermanentUser,
  serviceClient,
} from "../_shared/utils.ts";

Deno.serve(async (req) => {
  const preflight = options(req);
  if (preflight) return preflight;
  try {
    if (req.method !== "POST") {
      return json(405, { error: "Method not allowed" }, req);
    }
    const user = await requirePermanentUser(
      req.headers.get("Authorization") ?? undefined,
    );
    const body = await readJson<Record<string, unknown>>(req);
    const action = cleanText(body.action, 12) ?? "register";
    const token = cleanText(body.fcm_token, 4096, true)!;
    const admin = serviceClient();
    if (action === "unregister") {
      const { error } = await admin.from("user_push_tokens").delete().eq(
        "user_id",
        user.id,
      ).eq("fcm_token", token);
      if (error) throw new Error(error.message);
      return json(200, { removed: true }, req);
    }
    if (action !== "register") {
      throw new HttpError(400, "Geçersiz işlem", "VALIDATION_ERROR");
    }

    const { error: profileError } = await admin.from("users").upsert({
      id: user.id,
    }, { onConflict: "id" });
    if (profileError) throw new Error(profileError.message);

    const platform = cleanText(body.platform, 20);
    if (platform && !["android", "ios", "web"].includes(platform)) {
      throw new HttpError(400, "Geçersiz platform", "VALIDATION_ERROR");
    }
    const now = new Date().toISOString();
    const { error } = await admin.from("user_push_tokens").upsert({
      user_id: user.id,
      fcm_token: token,
      platform,
      device_id: cleanText(body.device_id, 200),
      app_version: cleanText(body.app_version, 40),
      locale: cleanText(body.locale, 20),
      disabled_at: null,
      last_seen_at: now,
      updated_at: now,
    }, { onConflict: "fcm_token" });
    if (error) throw new Error(error.message);
    return json(200, { saved: true }, req);
  } catch (error) {
    return errorResponse(error, req);
  }
});
