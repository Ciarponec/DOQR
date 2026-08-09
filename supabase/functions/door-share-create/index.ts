import { getOwnerPlan } from "../_shared/plans.ts";
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
    const pin = cleanText(body.pin, 12);
    if (pin && !/^\d{4,12}$/.test(pin)) {
      throw new HttpError(400, "PIN 4–12 rakam olmalı", "VALIDATION_ERROR");
    }
    const expiresMinutes = Number(body.expires_minutes ?? 1440);
    if (
      !Number.isInteger(expiresMinutes) ||
      expiresMinutes < 15 ||
      expiresMinutes > 10_080
    ) {
      throw new HttpError(
        400,
        "Davet süresi 15 dakika ile 7 gün arasında olmalı",
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
        "Yalnızca sahibi host davet edebilir",
        "FORBIDDEN",
      );
    }
    const [plan, { count, error: countError }] = await Promise.all([
      getOwnerPlan(admin, user.id),
      admin.from("door_shared_users").select("id", {
        count: "exact",
        head: true,
      }).eq("door_id", doorId),
    ]);
    if (countError) throw new Error(countError.message);
    const remaining = plan.max_hosts_per_door - 1 - (count ?? 0);
    if (remaining < 1) {
      throw new HttpError(
        402,
        "Planınızda bu dijital zil için boş host hakkı yok",
        "HOST_PLAN_LIMIT",
      );
    }
    const requestedUses = Number(body.max_uses ?? 1);
    if (
      !Number.isInteger(requestedUses) || requestedUses < 1 ||
      requestedUses > remaining
    ) {
      throw new HttpError(
        400,
        `Bu davet en fazla ${remaining} kez kullanılabilir`,
        "VALIDATION_ERROR",
      );
    }

    const rawToken = randomSecret(32);
    const { data, error } = await admin.from("door_share_tokens").insert({
      door_id: doorId,
      token_hash: await sha256Hex(rawToken),
      pin_hash: pin ? await sha256Hex(pin) : null,
      expires_at: new Date(Date.now() + expiresMinutes * 60_000).toISOString(),
      max_uses: requestedUses,
      created_by: user.id,
    }).select("id, expires_at, max_uses").single();
    if (error) throw new Error(error.message);
    return json(201, {
      share_token: rawToken,
      share_token_id: data.id,
      expires_at: data.expires_at,
      max_uses: data.max_uses,
    }, req);
  } catch (error) {
    return errorResponse(error, req);
  }
});
