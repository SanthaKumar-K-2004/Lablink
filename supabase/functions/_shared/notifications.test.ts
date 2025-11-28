import { assertEquals } from 'https://deno.land/std@0.203.0/testing/asserts.ts';
import { dispatchNotificationChannels } from './notifications.ts';
import { NotificationPayload } from './types.ts';

const basePayload: NotificationPayload = {
  title: 'Test title',
  message: 'Test body',
};

Deno.test('email channel skips when configuration is missing', async () => {
  const results = await dispatchNotificationChannels({
    channels: ['email'],
    payload: basePayload,
    targets: { email: 'user@example.com' },
    context: {},
  });

  assertEquals(results[0].status, 'skipped');
});

Deno.test('email channel succeeds with SendGrid configuration', async () => {
  const fakeFetch = async () => new Response(null, { status: 202 });
  const results = await dispatchNotificationChannels({
    channels: ['email'],
    payload: basePayload,
    targets: { email: 'user@example.com', fullName: 'Test User' },
    context: {
      emailApiKey: 'SG.fake',
      emailFrom: 'noreply@example.com',
      emailFromName: 'LabLink Tests',
      fetchImpl: fakeFetch,
    },
  });

  assertEquals(results[0], { channel: 'email', status: 'sent' });
});

Deno.test('sms channel reports failures from Twilio', async () => {
  const fakeFetch = async () => new Response(null, { status: 500 });
  const results = await dispatchNotificationChannels({
    channels: ['sms'],
    payload: basePayload,
    targets: { phone: '+15558675309' },
    context: {
      smsAccountSid: 'AC123',
      smsAuthToken: 'token',
      smsFromNumber: '+15550000000',
      fetchImpl: fakeFetch,
    },
  });

  assertEquals(results[0].status, 'failed');
});
