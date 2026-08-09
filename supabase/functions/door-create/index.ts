import { ensureProTrial, getOwnerPlan } from "../_shared/plans.ts";
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
    const body = await readJson<{ label?: unknown; address_text?: unknown }>(
      req,
    );
    const label = cleanText(body.label, 80, true)!;
    const address = cleanText(body.address_text, 300);
    const admin = serviceClient();

    const { error: profileError } = await admin.from("users").upsert({
      id: user.id,
    }, { onConflict: "id" });
    if (profileError) throw new Error(profileError.message);
    await ensureProTrial(admin, user.id);
    const [plan, { count, error: countError }] = await Promise.all([
      getOwnerPlan(admin, user.id),
      admin.from("doors").select("id", { count: "exact", head: true }).eq(
        "owner_user_id",
        user.id,
      ),
    ]);
    if (countError) throw new Error(countError.message);
    if ((count ?? 0) >= plan.max_doors) {
      throw new HttpError(
        402,
        `Planınız en fazla ${plan.max_doors} dijital zil destekliyor`,
        "DOOR_PLAN_LIMIT",
      );
    }

    const { data: door, error } = await admin
      .from("doors")
      .insert({
        owner_user_id: user.id,
        label,
        address_text: address,
        is_active: true,
      })
      .select("id, label, address_text, is_active")
      .single();
    if (error || !door) throw new Error(error?.message ?? "Door create failed");
    const { data: settings, error: settingsError } = await admin
      .from("door_settings")
      .insert({
        door_id: door.id,
        audio_enabled: plan.features.audio_call === true,
        video_enabled: plan.features.video_call === true,
      })
      .select(
        "welcome_message, text_enabled, audio_enabled, video_enabled, require_visitor_name, ring_timeout_seconds",
      )
      .single();
    if (settingsError) {
      await admin.from("doors").delete().eq("id", door.id);
      throw new Error(settingsError.message);
    }
    return json(201, { ...door, settings, plan_id: plan.id, plan }, req);
  } catch (error) {
    return errorResponse(error, req);
  }
});
