-- Phase 1: business logic, helpers, and scheduling support
begin;

-- =====================================================================
-- EXTENSIONS & ENUMS
-- =====================================================================
create schema if not exists cron;
create extension if not exists pg_cron with schema cron;

create type if not exists public.notification_channel as enum ('in_app', 'email', 'sms', 'push');
create type if not exists public.notification_dispatch_status as enum ('pending', 'sent', 'failed', 'skipped');

-- Expand notification_type enum to cover granular events used by phase 1
DO $$
DECLARE
  v_type text;
  v_values text[] := ARRAY[
    'rejection',
    'reminder_2days',
    'reminder_due',
    'reminder_overdue',
    'low_stock',
    'expiry_warning',
    'damage_reported',
    'maintenance_assigned',
    'maintenance_completed'
  ];
BEGIN
  FOREACH v_type IN ARRAY v_values LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_enum
      WHERE enumlabel = v_type
        AND enumtypid = 'public.notification_type'::regtype
    ) THEN
      EXECUTE format('alter type public.notification_type add value %L', v_type);
    END IF;
  END LOOP;
END $$;

-- =====================================================================
-- TABLES FOR NOTIFICATION PREFERENCES, DISPATCH QUEUE, JOB LOGGING
-- =====================================================================
create table if not exists public.user_notification_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  notification_type public.notification_type not null,
  channel public.notification_channel not null,
  enabled boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint user_notification_preferences_unique unique (user_id, notification_type, channel)
);

create trigger trg_user_notification_preferences_updated_at
before update on public.user_notification_preferences
for each row execute function public.update_updated_at();

create table if not exists public.notification_dispatch_queue (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications(id) on delete cascade,
  channel public.notification_channel not null,
  status public.notification_dispatch_status not null default 'pending',
  attempts integer not null default 0,
  last_attempt_at timestamptz,
  error_message text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint notification_dispatch_queue_unique unique (notification_id, channel)
);

create index if not exists notification_dispatch_queue_status_idx on public.notification_dispatch_queue (status);
create index if not exists notification_dispatch_queue_channel_idx on public.notification_dispatch_queue (channel);

create trigger trg_notification_dispatch_queue_updated_at
before update on public.notification_dispatch_queue
for each row execute function public.update_updated_at();

create table if not exists public.job_processing_log (
  id bigserial primary key,
  job_name text not null,
  entity_type text not null,
  entity_id uuid,
  processed_at timestamptz not null default timezone('utc', now()),
  context jsonb not null default '{}'::jsonb
);

create index if not exists job_processing_log_job_idx on public.job_processing_log (job_name, processed_at desc);
create index if not exists job_processing_log_entity_idx on public.job_processing_log (entity_type, entity_id, processed_at desc);

create table if not exists public.audit_logs_archive (like public.audit_logs including defaults including constraints including indexes);

-- =====================================================================
-- HELPER FUNCTIONS
-- =====================================================================
create or replace function public.generate_audit_trail(
  p_user_id uuid,
  p_action text,
  p_entity_type text,
  p_entity_id uuid,
  p_entity_name text default null,
  p_old_values jsonb default null,
  p_new_values jsonb default null,
  p_changes_summary text default null,
  p_status public.audit_status default 'system_generated',
  p_ip inet default null,
  p_user_agent text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  insert into public.audit_logs (
    user_id,
    action,
    entity_type,
    entity_id,
    entity_name,
    old_values,
    new_values,
    changes_summary,
    ip_address,
    user_agent,
    status,
    timestamp
  ) values (
    p_user_id,
    coalesce(nullif(trim(p_action), ''), 'unspecified'),
    coalesce(nullif(trim(p_entity_type), ''), 'system'),
    p_entity_id,
    coalesce(nullif(trim(p_entity_name), ''), p_entity_type),
    p_old_values,
    p_new_values,
    p_changes_summary,
    p_ip,
    p_user_agent,
    coalesce(p_status, 'system_generated'),
    timezone('utc', now())
  ) returning id into v_id;

  return v_id;
exception when others then
  raise warning 'generate_audit_trail failed: %', sqlerrm;
  return null;
end;
$$;

create or replace function public.calculate_item_availability(p_item_id uuid)
returns integer
language sql
stable
as $$
  select greatest(
    coalesce(total_quantity, 0)
    - coalesce(borrowed_quantity, 0)
    - coalesce(damaged_quantity, 0)
    - coalesce(maintenance_quantity, 0),
    0
  )
  from public.items
  where id = p_item_id;
$$;

create or replace function public.calculate_chemical_expiry_status(p_expiry_date date)
returns text
language plpgsql
as $$
declare
  days_left integer;
begin
  if p_expiry_date is null then
    return 'unknown';
  end if;

  days_left := (p_expiry_date - current_date);

  if days_left > 60 then
    return 'green';
  elsif days_left >= 30 then
    return 'yellow';
  elsif days_left >= 7 then
    return 'orange';
  elsif days_left > 0 then
    return 'red';
  else
    return 'black';
  end if;
end;
$$;

-- =====================================================================
-- QR HELPERS
-- =====================================================================
create or replace function public.generate_qr_hash(
  p_item_id uuid,
  p_department_id uuid default null,
  p_category_id uuid default null,
  p_status public.item_status default null,
  p_metadata jsonb default '{}'::jsonb
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  secret text;
  payload jsonb;
  department_id uuid;
  category_id uuid;
  item_status public.item_status;
  issued_at timestamptz := timezone('utc', now());
  expires_at timestamptz := timezone('utc', now()) + interval '30 days';
begin
  select i.department_id, i.category_id, i.status
  into department_id, category_id, item_status
  from public.items i
  where i.id = p_item_id;

  if not found then
    raise exception 'item % not found for QR generation', p_item_id;
  end if;

  department_id := coalesce(p_department_id, department_id);
  category_id := coalesce(p_category_id, category_id);
  item_status := coalesce(p_status, item_status);

  secret := current_setting('app.settings.qr_secret', true);
  if secret is null or secret = '' then
    secret := current_setting('supabase.jwt_secret', true);
  end if;
  if secret is null or secret = '' then
    raise exception 'QR secret is not configured';
  end if;

  payload := jsonb_build_object(
    'item_id', p_item_id,
    'department_id', department_id,
    'category_id', category_id,
    'status', item_status,
    'issued_at', issued_at,
    'expires_at', expires_at,
    'exp', floor(extract(epoch from expires_at)),
    'ts', floor(extract(epoch from issued_at)),
    'nonce', encode(gen_random_bytes(16), 'hex')
  ) || jsonb_build_object('metadata', coalesce(p_metadata, '{}'::jsonb));

  return pgjwt.sign(payload::text, secret, 'HS256');
end;
$$;

create or replace function public.assign_qr_hash()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  base_payload jsonb;
  encoded text;
begin
  if new.id is null then
    new.id := gen_random_uuid();
  end if;

  base_payload := jsonb_build_object(
    'serial_number', new.serial_number,
    'name', new.name,
    'timestamp', timezone('utc', now())
  );

  if new.qr_hash is null or new.qr_hash = '' then
    new.qr_hash := public.generate_qr_hash(
      new.id,
      new.department_id,
      new.category_id,
      new.status,
      base_payload
    );
  end if;

  encoded := encode(convert_to(new.qr_hash, 'utf-8'), 'base64');
  new.qr_payload := jsonb_build_object(
    'item_id', new.id,
    'department_id', new.department_id,
    'category_id', new.category_id,
    'status', new.status,
    'qr_payload', encoded,
    'expires_at', timezone('utc', now()) + interval '30 days'
  );

  return new;
end;
$$;

create or replace function public.validate_qr_scan(
  p_qr_payload text,
  p_user_id uuid default null,
  p_ip inet default null,
  p_user_agent text default null
)
returns table (
  valid boolean,
  message text,
  item_id uuid,
  department_id uuid,
  category_id uuid,
  status public.item_status,
  expires_at timestamptz,
  timestamp timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  secret text;
  decoded_token text;
  payload jsonb;
  expires_epoch bigint;
  audit_status public.audit_status := 'success';
  audit_message text;
  now_ts timestamptz := timezone('utc', now());
  qr_text text := coalesce(p_qr_payload, '');
begin
  if length(trim(qr_text)) = 0 then
    valid := false;
    message := 'QR payload is required';
    timestamp := now_ts;
    audit_status := 'failed';
    audit_message := 'Missing QR payload';
    perform public.generate_audit_trail(p_user_id, 'qr_scan', 'qr_code', null, null, null, jsonb_build_object('reason', audit_message), audit_message, audit_status, p_ip, p_user_agent);
    return next;
    return;
  end if;

  begin
    decoded_token := convert_from(decode(qr_text, 'base64'), 'utf-8');
  exception when others then
    decoded_token := qr_text;
  end;

  secret := current_setting('app.settings.qr_secret', true);
  if secret is null or secret = '' then
    secret := current_setting('supabase.jwt_secret', true);
  end if;
  if secret is null or secret = '' then
    raise exception 'QR secret is not configured';
  end if;

  begin
    payload := pgjwt.verify(decoded_token, secret, 'HS256')::jsonb;
  exception when others then
    valid := false;
    message := 'Invalid QR signature';
    timestamp := now_ts;
    audit_status := 'failed';
    audit_message := sqlerrm;
    perform public.generate_audit_trail(p_user_id, 'qr_scan', 'qr_code', null, null, null, jsonb_build_object('error', audit_message), 'Invalid QR signature', audit_status, p_ip, p_user_agent);
    return next;
    return;
  end;

  item_id := (payload ->> 'item_id')::uuid;
  department_id := (payload ->> 'department_id')::uuid;
  category_id := (payload ->> 'category_id')::uuid;
  status := (payload ->> 'status')::public.item_status;
  expires_epoch := nullif(payload ->> 'exp', '')::bigint;
  if expires_epoch is not null then
    expires_at := to_timestamp(expires_epoch) at time zone 'utc';
  else
    expires_at := (payload ->> 'expires_at')::timestamptz;
  end if;

  if expires_at is not null and expires_at < now_ts then
    valid := false;
    message := 'QR code expired';
    timestamp := now_ts;
    audit_status := 'attempted';
    perform public.generate_audit_trail(p_user_id, 'qr_scan', 'items', item_id, null, null, jsonb_build_object('valid', false, 'reason', 'expired'), message, audit_status, p_ip, p_user_agent);
    return next;
    return;
  end if;

  valid := true;
  message := 'QR code is valid';
  timestamp := now_ts;
  perform public.generate_audit_trail(p_user_id, 'qr_scan', 'items', item_id, null, null, jsonb_build_object('valid', true, 'department_id', department_id, 'category_id', category_id), message, audit_status, p_ip, p_user_agent);
  return next;
end;
$$;

-- =====================================================================
-- NOTIFICATION HELPERS
-- =====================================================================
create or replace function public.send_notification(
  p_user_id uuid,
  p_type public.notification_type,
  p_title text,
  p_message text,
  p_action_link text default null,
  p_channels public.notification_channel[] default array['in_app'::public.notification_channel],
  p_priority public.notification_priority default 'medium',
  p_action_data jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_notification_id uuid;
  v_channel public.notification_channel;
  v_channels public.notification_channel[];
begin
  if p_user_id is null then
    raise exception 'user_id is required';
  end if;

  v_channels := coalesce(nullif(p_channels, array[]::public.notification_channel[]), array['in_app'::public.notification_channel]);

  insert into public.notifications (
    user_id,
    type,
    title,
    message,
    action_link,
    action_data,
    priority,
    created_at,
    expires_at
  ) values (
    p_user_id,
    p_type,
    p_title,
    p_message,
    p_action_link,
    coalesce(p_action_data, '{}'::jsonb),
    coalesce(p_priority, 'medium'),
    timezone('utc', now()),
    timezone('utc', now()) + interval '30 days'
  ) returning id into v_notification_id;

  foreach v_channel in array v_channels loop
    insert into public.notification_dispatch_queue (
      notification_id,
      channel,
      payload,
      status,
      attempts
    ) values (
      v_notification_id,
      v_channel,
      jsonb_build_object(
        'title', p_title,
        'message', p_message,
        'action_link', p_action_link,
        'priority', p_priority,
        'type', p_type,
        'action_data', coalesce(p_action_data, '{}'::jsonb)
      ),
      case when v_channel = 'in_app' then 'sent' else 'pending' end,
      case when v_channel = 'in_app' then 1 else 0 end
    ) on conflict (notification_id, channel) do update
      set payload = excluded.payload,
          status = excluded.status,
          attempts = excluded.attempts,
          error_message = null,
          last_attempt_at = null,
          updated_at = timezone('utc', now());
  end loop;

  return v_notification_id;
end;
$$;

create or replace function public.get_user_notification_preferences(p_user_id uuid)
returns table (
  notification_type public.notification_type,
  channel public.notification_channel,
  enabled boolean
)
language plpgsql
set search_path = public
as $$
begin
  return query
  with type_list as (
    select unnest(array[
      'approval',
      'rejection',
      'reminder_2days',
      'reminder_due',
      'reminder_overdue',
      'low_stock',
      'expiry_warning',
      'damage_reported',
      'maintenance_assigned',
      'maintenance_completed'
    ]::public.notification_type[]) as notification_type
  ), channel_list as (
    select unnest(enum_range(null::public.notification_channel)) as channel
  )
  select
    t.notification_type,
    c.channel,
    coalesce(
      (
        select pref.enabled
        from public.user_notification_preferences pref
        where pref.user_id = p_user_id
          and pref.notification_type = t.notification_type
          and pref.channel = c.channel
      ),
      case when c.channel = 'in_app' then true else false end
    ) as enabled
  from type_list t
  cross join channel_list c
  order by t.notification_type, c.channel;
end;
$;

create or replace function public.update_notification_dispatch_status(
  p_notification_id uuid,
  p_channel public.notification_channel,
  p_status public.notification_dispatch_status,
  p_error text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.notification_dispatch_queue
  set status = p_status,
      error_message = p_error,
      last_attempt_at = timezone('utc', now()),
      attempts = case when p_status in ('sent', 'failed') then attempts + 1 else attempts end,
      updated_at = timezone('utc', now())
  where notification_id = p_notification_id
    and channel = p_channel;
end;
$;

-- =====================================================================
-- AUDIT LOG GUARD UPDATE
-- =====================================================================
create or replace function public.prevent_audit_log_mutation()
returns trigger
language plpgsql
as $$
declare
  allow_gc boolean := coalesce(current_setting('app.settings.allow_audit_log_gc', true), 'off') = 'on';
begin
  if allow_gc and tg_op = 'DELETE' then
    return old;
  end if;
  raise exception 'audit_logs table is immutable';
end;
$$;

-- =====================================================================
-- SCHEDULED JOB FUNCTIONS
-- =====================================================================
create or replace function public.check_expiring_chemicals()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  rec record;
  processed integer := 0;
  job_name constant text := 'check_expiring_chemicals';
  already_processed boolean;
  notif_id uuid;
  cutoff date := current_date + 7;
begin
  for rec in (
    select i.id as item_id,
           i.name,
           i.department_id,
           i.expiry_date,
           d.head_user_id,
           greatest((i.expiry_date - current_date), 0) as days_left
    from public.items i
    join public.departments d on d.id = i.department_id
    where not i.is_deleted
      and i.status <> 'retired'
      and i.expiry_date is not null
      and i.expiry_date <= cutoff
  ) loop
    select exists (
      select 1
      from public.job_processing_log l
      where l.job_name = job_name
        and l.entity_id = rec.item_id
        and l.processed_at >= timezone('utc', now()) - interval '1 day'
    ) into already_processed;

    if already_processed or rec.head_user_id is null then
      continue;
    end if;

    notif_id := public.send_notification(
      rec.head_user_id,
      'expiry_warning',
      format('Chemical %s expiring in %s days', rec.name, rec.days_left),
      format('Chemical %s will expire on %s', rec.name, rec.expiry_date),
      null,
      array['in_app'::public.notification_channel, 'email'::public.notification_channel],
      'high',
      jsonb_build_object(
        'item_id', rec.item_id,
        'department_id', rec.department_id,
        'days_until_expiry', rec.days_left,
        'job', job_name
      )
    );

    insert into public.job_processing_log (job_name, entity_type, entity_id, context)
    values (job_name, 'item', rec.item_id, jsonb_build_object('notification_id', notif_id));

    processed := processed + 1;
  end loop;

  return processed;
end;
$$;

create or replace function public.check_overdue_items()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  rec record;
  processed integer := 0;
  job_name constant text := 'check_overdue_items';
  already_processed boolean;
  notif_id uuid;
  admin_id uuid;
  recipients uuid[];
  target uuid;
  days_overdue_value integer;
  created_damage_report uuid;
begin
  select id
  into admin_id
  from public.users
  where role = 'admin'
    and status = 'active'
    and not is_deleted
  order by created_at
  limit 1;

  for rec in (
    select ii.id as issued_item_id,
           ii.item_id,
           ii.issued_to,
           ii.issued_by,
           ii.due_date,
           i.name as item_name,
           i.department_id,
           d.head_user_id
    from public.issued_items ii
    join public.items i on i.id = ii.item_id
    left join public.departments d on d.id = i.department_id
    where ii.status = 'active'
      and ii.due_date < current_date
  ) loop
    select exists (
      select 1
      from public.job_processing_log l
      where l.job_name = job_name
        and l.entity_id = rec.issued_item_id
        and l.processed_at >= timezone('utc', now()) - interval '1 day'
    ) into already_processed;

    if already_processed then
      continue;
    end if;

    days_overdue_value := greatest((current_date - rec.due_date), 1);

    update public.issued_items
    set status = 'overdue',
        is_overdue = true,
        days_overdue = days_overdue_value,
        updated_at = timezone('utc', now())
    where id = rec.issued_item_id
      and status <> 'overdue';

    recipients := array[rec.issued_to, rec.issued_by, rec.head_user_id, admin_id];

    foreach target in array recipients loop
      if target is null then
        continue;
      end if;

      notif_id := public.send_notification(
        target,
        'reminder_overdue',
        format('Item %s is overdue', rec.item_name),
        format('Item %s is overdue by %s days (due %s)', rec.item_name, days_overdue_value, rec.due_date),
        null,
        array['in_app'::public.notification_channel, 'email'::public.notification_channel],
        case when target = admin_id then 'critical' else 'high' end,
        jsonb_build_object(
          'item_id', rec.item_id,
          'issued_item_id', rec.issued_item_id,
          'days_overdue', days_overdue_value,
          'job', job_name
        )
      );
    end loop;

    if days_overdue_value >= 14 then
      select id
      into created_damage_report
      from public.damage_reports
      where item_id = rec.item_id
        and status in ('pending', 'approved', 'in_progress')
      order by created_at desc
      limit 1;

      if created_damage_report is null then
        insert into public.damage_reports (
          item_id,
          damage_type,
          severity,
          description,
          reported_by,
          status
        ) values (
          rec.item_id,
          'overdue_item',
          'moderate',
          format('Auto-generated flag after %s days overdue', days_overdue_value),
          coalesce(rec.issued_by, admin_id),
          'pending'
        );
      end if;
    end if;

    insert into public.job_processing_log (job_name, entity_type, entity_id, context)
    values (job_name, 'issued_item', rec.issued_item_id, jsonb_build_object('days_overdue', days_overdue_value));

    processed := processed + 1;
  end loop;

  return processed;
end;
$$;

create or replace function public.cleanup_expired_notifications(p_retention_days integer default 90)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  removed integer := 0;
begin
  with deleted as (
    delete from public.notifications n
    where (n.expires_at is not null and n.expires_at < timezone('utc', now()))
       or n.created_at < timezone('utc', now()) - (p_retention_days || ' days')::interval
    returning id
  )
  select count(*) into removed from deleted;

  insert into public.job_processing_log (job_name, entity_type, entity_id, context)
  values ('cleanup_expired_notifications', 'notification_batch', null, jsonb_build_object('removed', removed));

  return removed;
end;
$$;

create or replace function public.audit_log_retention(p_years integer default 7)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  cutoff timestamptz := timezone('utc', now()) - (p_years || ' years')::interval;
  moved integer := 0;
begin
  perform set_config('app.settings.allow_audit_log_gc', 'on', true);

  insert into public.audit_logs_archive
  select *
  from public.audit_logs
  where timestamp < cutoff;
  get diagnostics moved = row_count;

  delete from public.audit_logs
  where timestamp < cutoff;

  perform set_config('app.settings.allow_audit_log_gc', 'off', true);

  insert into public.job_processing_log (job_name, entity_type, entity_id, context)
  values ('audit_log_retention', 'audit_logs', null, jsonb_build_object('archived', moved, 'cutoff', cutoff));

  return moved;
exception when others then
  perform set_config('app.settings.allow_audit_log_gc', 'off', true);
  raise;
end;
$$;

-- =====================================================================
-- PG_CRON SCHEDULING
-- =====================================================================
DO $$
DECLARE
  existing_id bigint;
BEGIN
  SELECT jobid INTO existing_id FROM cron.job WHERE jobname = 'check_expiring_chemicals';
  IF existing_id IS NOT NULL THEN
    PERFORM cron.unschedule(existing_id);
  END IF;
  PERFORM cron.schedule('check_expiring_chemicals', '0 8 * * *', $$select public.check_expiring_chemicals();$$);
END $$;

DO $$
DECLARE
  existing_id bigint;
BEGIN
  SELECT jobid INTO existing_id FROM cron.job WHERE jobname = 'check_overdue_items';
  IF existing_id IS NOT NULL THEN
    PERFORM cron.unschedule(existing_id);
  END IF;
  PERFORM cron.schedule('check_overdue_items', '0 9 * * *', $$select public.check_overdue_items();$$);
END $$;

DO $$
DECLARE
  existing_id bigint;
BEGIN
  SELECT jobid INTO existing_id FROM cron.job WHERE jobname = 'cleanup_expired_notifications';
  IF existing_id IS NOT NULL THEN
    PERFORM cron.unschedule(existing_id);
  END IF;
  PERFORM cron.schedule('cleanup_expired_notifications', '0 2 * * 0', $$select public.cleanup_expired_notifications();$$);
END $$;

DO $$
DECLARE
  existing_id bigint;
BEGIN
  SELECT jobid INTO existing_id FROM cron.job WHERE jobname = 'audit_log_retention';
  IF existing_id IS NOT NULL THEN
    PERFORM cron.unschedule(existing_id);
  END IF;
  PERFORM cron.schedule('audit_log_retention', '0 3 1 * *', $$select public.audit_log_retention();$$);
END $$;

commit;
