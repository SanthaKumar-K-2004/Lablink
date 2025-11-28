import { serve } from 'https://deno.land/std@0.203.0/http/server.ts';
import { jsonResponse, errorResponse, parseJsonBody } from '../_shared/http.ts';
import { encodeQrPayload, calculateQrExpiry } from '../_shared/qr.ts';
import { createServiceClient } from '../_shared/supabaseClient.ts';
import { isUuid } from '../_shared/utils.ts';

interface QrSignRequestBody {
  item_id: string;
  department_id?: string;
  category_id?: string;
}

const supabase = createServiceClient();

serve(async (req) => {
  if (req.method !== 'POST') {
    return errorResponse(405, 'Method not allowed', { allowed: ['POST'] });
  }

  let body: QrSignRequestBody;
  try {
    body = await parseJsonBody<QrSignRequestBody>(req);
  } catch (error) {
    return errorResponse(400, (error as Error).message);
  }

  const { item_id: itemId, department_id: deptId, category_id: categoryId } = body ?? {};

  if (!isUuid(itemId)) {
    return errorResponse(400, 'item_id must be a valid UUID');
  }

  const { data: item, error: itemError } = await supabase
    .from('items')
    .select('id, department_id, category_id, status, name, serial_number')
    .eq('id', itemId)
    .maybeSingle();

  if (itemError) {
    console.error('qr-sign:item_lookup', itemError);
    return errorResponse(500, 'Failed to load item metadata');
  }

  if (!item) {
    return errorResponse(404, 'Item not found');
  }

  if (deptId && deptId !== item.department_id) {
    return errorResponse(400, 'Department mismatch for item');
  }

  if (categoryId && categoryId !== item.category_id) {
    return errorResponse(400, 'Category mismatch for item');
  }

  const metadata = {
    item_name: item.name,
    serial_number: item.serial_number,
    generated_at: new Date().toISOString(),
  };

  const { data: hashData, error: hashError } = await supabase.rpc('generate_qr_hash', {
    p_item_id: itemId,
    p_department_id: item.department_id,
    p_category_id: item.category_id,
    p_status: item.status,
    p_metadata: metadata,
  });

  if (hashError || !hashData) {
    console.error('qr-sign:generate_hash', hashError);
    return errorResponse(500, 'Failed to generate QR hash');
  }

  const qrHash = typeof hashData === 'string' ? hashData : String(hashData);
  const expiresAt = calculateQrExpiry();
  const { encoded } = encodeQrPayload(qrHash, expiresAt, {
    item_id: itemId,
    department_id: item.department_id,
    category_id: item.category_id,
    status: item.status,
  });

  const { error: updateError } = await supabase
    .from('items')
    .update({
      qr_hash: qrHash,
      qr_payload: {
        item_id: itemId,
        department_id: item.department_id,
        category_id: item.category_id,
        status: item.status,
        qr_payload: encoded,
        expires_at: expiresAt,
      },
    })
    .eq('id', itemId);

  if (updateError) {
    console.error('qr-sign:update_item', updateError);
    return errorResponse(500, 'Generated QR but failed to persist payload');
  }

  return jsonResponse(200, {
    qr_payload: encoded,
    qr_hash: qrHash,
    expires_at: expiresAt,
    item_id: itemId,
    department_id: item.department_id,
    category_id: item.category_id,
  });
});
