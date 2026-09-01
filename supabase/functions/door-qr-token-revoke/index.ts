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
    const admin = serviceClient();
    if (body.revoke_all === true) {
      const doorId = cleanText(body.door_id, 36, true)!;
      const { data: door, error: doorError } = await admin.from("doors")
        .select("id, owner_user_id").eq("id", doorId).maybeSingle();
      if (doorError) throw new Error(doorError.message);
      if (!door) throw new HttpError(404, "Dijital zil bulunamadı", "DOOR_NOT_FOUND");
      if (door.owner_user_id !== user.id) {
        throw new HttpError(403, "Bu QR kodlarını iptal edemezsiniz", "FORBIDDEN");
      }
      const { error } = await admin.from("door_public_tokens").update({
        revoked_at: new Date().toISOString(),
      }).eq("door_id", doorId).is("revoked_at", null);
      if (error) throw new Error(error.message);
      return json(200, { revoked: true }, req);
    }
    const tokenId = cleanText(body.token_id, 36, true)!;
    const { data: token, error: tokenError } = await admin
      .from("door_public_tokens")
      .select("id, door_id, doors!inner(owner_user_id)")
      .eq("id", tokenId)
      .maybeSingle();
    if (tokenError) throw new Error(tokenError.message);
    if (!token) throw new HttpError(404, "QR kaydı bulunamadı", "QR_NOT_FOUND");
    const door = Array.isArray(token.doors) ? token.doors[0] : token.doors;
    if (door?.owner_user_id !== user.id) {
      throw new HttpError(403, "Bu QR kodunu iptal edemezsiniz", "FORBIDDEN");
    }
    const { error } = await admin.from("door_public_tokens").update({
      revoked_at: new Date().toISOString(),
    }).eq("id", tokenId);
    if (error) throw new Error(error.message);
    return json(200, { revoked: true }, req);
  } catch (error) {
    return errorResponse(error, req);
  }
});
