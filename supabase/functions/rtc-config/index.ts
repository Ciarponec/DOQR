import {
  cleanText,
  errorResponse,
  HttpError,
  json,
  options,
  readJson,
  requireDoorHost,
  requireUser,
  serviceClient,
} from "../_shared/utils.ts";
import {
  generateTurnIceServers,
  getTurnServiceStatus,
} from "../_shared/turn.ts";

const VIDEO_MAX_SESSION_SECONDS = 60;

Deno.serve(async (req) => {
  const preflight = options(req);
  if (preflight) return preflight;
  try {
    if (req.method !== "POST") {
      return json(405, { error: "Method not allowed" }, req);
    }
    const user = await requireUser(
      req.headers.get("Authorization") ?? undefined,
    );
    const body = await readJson<{ ring_id?: unknown }>(req);
    const ringId = cleanText(body.ring_id, 36, true)!;
    const admin = serviceClient();
    const { data: ring, error } = await admin
      .from("rings")
      .select(
        "id, door_id, visitor_user_id, requested_mode, status, answered_at, session_expires_at",
      )
      .eq("id", ringId)
      .maybeSingle();
    if (error) throw new Error(error.message);
    if (!ring) throw new HttpError(404, "Ziyaret bulunamadı", "RING_NOT_FOUND");
    if (!["audio", "video"].includes(ring.requested_mode)) {
      throw new HttpError(
        400,
        "Bu oturum medya görüşmesi değil",
        "MEDIA_NOT_AVAILABLE",
      );
    }
    if (ring.status === "pending") {
      throw new HttpError(
        409,
        "Host görüşmeyi henüz yanıtlamadı",
        "RING_NOT_READY",
      );
    }
    if (ring.status !== "accepted") {
      throw new HttpError(409, "Görüşme sona ermiş", "RING_CLOSED");
    }
    if (user.is_anonymous) {
      if (ring.visitor_user_id !== user.id) {
        throw new HttpError(403, "Bu görüşmeye erişiminiz yok", "FORBIDDEN");
      }
      if (
        !ring.session_expires_at ||
        new Date(ring.session_expires_at).getTime() <= Date.now()
      ) {
        throw new HttpError(
          410,
          "Ziyaretçi oturumunun süresi dolmuş",
          "SESSION_EXPIRED",
        );
      }
    } else {
      await requireDoorHost(admin, ring.door_id, user.id);
    }

    const turnStatus = await getTurnServiceStatus(admin);
    if (!turnStatus.enabled) {
      const monthlyLimit = turnStatus.reason === "monthly_limit";
      throw new HttpError(
        503,
        monthlyLimit
          ? "Sesli ve görüntülü görüşme bu ayki altyapı sınırına ulaştı"
          : "Sesli ve görüntülü görüşme geçici olarak kullanılamıyor",
        monthlyLimit ? "TURN_MONTHLY_LIMIT" : "TURN_UNAVAILABLE",
      );
    }

    let mediaDeadline: string | null = null;
    let maxSessionSeconds: number | null = null;
    let credentialTtlLimit: number | undefined;
    if (ring.requested_mode === "video") {
      if (!ring.answered_at) {
        throw new HttpError(409, "Görüşme henüz başlamadı", "RING_NOT_READY");
      }
      const deadline = new Date(ring.answered_at).getTime() +
        VIDEO_MAX_SESSION_SECONDS * 1000;
      const remaining = Math.ceil((deadline - Date.now()) / 1000);
      if (remaining <= 0) {
        throw new HttpError(
          410,
          "Bir dakikalık görüntülü görüşme süresi doldu",
          "MEDIA_SESSION_EXPIRED",
        );
      }
      mediaDeadline = new Date(deadline).toISOString();
      maxSessionSeconds = VIDEO_MAX_SESSION_SECONDS;
      credentialTtlLimit = remaining;
    }

    const credentials = await generateTurnIceServers(credentialTtlLimit);

    return json(200, {
      ice_servers: credentials.iceServers,
      turn_configured: true,
      expires_in: credentials.ttlSeconds,
      max_session_seconds: maxSessionSeconds,
      media_deadline: mediaDeadline,
    }, req);
  } catch (error) {
    return errorResponse(error, req);
  }
});
