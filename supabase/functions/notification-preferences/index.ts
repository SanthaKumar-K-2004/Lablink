import { serve } from 'https://deno.land/std@0.203.0/http/server.ts';
import { errorResponse, jsonResponse } from '../_shared/http.ts';
import { createServiceClient } from '../_shared/supabaseClient.ts';
import { NotificationChannel } from '../_shared/types.ts';
import { isUuid } from '../_shared/utils.ts';

const supabase = createServiceClient();
const CHANNELS: NotificationChannel[] = ['in_app', 'email', 'sms', 'push'];

serve(async (req) => {
  if (req.method !== 'GET') {
    return errorResponse(405, 'Method not allowed', { allowed: ['GET'] });
  }

  const url = new URL(req.url);
  const userId = url.searchParams.get('user_id');

  if (!userId || !isUuid(userId)) {
    return errorResponse(400, 'user_id query parameter is required and must be a UUID');
  }

  const { data, error } = await supabase.rpc('get_user_notification_preferences', { p_user_id: userId });

  if (error) {
    console.error('notification-preferences:rpc', error);
    return errorResponse(500, 'Unable to load preferences');
  }

  const mapped = mapPreferences(data ?? []);

  return jsonResponse(200, {
    user_id: userId,
    preferences: mapped,
    available_channels: CHANNELS,
  });
});

function mapPreferences(rows: Array<{ notification_type: string; channel: NotificationChannel; enabled: boolean }>) {
  const result: Record<string, Record<NotificationChannel, boolean>> = {};
  for (const row of rows) {
    const typeKey = row.notification_type.toLowerCase();
    if (!result[typeKey]) {
      result[typeKey] = {} as Record<NotificationChannel, boolean>;
    }
    result[typeKey][row.channel] = row.enabled;
  }
  return result;
}
