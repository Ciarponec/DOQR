import {
  cleanText,
  errorResponse,
  HttpError,
  json,
  options,
  readJson,
  requirePermanentUser,
  serviceClient,
  sha256Hex,
} from "../_shared/utils.ts";

function shareError(message: string): HttpError | null {
  if (message.includes("SHARE_TOKEN_INVALID")) {
    return new HttpError(404, "Davet geçersiz", "SHARE_TOKEN_INVALID");
  }
  if (message.includes("SHARE_TOKEN_REVOKED")) {
    return new HttpError(410, "Davet iptal edilmiş", "SHARE_TOKEN_REVOKED");
  }
  if (message.includes("SHARE_TOKEN_EXPIRED")) {
    return new HttpError(410, "Davetin süresi dolmuş", "SHARE_TOKEN_EXPIRED");
  }
  if (message.includes("SHARE_TOKEN_USED")) {
    return new HttpError(
      409,
      "Davet kullanım sınırına ulaşmış",
      "SHARE_TOKEN_USED",
    );
  }
  if (message.includes("SHARE_PIN_INVALID")) {
    return new HttpError(403, "PIN yanlış", "SHARE_PIN_INVALID");
  }
  if (message.includes("HOST_PLAN_LIMIT")) {
    return new HttpError(402, "Host plan sınırına ulaşıldı", "HOST_PLAN_LIMIT");
  }
  return null;
}

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
    const token = cleanText(body.share_token, 256, true)!;
    const pin = cleanText(body.pin, 12);
    const admin = serviceClient();
    const { error: profileError } = await admin.from("users").upsert({
      id: user.id,
    }, { onConflict: "id" });
    if (profileError) throw new Error(profileError.message);
    const { data, error } = await admin.rpc("accept_door_share", {
      _user_id: user.id,
      _token_hash: await sha256Hex(token),
      _pin_hash: pin ? await sha256Hex(pin) : null,
    });
    if (error) throw shareError(error.message) ?? new Error(error.message);
    return json(200, data, req);
  } catch (error) {
    return errorResponse(error, req);
  }
});
