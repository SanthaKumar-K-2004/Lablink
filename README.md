# LabLink

Modern lab asset, compliance, and access management powered by Supabase.

## Phase 1 — Supabase Infrastructure

This repository now ships with a production-ready Supabase foundation:

- ✅ Supabase CLI + `supabase/config.toml` tuned for Flutter web + production
- ✅ Database migrations for extensions, enums, tables, triggers, audit logging, and realtime
- ✅ Storage buckets & policies for QR codes, images, MSDS files, and avatars
- ✅ Email templates + SMTP configuration for invites, confirmations, and password resets
- ✅ Comprehensive documentation for setup, schema, and troubleshooting

## Quick Start

```bash
# Clone & install CLI (if not already installed)
brew install supabase/tap/supabase  # or see docs/SUPABASE_SETUP.md

# Start the local stack
supabase start

# Environment variables
cp .env.example .env.local  # already populated with local defaults

# Apply migrations to production once tested
supabase link --project-ref <your-project-ref>
supabase db push
```

## Project Structure

```
├── .env.example           # Template of required env vars
├── .env.local             # Local defaults for supabase start
├── supabase/
│   ├── config.toml        # Auth/CORS/storage configuration
│   ├── migrations/        # SQL migrations (Phase 1 schema)
│   └── templates/auth/    # Email templates for Auth flows
└── docs/
    ├── SUPABASE_SETUP.md
    ├── DATABASE_SCHEMA.md
    └── TROUBLESHOOTING.md
```

## Documentation

- [Supabase Setup Guide](docs/SUPABASE_SETUP.md) — install CLI, run `supabase start`, verify schema
- [Database Schema](docs/DATABASE_SCHEMA.md) — ER diagram, helper functions, storage policies
- [Edge Functions](docs/EDGE_FUNCTIONS.md) — API contracts for QR signing/validation and notifications
- [Scheduled Jobs](docs/SCHEDULED_JOBS.md) — cron schedules, logic, and manual testing steps
- [Troubleshooting](docs/TROUBLESHOOTING.md) — common errors and fixes

For questions or follow-up tasks, review the documentation above or open an issue in this repo.
