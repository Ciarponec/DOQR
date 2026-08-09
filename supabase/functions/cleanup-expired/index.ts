import {
  errorResponse,
  getEnv,
  HttpError,
  json,
  options,
  serviceClient,
} from "../_shared/utils.ts";

function timingSafeEqual(left: string, right: string): boolean {
  const a = new TextEncoder().encode(left);
  const b = new TextEncoder().encode(right);
  if (a.length !== b.length) return false;
  let difference = 0;
  for (let index = 0; index < a.length; index++) {
    difference |= a[index] ^ b[index];
  }
  return difference === 0;
}

Deno.serve(async (req) => {
  const preflight = options(req);
  if (preflight) return preflight;
  try {
    if (req.method !== "POST") {
      return json(405, { error: "Method not allowed" }, req);
    }
    const supplied = req.headers.get("x-cron-secret") ?? "";
    if (!timingSafeEqual(supplied, getEnv("CLEANUP_CRON_SECRET"))) {
      throw new HttpError(401, "Unauthorized", "AUTH_INVALID");
    }
    const { data, error } = await serviceClient().rpc("purge_doorbell_data");
    if (error) throw new Error(error.message);
    return json(200, data, req);
  } catch (error) {
    return errorResponse(error, req);
  }
});
