# LabLink Supabase Troubleshooting Guide

Common issues and solutions when working with LabLink's local and production Supabase environments.

---

## Installation & CLI Issues

### "supabase: command not found"
**Cause:** Supabase CLI is not installed or not in your PATH.

**Solution:**
1. Install Supabase CLI:
   ```bash
   brew install supabase/tap/supabase  # macOS
   scoop install supabase             # Windows
   ```
2. Verify:
   ```bash
   supabase --version
   ```

---

### Docker is not running
**Error:**
```
Error: Cannot connect to the Docker daemon.
```

**Solution:**
- Start Docker Desktop (macOS/Windows) or Docker service (Linux):
  ```bash
  sudo systemctl start docker   # Linux
  open -a Docker               # macOS
  ```
- Verify:
  ```bash
  docker ps
  ```

---

## Local Development Issues

### `supabase start` hangs or fails to pull images
**Cause:** Slow network or Docker disk full.

**Solution:**
1. Check Docker storage:
   ```bash
   docker system df
   ```
2. Clean up:
   ```bash
   docker system prune -a
   ```
3. Restart Supabase:
   ```bash
   supabase stop
   supabase start
   ```

---

### Migration failed: "extension pgjwt does not exist"
**Cause:** `pgjwt` is not included in older Supabase versions or Postgres doesn't have it preloaded.

**Solution:**
1. Stop local Supabase:
   ```bash
   supabase stop
   ```
2. Ensure you're on the latest CLI version:
   ```bash
   supabase --version
   brew upgrade supabase/tap/supabase  # or equivalent
   ```
3. Start fresh:
   ```bash
   supabase start
   ```

---

### "QR secret is not configured" error in `generate_qr_hash()`
**Cause:** The function relies on `app.settings.qr_secret` (or fallback `supabase.jwt_secret`), which is not set.

**Solution:**
1. Set it for your current session:
   ```sql
   SET app.settings.qr_secret TO 'your-secret-here';
   ```
2. Make it persistent (PostgreSQL config file) or pass it from your application layer when calling the function.
3. Alternatively, rely on the JWT secret fallback by ensuring `SUPABASE_JWT_SECRET` is exported.

---

### Port conflicts: "port 54321 already in use"
**Cause:** Another Supabase instance or process is using the port.

**Solution:**
1. Check running Supabase projects:
   ```bash
   supabase stop
   ```
2. Or modify ports in `supabase/config.toml`:
   ```toml
   [api]
   port = 54421
   [db]
   port = 54422
   ```
3. Restart:
   ```bash
   supabase start
   ```

---

## Storage & Policy Issues

### "new row violates row-level security policy" when inserting into storage.objects
**Cause:** Storage policies require `auth.role() = 'authenticated'`, but your session is not authenticated.

**Solution:**
1. Ensure you're passing a valid JWT token in the `Authorization` header:
   ```http
   Authorization: Bearer <anon-key-or-service-role-key>
   ```
2. Test using service role key if you need to bypass RLS:
   ```bash
   export SUPABASE_SERVICE_ROLE_KEY=<your-service-role-key>
   ```
3. Or disable RLS temporarily (dev only):
   ```sql
   ALTER TABLE storage.objects DISABLE ROW LEVEL SECURITY;
   ```

---

### "policy already exists" error when re-running migration
**Cause:** Attempting to create policies that were already created by a previous run.

**Solution:**
- Use the `ensure_storage_policy` procedure included in the migration (idempotent).
- Or drop existing policies manually:
  ```sql
  DROP POLICY IF EXISTS lablink_public_read_qr_codes ON storage.objects;
  ```
- Ensure migrations use `IF NOT EXISTS` clauses or conditional logic.

---

## Realtime & Pub/Sub Issues

### Realtime subscription not working for a table
**Cause:** Table not added to the publication, or RLS prevents access.

**Solution:**
1. Check if table is published:
   ```sql
   SELECT schemaname, tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime';
   ```
2. Add missing table:
   ```sql
   ALTER PUBLICATION supabase_realtime ADD TABLE public.my_table;
   ```
3. Verify client authentication and RLS policies.

---

## Email & SMTP Issues

### Confirmation emails not received in production
**Cause:** SMTP credentials invalid or emails going to spam.

**Solution:**
1. Verify SMTP credentials in Supabase Dashboard → Authentication → Email Settings.
2. Use SendGrid/Postmark/AWS SES with verified domains.
3. Check spam folder and configure SPF/DKIM/DMARC records.

---

### Inbucket (local email) not showing emails
**Cause:** Inbucket service failed or not listening.

**Solution:**
1. Access Inbucket UI:
   ```bash
   open http://127.0.0.1:54324
   ```
2. Check status:
   ```bash
   supabase status
   ```
3. Restart:
   ```bash
   supabase stop && supabase start
   ```

---

## Migration & Schema Issues

### "relation already exists" error
**Cause:** Migration attempting to create a table/function that already exists.

**Solution:**
1. Use `CREATE ... IF NOT EXISTS`:
   ```sql
   CREATE TABLE IF NOT EXISTS public.my_table ...
   ```
2. Reset database (CAUTION: deletes all data):
   ```bash
   supabase db reset
   ```

---

### "permission denied for schema public"
**Cause:** Insufficient privileges for the database user.

**Solution:**
1. Grant permissions:
   ```sql
   GRANT ALL ON SCHEMA public TO postgres;
   GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres;
   ```
2. Or use service role key to bypass RLS during setup.

---

## Production Deployment Issues

### `supabase link` fails: "Project not found"
**Cause:** Invalid project ref or not logged in.

**Solution:**
1. Log in:
   ```bash
   supabase login
   ```
2. Get your project ref from Supabase Dashboard → Project Settings → General.
3. Link:
   ```bash
   supabase link --project-ref <your-ref>
   ```

---

### `supabase db push` fails with divergence error
**Cause:** Local schema and production schema have drifted.

**Solution:**
1. Pull remote schema:
   ```bash
   supabase db pull
   ```
2. Resolve conflicts manually by editing migrations.
3. Push:
   ```bash
   supabase db push
   ```

---

## Client SDK Issues

### "Invalid JWT: signature verification failed"
**Cause:** Using local JWT secret in production or vice versa.

**Solution:**
- Ensure your `.env` has the correct keys for each environment:
  ```env
  # Local
  SUPABASE_URL=http://127.0.0.1:54321
  SUPABASE_ANON_KEY=<local-anon-key>

  # Production
  SUPABASE_URL=https://<your-ref>.supabase.co
  SUPABASE_ANON_KEY=<prod-anon-key>
  ```

---

### "Request failed with status code 429" (Rate limit)
**Cause:** Exceeded rate limits defined in `supabase/config.toml`.

**Solution:**
1. Review `[auth.rate_limit]` section in config.
2. Adjust for development:
   ```toml
   email_sent = 100
   ```
3. Or wait for rate limit window to reset (typically 1 hour).

---

## Performance & Debugging

### Slow queries or high CPU usage
**Cause:** Missing indexes or inefficient queries.

**Solution:**
1. Enable query logging:
   ```sql
   ALTER DATABASE postgres SET log_statement = 'all';
   ```
2. Analyze slow queries:
   ```sql
   SELECT * FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 10;
   ```
3. Add indexes where necessary.

---

### How to inspect JWT claims in SQL?
Use Supabase's `auth.*` helper functions or inspect directly:
```sql
SELECT
  current_setting('request.jwt.claim.sub', true) AS user_id,
  current_setting('request.jwt.claim.role', true) AS role;
```

---

## Additional Resources

- **Supabase Docs:** https://supabase.com/docs
- **CLI Reference:** https://supabase.com/docs/reference/cli
- **Community Discord:** https://discord.supabase.com
- **GitHub Issues:** https://github.com/supabase/supabase

If you encounter an issue not listed here, please open a GitHub issue in the LabLink repository.
