export type NotificationChannel = 'in_app' | 'email' | 'sms' | 'push';

export type NotificationPriority = 'low' | 'medium' | 'high' | 'critical';

export interface NotificationContactInfo {
  email?: string | null;
  phone?: string | null;
  pushToken?: string | null;
  fullName?: string | null;
}

export interface NotificationPayload {
  title: string;
  message: string;
  actionLink?: string;
  actionData?: Record<string, unknown> | null;
  priority?: NotificationPriority;
}

export interface DispatchResult {
  channel: NotificationChannel;
  status: 'sent' | 'failed' | 'skipped';
  detail?: string;
}

export interface NotificationRequestBody extends NotificationPayload {
  user_id: string;
  type: string;
  channels?: NotificationChannel[];
  action_data?: Record<string, unknown>;
  sms_override?: string;
  email_override?: string;
  push_token?: string;
}
