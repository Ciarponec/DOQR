import { ensureProTrial, getOwnerPlan } from "../_shared/plans.ts";
import {
  errorResponse,
  json,
  options,
  requirePermanentUser,
  serviceClient,
} from "../_shared/utils.ts";

Deno.serve(async (req) => {
  const preflight = options(req);
  if (preflight) return preflight;
  try {
    if (req.method !== "GET") {
      return json(405, { error: "Method not allowed" }, req);
    }
    const user = await requirePermanentUser(
      req.headers.get("Authorization") ?? undefined,
    );
    const admin = serviceClient();
    const { data: owned, error: ownedError } = await admin
      .from("doors")
      .select(
        "id, label, address_text, is_active, owner_user_id, door_settings(welcome_message, text_enabled, audio_enabled, video_enabled, require_visitor_name, ring_timeout_seconds)",
      )
      .eq("owner_user_id", user.id)
      .order("label");
    if (ownedError) throw new Error(ownedError.message);
    const { data: shared, error: sharedError } = await admin
      .from("door_shared_users")
      .select(
        "doors!inner(id, label, address_text, is_active, owner_user_id, door_settings(welcome_message, text_enabled, audio_enabled, video_enabled, require_visitor_name, ring_timeout_seconds))",
      )
      .eq("user_id", user.id);
    if (sharedError) throw new Error(sharedError.message);

    if ((owned ?? []).length > 0) {
      const trialStarted = await ensureProTrial(admin, user.id);
      if (trialStarted) {
        const doorIds = (owned ?? []).map((door) => door.id);
        const { error: settingsError } = await admin
          .from("door_settings")
          .update({ audio_enabled: true, video_enabled: true })
          .in("door_id", doorIds);
        if (settingsError) throw new Error(settingsError.message);
        for (const door of owned ?? []) {
          const settings = Array.isArray(door.door_settings)
            ? door.door_settings[0]
            : door.door_settings;
          if (settings) {
            settings.audio_enabled = true;
            settings.video_enabled = true;
          }
        }
      }
    }

    const rows = [
      ...(owned ?? []).map((door) => ({ ...door, role: "owner" })),
      ...(shared ?? []).map((row) => ({
        ...(Array.isArray(row.doors) ? row.doors[0] : row.doors),
        role: "shared",
      })),
    ].filter((door) => door?.id);
    const ownerIds = [...new Set(rows.map((door) => door.owner_user_id))];
    const planEntries = await Promise.all(
      ownerIds.map(async (ownerId) =>
        [ownerId, await getOwnerPlan(admin, ownerId)] as const
      ),
    );
    const plans = new Map(planEntries);
    return json(200, {
      doors: rows.map((door) => ({
        ...door,
        plan: plans.get(door.owner_user_id),
      })),
      account_plan: await getOwnerPlan(admin, user.id),
    }, req);
  } catch (error) {
    return errorResponse(error, req);
  }
});
