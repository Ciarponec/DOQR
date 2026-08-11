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
import { getOwnerPlan, requireFeature } from "../_shared/plans.ts";

Deno.serve(async (req) => {
  const preflight = options(req);
  if (preflight) return preflight;
  try {
    const user = await requirePermanentUser(
      req.headers.get("Authorization") ?? undefined,
    );
    const admin = serviceClient();

    if (req.method === "GET") {
      const doorId = cleanText(
        new URL(req.url).searchParams.get("door_id"),
        36,
        true,
      )!;
      const { data: door, error: doorError } = await admin.from("doors")
        .select("owner_user_id")
        .eq("id", doorId)
        .maybeSingle();
      if (doorError) throw new Error(doorError.message);
      if (!door || door.owner_user_id !== user.id) {
        throw new HttpError(
          403,
          "Engelleri yalnızca zil sahibi görebilir",
          "FORBIDDEN",
        );
      }
      requireFeature(await getOwnerPlan(admin, user.id), "visitor_blocking");
      const now = new Date().toISOString();
      const { data, error } = await admin.from("door_blocks")
        .select("id, block_type, reason, expires_at, created_at")
        .eq("door_id", doorId)
        .or(`expires_at.is.null,expires_at.gt.${now}`)
        .order("created_at", { ascending: false });
      if (error) throw new Error(error.message);
      return json(200, { blocks: data ?? [] }, req);
    }
    if (req.method !== "POST") {
      return json(405, { error: "Method not allowed" }, req);
    }

    const body = await readJson<Record<string, unknown>>(req);
    const action = cleanText(body.action, 12) ?? "block";
    if (action === "unblock") {
      const doorId = cleanText(body.door_id, 36, true)!;
      const blockId = cleanText(body.block_id, 36, true)!;
      const { data: door, error: doorError } = await admin.from("doors")
        .select("owner_user_id")
        .eq("id", doorId)
        .maybeSingle();
      if (doorError) throw new Error(doorError.message);
      if (!door || door.owner_user_id !== user.id) {
        throw new HttpError(
          403,
          "Engeli yalnızca zil sahibi kaldırabilir",
          "FORBIDDEN",
        );
      }
      requireFeature(await getOwnerPlan(admin, user.id), "visitor_blocking");
      const { error } = await admin.from("door_blocks").delete()
        .eq("id", blockId)
        .eq("door_id", doorId);
      if (error) throw new Error(error.message);
      return json(200, { removed: true }, req);
    }
    if (action !== "block") {
      throw new HttpError(400, "Geçersiz işlem", "VALIDATION_ERROR");
    }

    const ringId = cleanText(body.ring_id, 36, true)!;
    const scope = cleanText(body.scope, 20, true)!;
    const reason = cleanText(body.reason, 240) ??
      "Rahatsız edici veya tekrarlanan zil";
    if (!["device", "network", "both"].includes(scope)) {
      throw new HttpError(400, "Geçersiz engel türü", "VALIDATION_ERROR");
    }
    const networkHours = Number(body.network_hours ?? 24);
    if (
      !Number.isFinite(networkHours) || networkHours < 1 || networkHours > 168
    ) {
      throw new HttpError(
        400,
        "Ağ engeli 1–168 saat arasında olmalı",
        "VALIDATION_ERROR",
      );
    }

    const { data: ring, error: ringError } = await admin
      .from("rings")
      .select(
        "id, door_id, visitor_device_hash, visitor_ip_hash, doors!inner(owner_user_id)",
      )
      .eq("id", ringId)
      .maybeSingle();
    if (ringError) throw new Error(ringError.message);
    if (!ring) throw new HttpError(404, "Ziyaret bulunamadı", "RING_NOT_FOUND");
    const doorRelation = ring.doors as unknown as
      | { owner_user_id: string }
      | { owner_user_id: string }[];
    const ownerId = Array.isArray(doorRelation)
      ? doorRelation[0]?.owner_user_id
      : doorRelation.owner_user_id;
    if (ownerId !== user.id) {
      throw new HttpError(
        403,
        "Yalnızca dijital zil sahibi engel koyabilir",
        "FORBIDDEN",
      );
    }
    requireFeature(await getOwnerPlan(admin, user.id), "visitor_blocking");

    const rows = [];
    if (["device", "both"].includes(scope)) {
      if (!ring.visitor_device_hash) {
        throw new HttpError(
          409,
          "Bu eski kayıtta cihaz kimliği yok",
          "DEVICE_HASH_MISSING",
        );
      }
      rows.push({
        door_id: ring.door_id,
        block_type: "device",
        value_hash: ring.visitor_device_hash,
        reason,
        expires_at: null,
        created_by: user.id,
      });
    }
    if (["network", "both"].includes(scope)) {
      if (!ring.visitor_ip_hash) {
        throw new HttpError(
          409,
          "Bu eski kayıtta ağ kimliği yok",
          "NETWORK_HASH_MISSING",
        );
      }
      rows.push({
        door_id: ring.door_id,
        block_type: "network",
        value_hash: ring.visitor_ip_hash,
        reason,
        expires_at: new Date(Date.now() + networkHours * 60 * 60 * 1000)
          .toISOString(),
        created_by: user.id,
      });
    }
    const { error } = await admin.from("door_blocks").upsert(rows, {
      onConflict: "door_id,block_type,value_hash",
    });
    if (error) throw new Error(error.message);
    await admin.from("ring_events").insert({
      ring_id: ringId,
      event_type: "security",
      actor_type: "host",
      actor_user_id: user.id,
      metadata: {
        action: "blocked",
        scope,
        network_hours: scope === "device" ? null : networkHours,
      },
    });
    return json(200, {
      blocked: true,
      scope,
      network_hours: scope === "device" ? null : networkHours,
    }, req);
  } catch (error) {
    return errorResponse(error, req);
  }
});
