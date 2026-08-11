import { notifyDoorbell, runInBackground } from "../_shared/fcm.ts";
import { enabledModes, getOwnerPlan } from "../_shared/plans.ts";
import {
  cleanText,
  errorResponse,
  HttpError,
  json,
  options,
  readJson,
  requestIpHash,
  requireAnonymousUser,
  serviceClient,
  sha256Hex,
  visitorDeviceHash,
} from "../_shared/utils.ts";

type RingRequest = {
  qr_token?: unknown;
  visitor_alias?: unknown;
  visitor_kind?: unknown;
  courier_code?: unknown;
  requested_mode?: unknown;
  consent_version?: unknown;
  client?: {
    language?: unknown;
    timezone?: unknown;
    platform?: unknown;
    screen?: unknown;
    device_key?: unknown;
    hardware_concurrency?: unknown;
    device_memory?: unknown;
    touch_points?: unknown;
  };
};

async function consumeLimit(
  admin: ReturnType<typeof serviceClient>,
  scopeType: "door" | "ip" | "token" | "device",
  scopeKey: string,
  limit: number,
  windowSeconds: number,
  blockSeconds: number,
) {
  const { data, error } = await admin.rpc("consume_doorbell_rate_limit", {
    _scope_type: scopeType,
    _scope_key: scopeKey,
    _limit: limit,
    _window_seconds: windowSeconds,
    _block_seconds: blockSeconds,
  });
  if (error) throw new Error(error.message);
  if (data?.allowed !== true) {
    throw new HttpError(
      429,
      "Çok sık zil isteği gönderildi. Lütfen biraz bekleyin.",
      "RATE_LIMITED",
    );
  }
}

Deno.serve(async (req) => {
  const preflight = options(req);
  if (preflight) return preflight;
  try {
    if (req.method !== "POST") {
      return json(405, { error: "Method not allowed" }, req);
    }
    const visitor = await requireAnonymousUser(
      req.headers.get("Authorization") ?? undefined,
    );
    const body = await readJson<RingRequest>(req);
    const qrToken = cleanText(body.qr_token, 256, true)!;
    const visitorAlias = cleanText(body.visitor_alias, 80);
    const visitorKind = cleanText(body.visitor_kind, 20) ?? "guest";
    const courierCode = cleanText(body.courier_code, 40);
    const requestedMode = cleanText(body.requested_mode, 10, true)!;
    const consentVersion = cleanText(body.consent_version, 40, true)!;
    const currentConsent = Deno.env.get("VISITOR_CONSENT_VERSION") ??
      "2026-08-01";

    if (!["guest", "courier", "other"].includes(visitorKind)) {
      throw new HttpError(400, "Geçersiz ziyaretçi türü", "VALIDATION_ERROR");
    }
    if (requestedMode !== "text") {
      throw new HttpError(
        400,
        "Ziyaretçi yalnızca zili çalabilir; görüşme türünü host seçer",
        "VISITOR_MODE_NOT_ALLOWED",
      );
    }
    if (courierCode && !/^[a-z0-9_-]{2,40}$/.test(courierCode)) {
      throw new HttpError(400, "Geçersiz kurye kodu", "VALIDATION_ERROR");
    }
    if (consentVersion !== currentConsent) {
      throw new HttpError(
        409,
        "Güvenlik bilgilendirmesi güncellendi. Sayfayı yenileyin.",
        "CONSENT_OUTDATED",
      );
    }

    const admin = serviceClient();
    const tokenHash = await sha256Hex(qrToken);
    const ipHash = await requestIpHash(req);
    const deviceHash = await visitorDeviceHash(
      req,
      body.client as Record<string, unknown> | undefined,
    );
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
    const plan = await getOwnerPlan(admin, door.owner_user_id);

    if (plan.features.spam_protection === true) {
      const nowIso = new Date().toISOString();
      const { data: blockRows, error: blockError } = await admin
        .from("door_blocks")
        .select("block_type, value_hash, expires_at")
        .eq("door_id", token.door_id)
        .in("value_hash", [deviceHash, ipHash])
        .or(`expires_at.is.null,expires_at.gt.${nowIso}`);
      if (blockError) throw new Error(blockError.message);
      const blocked = (blockRows ?? []).some((row) =>
        (row.block_type === "device" && row.value_hash === deviceHash) ||
        (row.block_type === "network" && row.value_hash === ipHash)
      );
      if (blocked) {
        throw new HttpError(
          403,
          "Bu dijital zil bu cihazdan kullanılamıyor",
          "VISITOR_BLOCKED",
        );
      }
      await Promise.all([
        consumeLimit(admin, "device", `${token.door_id}:${deviceHash}`, 1, 30, 60),
        consumeLimit(admin, "ip", `${token.door_id}:${ipHash}`, 8, 60, 5 * 60),
        consumeLimit(admin, "door", token.door_id, 20, 60, 2 * 60),
      ]);
    } else {
      // Every door has a deliberately broad platform safety guard.  It is not
      // a user-facing anti-spam feature; Pro adds the tighter limits and blocks.
      await Promise.all([
        consumeLimit(admin, "device", `${token.door_id}:${deviceHash}`, 10, 60, 60),
        consumeLimit(admin, "ip", `${token.door_id}:${ipHash}`, 60, 60, 5 * 60),
        consumeLimit(admin, "door", token.door_id, 120, 60, 2 * 60),
      ]);
    }

    const { data: settings, error: settingsError } = await admin
      .from("door_settings")
      .select("text_enabled, audio_enabled, video_enabled, require_visitor_name, ring_timeout_seconds")
      .eq("door_id", token.door_id)
      .single();
    if (settingsError || !settings) {
      throw new Error(settingsError?.message ?? "Door settings missing");
    }
    if (settings.require_visitor_name && !visitorAlias) {
      throw new HttpError(
        400,
        "Host adınızı belirtmenizi istiyor",
        "VISITOR_NAME_REQUIRED",
      );
    }
    const modes = enabledModes(settings, plan);
    if (!Object.values(modes).some(Boolean)) {
      throw new HttpError(
        503,
        "Host şu anda görüşme kabul etmiyor",
        "NO_MODES_AVAILABLE",
      );
    }

    const { error: usageError } = await admin.rpc("reserve_doorbell_usage", {
      _owner_user_id: door.owner_user_id,
      _requested_mode: requestedMode,
    });
    if (usageError) {
      if (usageError.message.includes("PRO_REQUIRED")) {
        throw new HttpError(
          402,
          "Bu görüşme türü Pro planı gerektiriyor",
          "PRO_REQUIRED",
        );
      }
      if (usageError.message.includes("MONTHLY_RING_LIMIT")) {
        throw new HttpError(
          429,
          "Aylık kullanım sınırına ulaşıldı",
          "PLAN_LIMIT",
        );
      }
      if (
        usageError.message.includes("MONTHLY_AUDIO_LIMIT") ||
        usageError.message.includes("MONTHLY_VIDEO_LIMIT")
      ) {
        throw new HttpError(
          429,
          "Bu ayki adil kullanım süresi doldu",
          "MEDIA_FAIR_USE_LIMIT",
        );
      }
      throw new Error(usageError.message);
    }

    const metadata = {
      user_agent: cleanText(req.headers.get("user-agent"), 500),
      language: cleanText(body.client?.language, 40),
      timezone: cleanText(body.client?.timezone, 80),
      platform: cleanText(body.client?.platform, 80),
      screen: cleanText(body.client?.screen, 40),
      hardware_concurrency: Number(body.client?.hardware_concurrency ?? 0) ||
        null,
      device_memory: Number(body.client?.device_memory ?? 0) || null,
      touch_points: Number(body.client?.touch_points ?? 0) || null,
    };
    let matchedCourierNote: {
      id: string;
      message_text: string;
      courier_label: string;
    } | null = null;
    if (
      visitorKind === "courier" && courierCode &&
      plan.features.courier_notes === true
    ) {
      const now = new Date().toISOString();
      const { data: note, error: noteError } = await admin
        .from("courier_notes")
        .select("id, message_text, courier_label")
        .eq("door_id", token.door_id)
        .eq("courier_code", courierCode)
        .eq("is_active", true)
        .or(`active_from.is.null,active_from.lte.${now}`)
        .or(`active_until.is.null,active_until.gt.${now}`)
        .maybeSingle();
      if (noteError) throw new Error(noteError.message);
      matchedCourierNote = note ?? null;
    }

    const sessionExpiresAt = new Date(Date.now() + 2 * 60 * 60 * 1000)
      .toISOString();
    const { data: ring, error: ringError } = await admin
      .from("rings")
      .insert({
        door_id: token.door_id,
        visitor_user_id: visitor.id,
        visitor_alias: visitorAlias,
        visitor_kind: visitorKind,
        courier_code: visitorKind === "courier" ? courierCode : null,
        courier_note_id: matchedCourierNote?.id ?? null,
        requested_mode: requestedMode,
        source_token_hash: tokenHash,
        visitor_ip_hash: ipHash,
        visitor_device_hash: deviceHash,
        client_metadata: metadata,
        consent_version: consentVersion,
        session_expires_at: sessionExpiresAt,
        status: "pending",
      })
      .select("id, status, created_at")
      .single();
    if (ringError || !ring) {
      throw new Error(ringError?.message ?? "Ring insert failed");
    }

    await admin.from("ring_events").insert({
      ring_id: ring.id,
      event_type: "created",
      actor_type: "visitor",
      actor_user_id: visitor.id,
      metadata: { requested_mode: requestedMode, visitor_kind: visitorKind },
    });
    if (matchedCourierNote) {
      const { error: noteMessageError } = await admin.from("chat_messages")
        .insert({
          ring_id: ring.id,
          sender_type: "system",
          message_text: matchedCourierNote.message_text,
        });
      if (noteMessageError) throw new Error(noteMessageError.message);
    }

    const { data: sharedRows, error: sharedError } = await admin
      .from("door_shared_users")
      .select("user_id")
      .eq("door_id", token.door_id);
    if (sharedError) throw new Error(sharedError.message);
    const recipients = [
      door.owner_user_id,
      ...(sharedRows ?? []).map((row) => row.user_id),
    ];
    runInBackground(notifyDoorbell(admin, {
      ringId: ring.id,
      doorId: token.door_id,
      doorLabel: door.label,
      visitorAlias,
      requestedMode,
      courierNoteAvailable: matchedCourierNote != null,
      courierLabel: matchedCourierNote?.courier_label,
      recipientIds: [...new Set(recipients)],
    }));

    return json(201, {
      ring_id: ring.id,
      status: ring.status,
      requested_mode: requestedMode,
      ring_timeout_seconds: settings.ring_timeout_seconds,
      session_expires_at: sessionExpiresAt,
      created_at: ring.created_at,
      courier_note_available: matchedCourierNote != null,
      courier_note_revealed: matchedCourierNote != null,
    }, req);
  } catch (error) {
    return errorResponse(error, req);
  }
});
