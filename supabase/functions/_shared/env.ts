import { NotificationChannel } from './types.ts';

export function getEnv(key: string, fallback?: string): string | undefined {
  const value = Deno.env.get(key) ?? undefined;
  return value ? value : fallback;
}

export function requireEnv(key: string): string {
  const value = getEnv(key);
  if (!value) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return value;
}

export function getSupabaseCredentials() {
  return {
    url: requireEnv('SUPABASE_URL'),
    serviceKey: requireEnv('SUPABASE_SERVICE_ROLE_KEY'),
  };
}

export function getQrSecret(): string {
  return (
    getEnv('LABLINK_QR_JWT_SECRET') ??
    getEnv('SUPABASE_JWT_SECRET') ??
    ''
  );
}

export function getFunctionTimeoutMs(): number {
  const raw = getEnv('LABLINK_FUNCTION_TIMEOUT_MS', '30000');
  const parsed = Number(raw);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 30000;
}

export interface NotificationEnvConfig {
  emailApiKey?: string;
  emailFrom?: string;
  emailFromName?: string;
  smsAccountSid?: string;
  smsAuthToken?: string;
  smsFromNumber?: string;
  fcmServerKey?: string;
  defaultChannels: NotificationChannel[];
}

export function getNotificationEnv(): NotificationEnvConfig {
  const defaultChannels = (getEnv('LABLINK_DEFAULT_NOTIFICATION_CHANNELS') ?? 'in_app,email')
    .split(',')
    .map((channel) => channel.trim())
    .filter((channel): channel is NotificationChannel => ['in_app', 'email', 'sms', 'push'].includes(channel as NotificationChannel));

  return {
    emailApiKey: getEnv('LABLINK_SENDGRID_API_KEY') ?? getEnv('LABLINK_SMTP_API_KEY'),
    emailFrom: getEnv('LABLINK_NOTIFICATION_EMAIL_FROM'),
    emailFromName: getEnv('LABLINK_NOTIFICATION_EMAIL_NAME') ?? 'LabLink Notifications',
    smsAccountSid: getEnv('LABLINK_TWILIO_ACCOUNT_SID'),
    smsAuthToken: getEnv('LABLINK_TWILIO_AUTH_TOKEN'),
    smsFromNumber: getEnv('LABLINK_TWILIO_FROM_NUMBER'),
    fcmServerKey: getEnv('LABLINK_FCM_SERVER_KEY'),
    defaultChannels: defaultChannels.length > 0 ? defaultChannels : ['in_app'],
  };
}
