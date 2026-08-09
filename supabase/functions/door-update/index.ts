import { getOwnerPlan } from "../_shared/plans.ts";
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
    const doorId = cleanText(body.door_id, 36, true)!;
    const label = cleanText(body.label, 80, true)!;
    const address = cleanText(body.address_text, 300);
    const welcome = cleanText(body.welcome_message, 280);
    const admin = serviceClient();
    const { data: door, error: doorError } = await admin
      .from("doors")
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
        "Yalnızca sahibi ayarları değiştirebilir",
        "FORBIDDEN",
      );
    }
    const plan = await getOwnerPlan(admin, user.id);
    const textEnabled = body.text_enabled !== false;
    const audioEnabled = body.audio_enabled === true;
    const videoEnabled = body.video_enabled === true;
    if (
      (audioEnabled && plan.features.audio_call !== true) ||
      (videoEnabled && plan.features.video_call !== true)
    ) {
      throw new HttpError(
        402,
        "Sesli ve görüntülü görüşme Pro planı gerektiriyor",
        "PRO_REQUIRED",
      );
    }
    if (!textEnabled && !audioEnabled && !videoEnabled) {
      throw new HttpError(
        400,
        "En az bir görüşme seçeneği açık olmalı",
        "NO_MODES_ENABLED",
      );
    }
    const timeout = Number(body.ring_timeout_seconds ?? 45);
    if (!Number.isInteger(timeout) || timeout < 15 || timeout > 120) {
      throw new HttpError(
        400,
        "Zil bekleme süresi 15–120 saniye olmalı",
        "VALIDATION_ERROR",
      );
    }

    const [
      { data: updatedDoor, error },
      { data: settings, error: settingsError },
    ] = await Promise.all([
      admin.from("doors").update({
        label,
        address_text: address,
        is_active: body.is_active !== false,
      }).eq("id", doorId).select("id, label, address_text, is_active").single(),
      admin.from("door_settings").upsert({
        door_id: doorId,
        welcome_message: welcome,
        text_enabled: textEnabled,
        audio_enabled: audioEnabled,
        video_enabled: videoEnabled,
        require_visitor_name: body.require_visitor_name === true,
        ring_timeout_seconds: timeout,
        updated_at: new Date().toISOString(),
      }, { onConflict: "door_id" }).select(
        "welcome_message, text_enabled, audio_enabled, video_enabled, require_visitor_name, ring_timeout_seconds",
      ).single(),
    ]);
    if (error || settingsError) {
      throw new Error(
        error?.message ?? settingsError?.message ?? "Update failed",
      );
    }
    return json(200, { ...updatedDoor, settings, plan_id: plan.id }, req);
  } catch (error) {
    return errorResponse(error, req);
  }
});
