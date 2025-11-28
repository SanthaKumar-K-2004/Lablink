import { serve } from 'https://deno.land/std@0.203.0/http/server.ts';
import { errorResponse, jsonResponse, parseJsonBody } from '../_shared/http.ts';
import { dispatchNotificationChannels } from '../_shared/notifications.ts';
import { createServiceClient } from '../_shared/supabaseClient.ts';
import { getNotificationEnv } from '../_shared/env.ts';
import { NotificationChannel, NotificationRequestBody } from '../_shared/types.ts';
import { ensureArray, isUuid } from '../_shared/utils.ts';

const supabase = createServiceClient();
const envConfig = getNotificationEnv();

const VALID_NOTIFICATION_TYPES = new Set([
  'approval',
  'rejection',
  'reminder_2days',
  'reminder_due',
  'reminder_overdue',
  'low_stock',
  'expiry_warning',
  'damage_reported',
  'maintenance_assigned',
  'maintenance_completed',
]);

const VALID_CHANNELS: NotificationChannel[] = ['in_app', 'email', 'sms', 'push'];

serve(async (req) => {
  if (req.method !== 'POST') {
    return errorResponse(405, 'Method not allowed', { allowed: ['POST'] });
  }

  let body: NotificationRequestBody;
  try {
    body = await parseJsonBody<NotificationRequestBody>(req);
  } catch (error) {
    return errorResponse(400, (error as Error).message);
  }

  if (!body?.user_id || !isUuid(body.user_id)) {
    return errorResponse(400, 'user_id is required and must be a UUID');
  }

  if (!body.title || !body.message || !body.type) {
    return errorResponse(400, 'type, title, and message are required');
  }

  const normalizedType = body.type.toLowerCase().trim();
  if (!VALID_NOTIFICATION_TYPES.has(normalizedType)) {
    return errorResponse(400, `Unsupported notification type: ${body.type}`);
  }

  const requestedChannels = dedupeChannels(
    ensureArray(body.channels).length > 0 ? ensureArray(body.channels) : envConfig.defaultChannels,
  );

  const invalidChannels = requestedChannels.filter((channel) => !VALID_CHANNELS.includes(channel));
  if (invalidChannels.length > 0) {
    return errorResponse(400, `Invalid channel(s): ${invalidChannels.join(', ')}`);
  }

  const { data: user, error: userError } = await supabase
    .from('users')
    .select('id, email, phone_number, full_name')
    .eq('id', body.user_id)
    .maybeSingle();

  if (userError) {
    console.error('notify:user_lookup', userError);
    return errorResponse(500, 'Unable to load user profile');
  }

  if (!user) {
    return errorResponse(404, 'User not found');
  }

  const { data: preferenceRows, error: preferenceError } = await supabase.rpc('get_user_notification_preferences', {
    p_user_id: body.user_id,
  });

  if (preferenceError) {
    console.error('notify:preferences', preferenceError);
    return errorResponse(500, 'Unable to load notification preferences');
  }

  const allowedChannels = filterChannelsByPreference(requestedChannels, normalizedType, preferenceRows ?? []);
  if (allowedChannels.length === 0) {
    allowedChannels.push('in_app');
  }

  const actionData = body.action_data ?? null;
  const supabasePayload = {
    p_user_id: body.user_id,
    p_type: normalizedType,
    p_title: body.title,
    p_message: body.message,
    p_action_link: body.action_link ?? null,
    p_channels: allowedChannels,
    p_priority: body.priority ?? 'medium',
    p_action_data: actionData,
  };

  const { data: notificationId, error: sendError } = await supabase.rpc('send_notification', supabasePayload);

  if (sendError || !notificationId) {
    console.error('notify:send_notification', sendError);
    return errorResponse(500, 'Failed to create notification');
  }

  const contact = {
    email: body.email_override ?? user.email,
    phone: body.sms_override ?? user.phone_number,
    pushToken: body.push_token ?? null,
    fullName: user.full_name,
  };

  const dispatchResults = await dispatchNotificationChannels({
    channels: allowedChannels,
    payload: {
      title: body.title,
      message: body.message,
      actionLink: body.action_link,
      actionData,
      priority: body.priority,
    },
    targets: contact,
    context: envConfig,
  });

  try {
    await Promise.all(dispatchResults
      .filter((result) => result.channel !== 'in_app')
      .map((result) => supabase.rpc('update_notification_dispatch_status', {
        p_notification_id: notificationId,
        p_channel: result.channel,
        p_status: result.status,
        p_error: result.detail ?? null,
      })));
  } catch (error) {
    console.error('notify:update_dispatch_status', error);
  }

  const anyFailed = dispatchResults.some((result) => result.status === 'failed');
  const responseStatus = anyFailed ? 'partial' : 'sent';

  return jsonResponse(200, {
    notification_id: notificationId,
    status: responseStatus,
    channels_sent: dispatchResults,
  });
});

function dedupeChannels(channels: NotificationChannel[]): NotificationChannel[] {
  const seen = new Set<NotificationChannel>();
  const result: NotificationChannel[] = [];
  for (const channel of channels) {
    if (!seen.has(channel)) {
      seen.add(channel);
      result.push(channel);
    }
  }
  if (!seen.has('in_app')) {
    result.unshift('in_app');
  }
  return result;
}

function filterChannelsByPreference(
  requested: NotificationChannel[],
  type: string,
  preferenceRows: Array<{ notification_type: string; channel: NotificationChannel; enabled: boolean }>,
): NotificationChannel[] {
  const allowed = new Set<NotificationChannel>();
  const lookup = new Map<string, Map<NotificationChannel, boolean>>();

  for (const row of preferenceRows) {
    const typeKey = row.notification_type.toLowerCase();
    if (!lookup.has(typeKey)) {
      lookup.set(typeKey, new Map());
    }
    lookup.get(typeKey)!.set(row.channel, row.enabled);
  }

  for (const channel of requested) {
    if (channel === 'in_app') {
      allowed.add('in_app');
      continue;
    }
    const channelMap = lookup.get(type);
    if (!channelMap || channelMap.get(channel) !== false) {
      allowed.add(channel);
    }
  }

  return Array.from(allowed);
}
