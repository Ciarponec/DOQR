import {
  cleanText,
  errorResponse,
  HttpError,
  json,
  options,
  readJson,
  requirePermanentUser,
  serviceClient,
  sha256Hex,
} from "../_shared/utils.ts";
import {
  APPLE_PRO_PRODUCT_ID,
  verifyAppleTransaction,
} from "../_shared/apple_store.ts";

const PACKAGE_NAME = "com.doqr.app";
const PRO_PRODUCT_ID = "doqr_pro_annual";
const PLAY_SCOPE = "https://www.googleapis.com/auth/androidpublisher";

type ServiceAccount = {
  client_email: string;
  private_key: string;
  token_uri?: string;
};

type GoogleSubscription = {
  subscriptionState?: string;
  acknowledgementState?: string;
  externalAccountIdentifiers?: { obfuscatedExternalAccountId?: string };
  lineItems?: Array<{
    productId?: string;
    expiryTime?: string;
    latestSuccessfulOrderId?: string;
  }>;
};

function base64Url(input: Uint8Array | string): string {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : input;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToBytes(pem: string): ArrayBuffer {
  const base64 = pem.replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  const binary = atob(base64);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0)).buffer;
}

async function googleAccessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64Url(JSON.stringify({
    iss: account.client_email,
    scope: PLAY_SCOPE,
    aud: account.token_uri ?? "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToBytes(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${base64Url(new Uint8Array(signature))}`;
  const response = await fetch(account.token_uri ?? "https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) {
    console.error("Google OAuth failed", response.status, await response.text());
    throw new HttpError(503, "Google Play doğrulamasına ulaşılamadı", "PLAY_AUTH_FAILED");
  }
  const data = await response.json() as { access_token?: string };
  if (!data.access_token) throw new Error("Google OAuth response has no access token");
  return data.access_token;
}

function serviceAccount(): ServiceAccount {
  const raw = Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON") ??
    Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!raw) throw new Error("Missing Google Play service account secret");
  const value = JSON.parse(raw) as Partial<ServiceAccount>;
  if (!value.client_email || !value.private_key) {
    throw new Error("Invalid Google Play service account secret");
  }
  return value as ServiceAccount;
}

async function playRequest(
  accessToken: string,
  path: string,
  init?: RequestInit,
): Promise<Response> {
  return fetch(`https://androidpublisher.googleapis.com/androidpublisher/v3/${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
      ...(init?.headers ?? {}),
    },
  });
}

async function verifyApplePurchase(
  userId: string,
  productId: string,
  signedTransaction: string,
) {
  if (productId !== APPLE_PRO_PRODUCT_ID) {
    throw new HttpError(400, "Geçersiz mağaza ürünü", "INVALID_PRODUCT");
  }
  const transaction = await verifyAppleTransaction(signedTransaction);
  if (transaction.productId !== APPLE_PRO_PRODUCT_ID) {
    throw new HttpError(
      400,
      "Satın alınan ürün eşleşmiyor",
      "PRODUCT_MISMATCH",
    );
  }
  if (transaction.type !== "Auto-Renewable Subscription") {
    throw new HttpError(
      400,
      "Satın alma bir App Store aboneliği değil",
      "PRODUCT_TYPE_MISMATCH",
    );
  }
  if (transaction.appAccountToken?.toLowerCase() !== userId.toLowerCase()) {
    throw new HttpError(
      403,
      "Satın alma bu DOQR hesabına ait değil",
      "ACCOUNT_MISMATCH",
    );
  }

  const transactionId = transaction.transactionId;
  const originalTransactionId = transaction.originalTransactionId;
  const expiresDate = transaction.expiresDate;
  if (!transactionId || !originalTransactionId || !Number.isFinite(expiresDate)) {
    throw new HttpError(
      400,
      "App Store işlem bilgisi eksik",
      "APPLE_TRANSACTION_INVALID",
    );
  }

  const admin = serviceClient();
  const { data: owner, error: ownerError } = await admin
    .from("store_purchase_records")
    .select("user_id")
    .eq("provider", "apple")
    .eq("original_transaction_id", originalTransactionId)
    .limit(1)
    .maybeSingle();
  if (ownerError) throw new Error(ownerError.message);
  if (owner && owner.user_id !== userId) {
    throw new HttpError(
      409,
      "Bu satın alma başka bir hesaba bağlı",
      "PURCHASE_OWNERSHIP_CONFLICT",
    );
  }

  const currentPeriodEndMs = expiresDate!;
  const entitlementActive = transaction.revocationDate == null &&
    currentPeriodEndMs > Date.now();
  const periodEnd = new Date(currentPeriodEndMs).toISOString();
  const state = transaction.revocationDate != null
    ? "REVOKED"
    : entitlementActive
    ? "ACTIVE"
    : "EXPIRED";
  const tokenHash = await sha256Hex(`apple:${transactionId}`);
  const now = new Date().toISOString();

  const { error: recordError } = await admin.from("store_purchase_records")
    .upsert({
      user_id: userId,
      provider: "apple",
      product_id: APPLE_PRO_PRODUCT_ID,
      purchase_token_hash: tokenHash,
      original_transaction_id: originalTransactionId,
      store_state: state,
      entitlement_active: entitlementActive,
      current_period_end: periodEnd,
      acknowledgement_state: transaction.environment ?? null,
      last_verified_at: now,
      updated_at: now,
    }, { onConflict: "provider,purchase_token_hash" });
  if (recordError) throw new Error(recordError.message);

  const { error: subscriptionError } = await admin.from("user_subscriptions")
    .upsert({
      user_id: userId,
      plan_id: "pro",
      status: entitlementActive ? "active" : "expired",
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

  if (!entitlementActive) {
    throw new HttpError(
      409,
      "Abonelik etkin değil veya süresi dolmuş",
      "ENTITLEMENT_INACTIVE",
    );
  }
  return {
    verified: true,
    plan_id: "pro",
    status: "active",
    current_period_end: periodEnd,
  };
}

Deno.serve(async (req) => {
  const preflight = options(req);
  if (preflight) return preflight;
  try {
    if (req.method !== "POST") return json(405, { error: "Method not allowed" }, req);
    const user = await requirePermanentUser(req.headers.get("Authorization") ?? undefined);
    const body = await readJson<Record<string, unknown>>(req, 12_000);
    const provider = cleanText(body.provider, 20, true)!;
    const productId = cleanText(body.product_id, 200, true)!;
    const purchaseToken = cleanText(body.verification_data, 8_000, true)!;

    if (provider === "apple") {
      return json(
        200,
        await verifyApplePurchase(user.id, productId, purchaseToken),
        req,
      );
    }
    if (provider !== "google") {
      throw new HttpError(400, "Geçersiz mağaza sağlayıcısı", "INVALID_PROVIDER");
    }
    if (productId !== PRO_PRODUCT_ID) {
      throw new HttpError(400, "Geçersiz mağaza ürünü", "INVALID_PRODUCT");
    }

    const tokenHash = await sha256Hex(purchaseToken);
    const expectedAccountId = await sha256Hex(user.id);
    const admin = serviceClient();
    const { data: existing, error: existingError } = await admin
      .from("store_purchase_records")
      .select("user_id")
      .eq("provider", "google")
      .eq("purchase_token_hash", tokenHash)
      .maybeSingle();
    if (existingError) throw new Error(existingError.message);
    if (existing && existing.user_id !== user.id) {
      throw new HttpError(409, "Bu satın alma başka bir hesaba bağlı", "PURCHASE_OWNERSHIP_CONFLICT");
    }

    const accessToken = await googleAccessToken(serviceAccount());
    const verifyResponse = await playRequest(
      accessToken,
      `applications/${PACKAGE_NAME}/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`,
    );
    if (verifyResponse.status === 404) {
      throw new HttpError(400, "Satın alma Google Play tarafından doğrulanamadı", "PURCHASE_NOT_FOUND");
    }
    if (!verifyResponse.ok) {
      console.error("Play verification failed", verifyResponse.status, await verifyResponse.text());
      throw new HttpError(503, "Google Play doğrulaması geçici olarak kullanılamıyor", "PLAY_VERIFY_FAILED");
    }
    const purchase = await verifyResponse.json() as GoogleSubscription;
    const lineItems = purchase.lineItems ?? [];
    const matchingItems = lineItems.filter((item) => item.productId === productId);
    if (matchingItems.length === 0) {
      throw new HttpError(400, "Satın alınan ürün eşleşmiyor", "PRODUCT_MISMATCH");
    }
    if (purchase.externalAccountIdentifiers?.obfuscatedExternalAccountId !== expectedAccountId) {
      throw new HttpError(403, "Satın alma bu DOQR hesabına ait değil", "ACCOUNT_MISMATCH");
    }

    const expiryTimes = matchingItems
      .map((item) => item.expiryTime ? Date.parse(item.expiryTime) : Number.NaN)
      .filter(Number.isFinite);
    const currentPeriodEndMs = expiryTimes.length ? Math.max(...expiryTimes) : 0;
    const state = purchase.subscriptionState ?? "SUBSCRIPTION_STATE_UNSPECIFIED";
    const validStates = new Set([
      "SUBSCRIPTION_STATE_ACTIVE",
      "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
      "SUBSCRIPTION_STATE_CANCELED",
    ]);
    const entitlementActive = validStates.has(state) && currentPeriodEndMs > Date.now();
    const periodEnd = currentPeriodEndMs
      ? new Date(currentPeriodEndMs).toISOString()
      : null;

    if (entitlementActive &&
      purchase.acknowledgementState === "ACKNOWLEDGEMENT_STATE_PENDING") {
      const acknowledgeResponse = await playRequest(
        accessToken,
        `applications/${PACKAGE_NAME}/purchases/subscriptions/${productId}/tokens/${encodeURIComponent(purchaseToken)}:acknowledge`,
        { method: "POST", body: "{}" },
      );
      if (!acknowledgeResponse.ok) {
        console.error("Play acknowledge failed", acknowledgeResponse.status, await acknowledgeResponse.text());
        throw new HttpError(503, "Satın alma onaylanamadı; tekrar deneyin", "PLAY_ACK_FAILED");
      }
    }

    const now = new Date().toISOString();
    const { error: recordError } = await admin.from("store_purchase_records").upsert({
      user_id: user.id,
      provider: "google",
      product_id: productId,
      purchase_token_hash: tokenHash,
      original_transaction_id: matchingItems[0]?.latestSuccessfulOrderId ?? null,
      store_state: state,
      entitlement_active: entitlementActive,
      current_period_end: periodEnd,
      acknowledgement_state: purchase.acknowledgementState ?? null,
      last_verified_at: now,
      updated_at: now,
    }, { onConflict: "provider,purchase_token_hash" });
    if (recordError) throw new Error(recordError.message);

    const { error: subscriptionError } = await admin.from("user_subscriptions").upsert({
      user_id: user.id,
      plan_id: "pro",
      status: entitlementActive ? "active" : "expired",
      provider: "google",
      provider_customer_id: expectedAccountId,
      provider_subscription_id: tokenHash,
      product_id: productId,
      current_period_end: periodEnd,
      trial_started_at: null,
      trial_ends_at: null,
      updated_at: now,
    }, { onConflict: "user_id" });
    if (subscriptionError) throw new Error(subscriptionError.message);

    if (!entitlementActive) {
      throw new HttpError(409, "Abonelik etkin değil veya süresi dolmuş", "ENTITLEMENT_INACTIVE");
    }
    return json(200, {
      verified: true,
      plan_id: "pro",
      status: "active",
      current_period_end: periodEnd,
    }, req);
  } catch (error) {
    return errorResponse(error, req);
  }
});
