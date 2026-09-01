import {
  cleanText,
  errorResponse,
  HttpError,
  json,
  options,
  requirePermanentUser,
  serviceClient,
} from "../_shared/utils.ts";

Deno.serve(async (req) => {
  const preflight = options(req);
  if (preflight) return preflight;
  try {
    if (req.method !== "GET") {
      return json(405, { error: "Method not allowed", code: "METHOD_NOT_ALLOWED" }, req);
    }
    const user = await requirePermanentUser(
      req.headers.get("Authorization") ?? undefined,
    );
    const doorId = cleanText(
      new URL(req.url).searchParams.get("door_id"),
      36,
      true,
    )!;
    const admin = serviceClient();
    const { data: door, error: doorError } = await admin.from("doors")
      .select("id, owner_user_id").eq("id", doorId).maybeSingle();
    if (doorError) throw new Error(doorError.message);
    if (!door) throw new HttpError(404, "Dijital zil bulunamadı", "DOOR_NOT_FOUND");
    if (door.owner_user_id !== user.id) {
      throw new HttpError(403, "QR kayıtlarını yalnızca kapı sahibi görebilir", "FORBIDDEN");
    }
    const { data, error } = await admin.from("door_public_tokens")
      .select("id, created_at, expires_at, revoked_at")
      .eq("door_id", doorId).order("created_at", { ascending: false });
    if (error) throw new Error(error.message);
    return json(200, {
      tokens: data ?? [],
      active_count: (data ?? []).filter((token) =>
        token.revoked_at == null &&
        (token.expires_at == null || new Date(token.expires_at).getTime() > Date.now())
      ).length,
    }, req);
  } catch (error) {
    return errorResponse(error, req);
  }
});
