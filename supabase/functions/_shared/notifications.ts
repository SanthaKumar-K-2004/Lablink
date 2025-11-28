import { DispatchResult, NotificationChannel, NotificationContactInfo, NotificationPayload } from './types.ts';

export interface NotificationDispatchContext {
  emailApiKey?: string;
  emailFrom?: string;
  emailFromName?: string;
  smsAccountSid?: string;
  smsAuthToken?: string;
  smsFromNumber?: string;
  fcmServerKey?: string;
  fetchImpl?: typeof fetch;
}

const SENDGRID_URL = 'https://api.sendgrid.com/v3/mail/send';
const TWILIO_BASE = 'https://api.twilio.com/2010-04-01';
const FCM_URL = 'https://fcm.googleapis.com/fcm/send';

interface DispatchInput {
  channels: NotificationChannel[];
  payload: NotificationPayload;
  targets: NotificationContactInfo;
  context: NotificationDispatchContext;
}

export async function dispatchNotificationChannels(input: DispatchInput): Promise<DispatchResult[]> {
  const { channels, payload, targets, context } = input;
  const fetchImpl = context.fetchImpl ?? fetch;
  const tasks: Promise<DispatchResult>[] = [];

  for (const channel of channels) {
    switch (channel) {
      case 'in_app':
        tasks.push(Promise.resolve({ channel, status: 'sent' }));
        break;
      case 'email':
        tasks.push(sendEmail(payload, targets, context, fetchImpl));
        break;
      case 'sms':
        tasks.push(sendSms(payload, targets, context, fetchImpl));
        break;
      case 'push':
        tasks.push(sendPush(payload, targets, context, fetchImpl));
        break;
      default:
        tasks.push(Promise.resolve({ channel, status: 'skipped', detail: 'Unsupported channel' }));
    }
  }

  return await Promise.all(tasks);
}

function buildEmailBody(payload: NotificationPayload) {
  const plain = `${payload.message}${payload.actionLink ? `\n\nTake action: ${payload.actionLink}` : ''}`;
  const htmlMessage = escapeHtml(payload.message).replace(/\n/g, '<br/>');
  const html = `${htmlMessage}${payload.actionLink ? `<p><a href="${payload.actionLink}">Take action</a></p>` : ''}`;
  return { plain, html };
}

async function sendEmail(
  payload: NotificationPayload,
  targets: NotificationContactInfo,
  context: NotificationDispatchContext,
  fetchImpl: typeof fetch,
): Promise<DispatchResult> {
  if (!targets.email) {
    return { channel: 'email', status: 'skipped', detail: 'Recipient missing email address' };
  }
  if (!context.emailApiKey || !context.emailFrom) {
    return { channel: 'email', status: 'skipped', detail: 'Email channel not configured' };
  }

  const { plain, html } = buildEmailBody(payload);
  const body = {
    personalizations: [
      {
        to: [{ email: targets.email, name: targets.fullName ?? undefined }],
      },
    ],
    from: {
      email: context.emailFrom,
      name: context.emailFromName ?? 'LabLink Notifications',
    },
    subject: payload.title,
    content: [
      { type: 'text/plain', value: plain },
      { type: 'text/html', value: html },
    ],
  };

  try {
    const response = await fetchImpl(SENDGRID_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${context.emailApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      return { channel: 'email', status: 'failed', detail: `SendGrid ${response.status}` };
    }
  } catch (error) {
    return { channel: 'email', status: 'failed', detail: (error as Error).message };
  }

  return { channel: 'email', status: 'sent' };
}

async function sendSms(
  payload: NotificationPayload,
  targets: NotificationContactInfo,
  context: NotificationDispatchContext,
  fetchImpl: typeof fetch,
): Promise<DispatchResult> {
  if (!targets.phone) {
    return { channel: 'sms', status: 'skipped', detail: 'Recipient missing phone number' };
  }
  if (!context.smsAccountSid || !context.smsAuthToken || !context.smsFromNumber) {
    return { channel: 'sms', status: 'skipped', detail: 'SMS channel not configured' };
  }

  const text = `${payload.title}: ${payload.message}`.slice(0, 1500);
  const params = new URLSearchParams({
    To: targets.phone,
    From: context.smsFromNumber,
    Body: payload.actionLink ? `${text}\n${payload.actionLink}` : text,
  });

  const auth = btoa(`${context.smsAccountSid}:${context.smsAuthToken}`);
  const url = `${TWILIO_BASE}/Accounts/${context.smsAccountSid}/Messages.json`;

  try {
    const response = await fetchImpl(url, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${auth}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: params,
    });

    if (!response.ok) {
      return { channel: 'sms', status: 'failed', detail: `Twilio ${response.status}` };
    }
  } catch (error) {
    return { channel: 'sms', status: 'failed', detail: (error as Error).message };
  }

  return { channel: 'sms', status: 'sent' };
}

async function sendPush(
  payload: NotificationPayload,
  targets: NotificationContactInfo,
  context: NotificationDispatchContext,
  fetchImpl: typeof fetch,
): Promise<DispatchResult> {
  if (!targets.pushToken) {
    return { channel: 'push', status: 'skipped', detail: 'Recipient missing push token' };
  }
  if (!context.fcmServerKey) {
    return { channel: 'push', status: 'skipped', detail: 'Push channel not configured' };
  }

  const body = {
    to: targets.pushToken,
    notification: {
      title: payload.title,
      body: payload.message,
    },
    data: payload.actionData ?? {},
  };

  try {
    const response = await fetchImpl(FCM_URL, {
      method: 'POST',
      headers: {
        Authorization: `key=${context.fcmServerKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      return { channel: 'push', status: 'failed', detail: `FCM ${response.status}` };
    }
  } catch (error) {
    return { channel: 'push', status: 'failed', detail: (error as Error).message };
  }

  return { channel: 'push', status: 'sent' };
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
