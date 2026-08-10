import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.91.0";

const CLOUDFLARE_GRAPHQL_URL = "https://api.cloudflare.com/client/v4/graphql";
const CLOUDFLARE_TURN_URL = "https://rtc.live.cloudflare.com/v1/turn/keys";
const DEFAULT_HARD_LIMIT_GB = 950;
const DEFAULT_CACHE_SECONDS = 5 * 60;
const MAX_STALE_SECONDS = 30 * 60;
const DEFAULT_CREDENTIAL_TTL_SECONDS = 60;
const MIN_CREDENTIAL_TTL_SECONDS = 5 * 60;
const MAX_CREDENTIAL_TTL_SECONDS = 48 * 60 * 60;

export type TurnServiceStatus = {
  enabled: boolean;
  reason: string | null;
  egressBytes: number;
  limitBytes: number;
  periodStart: string;
  lastCheckedAt: string | null;
  stale: boolean;
};

type IceServer = {
  urls: string | string[];
  username?: string;
  credential?: string;
};

function positiveInteger(value: string | undefined, fallback: number): number {
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : fallback;
}

export function turnLimitBytes(): number {
  const gigabytes = positiveInteger(
    Deno.env.get("TURN_MONTHLY_HARD_LIMIT_GB"),
    DEFAULT_HARD_LIMIT_GB,
  );
  return gigabytes * 1_000_000_000;
}

export function utcMonthStart(now = new Date()): string {
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1))
    .toISOString()
    .slice(0, 10);
}

function utcDate(now = new Date()): string {
  return now.toISOString().slice(0, 10);
}

let cachedStatus: TurnServiceStatus | null = null;
let usageQueryInFlight: Promise<TurnServiceStatus> | null = null;

function isFresh(
  status: TurnServiceStatus,
  now: Date,
  seconds: number,
): boolean {
  return status.periodStart === utcMonthStart(now) &&
    status.lastCheckedAt != null &&
    now.getTime() - new Date(status.lastCheckedAt).getTime() <= seconds * 1000;
}

function requiredCloudflareAnalyticsConfig() {
  const accountId = Deno.env.get("CLOUDFLARE_ACCOUNT_ID")?.trim();
  const token = Deno.env.get("CLOUDFLARE_ANALYTICS_API_TOKEN")?.trim();
  if (!accountId || !token) {
    throw new Error("Cloudflare TURN analytics secrets are not configured");
  }
  if (!/^[A-Za-z0-9_-]{16,128}$/.test(accountId)) {
    throw new Error("Invalid Cloudflare account id");
  }
  return { accountId, token };
}

function requiredCloudflareTurnConfig() {
  const keyId = Deno.env.get("CLOUDFLARE_TURN_KEY_ID")?.trim();
  const token = Deno.env.get("CLOUDFLARE_TURN_API_TOKEN")?.trim();
  if (!keyId || !token) {
    throw new Error("Cloudflare TURN credentials are not configured");
  }
  if (!/^[A-Za-z0-9_-]{8,128}$/.test(keyId)) {
    throw new Error("Invalid Cloudflare TURN key id");
  }
  return { keyId, token };
}

async function queryMonthlyEgressBytes(now: Date): Promise<number> {
  const { accountId, token } = requiredCloudflareAnalyticsConfig();
  const query = `query DoqrTurnUsage {
    viewer {
      accounts(filter: { accountTag: "${accountId}" }) {
        callsTurnUsageAdaptiveGroups(
          limit: 1
          filter: { date_geq: "${utcMonthStart(now)}", date_leq: "${
    utcDate(now)
  }" }
        ) {
          sum { egressBytes }
        }
      }
    }
  }`;
  const response = await fetch(CLOUDFLARE_GRAPHQL_URL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ query }),
    signal: AbortSignal.timeout(8_000),
  });
  if (!response.ok) {
    throw new Error(`Cloudflare analytics failed with ${response.status}`);
  }
  const payload = await response.json() as {
    data?: {
      viewer?: {
        accounts?: Array<{
          callsTurnUsageAdaptiveGroups?: Array<{
            sum?: { egressBytes?: number | string };
          }>;
        }>;
      };
    };
    errors?: Array<{ message?: string }>;
  };
  if (payload.errors?.length) {
    throw new Error(
      `Cloudflare analytics error: ${payload.errors[0]?.message ?? "unknown"}`,
    );
  }
  const raw = payload.data?.viewer?.accounts?.[0]
    ?.callsTurnUsageAdaptiveGroups?.[0]?.sum?.egressBytes ?? 0;
  const bytes = Number(raw);
  if (!Number.isFinite(bytes) || bytes < 0) {
    throw new Error("Cloudflare analytics returned invalid egress bytes");
  }
  return Math.floor(bytes);
}

export async function getTurnServiceStatus(
  _admin: SupabaseClient,
  options: { force?: boolean; now?: Date } = {},
): Promise<TurnServiceStatus> {
  const now = options.now ?? new Date();
  const cacheSeconds = positiveInteger(
    Deno.env.get("TURN_USAGE_CACHE_SECONDS"),
    DEFAULT_CACHE_SECONDS,
  );
  if (
    !options.force && cachedStatus && isFresh(cachedStatus, now, cacheSeconds)
  ) {
    return cachedStatus;
  }
  if (usageQueryInFlight) return await usageQueryInFlight;

  usageQueryInFlight = (async () => {
    const limitBytes = turnLimitBytes();
    try {
      const egressBytes = await queryMonthlyEgressBytes(now);
      cachedStatus = {
        enabled: egressBytes < limitBytes,
        reason: egressBytes < limitBytes ? null : "monthly_limit",
        egressBytes,
        limitBytes,
        periodStart: utcMonthStart(now),
        lastCheckedAt: now.toISOString(),
        stale: false,
      };
      return cachedStatus;
    } catch (error) {
      console.error("TURN usage guard failed", error);
      if (cachedStatus && isFresh(cachedStatus, now, MAX_STALE_SECONDS)) {
        return { ...cachedStatus, stale: true };
      }
      cachedStatus = {
        enabled: false,
        reason: "analytics_unavailable",
        egressBytes: 0,
        limitBytes,
        periodStart: utcMonthStart(now),
        lastCheckedAt: now.toISOString(),
        stale: true,
      };
      return cachedStatus;
    }
  })();
  try {
    return await usageQueryInFlight;
  } finally {
    usageQueryInFlight = null;
  }
}

export function filterBrowserIceUrls(urls: string[]): string[] {
  return urls.filter((url) =>
    /^(stun|turn|turns):/i.test(url) && !/:53(?:[/?]|$)/i.test(url)
  );
}

export function resolveTurnCredentialTtl(
  configuredTtlSeconds: number,
  sessionRemainingSeconds?: number,
): number {
  const configured = Math.max(
    MIN_CREDENTIAL_TTL_SECONDS,
    Math.min(configuredTtlSeconds, MAX_CREDENTIAL_TTL_SECONDS),
  );
  if (sessionRemainingSeconds == null) return configured;

  // The media deadline remains authoritative. TURN credentials need extra
  // setup time because both peers request them after the call is accepted.
  return Math.max(
    MIN_CREDENTIAL_TTL_SECONDS,
    Math.min(configured, sessionRemainingSeconds),
  );
}

function sanitizeIceServers(value: unknown): IceServer[] {
  if (!Array.isArray(value)) return [];
  const result: IceServer[] = [];
  for (const candidate of value) {
    if (!candidate || typeof candidate !== "object") continue;
    const raw = candidate as Record<string, unknown>;
    const sourceUrls = typeof raw.urls === "string"
      ? [raw.urls]
      : Array.isArray(raw.urls) &&
          raw.urls.every((url) => typeof url === "string")
      ? raw.urls as string[]
      : [];
    const urls = filterBrowserIceUrls(sourceUrls);
    if (!urls.length) continue;
    const isTurn = urls.some((url) => /^turns?:/i.test(url));
    if (
      isTurn &&
      (typeof raw.username !== "string" || typeof raw.credential !== "string")
    ) continue;
    result.push({
      urls: urls.length === 1 ? urls[0] : urls,
      ...(isTurn
        ? {
          username: raw.username as string,
          credential: raw.credential as string,
        }
        : {}),
    });
  }
  return result;
}

export async function generateTurnIceServers(
  maxTtlSeconds?: number,
): Promise<{
  iceServers: IceServer[];
  ttlSeconds: number;
  usernames: string[];
}> {
  const { keyId, token } = requiredCloudflareTurnConfig();
  const configuredTtlSeconds = positiveInteger(
    Deno.env.get("TURN_CREDENTIAL_TTL_SECONDS"),
    DEFAULT_CREDENTIAL_TTL_SECONDS,
  );
  const ttlSeconds = resolveTurnCredentialTtl(
    configuredTtlSeconds,
    maxTtlSeconds,
  );
  const response = await fetch(
    `${CLOUDFLARE_TURN_URL}/${keyId}/credentials/generate-ice-servers`,
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ ttl: ttlSeconds }),
      signal: AbortSignal.timeout(8_000),
    },
  );
  if (!response.ok) {
    const providerDetails = (await response.text()).slice(0, 300);
    console.error("Cloudflare TURN credential request rejected", {
      status: response.status,
      providerDetails,
      ttlSeconds,
    });
    throw new Error(
      `Cloudflare TURN credentials failed with ${response.status}`,
    );
  }
  const payload = await response.json() as { iceServers?: unknown };
  const iceServers = sanitizeIceServers(payload.iceServers);
  if (
    !iceServers.some((server) => {
      const urls = Array.isArray(server.urls) ? server.urls : [server.urls];
      return urls.some((url) => /^turns?:/i.test(url));
    })
  ) {
    throw new Error("Cloudflare TURN response did not include a TURN server");
  }
  const usernames = [
    ...new Set(
      iceServers.map((server) => server.username).filter((
        value,
      ): value is string => typeof value === "string" && value.length > 0),
    ),
  ];
  return { iceServers, ttlSeconds, usernames };
}
