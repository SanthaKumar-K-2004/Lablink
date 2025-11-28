# LabLink Supabase Setup Guide

This guide will walk you through setting up Supabase for local development and deploying to production.

## Prerequisites

- Docker Desktop installed and running (for local development)
- Node.js v16+ or Bun installed (optional, for package management)
- PostgreSQL client (optional, for direct database access)
- A Supabase account (https://supabase.com)

## 1. Install Supabase CLI

### macOS / Linux
```bash
# Using Homebrew
brew install supabase/tap/supabase

# Or download binary directly
curl -o supabase.tar.gz -L "https://github.com/supabase/cli/releases/latest/download/supabase_linux_amd64.tar.gz"
tar -xzf supabase.tar.gz -C /usr/local/bin
```

### Windows
```powershell
# Using Scoop
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase
```

Verify installation:
```bash
supabase --version
```

## 2. Initialize Local Supabase Environment

From the repository root, start the local Supabase stack:

```bash
supabase start
```

This command will:
- Pull required Docker images (first run only, ~2GB)
- Start Postgres, PostgREST, GoTrue (Auth), Realtime, Storage, Studio, and Inbucket (email testing)
- Run all migrations in `supabase/migrations/`
- Display connection credentials

**Expected Output:**
```
Started supabase local development setup.

         API URL: http://127.0.0.1:54321
     GraphQL URL: http://127.0.0.1:54321/graphql/v1
  S3 Storage URL: http://127.0.0.1:54321/storage/v1/s3
          DB URL: postgresql://postgres:postgres@127.0.0.1:54322/postgres
      Studio URL: http://127.0.0.1:54323
    Inbucket URL: http://127.0.0.1:54324
      JWT secret: super-secret-jwt-token-with-at-least-32-characters-long
        anon key: eyJhbGc...
service_role key: eyJhbGc...
   S3 Access Key: 625729a08b95bf1b7ff351a663f3a23c
   S3 Secret Key: 850181e4652dd023b7a98c58ae0d2d34bd487ee0cc3254aed6eda37307425907
       S3 Region: local
```

> **Note:** JWT secret and keys are generated locally. These will differ from your production environment.

## 3. Configure Environment Variables

Copy `.env.example` to `.env.local` and populate it with the values from `supabase start`:

```bash
cp .env.example .env.local
```

Update `.env.local` with:
```env
SUPABASE_PROJECT_REF=lablink-local
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=<anon-key-from-supabase-start>
SUPABASE_SERVICE_ROLE_KEY=<service-role-key-from-supabase-start>
SUPABASE_JWT_SECRET=<jwt-secret-from-supabase-start>
SUPABASE_DB_PASSWORD=postgres
LABLINK_QR_JWT_SECRET=<same-as-jwt-secret>
LABLINK_SMTP_API_KEY=demo-key
```

For **production**, create a Supabase project at https://supabase.com/dashboard and update `.env` with your production keys.

## 4. Configure Auth, Email, and CORS

All infrastructure settings live in `supabase/config.toml`.

Key defaults to review before deploying to production:
- **Auth URLs:** `site_url` is set to `https://lablink.app` and `additional_redirect_urls` already include `http://localhost:8080` for Flutter web preview plus the production domains.
- **CORS:** `[api].cors_origins` allows requests from `http://localhost:8080` and `https://lablink.app`.
- **Email:** SMTP credentials reference `LABLINK_SMTP_API_KEY` and each auth flow (invite, confirm signup, recovery, magic link) points at a custom HTML template stored in `supabase/templates/auth/`.
- **Sessions:** JWT expiry is 1 hour and refresh/session lifetime is 7 days to match the ticket requirements.
- **Storage buckets:** Defaults are defined under `[storage.buckets.*]` so `supabase start` pre-seeds local folders.

After editing `supabase/config.toml`, restart the local stack:
```bash
supabase stop
supabase start
```

## 5. Verify Extensions and Setup

Open Supabase Studio:
```bash
open http://127.0.0.1:54323
```

Or connect via `psql`:
```bash
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres
```

### Check Installed Extensions
```sql
SELECT extname, extversion FROM pg_extension WHERE extname IN ('pgcrypto', 'pgjwt');
```

Expected output:
```
 extname  | extversion
----------+------------
 pgcrypto | 1.3
 pgjwt    | 0.2.0
```

### Check Custom Types
```sql
\dT+ public.user_role
\dT+ public.item_status
\dT+ public.request_status
```

### Check Tables
```sql
\dt public.*
```

### Verify Storage Buckets
```sql
SELECT id, name, public FROM storage.buckets;
```

Expected output:
```
       id        |        name         | public
-----------------+---------------------+--------
 qr_codes        | qr_codes            | t
 item_images     | item_images         | t
 maintenance_photos | maintenance_photos | t
 chemical_msds   | chemical_msds       | t
 user_avatars    | user_avatars        | t
```

## 6. Test Helper Functions

### Test QR Hash Generation
```sql
-- Set QR secret in current session
SET app.settings.qr_secret TO 'test-secret-for-qr-generation';

-- Generate a test QR hash
SELECT public.generate_qr_hash(
  '123e4567-e89b-12d3-a456-426614174000'::uuid,
  '{"serial_number": "ITEM-001", "name": "Test Item"}'::jsonb
);
```

### Insert a Test Item (Triggers QR Assignment)
```sql
INSERT INTO public.items (name, serial_number, location, status)
VALUES ('Microscope', 'MIC-001', 'Lab A', 'available')
RETURNING id, qr_hash, qr_payload;
```

### Check Audit Logs
```sql
SELECT * FROM public.audit_logs ORDER BY changed_at DESC LIMIT 5;
```

## 7. Stop Supabase

To stop the local Supabase instance:
```bash
supabase stop
```

To stop and delete all local data:
```bash
supabase stop --no-backup
```

## 8. Apply Changes to Production

After testing locally:

1. Link your local project to your production Supabase project:
   ```bash
   supabase link --project-ref <your-project-ref>
   ```

2. Push migrations:
   ```bash
   supabase db push
   ```

3. Verify in production via Studio or `psql`:
   ```bash
   psql "postgresql://postgres:[YOUR-PASSWORD]@db.[YOUR-PROJECT-REF].supabase.co:5432/postgres"
   ```

## 9. Email Testing

All authentication emails are captured by Inbucket (local email testing server).

View sent emails:
```bash
open http://127.0.0.1:54324
```

Check:
- Password reset emails
- Email confirmation emails
- Invite emails
- Magic link emails

## Additional Commands

| Command | Description |
|---------|-------------|
| `supabase status` | View local service URLs and status |
| `supabase db reset` | Drop and recreate database (runs all migrations) |
| `supabase db diff` | Generate migration from schema changes |
| `supabase gen types typescript` | Generate TypeScript types from schema |
| `supabase functions serve` | Start local Edge Functions |

## Troubleshooting

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for common issues and solutions.
