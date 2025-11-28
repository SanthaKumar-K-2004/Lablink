-- Phase 1 Supabase configuration for LabLink
-- Includes extensions, custom types, tables, helper functions, triggers,
-- realtime configuration, and storage buckets / policies.

begin;

-- Extensions -----------------------------------------------------------------
create extension if not exists "pgcrypto" with schema public;
create extension if not exists "pgjwt" with schema public;

-- Custom enums ----------------------------------------------------------------
create type if not exists public.user_role as enum ('admin', 'staff', 'student', 'technician');
create type if not exists public.item_status as enum ('available', 'borrowed', 'maintenance', 'damaged', 'retired');
create type if not exists public.request_status as enum ('pending', 'approved', 'rejected', 'issued', 'returned');

-- Tables ----------------------------------------------------------------------
create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users (id) on delete cascade,
  email text not null unique,
  full_name text,
  role public.user_role not null default 'student',
  phone text,
  department text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.items (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  serial_number text unique,
  location text,
  status public.item_status not null default 'available',
  qr_hash text unique,
  qr_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.borrow_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.users (id) on delete cascade,
  item_id uuid not null references public.items (id) on delete cascade,
  status public.request_status not null default 'pending',
  needed_from timestamptz,
  needed_until timestamptz,
  purpose text,
  notes text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.issued_items (
  id uuid primary key default gen_random_uuid(),
  borrow_request_id uuid references public.borrow_requests (id) on delete set null,
  user_id uuid references public.users (id) on delete set null,
  item_id uuid references public.items (id) on delete set null,
  issued_at timestamptz not null default timezone('utc', now()),
  due_at timestamptz,
  returned_at timestamptz,
  condition_on_issue text,
  condition_on_return text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.damage_reports (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.items (id) on delete cascade,
  reported_by uuid references public.users (id) on delete set null,
  description text not null,
  severity text,
  status public.item_status not null default 'maintenance',
  photo_path text,
  metadata jsonb not null default '{}'::jsonb,
  reported_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.maintenance_records (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.items (id) on delete cascade,
  reported_by uuid references public.users (id) on delete set null,
  performed_by uuid references public.users (id) on delete set null,
  description text not null,
  scheduled_for timestamptz,
  completed_at timestamptz,
  status public.item_status not null default 'maintenance',
  notes text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.audit_logs (
  id bigserial primary key,
  table_name text not null,
  record_id text,
  action text not null,
  old_data jsonb,
  new_data jsonb,
  changed_at timestamptz not null default timezone('utc', now()),
  changed_by uuid,
  context jsonb not null default '{}'::jsonb
);

create index if not exists audit_logs_table_idx on public.audit_logs (table_name);
create index if not exists audit_logs_record_idx on public.audit_logs (record_id);

-- Helper Functions ------------------------------------------------------------
create or replace function public.update_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create or replace function public.audit_log_trigger()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid;
  record_identifier text;
  payload jsonb;
begin
  begin
    actor := nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
  exception when others then
    actor := null;
  end;

  if tg_op = 'DELETE' then
    payload := to_jsonb(old);
  else
    payload := to_jsonb(new);
  end if;

  record_identifier := coalesce(
    payload ->> 'id',
    payload ->> 'item_id',
    payload ->> 'borrow_request_id',
    payload ->> 'record_id'
  );

  insert into public.audit_logs(
    table_name,
    record_id,
    action,
    old_data,
    new_data,
    changed_at,
    changed_by,
    context
  ) values (
    tg_table_name,
    record_identifier,
    tg_op,
    to_jsonb(old),
    to_jsonb(new),
    timezone('utc', now()),
    actor,
    jsonb_build_object(
      'trigger', tg_name,
      'role', nullif(current_setting('request.jwt.claim.role', true), '')
    )
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create or replace function public.generate_qr_hash(p_item_id uuid, metadata jsonb default '{}'::jsonb)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  secret text;
  payload jsonb;
begin
  secret := current_setting('app.settings.qr_secret', true);
  if secret is null or secret = '' then
    secret := current_setting('supabase.jwt_secret', true);
  end if;
  if secret is null or secret = '' then
    raise exception 'QR secret is not configured. Set app.settings.qr_secret or SUPABASE_JWT_SECRET.';
  end if;

  payload := jsonb_build_object(
    'item_id', p_item_id,
    'metadata', coalesce(metadata, '{}'::jsonb),
    'iss', 'lablink',
    'iat', extract(epoch from now())::bigint
  );

  return pgjwt.sign(payload::text, secret, 'HS256');
end;
$$;

create or replace function public.assign_qr_hash()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.id is null then
    new.id := gen_random_uuid();
  end if;

  if new.qr_hash is null then
    new.qr_hash := public.generate_qr_hash(
      new.id,
      jsonb_build_object(
        'serial_number', new.serial_number,
        'name', new.name
      )
    );
  end if;

  if new.qr_payload is null or new.qr_payload = '{}'::jsonb then
    new.qr_payload := jsonb_build_object(
      'item_id', new.id,
      'serial_number', new.serial_number,
      'name', new.name
    );
  end if;

  return new;
end;
$$;

-- Triggers --------------------------------------------------------------------

-- Users
create trigger trg_users_updated_at before update on public.users
for each row execute function public.update_updated_at();

create trigger trg_users_audit after insert or update or delete on public.users
for each row execute function public.audit_log_trigger();

-- Items
create trigger trg_items_updated_at before update on public.items
for each row execute function public.update_updated_at();

create trigger trg_items_audit after insert or update or delete on public.items
for each row execute function public.audit_log_trigger();

create trigger trg_items_qr before insert on public.items
for each row execute function public.assign_qr_hash();

-- Borrow requests
create trigger trg_borrow_requests_updated_at before update on public.borrow_requests
for each row execute function public.update_updated_at();

create trigger trg_borrow_requests_audit after insert or update or delete on public.borrow_requests
for each row execute function public.audit_log_trigger();

-- Issued items
create trigger trg_issued_items_updated_at before update on public.issued_items
for each row execute function public.update_updated_at();

create trigger trg_issued_items_audit after insert or update or delete on public.issued_items
for each row execute function public.audit_log_trigger();

-- Damage reports
create trigger trg_damage_reports_updated_at before update on public.damage_reports
for each row execute function public.update_updated_at();

create trigger trg_damage_reports_audit after insert or update or delete on public.damage_reports
for each row execute function public.audit_log_trigger();

-- Maintenance records
create trigger trg_maintenance_records_updated_at before update on public.maintenance_records
for each row execute function public.update_updated_at();

create trigger trg_maintenance_records_audit after insert or update or delete on public.maintenance_records
for each row execute function public.audit_log_trigger();

-- Realtime publication --------------------------------------------------------
alter publication supabase_realtime add table
  public.users,
  public.items,
  public.borrow_requests,
  public.issued_items,
  public.damage_reports,
  public.maintenance_records;

-- Storage buckets -------------------------------------------------------------
insert into storage.buckets (id, name, public)
values
  ('qr_codes', 'qr_codes', true),
  ('item_images', 'item_images', true),
  ('maintenance_photos', 'maintenance_photos', true),
  ('chemical_msds', 'chemical_msds', true),
  ('user_avatars', 'user_avatars', true)
on conflict (id) do update set public = excluded.public;

-- Helper procedure to create policies idempotently
create or replace procedure public.ensure_storage_policy(
  policy_name text,
  bucket text,
  policy_cmd text
)
language plpgsql
as $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and polname = policy_name
  ) then
    execute policy_cmd;
  end if;
end;
$$;

do $$
begin
  perform public.ensure_storage_policy(
    'lablink_public_read_qr_codes',
    'qr_codes',
    $$create policy lablink_public_read_qr_codes on storage.objects for select using (bucket_id = 'qr_codes')$$
  );
  perform public.ensure_storage_policy(
    'lablink_public_read_item_images',
    'item_images',
    $$create policy lablink_public_read_item_images on storage.objects for select using (bucket_id = 'item_images')$$
  );
  perform public.ensure_storage_policy(
    'lablink_public_read_maintenance_photos',
    'maintenance_photos',
    $$create policy lablink_public_read_maintenance_photos on storage.objects for select using (bucket_id = 'maintenance_photos')$$
  );
  perform public.ensure_storage_policy(
    'lablink_public_read_chemical_msds',
    'chemical_msds',
    $$create policy lablink_public_read_chemical_msds on storage.objects for select using (bucket_id = 'chemical_msds')$$
  );
  perform public.ensure_storage_policy(
    'lablink_public_read_user_avatars',
    'user_avatars',
    $$create policy lablink_public_read_user_avatars on storage.objects for select using (bucket_id = 'user_avatars')$$
  );

  perform public.ensure_storage_policy(
    'lablink_authenticated_write_qr_codes',
    'qr_codes',
    $$create policy lablink_authenticated_write_qr_codes on storage.objects
       for insert with check (bucket_id = 'qr_codes' and auth.role() = 'authenticated')$$
  );
  perform public.ensure_storage_policy(
    'lablink_authenticated_write_item_images',
    'item_images',
    $$create policy lablink_authenticated_write_item_images on storage.objects
       for insert with check (bucket_id = 'item_images' and auth.role() = 'authenticated')$$
  );
  perform public.ensure_storage_policy(
    'lablink_authenticated_write_maintenance_photos',
    'maintenance_photos',
    $$create policy lablink_authenticated_write_maintenance_photos on storage.objects
       for insert with check (bucket_id = 'maintenance_photos' and auth.role() = 'authenticated')$$
  );
  perform public.ensure_storage_policy(
    'lablink_authenticated_write_chemical_msds',
    'chemical_msds',
    $$create policy lablink_authenticated_write_chemical_msds on storage.objects
       for insert with check (bucket_id = 'chemical_msds' and auth.role() = 'authenticated')$$
  );
  perform public.ensure_storage_policy(
    'lablink_authenticated_write_user_avatars',
    'user_avatars',
    $$create policy lablink_authenticated_write_user_avatars on storage.objects
       for insert with check (bucket_id = 'user_avatars' and auth.role() = 'authenticated')$$
  );

  perform public.ensure_storage_policy(
    'lablink_service_delete',
    'qr_codes',
    $$create policy lablink_service_delete on storage.objects
       for delete using (auth.role() = 'service_role')$$
  );
end;
$$;

commit;
