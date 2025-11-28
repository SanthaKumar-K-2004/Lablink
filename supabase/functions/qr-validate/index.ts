import { serve } from 'https://deno.land/std@0.203.0/http/server.ts';
import { errorResponse, jsonResponse, parseJsonBody } from '../_shared/http.ts';
import { createServiceClient } from '../_shared/supabaseClient.ts';
import { extractClientIp, isUuid } from '../_shared/utils.ts';

interface QrValidateRequestBody {
  qr_payload: string;
  user_id?: string;
}

const supabase = createServiceClient();

serve(async (req) => {
  if (req.method !== 'POST') {
    return errorResponse(405, 'Method not allowed', { allowed: ['POST'] });
  }

  let body: QrValidateRequestBody;
  try {
    body = await parseJsonBody<QrValidateRequestBody>(req);
  } catch (error) {
    return errorResponse(400, (error as Error).message);
  }

  if (!body?.qr_payload) {
    return errorResponse(400, 'qr_payload is required');
  }

  const userId = body.user_id;
  if (userId && !isUuid(userId)) {
    return errorResponse(400, 'user_id must be a valid UUID');
  }

  const ip = extractClientIp(req.headers);
  const userAgent = req.headers.get('user-agent') ?? undefined;

  const { data, error } = await supabase.rpc('validate_qr_scan', {
    p_qr_payload: body.qr_payload,
    p_user_id: userId ?? null,
    p_ip: ip ?? null,
    p_user_agent: userAgent ?? null,
  }).single();

  if (error) {
    console.error('qr-validate:rpc', error);
    return errorResponse(400, 'Unable to validate QR payload');
  }

  if (!data) {
    return jsonResponse(200, { valid: false, message: 'Unable to validate QR payload' });
  }

  return jsonResponse(200, data);
});
