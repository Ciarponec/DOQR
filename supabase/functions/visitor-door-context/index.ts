import { enabledModes, getOwnerPlan } from "../_shared/plans.ts";
import {
  cleanText,
  errorResponse,
  HttpError,
  json,
  options,
  readJson,
  requireAnonymousUser,
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
    await requireAnonymousUser(req.headers.get("Authorization") ?? undefined);
    const body = await readJson<{ qr_token?: unknown }>(req);
    const qrToken = cleanText(body.qr_token, 256, true)!;
    const admin = serviceClient();
    const tokenHash = await sha256Hex(qrToken);
    const { data: token, error: tokenError } = await admin
      .from("door_public_tokens")
      .select(
        "door_id, revoked_at, expires_at, doors!inner(id, label, owner_user_id, is_active)",
      )
      .eq("token_hash", tokenHash)
      .maybeSingle();
    if (tokenError) throw new Error(tokenError.message);
    if (!token || token.revoked_at) {
      throw new HttpError(404, "QR kodu geçersiz", "QR_INVALID");
    }
    if (
      token.expires_at && new Date(token.expires_at).getTime() <= Date.now()
    ) {
      throw new HttpError(410, "QR kodunun süresi dolmuş", "QR_EXPIRED");
    }
    const door = Array.isArray(token.doors) ? token.doors[0] : token.doors;
    if (!door?.is_active) {
      throw new HttpError(
        410,
        "Bu dijital zil şu anda aktif değil",
        "DOOR_INACTIVE",
      );
    }

    const [{ data: settings, error: settingsError }, plan] = await Promise.all([
      admin.from("door_settings").select(
        "welcome_message, text_enabled, audio_enabled, video_enabled, require_visitor_name, ring_timeout_seconds",
      ).eq("door_id", token.door_id).single(),
      getOwnerPlan(admin, door.owner_user_id),
    ]);
    if (settingsError || !settings) {
      throw new Error(settingsError?.message ?? "Door settings missing");
    }
    const modes = enabledModes(settings, plan);
    const mediaAvailability: { available: boolean; reason: string | null } = {
      available: modes.audio || modes.video,
      reason: null,
    };
    if (!Object.values(modes).some(Boolean)) {
      throw new HttpError(
        503,
        "Host şu anda görüşme kabul etmiyor",
        "NO_MODES_AVAILABLE",
      );
    }

    const commonCouriers = [
      { code: "hepsijet", label: "HepsiJET" },
      { code: "trendyol_express", label: "Trendyol Express" },
      { code: "yurtici", label: "Yurtiçi Kargo" },
      { code: "aras", label: "Aras Kargo" },
      { code: "mng", label: "DHL eCommerce (MNG)" },
      { code: "surat", label: "Sürat Kargo" },
      { code: "ptt", label: "PTT Kargo" },
      { code: "ups", label: "UPS" },
      { code: "amazon", label: "Amazon teslimatı" },
      { code: "diger", label: "Diğer kurye" },
    ];
    const courierMap = new Map(
      commonCouriers.map((courier) => [courier.code, courier.label]),
    );
    if (plan.features.courier_notes === true) {
      const now = new Date().toISOString();
      const { data: notes, error: noteError } = await admin
        .from("courier_notes")
        .select("courier_code, courier_label")
        .eq("door_id", token.door_id)
        .eq("is_active", true)
        .or(`active_from.is.null,active_from.lte.${now}`)
        .or(`active_until.is.null,active_until.gt.${now}`)
        .order("courier_label");
      if (noteError) throw new Error(noteError.message);
      for (const note of notes ?? []) {
        courierMap.set(note.courier_code, note.courier_label);
      }
    }
    const couriers = [...courierMap.entries()].map(([code, label]) => ({
      code,
      label,
    }));

    return json(200, {
      door: {
        label: door.label,
        welcome_message: settings.welcome_message,
        require_visitor_name: settings.require_visitor_name,
      },
      modes,
      media: mediaAvailability,
      couriers,
      plan: { courier_notes: plan.features.courier_notes === true },
    }, req);
  } catch (error) {
    return errorResponse(error, req);
  }
});
