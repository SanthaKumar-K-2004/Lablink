# Supabase Edge Functions

Phase 1 introduces four Supabase Edge Functions that encapsulate the most critical server-side business logic. All functions are deployed under `/functions/v1/*` and require the Supabase service role (or another privileged key) when invoked from trusted backends.

> **Authentication**
>
> - Local development: use `SUPABASE_SERVICE_ROLE_KEY` when invoking functions
> - Production: route calls through a backend service so the service key never ships to clients
> - All responses are JSON and include the `cache-control: no-store` header

## `qr-sign` – Tamper-Proof QR Issuance

- **Endpoint:** `POST /functions/v1/qr-sign`
- **Purpose:** Generates a JWT-backed QR code payload for an asset
- **Request Body:**
  ```json
  {
    "item_id": "<uuid>",
    "department_id": "<optional-uuid>",
    "category_id": "<optional-uuid>"
  }
  ```
- **Response Body:**
  ```json
  {
    "qr_payload": "<base64-envelope>",
    "qr_hash": "<jwt-token>",
    "expires_at": "2024-12-01T00:00:00Z",
    "item_id": "<uuid>",
    "department_id": "<uuid>",
    "category_id": "<uuid>"
  }
  ```
- **Business Logic:**
  1. Validates the item and (optional) department/category inputs
  2. Calls the `public.generate_qr_hash` SQL function which signs the payload with the Supabase JWT secret (or `LABLINK_QR_JWT_SECRET`)
  3. Base64-encodes the payload (`qr_payload`) so it can be fed directly to any QR library
  4. Persists the new `qr_hash` + structured `qr_payload` on the `items` row
- **Errors:** `400 (validation)`, `404 (item missing)`, `500 (database failure)`

## `qr-validate` – Scan Verification & Audit Trail

- **Endpoint:** `POST /functions/v1/qr-validate`
- **Purpose:** Validates a scanned QR payload and records the attempt in `audit_logs`
- **Request Body:**
  ```json
  {
    "qr_payload": "<base64-blob>",
    "user_id": "<optional-scanner-uuid>"
  }
  ```
- **Response Body:**
  ```json
  {
    "valid": true,
    "message": "QR code is valid",
    "item_id": "<uuid>",
    "department_id": "<uuid>",
    "category_id": "<uuid>",
    "status": "available",
    "expires_at": "2024-12-01T00:00:00Z",
    "timestamp": "2024-11-28T05:00:00Z"
  }
  ```
- **Business Logic:**
  1. Delegates signature/timestamp verification to the `public.validate_qr_scan` SQL function
  2. Automatically logs both successful and failed scans through `public.generate_audit_trail`
  3. Returns a structured payload that client applications can use for contextual messaging
- **Errors:** `400 (missing payload, invalid UUID)`, `500 (unexpected RPC failure)`

## `notify` – Multi-Channel Notification Dispatcher

- **Endpoint:** `POST /functions/v1/notify`
- **Purpose:** Creates an in-app notification record and (optionally) sends email, SMS, and push alerts
- **Request Body:**
  ```json
  {
    "user_id": "<uuid>",
    "type": "reminder_overdue",
    "title": "Item is overdue",
    "message": "Oscilloscope ABC-123 is 3 days overdue",
    "action_link": "https://lablink.app/issued/123",
    "channels": ["in_app", "email", "sms"],
    "priority": "high",
    "action_data": {"issued_item_id": "..."},
    "sms_override": "+15550001111",
    "email_override": "faculty@example.edu",
    "push_token": "fcm-token"
  }
  ```
- **Response Body:**
  ```json
  {
    "notification_id": "<uuid>",
    "status": "sent",
    "channels_sent": [
      { "channel": "in_app", "status": "sent" },
      { "channel": "email", "status": "sent" },
      { "channel": "sms", "status": "failed", "detail": "Twilio 500" }
    ]
  }
  ```
- **Business Logic:**
  1. Respects per-user channel preferences via `public.get_user_notification_preferences`
  2. Persists the notification (and dispatch queue rows) through `public.send_notification`
  3. Executes external deliveries:
     - **Email:** SendGrid / SMTP using `LABLINK_SENDGRID_API_KEY` or `LABLINK_SMTP_API_KEY`
     - **SMS:** Twilio using `LABLINK_TWILIO_*` settings
     - **Push:** Firebase Cloud Messaging via `LABLINK_FCM_SERVER_KEY`
  4. Updates `notification_dispatch_queue` with per-channel delivery status using `public.update_notification_dispatch_status`
- **Errors:**
  - `400` – validation failures (missing IDs, unsupported channels/types)
  - `404` – user not found
  - `500` – database or provider failures

## `notification-preferences` – Preference Explorer

- **Endpoint:** `GET /functions/v1/notification-preferences?user_id=<uuid>`
- **Purpose:** Returns the effective channel opt-in matrix for a user (covering all supported notification types)
- **Response Body:**
  ```json
  {
    "user_id": "<uuid>",
    "available_channels": ["in_app", "email", "sms", "push"],
    "preferences": {
      "approval": { "in_app": true, "email": true, "sms": false, "push": false },
      "reminder_overdue": { "in_app": true, "email": true, "sms": true, "push": false }
    }
  }
  ```
- **Business Logic:**
  - Reads from `user_notification_preferences` if overrides exist
  - Falls back to sensible defaults (in-app always enabled, other channels disabled until opted in)

## Environment Variables

| Variable | Description |
| --- | --- |
| `LABLINK_QR_JWT_SECRET` | Overrides the Supabase JWT secret for QR signing (optional) |
| `LABLINK_SENDGRID_API_KEY` / `LABLINK_SMTP_API_KEY` | Email provider credentials |
| `LABLINK_NOTIFICATION_EMAIL_FROM` / `LABLINK_NOTIFICATION_EMAIL_NAME` | From address + label |
| `LABLINK_TWILIO_ACCOUNT_SID`, `LABLINK_TWILIO_AUTH_TOKEN`, `LABLINK_TWILIO_FROM_NUMBER` | SMS dispatch credentials |
| `LABLINK_FCM_SERVER_KEY` | Firebase Cloud Messaging server token |
| `LABLINK_DEFAULT_NOTIFICATION_CHANNELS` | CSV list used when the request omits `channels` |
| `LABLINK_FUNCTION_TIMEOUT_MS` | Shared fetch timeout (ms) for Supabase + provider calls |

## Error Handling & Logging

- All functions wrap handler logic with detailed `console.error` entries (visible inside Supabase logs)
- User-facing responses remain concise; internal error messages never leak secrets
- Each QR validation automatically records an audit event through `public.generate_audit_trail`
- Notification delivery failures leave a permanent trace in `notification_dispatch_queue` (and are surfaced via the `channels_sent` array)

## Testing Locally

```bash
# With supabase CLI running (supabase start)
supabase functions serve qr-sign --env-file .env.local

# Call qr-sign
curl -X POST \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"item_id":"<uuid>"}' \
  http://localhost:54321/functions/v1/qr-sign
```

> The shared helper modules under `supabase/functions/_shared` include lightweight Deno unit tests (`deno test supabase/functions/_shared/*.test.ts`) covering QR payload helpers and notification dispatch fallbacks.
