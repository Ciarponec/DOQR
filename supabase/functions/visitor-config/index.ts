import {
  errorResponse,
  getEnv,
  getPublishableKey,
  json,
  options,
} from "../_shared/utils.ts";

Deno.serve(async (req) => {
  const preflight = options(req);
  if (preflight) return preflight;
  try {
    if (req.method !== "GET") {
      return json(405, { error: "Method not allowed" }, req);
    }
    return json(200, {
      supabase_url: getEnv("SUPABASE_URL"),
      supabase_publishable_key: getPublishableKey(),
      turnstile_site_key: Deno.env.get("TURNSTILE_SITE_KEY") ?? null,
      consent_version: Deno.env.get("VISITOR_CONSENT_VERSION") ?? "2026-08-01",
      build: "2026-08-digital-doorbell",
    }, req);
  } catch (error) {
    return errorResponse(error, req);
  }
});
