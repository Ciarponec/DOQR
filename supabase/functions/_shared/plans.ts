import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.91.0";
import { HttpError } from "./utils.ts";

export type Plan = {
  id: string;
  display_name: string;
  annual_price_usd_cents: number;
  max_doors: number;
  max_hosts_per_door: number;
  monthly_ring_limit: number | null;
  log_retention_days: number | null;
  log_retention_count: number | null;
  monthly_audio_seconds: number;
  monthly_video_seconds: number;
  features: Record<string, boolean>;
  subscription_status: string;
  current_period_end: string | null;
  trial_ends_at: string | null;
  is_trial: boolean;
};

export async function ensureProTrial(
  admin: SupabaseClient,
  ownerUserId: string,
): Promise<boolean> {
  const now = new Date();
  const endsAt = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);
  const { data, error } = await admin.from("user_subscriptions")
    .upsert({
      user_id: ownerUserId,
      plan_id: "trial",
      status: "trialing",
      provider: "manual",
      current_period_end: endsAt.toISOString(),
      trial_started_at: now.toISOString(),
      trial_ends_at: endsAt.toISOString(),
    }, { onConflict: "user_id", ignoreDuplicates: true })
    .select("user_id")
    .maybeSingle();
  if (error) throw new Error(error.message);
  return data?.user_id === ownerUserId;
}

export async function getOwnerPlan(
  admin: SupabaseClient,
  ownerUserId: string,
): Promise<Plan> {
  const { data: subscription, error: subscriptionError } = await admin
    .from("user_subscriptions")
    .select(
      "plan_id, status, current_period_end, trial_ends_at, entitlement_override",
    )
    .eq("user_id", ownerUserId)
    .maybeSingle();
  if (subscriptionError) throw new Error(subscriptionError.message);

  const valid = subscription &&
    ["active", "trialing"].includes(subscription.status) &&
    (!subscription.current_period_end ||
      new Date(subscription.current_period_end).getTime() > Date.now());
  const planId = valid ? subscription.plan_id : "free";
  const { data: plan, error } = await admin
    .from("plan_definitions")
    .select(
      "id, display_name, annual_price_usd_cents, max_doors, max_hosts_per_door, monthly_ring_limit, log_retention_days, log_retention_count, monthly_audio_seconds, monthly_video_seconds, features",
    )
    .eq("id", planId)
    .eq("is_active", true)
    .single();
  if (error || !plan) throw new Error(error?.message ?? "Plan not found");
  return {
    ...plan,
    features: {
      ...(plan.features as Record<string, boolean>),
      ...((valid ? subscription.entitlement_override : {}) as Record<
        string,
        boolean
      >),
    },
    subscription_status: valid ? subscription.status : "free",
    current_period_end: valid ? subscription.current_period_end : null,
    trial_ends_at: valid && subscription.status === "trialing"
      ? subscription.trial_ends_at ?? subscription.current_period_end
      : null,
    is_trial: valid && subscription.status === "trialing",
  } as Plan;
}

export function enabledModes(
  settings: {
    text_enabled: boolean;
    audio_enabled: boolean;
    video_enabled: boolean;
  },
  plan: Plan,
) {
  return {
    text: settings.text_enabled && plan.features.text_chat === true,
    audio: settings.audio_enabled && plan.features.audio_call === true,
    video: settings.video_enabled && plan.features.video_call === true,
  };
}

export function requireFeature(
  plan: Plan,
  feature: string,
  code = "PRO_REQUIRED",
) {
  if (plan.features[feature] !== true) {
    throw new HttpError(402, "Bu özellik Pro planında kullanılabilir", code);
  }
}
