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
      return json(405, { error: "Method not allowed", code: "METHOD_NOT_ALLOWED" }, req);
    }
    const user = await requirePermanentUser(
      req.headers.get("Authorization") ?? undefined,
    );
    const body = await readJson<Record<string, unknown>>(req);
    const doorId = cleanText(body.door_id, 36, true)!;
    const admin = serviceClient();
    const { data: door, error: doorError } = await admin.from("doors")
      .select("id, owner_user_id").eq("id", doorId).maybeSingle();
    if (doorError) throw new Error(doorError.message);
    if (!door) throw new HttpError(404, "Dijital zil bulunamadı", "DOOR_NOT_FOUND");
    if (door.owner_user_id !== user.id) {
      throw new HttpError(403, "Yalnızca kapı sahibi silebilir", "FORBIDDEN");
    }
    const { count, error: ringError } = await admin.from("rings")
      .select("id", { count: "exact", head: true }).eq("door_id", doorId)
      .in("status", ["pending", "media_requested", "accepted"]);
    if (ringError) throw new Error(ringError.message);
    if ((count ?? 0) > 0) {
      throw new HttpError(409, "Aktif ziyaret sona ermeden dijital zil silinemez", "DOOR_HAS_ACTIVE_SESSION");
    }
    const { error } = await admin.from("doors").delete().eq("id", doorId);
    if (error) throw new Error(error.message);
    return json(200, { deleted: true }, req);
  } catch (error) {
    return errorResponse(error, req);
  }
});
