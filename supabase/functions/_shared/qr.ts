export const QR_VALIDITY_MS = 1000 * 60 * 60 * 24 * 30;

export function calculateQrExpiry(baseDate = new Date()): string {
  return new Date(baseDate.getTime() + QR_VALIDITY_MS).toISOString();
}

export interface QrEnvelopeMetadata {
  item_id?: string;
  department_id?: string;
  category_id?: string;
  status?: string;
  [key: string]: unknown;
}

export function encodeQrPayload(token: string, expiresAt: string, metadata: QrEnvelopeMetadata = {}) {
  const envelope = {
    token,
    expires_at: expiresAt,
    ...metadata,
  };
  const encoded = btoa(JSON.stringify(envelope));
  return { envelope, encoded };
}

export function decodeQrPayload(encoded: string) {
  const raw = atob(encoded);
  return JSON.parse(raw);
}
