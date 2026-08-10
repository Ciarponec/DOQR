import {
  createClient,
  type SupabaseClient,
  type User,
} from "https://esm.sh/@supabase/supabase-js@2.91.0";

export class HttpError extends Error {
  constructor(
    public status: number,
    message: string,
    public code = "REQUEST_FAILED",
  ) {
    super(message);
  }
}

function allowedOrigin(req?: Request): string {
  const origin = req?.headers.get("origin") ?? "";
  const configured = (Deno.env.get("ALLOWED_ORIGINS") ?? "*")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
  if (configured.includes("*")) return "*";
  return configured.includes(origin) ? origin : configured[0] ?? "null";
}

export function corsHeaders(req?: Request): HeadersInit {
  return {
    "Access-Control-Allow-Origin": allowedOrigin(req),
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, x-client-info",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Max-Age": "86400",
    "Vary": "Origin",
  };
}

export function json(status: number, body: unknown, req?: Request) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders(req),
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
    },
  });
}

export function options(req: Request): Response | null {
  return req.method === "OPTIONS"
    ? new Response(null, { status: 204, headers: corsHeaders(req) })
    : null;
}

export function errorResponse(error: unknown, req?: Request): Response {
  if (error instanceof HttpError) {
    return json(error.status, { error: error.message, code: error.code }, req);
  }
  console.error(error);
  return json(500, {
    error: "Beklenmeyen bir sunucu hatası oluştu",
    code: "INTERNAL_ERROR",
  }, req);
}

export function getEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing env: ${name}`);
  return value;
}

export function getPublishableKey(): string {
  return Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
    getEnv("SUPABASE_ANON_KEY");
}

export function clientWithJwt(authHeader?: string): SupabaseClient {
  return createClient(getEnv("SUPABASE_URL"), getPublishableKey(), {
    global: { headers: authHeader ? { Authorization: authHeader } : {} },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export function serviceClient(): SupabaseClient {
  const secret = Deno.env.get("SUPABASE_SECRET_KEY") ??
    getEnv("SUPABASE_SERVICE_ROLE_KEY");
  return createClient(getEnv("SUPABASE_URL"), secret, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export async function requireUser(authHeader?: string): Promise<User> {
  if (!authHeader?.startsWith("Bearer ")) {
    throw new HttpError(401, "Oturum gerekli", "AUTH_REQUIRED");
  }

  const auth = clientWithJwt(authHeader).auth;
  const clockSkewBackoffMs = [0, 750, 1_500];
  for (const delayMs of clockSkewBackoffMs) {
    if (delayMs > 0) {
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
    try {
      const { data, error } = await auth.getUser();
      if (data.user) return data.user;
      if (!error?.message.toLowerCase().includes("jwt issued at future")) {
        break;
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      if (!message.toLowerCase().includes("jwt issued at future")) {
        break;
      }
    }
  }

  throw new HttpError(
    401,
    "Geçersiz veya süresi dolmuş oturum",
    "AUTH_INVALID",
  );
}

export async function requirePermanentUser(authHeader?: string): Promise<User> {
  const user = await requireUser(authHeader);
  if (user.is_anonymous) {
    throw new HttpError(403, "Host hesabı gerekli", "HOST_REQUIRED");
  }
  return user;
}

export async function requireAnonymousUser(authHeader?: string): Promise<User> {
  const user = await requireUser(authHeader);
  if (!user.is_anonymous) {
    throw new HttpError(403, "Ziyaretçi oturumu gerekli", "VISITOR_REQUIRED");
  }
  return user;
}

export async function readJson<T = Record<string, unknown>>(
  req: Request,
  maxBytes = 16_384,
): Promise<T> {
  const contentLength = Number(req.headers.get("content-length") ?? "0");
  if (contentLength > maxBytes) {
    throw new HttpError(413, "İstek çok büyük", "PAYLOAD_TOO_LARGE");
  }
  try {
    return await req.json() as T;
  } catch {
    throw new HttpError(400, "Geçersiz JSON", "INVALID_JSON");
  }
}

export function cleanText(
  value: unknown,
  maxLength: number,
  required = false,
): string | null {
  if (typeof value !== "string") {
    if (required) {
      throw new HttpError(400, "Zorunlu metin eksik", "VALIDATION_ERROR");
    }
    return null;
  }
  const cleaned = value.trim();
  if (!cleaned && required) {
    throw new HttpError(400, "Zorunlu metin eksik", "VALIDATION_ERROR");
  }
  if (cleaned.length > maxLength) {
    throw new HttpError(
      400,
      `Metin en fazla ${maxLength} karakter olabilir`,
      "VALIDATION_ERROR",
    );
  }
  return cleaned || null;
}

export async function sha256Hex(input: string) {
  const hashBuffer = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(input),
  );
  return Array.from(new Uint8Array(hashBuffer))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export async function hmacSha256Hex(input: string, secret: string) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(input),
  );
  return Array.from(new Uint8Array(signature))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export function requestIp(req: Request): string {
  return req.headers.get("cf-connecting-ip") ??
    req.headers.get("x-real-ip") ??
    req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ??
    "unknown";
}

export async function requestIpHash(req: Request): Promise<string> {
  return hmacSha256Hex(requestIp(req), getEnv("VISITOR_IP_HASH_SALT"));
}

export async function visitorDeviceHash(
  req: Request,
  client: Record<string, unknown> | undefined,
): Promise<string> {
  const deviceKey = cleanText(client?.device_key, 100, true)!;
  const canonical = [
    deviceKey,
    req.headers.get("user-agent") ?? "",
    cleanText(client?.platform, 80) ?? "",
    cleanText(client?.language, 40) ?? "",
    cleanText(client?.timezone, 80) ?? "",
    cleanText(client?.screen, 40) ?? "",
    String(client?.hardware_concurrency ?? ""),
    String(client?.device_memory ?? ""),
    String(client?.touch_points ?? ""),
  ].join("|");
  return hmacSha256Hex(canonical, getEnv("VISITOR_DEVICE_HASH_SALT"));
}

export function randomSecret(bytes = 32) {
  const array = new Uint8Array(bytes);
  crypto.getRandomValues(array);
  return btoa(String.fromCharCode(...array))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

export async function requireDoorHost(
  admin: SupabaseClient,
  doorId: string,
  userId: string,
) {
  const { data: door, error } = await admin
    .from("doors")
    .select("id, owner_user_id, label")
    .eq("id", doorId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  if (!door) {
    throw new HttpError(404, "Dijital zil bulunamadı", "DOOR_NOT_FOUND");
  }
  if (door.owner_user_id === userId) return { ...door, role: "owner" as const };

  const { data: shared, error: sharedError } = await admin
    .from("door_shared_users")
    .select("id")
    .eq("door_id", doorId)
    .eq("user_id", userId)
    .maybeSingle();
  if (sharedError) throw new Error(sharedError.message);
  if (!shared) {
    throw new HttpError(403, "Bu dijital zile erişiminiz yok", "FORBIDDEN");
  }
  return { ...door, role: "shared" as const };
}
