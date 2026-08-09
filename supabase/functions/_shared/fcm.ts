import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.91.0";
import { getEnv } from "./utils.ts";

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
};

type AccessToken = { value: string; expiresAt: number };
let cachedAccessToken: AccessToken | null = null;

function base64Url(input: Uint8Array | string): string {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : input;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(
    /=+$/,
    "",
  );
}

function pemToBytes(pem: string): Uint8Array {
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");
  const binary = atob(base64);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

function asArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  return Uint8Array.from(bytes).buffer as ArrayBuffer;
}

function serviceAccount(): ServiceAccount {
  const parsed = JSON.parse(
    getEnv("FIREBASE_SERVICE_ACCOUNT_JSON"),
  ) as ServiceAccount;
  if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT_JSON is incomplete");
  }
  return parsed;
}

async function googleAccessToken(): Promise<string> {
  if (cachedAccessToken && cachedAccessToken.expiresAt > Date.now() + 60_000) {
    return cachedAccessToken.value;
  }

  const account = serviceAccount();
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64Url(JSON.stringify({
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: account.token_uri ?? "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    asArrayBuffer(pemToBytes(account.private_key)),
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

  const response = await fetch(
    account.token_uri ?? "https://oauth2.googleapis.com/token",
    {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion,
      }),
    },
  );
  const payload = await response.json();
  if (!response.ok || typeof payload.access_token !== "string") {
    throw new Error(`FCM OAuth failed (${response.status})`);
  }
  cachedAccessToken = {
    value: payload.access_token,
    expiresAt: Date.now() + Number(payload.expires_in ?? 3600) * 1000,
  };
  return cachedAccessToken.value;
}

async function sendOne(
  token: string,
  notification: { title: string; body: string },
  data: Record<string, string>,
) {
  const account = serviceAccount();
  const accessToken = await googleAccessToken();
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification,
          data,
          android: {
            priority: "HIGH",
            ttl: "60s",
            notification: {
              channel_id: "doqr_rings",
              sound: "default",
              tag: `ring-${data.ring_id}`,
            },
          },
          apns: {
            headers: {
              "apns-priority": "10",
              "apns-expiration": String(Math.floor(Date.now() / 1000) + 60),
            },
            payload: { aps: { sound: "default", "content-available": 1 } },
          },
        },
      }),
    },
  );
  const payload = await response.json();
  return { ok: response.ok, status: response.status, payload };
}

function isUnregistered(payload: unknown): boolean {
  const json = JSON.stringify(payload);
  return json.includes("UNREGISTERED") ||
    json.includes("registration-token-not-registered");
}

export async function notifyDoorbell(
  admin: SupabaseClient,
  input: {
    ringId: string;
    doorId: string;
    doorLabel: string;
    visitorAlias: string | null;
    requestedMode: string;
    recipientIds: string[];
  },
) {
  if (input.recipientIds.length === 0) return { sent: 0, failed: 0 };
  const { data: rows, error } = await admin
    .from("user_push_tokens")
    .select("id, fcm_token")
    .in("user_id", input.recipientIds);
  if (error) throw new Error(error.message);

  const tokens = rows ?? [];
  const title = `${input.doorLabel}: Zil çalıyor`;
  const modeLabel = input.requestedMode === "video"
    ? "görüntülü görüşme"
    : input.requestedMode === "audio"
    ? "sesli görüşme"
    : "mesajlaşma";
  const body = `${input.visitorAlias ?? "Bir ziyaretçi"} ${modeLabel} istiyor`;
  const results = await Promise.allSettled(tokens.map(async (row) => {
    const result = await sendOne(row.fcm_token, { title, body }, {
      type: "doorbell_ring",
      ring_id: input.ringId,
      door_id: input.doorId,
      requested_mode: input.requestedMode,
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    });
    if (!result.ok && isUnregistered(result.payload)) {
      await admin.from("user_push_tokens").delete().eq("id", row.id);
    }
    if (!result.ok) throw new Error(`FCM ${result.status}`);
  }));
  return {
    sent: results.filter((result) => result.status === "fulfilled").length,
    failed: results.filter((result) => result.status === "rejected").length,
  };
}

export function runInBackground(promise: Promise<unknown>) {
  const guarded = promise.catch((error) => {
    console.error("Background notification failed", error);
  });
  const runtime = (globalThis as unknown as {
    EdgeRuntime?: { waitUntil: (promise: Promise<unknown>) => void };
  }).EdgeRuntime;
  if (runtime?.waitUntil) runtime.waitUntil(guarded);
}
