# Scheduled Jobs & Background Tasks

Phase 1 adds native PostgreSQL jobs using the `pg_cron` extension. All jobs run inside the primary database (no external worker needed) and rely on SQL helpers declared in `supabase/migrations/004_edge_functions_business_logic.sql`.

| Job | Schedule (UTC) | Function | Purpose |
| --- | --- | --- | --- |
| `check_expiring_chemicals` | Daily @ 08:00 | `public.check_expiring_chemicals()` | Alerts department heads about chemicals expiring within seven days |
| `check_overdue_items` | Daily @ 09:00 | `public.check_overdue_items()` | Marks issued items as overdue, notifies borrowers/staff/admins, flags chronic offenders |
| `cleanup_expired_notifications` | Sunday @ 02:00 | `public.cleanup_expired_notifications()` | Deletes/archives notifications older than 90 days |
| `audit_log_retention` | 1st of each month @ 03:00 | `public.audit_log_retention()` | Moves audit records older than seven years into `audit_logs_archive` |

## Implementation Notes

### Core Tables & Helpers

- **`notification_dispatch_queue`** – Tracks delivery status for each channel (in-app, email, SMS, push)
- **`user_notification_preferences`** – Stores per-user opt-in overrides (defaults handled when no rows exist)
- **`job_processing_log`** – Prevents duplicate notifications by recording the last processed time per entity/job
- **`audit_logs_archive`** – Immutable cold-storage table for retired audit entries

### Chemical Expiry Monitor (`check_expiring_chemicals`)

1. Finds items with `expiry_date <= current_date + 7` and `status <> 'retired'`
2. Skips any item that was already processed in the last 24 hours
3. Sends a high-priority `expiry_warning` notification to the department head (in-app + email)
4. Logs processing metadata inside `job_processing_log`

### Overdue Issued Items (`check_overdue_items`)

1. Queries active `issued_items` with `due_date < current_date`
2. Marks matching rows as `status = 'overdue'` and updates `days_overdue`
3. Sends notifications to:
   - Borrower (`issued_to`)
   - Issuing staff (`issued_by`)
   - Department head
   - First active admin account
4. Automatically opens a `damage_reports` entry if the item remains overdue for 14+ days and no report exists
5. Records each processed issued item in `job_processing_log`

### Notification Cleanup (`cleanup_expired_notifications`)

- Removes notifications whose `expires_at` elapsed or whose `created_at` is older than 90 days (default)
- Deletes cascade into `notification_dispatch_queue`
- The existing `audit_logs` trigger records every deletion for compliance

### Audit Log Retention (`audit_log_retention`)

- Copies audit rows older than seven years into `audit_logs_archive`
- Temporarily enables a guarded session variable to allow deleting from the otherwise immutable `audit_logs`
- Logs summary stats (`archived` count + cutoff timestamp) back into `job_processing_log`

## Manual Testing

From a Supabase SQL console or `psql`, you can execute each function manually:

```sql
-- Trigger a chemical expiry sweep
select public.check_expiring_chemicals();

-- Force overdue processing
select public.check_overdue_items();

-- Clean up notifications older than 30 days for testing
select public.cleanup_expired_notifications(30);

-- Archive audit logs using a custom retention window
select public.audit_log_retention(1);
```

To review job schedules:

```sql
select jobname, schedule, command, nodename
from cron.job
order by jobname;
```

## Troubleshooting

- **Missing `pg_cron` extension:** Run `create extension if not exists pg_cron with schema cron;` (already handled in migration 004)
- **Jobs not firing:** Ensure the database is using the `postgres` role (or another superuser) to own the cron jobs. Supabase-hosted projects automatically wire this up when migrations run via `supabase db push`.
- **Dispatch queue stuck in `pending`:** Call the `/functions/v1/notify` endpoint (or another worker) to retry channels. Each dispatch attempt increments the `attempts` counter and captures the last error for observability.
