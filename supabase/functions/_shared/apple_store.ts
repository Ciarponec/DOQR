import "npm:reflect-metadata@0.2.2";
import { X509Certificate } from "npm:@peculiar/x509@2.0.0";
import { compactVerify, decodeJwt, decodeProtectedHeader } from "jsr:@panva/jose@6";

import { HttpError } from "./utils.ts";

export const APPLE_BUNDLE_ID = "com.doqr.app";
export const APPLE_PRO_PRODUCT_ID = "doqr_pro_annual";

type AppleEnvironment = "Sandbox" | "Production";

export interface AppleTransactionPayload {
  appAccountToken?: string;
  bundleId?: string;
  environment?: AppleEnvironment;
  expiresDate?: number;
  originalTransactionId?: string;
  productId?: string;
  revocationDate?: number;
  signedDate?: number;
  transactionId?: string;
  type?: string;
  [key: string]: unknown;
}

export interface AppleRenewalInfoPayload {
  autoRenewStatus?: number;
  environment?: AppleEnvironment;
  gracePeriodExpiresDate?: number;
  signedDate?: number;
  [key: string]: unknown;
}

export interface AppleNotificationPayload {
  data?: {
    appAppleId?: number;
    bundleId?: string;
    environment?: AppleEnvironment;
    signedRenewalInfo?: string;
    signedTransactionInfo?: string;
    [key: string]: unknown;
  };
  notificationType?: string;
  signedDate?: number;
  subtype?: string;
  [key: string]: unknown;
}

// DER-encoded Apple root certificates, downloaded from Apple's PKI page on
// 2026-08-10. Keeping the roots in the function bundle avoids trusting a
// network-fetched certificate at verification time.
// https://www.apple.com/certificateauthority/
const APPLE_ROOT_CERTIFICATES = [
  "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",
];

const APPLE_LEAF_EXTENSION = "1.2.840.113635.100.6.11.1";
const APPLE_INTERMEDIATE_EXTENSION = "1.2.840.113635.100.6.2.1";
const APPLE_JWS_ALGORITHM = "ES256";
const CLOCK_SKEW_MS = 60_000;

const trustedRoots = APPLE_ROOT_CERTIFICATES.map((value) =>
  new X509Certificate(value)
);

function requireEnvironment(value: unknown): AppleEnvironment {
  if (value === "Sandbox" || value === "Production") return value;
  throw new HttpError(
    400,
    "Desteklenmeyen App Store ortamı",
    "APPLE_ENVIRONMENT_INVALID",
  );
}

function assertCertificateDate(
  certificate: X509Certificate,
  effectiveDate: Date,
): void {
  const timestamp = effectiveDate.getTime();
  if (
    certificate.notBefore.getTime() > timestamp + CLOCK_SKEW_MS ||
    certificate.notAfter.getTime() < timestamp - CLOCK_SKEW_MS
  ) {
    throw new HttpError(
      400,
      "App Store sertifikasının geçerlilik süresi uygun değil",
      "APPLE_CERTIFICATE_EXPIRED",
    );
  }
}

async function verifyCertificateChain(
  encodedChain: string[],
  effectiveDate: Date,
): Promise<X509Certificate> {
  if (encodedChain.length !== 3) {
    throw new HttpError(
      400,
      "App Store sertifika zinciri geçersiz",
      "APPLE_CERTIFICATE_CHAIN_INVALID",
    );
  }

  let leaf: X509Certificate;
  let intermediate: X509Certificate;
  try {
    leaf = new X509Certificate(encodedChain[0]);
    intermediate = new X509Certificate(encodedChain[1]);
  } catch (error) {
    console.error("Apple certificate parsing failed", error);
    throw new HttpError(
      400,
      "App Store sertifikası okunamadı",
      "APPLE_CERTIFICATE_INVALID",
    );
  }

  assertCertificateDate(leaf, effectiveDate);
  assertCertificateDate(intermediate, effectiveDate);
  if (
    leaf.issuer !== intermediate.subject ||
    !leaf.getExtension(APPLE_LEAF_EXTENSION) ||
    !intermediate.getExtension(APPLE_INTERMEDIATE_EXTENSION) ||
    !(await leaf.verify({ publicKey: intermediate.publicKey }))
  ) {
    throw new HttpError(
      400,
      "App Store sertifika zinciri doğrulanamadı",
      "APPLE_CERTIFICATE_CHAIN_INVALID",
    );
  }

  for (const root of trustedRoots) {
    assertCertificateDate(root, effectiveDate);
    if (
      intermediate.issuer === root.subject &&
      await intermediate.verify({ publicKey: root.publicKey })
    ) {
      return leaf;
    }
  }
  throw new HttpError(
    400,
    "App Store sertifika zinciri güvenilir bir Apple köküne ulaşmıyor",
    "APPLE_CERTIFICATE_CHAIN_INVALID",
  );
}

function parseJsonObject(value: Uint8Array): Record<string, unknown> {
  try {
    const parsed = JSON.parse(new TextDecoder().decode(value));
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      throw new Error("JWS payload is not an object");
    }
    return parsed as Record<string, unknown>;
  } catch (error) {
    console.error("Apple JWS payload parsing failed", error);
    throw new HttpError(400, "Geçersiz App Store imzası", "APPLE_JWS_INVALID");
  }
}

async function verifySignedData<T extends Record<string, unknown>>(
  signedData: string,
): Promise<T> {
  const parts = signedData.split(".");
  if (parts.length !== 3) {
    throw new HttpError(400, "Geçersiz App Store imzası", "APPLE_JWS_INVALID");
  }

  try {
    const header = decodeProtectedHeader(signedData);
    if (header.alg !== APPLE_JWS_ALGORITHM || !Array.isArray(header.x5c)) {
      throw new HttpError(
        400,
        "App Store imza başlığı geçersiz",
        "APPLE_JWS_INVALID",
      );
    }
    const unverifiedPayload = decodeJwt(signedData) as Record<string, unknown>;
    const signedDate = typeof unverifiedPayload.signedDate === "number"
      ? new Date(unverifiedPayload.signedDate)
      : null;
    if (signedDate != null && !Number.isFinite(signedDate.getTime())) {
      throw new HttpError(400, "Geçersiz App Store tarihi", "APPLE_JWS_INVALID");
    }

    const leaf = await verifyCertificateChain(header.x5c, new Date());
    const publicKey = await leaf.publicKey.export(
      { name: "ECDSA", namedCurve: "P-256" },
      ["verify"],
    );
    const verified = await compactVerify(signedData, publicKey, {
      algorithms: [APPLE_JWS_ALGORITHM],
    });
    return parseJsonObject(verified.payload) as T;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    console.error("Apple signed-data verification failed", error);
    throw new HttpError(
      400,
      "App Store satın alma imzası doğrulanamadı",
      "APPLE_VERIFY_FAILED",
    );
  }
}

function expectedAppAppleId(): number {
  const value = Number(Deno.env.get("APPLE_APP_ID"));
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new Error("Missing or invalid APPLE_APP_ID");
  }
  return value;
}

export async function verifyAppleTransaction(
  signedTransaction: string,
): Promise<AppleTransactionPayload> {
  const transaction = await verifySignedData<AppleTransactionPayload>(
    signedTransaction,
  );
  const environment = requireEnvironment(transaction.environment);
  if (transaction.bundleId !== APPLE_BUNDLE_ID) {
    throw new HttpError(400, "App Store uygulama kimliği eşleşmiyor", "APPLE_APP_MISMATCH");
  }
  if (environment === "Production") expectedAppAppleId();
  return transaction;
}

export async function verifyAppleNotification(
  signedPayload: string,
): Promise<AppleNotificationPayload> {
  const notification = await verifySignedData<AppleNotificationPayload>(signedPayload);
  const environment = requireEnvironment(notification.data?.environment);
  if (notification.data?.bundleId !== APPLE_BUNDLE_ID) {
    throw new HttpError(400, "App Store uygulama kimliği eşleşmiyor", "APPLE_APP_MISMATCH");
  }
  if (
    environment === "Production" &&
    notification.data?.appAppleId !== expectedAppAppleId()
  ) {
    throw new HttpError(400, "App Store uygulama kimliği eşleşmiyor", "APPLE_APP_MISMATCH");
  }
  return notification;
}

export async function verifyAppleRenewalInfo(
  signedRenewalInfo: string,
): Promise<AppleRenewalInfoPayload> {
  const renewal = await verifySignedData<AppleRenewalInfoPayload>(
    signedRenewalInfo,
  );
  requireEnvironment(renewal.environment);
  return renewal;
}
