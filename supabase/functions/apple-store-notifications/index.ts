import {
  APPLE_PRO_PRODUCT_ID,
  verifyAppleNotification,
  verifyAppleRenewalInfo,
  verifyAppleTransaction,
} from "../_shared/apple_store.ts";
import {
  errorResponse,
  HttpError,
  json,
  options,
  readJson,
  serviceClient,
  sha256Hex,
} from "../_shared/utils.ts";

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const TERMINAL_NOTIFICATIONS = new Set([
  "EXPIRED",
  "GRACE_PERIOD_EXPIRED",
  "REFUND",
  "REVOKE",
]);

Deno.serve(async (req) => {
  const preflight = options(req);
  if (preflight) return preflight;
  try {
    if (req.method !== "POST") {
      return json(405, { error: "Method not allowed" }, req);
    }
    const body = await readJson<{ signedPayload?: unknown }>(req, 262_144);
    if (typeof body.signedPayload !== "string" || !body.signedPayload) {
      throw new HttpError(
        400,
        "App Store signedPayload eksik",
        "APPLE_PAYLOAD_REQUIRED",
      );
    }

    const notification = await verifyAppleNotification(body.signedPayload);
    const notificationType = notification.notificationType ?? "UNKNOWN";
    if (notificationType === "TEST") {
      return json(200, { accepted: true, test: true }, req);
    }

    const signedTransaction = notification.data?.signedTransactionInfo;
    if (!signedTransaction) {
      return json(200, { accepted: true, ignored: "no_transaction" }, req);
    }
    const transaction = await verifyAppleTransaction(signedTransaction);
    if (transaction.productId !== APPLE_PRO_PRODUCT_ID) {
      return json(200, { accepted: true, ignored: "other_product" }, req);
    }

    const transactionId = transaction.transactionId;
    const originalTransactionId = transaction.originalTransactionId;
    const expiresDate = transaction.expiresDate;
    if (
      !transactionId || !originalTransactionId ||
      typeof expiresDate !== "number" || !Number.isFinite(expiresDate)
    ) {
      throw new HttpError(
        400,
        "App Store işlem bilgisi eksik",
        "APPLE_TRANSACTION_INVALID",
      );
    }

    const renewal = notification.data?.signedRenewalInfo
      ? await verifyAppleRenewalInfo(notification.data.signedRenewalInfo)
      : null;
    const admin = serviceClient();
    let userId = transaction.appAccountToken?.toLowerCase() ?? null;
    if (!userId || !UUID_PATTERN.test(userId)) {
      const { data: owner, error: ownerError } = await admin
        .from("store_purchase_records")
        .select("user_id")
        .eq("provider", "apple")
        .eq("original_transaction_id", originalTransactionId)
        .limit(1)
        .maybeSingle();
      if (ownerError) throw new Error(ownerError.message);
      userId = owner?.user_id ?? null;
    }
    if (!userId) {
      throw new HttpError(
        503,
        "App Store işlemi henüz bir DOQR hesabıyla eşleşmedi",
        "APPLE_ACCOUNT_PENDING",
      );
    }

    const { data: knownOwner, error: knownOwnerError } = await admin
      .from("store_purchase_records")
      .select("user_id")
      .eq("provider", "apple")
      .eq("original_transaction_id", originalTransactionId)
      .limit(1)
      .maybeSingle();
    if (knownOwnerError) throw new Error(knownOwnerError.message);
    if (knownOwner && knownOwner.user_id !== userId) {
      throw new HttpError(
        409,
        "App Store işlemi farklı bir DOQR hesabına bağlı",
        "PURCHASE_OWNERSHIP_CONFLICT",
      );
    }

    const graceEnd = renewal?.gracePeriodExpiresDate;
    const effectiveEndMs = typeof graceEnd === "number" &&
        Number.isFinite(graceEnd) && graceEnd > expiresDate
      ? graceEnd
      : expiresDate;
    const terminal = TERMINAL_NOTIFICATIONS.has(notificationType);
    const entitlementActive = !terminal && transaction.revocationDate == null &&
      effectiveEndMs > Date.now();
    const subscriptionStatus = entitlementActive
      ? "active"
      : notificationType === "DID_FAIL_TO_RENEW"
      ? "past_due"
      : "expired";
    const storeState = `${notificationType}${notification.subtype ? `:${notification.subtype}` : ""}`
      .slice(0, 100);
    const periodEnd = new Date(effectiveEndMs).toISOString();
    const now = new Date().toISOString();
    const tokenHash = await sha256Hex(`apple:${transactionId}`);
    const autoRenewState = renewal == null
      ? transaction.environment ?? null
      : `${transaction.environment ?? "UNKNOWN"}:${renewal.autoRenewStatus === 1 ? "AUTO_RENEW_ON" : "AUTO_RENEW_OFF"}`;

    const { error: recordError } = await admin.from("store_purchase_records")
      .upsert({
        user_id: userId,
        provider: "apple",
        product_id: APPLE_PRO_PRODUCT_ID,
        purchase_token_hash: tokenHash,
        original_transaction_id: originalTransactionId,
        store_state: storeState,
        entitlement_active: entitlementActive,
        current_period_end: periodEnd,
        acknowledgement_state: autoRenewState,
        last_verified_at: now,
        updated_at: now,
      }, { onConflict: "provider,purchase_token_hash" });
    if (recordError) throw new Error(recordError.message);

    const { data: existing, error: existingError } = await admin
      .from("user_subscriptions")
      .select("provider,current_period_end")
      .eq("user_id", userId)
      .maybeSingle();
    if (existingError) throw new Error(existingError.message);
    const existingEndMs = existing?.current_period_end
      ? Date.parse(existing.current_period_end)
      : 0;
    const stale = Number.isFinite(existingEndMs) &&
      existingEndMs > effectiveEndMs && existingEndMs > Date.now();
    if (!stale) {
      const { error: subscriptionError } = await admin
        .from("user_subscriptions")
        .upsert({
          user_id: userId,
          plan_id: "pro",
          status: subscriptionStatus,
          provider: "apple",
          provider_customer_id: userId,
          provider_subscription_id: originalTransactionId,
          product_id: APPLE_PRO_PRODUCT_ID,
          current_period_end: periodEnd,
          trial_started_at: null,
          trial_ends_at: null,
          updated_at: now,
        }, { onConflict: "user_id" });
      if (subscriptionError) throw new Error(subscriptionError.message);
    }

    return json(200, {
      accepted: true,
      notification_type: notificationType,
      entitlement_active: entitlementActive,
      stale,
    }, req);
  } catch (error) {
    return errorResponse(error, req);
  }
});
