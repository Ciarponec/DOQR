import { getOwnerPlan, requireFeature } from "../_shared/plans.ts";
import { decryptCourierCode, encryptCourierCode } from "../_shared/secrets.ts";
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
      const { data: door, error: doorError } = await admin.from("doors").select(
        "owner_user_id",
      ).eq("id", doorId).maybeSingle();
      if (doorError) throw new Error(doorError.message);
      if (!door || door.owner_user_id !== user.id) {
        throw new HttpError(
          403,
          "Yalnızca dijital zil sahibi notları görebilir",
          "FORBIDDEN",
        );
      }
      requireFeature(await getOwnerPlan(admin, user.id), "courier_notes");
      const { data, error } = await admin.from("courier_notes").select(
        "id, courier_code, courier_label, title, message_text, delivery_code, active_from, active_until, is_active, created_at, updated_at",
      ).eq("door_id", doorId).order("courier_label");
      if (error) throw new Error(error.message);
      return json(200, {
        notes: await Promise.all((data ?? []).map(async (note) => ({
          ...note,
          delivery_code: await decryptCourierCode(note.delivery_code),
        }))),
      }, req);
    }
    if (req.method !== "POST") {
      return json(405, { error: "Method not allowed" }, req);
    }

    const body = await readJson<Record<string, unknown>>(req);
    const action = cleanText(body.action, 10) ?? "save";
    const doorId = cleanText(body.door_id, 36, true)!;
    const { data: door, error: doorError } = await admin.from("doors").select(
      "owner_user_id",
    ).eq("id", doorId).maybeSingle();
    if (doorError) throw new Error(doorError.message);
    if (!door || door.owner_user_id !== user.id) {
      throw new HttpError(
        403,
        "Yalnızca dijital zil sahibi notları yönetebilir",
        "FORBIDDEN",
      );
    }
    requireFeature(await getOwnerPlan(admin, user.id), "courier_notes");

    if (action === "delete") {
      const noteId = cleanText(body.id, 36, true)!;
      const { error } = await admin.from("courier_notes").delete().eq(
        "id",
        noteId,
      ).eq("door_id", doorId);
      if (error) throw new Error(error.message);
      return json(200, { deleted: true }, req);
    }
    if (action !== "save") {
      throw new HttpError(400, "Geçersiz işlem", "VALIDATION_ERROR");
    }

    const id = cleanText(body.id, 36);
    const courierCode = cleanText(body.courier_code, 40, true)!.toLowerCase();
    const courierLabel = cleanText(body.courier_label, 80, true)!;
    const title = cleanText(body.title, 100) ?? "Teslimat notu";
    const message = cleanText(body.message_text, 500, true)!;
    const deliveryCode = cleanText(body.delivery_code, 80);
    if (!/^[a-z0-9_-]{2,40}$/.test(courierCode)) {
      throw new HttpError(400, "Geçersiz kurye kodu", "VALIDATION_ERROR");
    }
    const activeFrom = cleanText(body.active_from, 40);
    const activeUntil = cleanText(body.active_until, 40);
    const row = {
      door_id: doorId,
      courier_code: courierCode,
      courier_label: courierLabel,
      title,
      message_text: message,
      delivery_code: await encryptCourierCode(deliveryCode),
      active_from: activeFrom,
      active_until: activeUntil,
      is_active: body.is_active !== false,
      created_by: user.id,
      updated_at: new Date().toISOString(),
    };
    const query = id
      ? admin.from("courier_notes").update(row).eq("id", id).eq(
        "door_id",
        doorId,
      )
      : admin.from("courier_notes").insert(row);
    const { data, error } = await query.select(
      "id, courier_code, courier_label, title, message_text, active_from, active_until, is_active, created_at, updated_at",
    ).single();
    if (error?.code === "23505") {
      throw new HttpError(
        409,
        "Bu kurye için zaten aktif bir not var",
        "COURIER_NOTE_CONFLICT",
      );
    }
    if (error) throw new Error(error.message);
    return json(id ? 200 : 201, { ...data, delivery_code: deliveryCode }, req);
  } catch (error) {
    return errorResponse(error, req);
  }
});
