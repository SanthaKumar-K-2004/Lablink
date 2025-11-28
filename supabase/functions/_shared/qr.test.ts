import { assertEquals, assertAlmostEquals } from 'https://deno.land/std@0.203.0/testing/asserts.ts';
import { QR_VALIDITY_MS, calculateQrExpiry, decodeQrPayload, encodeQrPayload } from './qr.ts';

Deno.test('encodeQrPayload produces reversible envelope', () => {
  const expires = calculateQrExpiry(new Date('2024-01-01T00:00:00Z'));
  const token = 'demo-token';
  const { encoded } = encodeQrPayload(token, expires, { item_id: '123' });
  const decoded = decodeQrPayload(encoded);

  assertEquals(decoded.token, token);
  assertEquals(decoded.expires_at, expires);
  assertEquals(decoded.item_id, '123');
});

Deno.test('calculateQrExpiry adds 30 days worth of milliseconds', () => {
  const now = new Date();
  const expires = new Date(calculateQrExpiry(now));
  assertAlmostEquals(expires.getTime() - now.getTime(), QR_VALIDITY_MS, 25);
});
