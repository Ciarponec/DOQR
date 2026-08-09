import { getEnv } from "./utils.ts";

function fromBase64Url(value: string): Uint8Array {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  return Uint8Array.from(atob(padded), (char) => char.charCodeAt(0));
}

function toBase64Url(value: Uint8Array): string {
  let binary = "";
  for (const byte of value) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(
    /=+$/,
    "",
  );
}

function asArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  return Uint8Array.from(bytes).buffer as ArrayBuffer;
}

async function courierKey() {
  const bytes = fromBase64Url(getEnv("COURIER_NOTE_ENCRYPTION_KEY"));
  if (bytes.byteLength !== 32) {
    throw new Error("COURIER_NOTE_ENCRYPTION_KEY must be 32 bytes (base64url)");
  }
  return crypto.subtle.importKey(
    "raw",
    asArrayBuffer(bytes),
    { name: "AES-GCM" },
    false,
    ["encrypt", "decrypt"],
  );
}

export async function encryptCourierCode(
  value: string | null,
): Promise<string | null> {
  if (!value) return null;
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encrypted = await crypto.subtle.encrypt(
    {
      name: "AES-GCM",
      iv: asArrayBuffer(iv),
      additionalData: new TextEncoder().encode("doqr:courier:v1"),
    },
    await courierKey(),
    new TextEncoder().encode(value),
  );
  return `v1:${toBase64Url(iv)}:${toBase64Url(new Uint8Array(encrypted))}`;
}

export async function decryptCourierCode(
  value: string | null,
): Promise<string | null> {
  if (!value) return null;
  if (!value.startsWith("v1:")) return value;
  const [, iv, encrypted] = value.split(":");
  const plain = await crypto.subtle.decrypt(
    {
      name: "AES-GCM",
      iv: asArrayBuffer(fromBase64Url(iv)),
      additionalData: new TextEncoder().encode("doqr:courier:v1"),
    },
    await courierKey(),
    asArrayBuffer(fromBase64Url(encrypted)),
  );
  return new TextDecoder().decode(plain);
}
