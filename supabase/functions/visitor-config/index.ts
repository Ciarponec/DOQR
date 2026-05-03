import { json, getEnv } from "../_shared/utils.ts";

Deno.serve(async (req) => {
  if (req.method !== "GET") return json(405, { error: "Method not allowed" });
  try {
    return json(200, {
      supabase_url: getEnv("SUPABASE_URL"),
      supabase_anon_key: getEnv("VISITOR_ANON_KEY"),
      build: "2026-05-03",
    });
  } catch (e) {
    return json(500, { error: e.message ?? "Config error" });
  }
});
