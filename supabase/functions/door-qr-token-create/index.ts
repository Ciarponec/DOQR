import {
  cleanText,
  errorResponse,
  HttpError,
  json,
  options,
  randomSecret,
  readJson,
  requirePermanentUser,
  serviceClient,
  sha256Hex,
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
    const doorId = cleanText(body.door_id, 36, true)!;
    const expiresMinutes = body.expires_minutes == null
      ? null
      : Number(body.expires_minutes);
    if (
      expiresMinutes != null &&
      (!Number.isInteger(expiresMinutes) ||
        expiresMinutes < 10 ||
        expiresMinutes > 2_628_000)
    ) {
      throw new HttpError(
        400,
        "QR süresi 10 dakika ile 5 yıl arasında olmalı",
        "VALIDATION_ERROR",
      );
    }

    const admin = serviceClient();
    const { data: door, error: doorError } = await admin.from("doors")
      .select("id, owner_user_id")
      .eq("id", doorId)
      .maybeSingle();
    if (doorError) throw new Error(doorError.message);
    if (!door) {
      throw new HttpError(404, "Dijital zil bulunamadı", "DOOR_NOT_FOUND");
    }
    if (door.owner_user_id !== user.id) {
      throw new HttpError(
        403,
        "Yalnızca dijital zil sahibi QR kodu üretebilir",
        "FORBIDDEN",
      );
    }

    const raw = randomSecret(32);
    const expiresAt = expiresMinutes == null
      ? null
      : new Date(Date.now() + expiresMinutes * 60_000).toISOString();
    const { data, error } = await admin.from("door_public_tokens").insert({
      door_id: doorId,
      token_hash: await sha256Hex(raw),
      expires_at: expiresAt,
    }).select("id, expires_at").single();
    if (error) throw new Error(error.message);

    return json(201, {
      qr_token: raw,
      token_id: data.id,
      expires_at: data.expires_at,
    }, req);
  } catch (error) {
    return errorResponse(error, req);
  }
});
