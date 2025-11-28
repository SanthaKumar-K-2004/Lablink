-- LabLink Phase 1: Audit, History Automation, Computed Columns & Admin Views
-- Part 2: Functions, triggers, auditing, computed metrics, reporting views, storage policies

begin;

-- =====================================================================
-- AUDIT LOG TABLE & INDEXES
-- =====================================================================
create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id),
  action text not null,
  entity_type text not null,
  entity_id uuid not null,
  entity_name text,
  old_values jsonb,
  new_values jsonb,
  changes_summary text,
  ip_address inet,
  user_agent text,
  status public.audit_status not null default 'success',
  error_message text,
  request_id uuid,
  timestamp timestamptz not null default timezone('utc', now()),
  retention_until date default (current_date + interval '7 years'),
  is_archived boolean not null default false
);

create index if not exists audit_logs_timestamp_idx on public.audit_logs (timestamp);
create index if not exists audit_logs_user_id_idx on public.audit_logs (user_id);
create index if not exists audit_logs_entity_type_idx on public.audit_logs (entity_type);
create index if not exists audit_logs_entity_id_idx on public.audit_logs (entity_id);
create index if not exists audit_logs_action_idx on public.audit_logs (action);
create index if not exists audit_logs_request_idx on public.audit_logs (request_id);

-- =====================================================================
-- AUDIT LOGGING FUNCTION & IMMUTABILITY
-- =====================================================================
create or replace function public.audit_log_trigger()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid;
  action_text text := lower(tg_op);
  record_id uuid;
  record_name text;
  old_data jsonb;
  new_data jsonb;
  summary text := null;
begin
  begin
    actor := nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
  exception when others then
    actor := null;
  end;

  if tg_op = 'DELETE' then
    record_id := old.id;
    record_name := coalesce(old.name, old.title, old.email, old.id::text);
    old_data := to_jsonb(old);
    new_data := null;
  else
    record_id := new.id;
    record_name := coalesce(new.name, new.title, new.email, new.id::text);
    old_data := case when tg_op = 'UPDATE' then to_jsonb(old) end;
    new_data := to_jsonb(new);
  end if;

  if tg_op = 'UPDATE' then
    with diffs as (
      select coalesce(o.key, n.key) as key,
             o.value as old_val,
             n.value as new_val
      from jsonb_each_text(coalesce(old_data, '{}'::jsonb)) o
      full outer join jsonb_each_text(coalesce(new_data, '{}'::jsonb)) n using (key)
    )
    select string_agg(format('%s: %s -> %s', key, coalesce(old_val, '∅'), coalesce(new_val, '∅')), '; ')
    into summary
    from diffs
    where coalesce(old_val, '') is distinct from coalesce(new_val, '');
  end if;

  insert into public.audit_logs (
    user_id,
    action,
    entity_type,
    entity_id,
    entity_name,
    old_values,
    new_values,
    changes_summary,
    timestamp
  ) values (
    actor,
    action_text,
    tg_table_name,
    record_id,
    record_name,
    old_data,
    new_data,
    summary,
    timezone('utc', now())
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create or replace function public.prevent_audit_log_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'audit_logs table is immutable';
end;
$$;

create trigger trg_audit_logs_lock before update or delete on public.audit_logs
for each row execute function public.prevent_audit_log_mutation();

-- =====================================================================
-- ROLE VALIDATION HELPERS
-- =====================================================================
create or replace function public.enforce_user_roles(p_user_id uuid, allowed_roles public.user_role[], context text)
returns void
language plpgsql
as $$
declare
  actual_role public.user_role;
begin
  if p_user_id is null then
    raise exception 'User id cannot be null for %', context;
  end if;

  select role into actual_role from public.users where id = p_user_id;
  if actual_role is null then
    raise exception 'User % not found for %', p_user_id, context;
  end if;

  if not (actual_role = any(allowed_roles)) then
    raise exception 'User % has role %, expected one of % for %', p_user_id, actual_role, allowed_roles, context;
  end if;
end;
$$;

-- =====================================================================
-- ITEM COMPUTED FIELD MANAGEMENT
-- =====================================================================
create or replace function public.set_item_computed_fields()
returns trigger
language plpgsql
set search_path = public
as $
declare
  threshold integer;
begin
  if new.category_id is not null then
    select low_stock_threshold into threshold from public.categories where id = new.category_id;
    if threshold is not null then
      new.low_stock_threshold_value := threshold;
    end if;
  end if;

  if tg_op = 'INSERT' then
    if new.expiry_date is not null then
      new.days_until_expiry := (new.expiry_date - current_date);
    else
      new.days_until_expiry := null;
    end if;
  elsif new.expiry_date is distinct from old.expiry_date then
    if new.expiry_date is not null then
      new.days_until_expiry := (new.expiry_date - current_date);
    else
      new.days_until_expiry := null;
    end if;
  end if;

  return new;
end;
$;

create or replace function public.apply_category_threshold_change()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if old.low_stock_threshold is distinct from new.low_stock_threshold then
    update public.items
    set low_stock_threshold_value = new.low_stock_threshold
    where category_id = new.id;
  end if;
  return new;
end;
$$;

-- =====================================================================
-- ISSUED ITEM OVERDUE FLAGS
-- =====================================================================
create or replace function public.set_issued_items_overdue_flags()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  reference_date date;
begin
  reference_date := coalesce(new.returned_date::date, current_date);

  if new.returned_date is not null and new.returned_date::date > new.due_date then
    new.is_overdue := true;
    new.days_overdue := greatest((new.returned_date::date - new.due_date), 0);
  elsif new.returned_date is null and reference_date > new.due_date then
    new.is_overdue := true;
    new.days_overdue := greatest((reference_date - new.due_date), 0);
  else
    new.is_overdue := false;
    new.days_overdue := 0;
  end if;

  return new;
end;
$$;

-- =====================================================================
-- INVENTORY COUNTER SYNC HELPERS
-- =====================================================================
create or replace function public.sync_borrowed_quantity()
returns trigger
language plpgsql
set search_path = public
as $
declare
  delta integer := 0;
  tracked_status constant public.issued_item_status[] := array['active', 'overdue', 'lost', 'damaged_during_use'];
  item_id uuid := coalesce(new.item_id, old.item_id);
  old_counts boolean := (tg_op <> 'INSERT') and old.status = any(tracked_status) and old.returned_date is null;
  new_counts boolean := (tg_op <> 'DELETE') and new.status = any(tracked_status) and new.returned_date is null;
begin
  if tg_op = 'INSERT' then
    if new_counts then
      delta := 1;
    end if;
  elsif tg_op = 'UPDATE' then
    delta := (case when new_counts then 1 else 0 end) - (case when old_counts then 1 else 0 end);
  elsif tg_op = 'DELETE' then
    if old_counts then
      delta := -1;
    end if;
  end if;

  if delta <> 0 then
    update public.items
    set borrowed_quantity = greatest(borrowed_quantity + delta, 0)
    where id = item_id;
  end if;

  return coalesce(new, old);
end;
$;

create or replace function public.sync_damaged_quantity()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  delta integer := 0;
  tracked_status constant public.damage_report_status[] := array['pending', 'approved', 'in_progress'];
  item_id uuid := coalesce(new.item_id, old.item_id);
begin
  if tg_op = 'INSERT' then
    if new.status = any(tracked_status) then
      delta := 1;
    end if;
  elsif tg_op = 'UPDATE' then
    if old.status = any(tracked_status) and new.status <> all(tracked_status) then
      delta := delta - 1;
    end if;
    if old.status <> all(tracked_status) and new.status = any(tracked_status) then
      delta := delta + 1;
    end if;
  elsif tg_op = 'DELETE' then
    if old.status = any(tracked_status) then
      delta := -1;
    end if;
  end if;

  if delta <> 0 then
    update public.items
    set damaged_quantity = greatest(damaged_quantity + delta, 0)
    where id = item_id;
  end if;

  return coalesce(new, old);
end;
$$;

create or replace function public.sync_maintenance_quantity()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  delta integer := 0;
  tracked_status constant public.maintenance_status[] := array['assigned', 'in_progress', 'on_hold'];
  item_id uuid := coalesce(new.item_id, old.item_id);
begin
  if tg_op = 'INSERT' then
    if new.status = any(tracked_status) then
      delta := 1;
    end if;
  elsif tg_op = 'UPDATE' then
    if old.status = any(tracked_status) and new.status <> all(tracked_status) then
      delta := delta - 1;
    end if;
    if old.status <> all(tracked_status) and new.status = any(tracked_status) then
      delta := delta + 1;
    end if;
  elsif tg_op = 'DELETE' then
    if old.status = any(tracked_status) then
      delta := -1;
    end if;
  end if;

  if delta <> 0 then
    update public.items
    set maintenance_quantity = greatest(maintenance_quantity + delta, 0)
    where id = item_id;
  end if;

  return coalesce(new, old);
end;
$$;

-- =====================================================================
-- METRIC REFRESH HELPERS
-- =====================================================================
create or replace function public.refresh_department_item_count(p_department_id uuid)
returns void
language plpgsql
as $$
begin
  if p_department_id is null then
    return;
  end if;
  update public.departments d
  set item_count = (
    select count(*) from public.items i
    where i.department_id = p_department_id and not i.is_deleted
  )
  where d.id = p_department_id;
end;
$$;

create or replace function public.touch_department_item_count()
returns trigger
language plpgsql
as $$
begin
  if tg_op in ('INSERT', 'UPDATE') then
    perform public.refresh_department_item_count(new.department_id);
  end if;
  if tg_op in ('UPDATE', 'DELETE') then
    if (old.department_id is distinct from coalesce(new.department_id, old.department_id)) or tg_op = 'DELETE' then
      perform public.refresh_department_item_count(old.department_id);
    end if;
  end if;
  return coalesce(new, old);
end;
$$;

create or replace function public.refresh_department_budget(p_department_id uuid)
returns void
language plpgsql
as $$
begin
  if p_department_id is null then
    return;
  end if;
  update public.departments d
  set budget_spent = coalesce((
    select sum(amount)
    from public.cost_tracking c
    where c.department_id = p_department_id
  ), 0)
  where d.id = p_department_id;
end;
$$;

create or replace function public.touch_department_budget()
returns trigger
language plpgsql
as $$
begin
  if tg_op in ('INSERT', 'UPDATE') then
    perform public.refresh_department_budget(new.department_id);
  end if;
  if tg_op in ('UPDATE', 'DELETE') then
    if old.department_id is distinct from coalesce(new.department_id, old.department_id) or tg_op = 'DELETE' then
      perform public.refresh_department_budget(old.department_id);
    end if;
  end if;
  return coalesce(new, old);
end;
$$;

create or replace function public.refresh_user_metrics(p_user_id uuid)
returns void
language plpgsql
as $$
begin
  if p_user_id is null then
    return;
  end if;
  update public.users u
  set total_borrows = (
        select count(*) from public.borrow_requests br where br.student_id = p_user_id
      ),
      overdue_items = (
        select count(*)
        from public.issued_items ii
        where ii.issued_to = p_user_id
          and ii.status in ('active', 'overdue')
          and ((ii.returned_date is null and ii.due_date < current_date) or ii.status = 'overdue')
      ),
      updated_at = u.updated_at
  where u.id = p_user_id;
end;
$$;

create or replace function public.touch_user_borrow_metrics()
returns trigger
language plpgsql
as $$
begin
  if tg_op in ('INSERT', 'UPDATE') then
    perform public.refresh_user_metrics(new.student_id);
  end if;
  if tg_op in ('UPDATE', 'DELETE') then
    if old.student_id is distinct from coalesce(new.student_id, old.student_id) or tg_op = 'DELETE' then
      perform public.refresh_user_metrics(old.student_id);
    end if;
  end if;
  return coalesce(new, old);
end;
$$;

create or replace function public.touch_user_overdue_metrics()
returns trigger
language plpgsql
as $$
begin
  if tg_op in ('INSERT', 'UPDATE') then
    perform public.refresh_user_metrics(new.issued_to);
  end if;
  if tg_op in ('UPDATE', 'DELETE') then
    if old.issued_to is distinct from coalesce(new.issued_to, old.issued_to) or tg_op = 'DELETE' then
      perform public.refresh_user_metrics(old.issued_to);
    end if;
  end if;
  return coalesce(new, old);
end;
$$;

-- =====================================================================
-- HISTORY HELPERS
-- =====================================================================
create or replace function public.record_department_history()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  actor uuid;
begin
  begin
    actor := nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
  exception when others then
    actor := coalesce(new.updated_by, old.updated_by);
  end;

  insert into public.department_history (
    department_id,
    name,
    head_user_id,
    budget_allocated,
    budget_spent,
    active,
    is_deleted,
    change_summary,
    changed_by,
    changed_at
  ) values (
    new.id,
    new.name,
    new.head_user_id,
    new.budget_allocated,
    new.budget_spent,
    new.active,
    new.is_deleted,
    'Department updated',
    actor,
    timezone('utc', now())
  );

  return new;
end;
$$;

create or replace function public.record_department_history_on_insert()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  insert into public.department_history (
    department_id,
    name,
    head_user_id,
    budget_allocated,
    budget_spent,
    active,
    is_deleted,
    change_summary,
    changed_by,
    changed_at
  ) values (
    new.id,
    new.name,
    new.head_user_id,
    new.budget_allocated,
    new.budget_spent,
    new.active,
    new.is_deleted,
    'Department created',
    coalesce(new.created_by, new.head_user_id),
    coalesce(new.created_at, timezone('utc', now()))
  );
  return new;
end;
$$;

create or replace function public.log_initial_item_history()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  insert into public.item_history (
    item_id,
    version_number,
    name,
    category_id,
    department_id,
    serial_number,
    model_number,
    brand,
    status,
    total_quantity,
    expiry_date,
    safety_level,
    hazard_type,
    storage_location,
    purchase_price,
    warranty_expiry,
    modified_by,
    modification_reason,
    modified_at
  ) values (
    new.id,
    new.version_number,
    new.name,
    new.category_id,
    new.department_id,
    new.serial_number,
    new.model_number,
    new.brand,
    new.status,
    new.total_quantity,
    new.expiry_date,
    new.safety_level,
    new.hazard_type,
    new.storage_location,
    new.purchase_price,
    new.warranty_expiry,
    coalesce(new.created_by, '00000000-0000-0000-0000-000000000000'::uuid),
    'Item created',
    coalesce(new.created_at, timezone('utc', now()))
  );
  return new;
end;
$$;

create or replace function public.log_initial_inventory()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  insert into public.inventory_change_history (
    item_id,
    change_type,
    quantity_before,
    quantity_after,
    quantity_changed,
    reason,
    changed_by,
    changed_at
  ) values (
    new.id,
    'import',
    0,
    new.available_count,
    new.available_count,
    'Initial stock added',
    new.created_by,
    coalesce(new.created_at, timezone('utc', now()))
  );
  return new;
end;
$$;

-- =====================================================================
-- VALIDATION TRIGGERS
-- =====================================================================
create or replace function public.validate_borrow_request()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  perform public.enforce_user_roles(new.student_id, array['student'], 'borrow_requests.student_id');
  if tg_op = 'INSERT' and new.created_by is null then
    new.created_by := new.student_id;
  end if;
  if new.requested_start_date >= new.requested_end_date then
    raise exception 'requested_end_date must be after requested_start_date';
  end if;
  return new;
end;
$$;

create or replace function public.validate_issued_item()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  perform public.enforce_user_roles(new.issued_to, array['student'], 'issued_items.issued_to');
  perform public.enforce_user_roles(new.issued_by, array['staff','admin'], 'issued_items.issued_by');
  if new.due_date <= new.issued_date::date then
    raise exception 'Due date must be after issued date';
  end if;
  return new;
end;
$$;

create or replace function public.validate_maintenance_assignment()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  perform public.enforce_user_roles(new.assigned_to, array['technician'], 'maintenance_records.assigned_to');
  perform public.enforce_user_roles(new.assigned_by, array['admin','staff'], 'maintenance_records.assigned_by');
  if new.start_date is not null and new.completion_date is not null and new.start_date > new.completion_date then
    raise exception 'completion_date must be after start_date';
  end if;
  return new;
end;
$$;

create or replace function public.validate_admin_action()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  perform public.enforce_user_roles(new.admin_id, array['admin'], 'admin_actions_log.admin_id');
  return new;
end;
$$;

create or replace function public.validate_chemical_usage()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  has_expiry boolean;
begin
  select (expiry_date is not null) into has_expiry
  from public.items
  where id = new.item_id;

  if not coalesce(has_expiry, false) then
    raise exception 'Chemical usage logs require the referenced item % to have an expiry_date set', new.item_id;
  end if;
  return new;
end;
$$;

create or replace function public.log_chemical_usage_change()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  insert into public.inventory_change_history (
    item_id,
    change_type,
    quantity_before,
    quantity_after,
    quantity_changed,
    reason,
    related_entity_id,
    changed_by,
    changed_at,
    notes
  ) values (
    new.item_id,
    'usage',
    new.quantity_remaining + new.quantity_used,
    new.quantity_remaining,
    new.quantity_remaining - (new.quantity_remaining + new.quantity_used),
    'Chemical consumed',
    new.id,
    new.used_by,
    new.usage_date,
    new.experiment_purpose
  );
  return new;
end;
$$;

-- =====================================================================
-- BORROW HISTORY EVENTS
-- =====================================================================
create or replace function public.log_borrow_creation()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  insert into public.borrow_history (
    borrow_request_id,
    student_id,
    item_id,
    status_change,
    previous_status,
    new_status,
    changed_by,
    reason,
    changed_at,
    notes
  ) values (
    new.id,
    new.student_id,
    new.item_id,
    'pending',
    null,
    new.status::text,
    new.created_by,
    null,
    coalesce(new.created_at, timezone('utc', now())),
    'Borrow request submitted'
  );
  return new;
end;
$$;

create or replace function public.track_borrow_status_change()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  actor uuid;
begin
  begin
    actor := nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
  exception when others then
    actor := coalesce(new.updated_by, old.updated_by, new.approved_by);
  end;

  if old.status is distinct from new.status then
    insert into public.borrow_history (
      borrow_request_id,
      student_id,
      item_id,
      status_change,
      previous_status,
      new_status,
      changed_by,
      reason,
      changed_at
    ) values (
      new.id,
      new.student_id,
      new.item_id,
      new.status,
      old.status::text,
      new.status::text,
      actor,
      coalesce(new.rejection_reason, new.special_requirements),
      timezone('utc', now())
    );
  end if;

  return new;
end;
$$;

-- =====================================================================
-- ITEM VERSION HISTORY
-- =====================================================================
create or replace function public.track_item_version()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  actor uuid;
begin
  begin
    actor := nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
  exception when others then
    actor := coalesce(new.updated_by, old.updated_by);
  end;

  new.version_number := old.version_number + 1;

  insert into public.item_history (
    item_id,
    version_number,
    name,
    category_id,
    department_id,
    serial_number,
    model_number,
    brand,
    status,
    total_quantity,
    expiry_date,
    safety_level,
    hazard_type,
    storage_location,
    purchase_price,
    warranty_expiry,
    modified_by,
    modification_reason,
    modified_at
  ) values (
    old.id,
    old.version_number,
    old.name,
    old.category_id,
    old.department_id,
    old.serial_number,
    old.model_number,
    old.brand,
    old.status,
    old.total_quantity,
    old.expiry_date,
    old.safety_level,
    old.hazard_type,
    old.storage_location,
    old.purchase_price,
    old.warranty_expiry,
    actor,
    'Field update',
    timezone('utc', now())
  );

  return new;
end;
$$;

-- =====================================================================
-- INVENTORY CHANGE TRACKING
-- =====================================================================
create or replace function public.track_inventory_change()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  actor uuid;
  before_available numeric := coalesce(old.available_count, 0);
  after_available numeric := coalesce(new.available_count, 0);
  before_total numeric := coalesce(old.total_quantity, 0);
  after_total numeric := coalesce(new.total_quantity, 0);
  change_type_val public.inventory_change_type;
  reason_text text;
  quantity_before numeric;
  quantity_after numeric;
  quantity_changed numeric;
begin
  begin
    actor := nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
  exception when others then
    actor := coalesce(new.updated_by, old.updated_by, new.created_by);
  end;

  if after_available <> before_available then
    quantity_before := before_available;
    quantity_after := after_available;
    quantity_changed := quantity_after - quantity_before;

    if new.borrowed_quantity > old.borrowed_quantity then
      change_type_val := 'borrow';
      reason_text := 'Item issued to borrower';
    elsif new.borrowed_quantity < old.borrowed_quantity then
      change_type_val := 'return';
      reason_text := 'Item returned to inventory';
    elsif new.damaged_quantity > old.damaged_quantity then
      change_type_val := 'damage';
      reason_text := 'Item reported damaged';
    elsif new.damaged_quantity < old.damaged_quantity then
      change_type_val := 'adjustment';
      reason_text := 'Damage resolved';
    elsif new.maintenance_quantity > old.maintenance_quantity then
      change_type_val := 'maintenance';
      reason_text := 'Item moved to maintenance';
    elsif new.maintenance_quantity < old.maintenance_quantity then
      change_type_val := 'maintenance';
      reason_text := 'Item returned from maintenance';
    else
      change_type_val := 'adjustment';
      reason_text := 'Inventory availability changed';
    end if;

    insert into public.inventory_change_history (
      item_id,
      change_type,
      quantity_before,
      quantity_after,
      quantity_changed,
      reason,
      changed_by,
      changed_at
    ) values (
      new.id,
      change_type_val,
      quantity_before,
      quantity_after,
      quantity_changed,
      reason_text,
      actor,
      timezone('utc', now())
    );
  elsif after_total <> before_total then
    quantity_before := before_total;
    quantity_after := after_total;
    quantity_changed := quantity_after - quantity_before;

    if quantity_changed > 0 then
      change_type_val := 'import';
      reason_text := 'Stock increased';
    else
      change_type_val := 'adjustment';
      reason_text := 'Stock decreased';
    end if;

    insert into public.inventory_change_history (
      item_id,
      change_type,
      quantity_before,
      quantity_after,
      quantity_changed,
      reason,
      changed_by,
      changed_at
    ) values (
      new.id,
      change_type_val,
      quantity_before,
      quantity_after,
      quantity_changed,
      reason_text,
      actor,
      timezone('utc', now())
    );
  end if;

  return new;
end;
$$;

-- =====================================================================
-- QR CODE HELPERS
-- =====================================================================
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
    raise exception 'QR secret is not configured';
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

  if new.qr_hash is null or new.qr_hash = '' then
    new.qr_hash := public.generate_qr_hash(
      new.id,
      jsonb_build_object('serial_number', new.serial_number, 'name', new.name)
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

-- =====================================================================
-- TRIGGER ASSIGNMENTS
-- =====================================================================
-- Core tables audited
create trigger trg_users_audit after insert or update or delete on public.users for each row execute function public.audit_log_trigger();
create trigger trg_departments_audit after insert or update or delete on public.departments for each row execute function public.audit_log_trigger();
create trigger trg_categories_audit after insert or update or delete on public.categories for each row execute function public.audit_log_trigger();
create trigger trg_items_audit after insert or update or delete on public.items for each row execute function public.audit_log_trigger();
create trigger trg_borrow_requests_audit after insert or update or delete on public.borrow_requests for each row execute function public.audit_log_trigger();
create trigger trg_issued_items_audit after insert or update or delete on public.issued_items for each row execute function public.audit_log_trigger();
create trigger trg_damage_reports_audit after insert or update or delete on public.damage_reports for each row execute function public.audit_log_trigger();
create trigger trg_maintenance_records_audit after insert or update or delete on public.maintenance_records for each row execute function public.audit_log_trigger();
create trigger trg_chemical_usage_logs_audit after insert or update or delete on public.chemical_usage_logs for each row execute function public.audit_log_trigger();
create trigger trg_notifications_audit after insert or update or delete on public.notifications for each row execute function public.audit_log_trigger();
create trigger trg_cost_tracking_audit after insert or update or delete on public.cost_tracking for each row execute function public.audit_log_trigger();
create trigger trg_admin_actions_audit after insert or update or delete on public.admin_actions_log for each row execute function public.audit_log_trigger();

-- Item computed fields and QR assignment
create trigger trg_items_computed before insert or update on public.items for each row execute function public.set_item_computed_fields();
create trigger trg_items_qr before insert on public.items for each row execute function public.assign_qr_hash();
create trigger trg_categories_threshold after update on public.categories for each row execute function public.apply_category_threshold_change();

-- Item history & inventory initial records
create trigger trg_items_history_insert after insert on public.items for each row execute function public.log_initial_item_history();
create trigger trg_items_inventory_insert after insert on public.items for each row execute function public.log_initial_inventory();
create trigger trg_items_version before update of name, category_id, department_id, description, serial_number, model_number, brand, image_url, storage_location, supplier_name, supplier_id, purchase_date, purchase_price, warranty_expiry, status, total_quantity, expiry_date, safety_level, hazard_type, manual_url, qr_hash, is_deleted on public.items for each row execute function public.track_item_version();
create trigger trg_items_inventory_change after update on public.items for each row execute function public.track_inventory_change();
create trigger trg_items_department_counts after insert or update or delete on public.items for each row execute function public.touch_department_item_count();

-- Borrow requests
create trigger trg_borrow_requests_validate before insert or update on public.borrow_requests for each row execute function public.validate_borrow_request();
create trigger trg_borrow_requests_history_insert after insert on public.borrow_requests for each row execute function public.log_borrow_creation();
create trigger trg_borrow_requests_status_change after update on public.borrow_requests for each row execute function public.track_borrow_status_change();
create trigger trg_borrow_requests_user_metrics after insert or update or delete on public.borrow_requests for each row execute function public.touch_user_borrow_metrics();

-- Issued items
create trigger trg_issued_items_validate before insert or update on public.issued_items for each row execute function public.validate_issued_item();
create trigger trg_issued_items_overdue before insert or update on public.issued_items for each row execute function public.set_issued_items_overdue_flags();
create trigger trg_issued_items_inventory after insert or update or delete on public.issued_items for each row execute function public.sync_borrowed_quantity();
create trigger trg_issued_items_user_metrics after insert or update or delete on public.issued_items for each row execute function public.touch_user_overdue_metrics();

-- Damage reports & maintenance
create trigger trg_damage_reports_inventory after insert or update or delete on public.damage_reports for each row execute function public.sync_damaged_quantity();
create trigger trg_maintenance_records_validate before insert or update on public.maintenance_records for each row execute function public.validate_maintenance_assignment();
create trigger trg_maintenance_records_inventory after insert or update or delete on public.maintenance_records for each row execute function public.sync_maintenance_quantity();

-- Departments history & budgets
create trigger trg_departments_history_insert after insert on public.departments for each row execute function public.record_department_history_on_insert();
create trigger trg_departments_history_update after update on public.departments for each row execute function public.record_department_history();
create trigger trg_cost_tracking_budget after insert or update or delete on public.cost_tracking for each row execute function public.touch_department_budget();

-- Admin actions
create trigger trg_admin_actions_validate before insert on public.admin_actions_log for each row execute function public.validate_admin_action();

-- Chemical usage logs
create trigger trg_chemical_usage_validate before insert on public.chemical_usage_logs for each row execute function public.validate_chemical_usage();
create trigger trg_chemical_usage_inventory after insert on public.chemical_usage_logs for each row execute function public.log_chemical_usage_change();

-- =====================================================================
-- ADMIN & ANALYTICS VIEWS
-- =====================================================================
create or replace view public.admin_dashboard_snapshot as
with inventory_metrics as (
  select
    count(*) filter (where not i.is_deleted) as total_items,
    count(*) filter (where i.status = 'available' and not i.is_deleted) as available_items,
    count(*) filter (where i.status = 'borrowed' and not i.is_deleted) as borrowed_items,
    count(*) filter (where i.status = 'damaged' and not i.is_deleted) as damaged_items,
    count(*) filter (where i.status = 'maintenance' and not i.is_deleted) as maintenance_items,
    count(*) filter (where i.is_low_stock and not i.is_deleted) as low_stock_items
  from public.items i
),
department_metrics as (
  select
    d.id as department_id,
    d.name as department_name,
    d.item_count,
    d.budget_allocated,
    d.budget_spent,
    d.budget_remaining,
    (select count(*) from public.issued_items ii join public.items it on ii.item_id = it.id where it.department_id = d.id and ii.status = 'active') as active_borrows,
    (select count(*) from public.damage_reports dr join public.items it on dr.item_id = it.id where it.department_id = d.id and dr.status in ('pending','in_progress')) as open_damage_reports
  from public.departments d
  where not d.is_deleted
),
staff_metrics as (
  select
    u.id as staff_id,
    u.full_name,
    u.role,
    count(br.*) filter (where br.approved_by = u.id and br.status = 'approved') as approvals,
    count(br.*) filter (where br.approved_by = u.id and br.status = 'rejected') as rejections,
    count(dr.*) filter (where dr.approved_by = u.id) as damage_approvals
  from public.users u
  left join public.borrow_requests br on br.approved_by = u.id
  left join public.damage_reports dr on dr.approved_by = u.id
  where u.role in ('staff','admin') and not u.is_deleted
  group by u.id
),
student_metrics as (
  select
    u.id as student_id,
    u.full_name,
    u.total_borrows,
    u.overdue_items,
    count(br.*) filter (where br.status = 'pending') as pending_requests,
    count(ii.*) filter (where ii.status = 'active' and ii.is_overdue) as active_overdue
  from public.users u
  left join public.borrow_requests br on br.student_id = u.id
  left join public.issued_items ii on ii.issued_to = u.id
  where u.role = 'student' and not u.is_deleted
  group by u.id
),
chemical_metrics as (
  select
    count(*) filter (where i.safety_level = 'high' or i.hazard_type is not null) as hazardous_items,
    count(*) filter (where i.is_low_stock and (i.hazard_type is not null or i.safety_level is not null)) as hazardous_low_stock,
    count(*) filter (where i.expiry_date is not null and i.expiry_date <= current_date + 30) as expiring_soon,
    count(*) filter (where i.safety_level = 'low') as low_risk_items,
    (select count(*) from public.chemical_usage_logs where usage_date >= current_date - 30) as usage_last_30_days
  from public.items i
  where not i.is_deleted
)
select
  to_jsonb(inventory_metrics) as inventory_overview,
  coalesce((select jsonb_agg(to_jsonb(department_metrics)) from department_metrics), '[]'::jsonb) as department_breakdown,
  coalesce((select jsonb_agg(to_jsonb(staff_metrics)) from staff_metrics), '[]'::jsonb) as staff_performance,
  coalesce((select jsonb_agg(to_jsonb(student_metrics)) from student_metrics), '[]'::jsonb) as student_activity,
  to_jsonb(chemical_metrics) as chemical_status
from inventory_metrics, chemical_metrics
limit 1;

create or replace view public.user_activity_summary as
select
  u.id,
  u.full_name,
  u.email,
  u.role,
  u.status,
  d.name as primary_department,
  u.last_login,
  u.total_borrows,
  u.overdue_items,
  (select count(*) from public.user_login_history ulh where ulh.user_id = u.id and ulh.login_status = 'success' and ulh.login_time >= date_trunc('month', current_date)) as login_count_this_month,
  (select count(*) from public.user_login_history ulh where ulh.user_id = u.id and ulh.login_status <> 'success' and ulh.login_time >= date_trunc('month', current_date)) as failed_logins_this_month,
  (select count(*) from public.issued_items ii where ii.issued_by = u.id) as items_issued,
  (select count(*) from public.borrow_requests br where br.approved_by = u.id) as approvals_made,
  (select count(*) from public.damage_reports dr where dr.reported_by = u.id) as damage_reports_filed,
  (select count(*) from public.issued_items ii where ii.issued_to = u.id and ii.status = 'active' and ii.is_overdue) as active_overdue_items
from public.users u
left join public.departments d on d.id = (u.department_ids[1])
where not u.is_deleted;

create or replace view public.item_movement_audit as
select
  i.id as item_id,
  i.name,
  i.serial_number,
  i.status,
  i.total_quantity,
  i.available_count,
  i.is_low_stock,
  d.name as department_name,
  c.name as category_name,
  (select jsonb_agg(jsonb_build_object(
      'change_type', ich.change_type,
      'quantity_before', ich.quantity_before,
      'quantity_after', ich.quantity_after,
      'quantity_changed', ich.quantity_changed,
      'reason', ich.reason,
      'changed_at', ich.changed_at,
      'changed_by', ich.changed_by
    ) order by ich.changed_at desc)
   from public.inventory_change_history ich
   where ich.item_id = i.id
  ) as movement_history,
  (select jsonb_agg(jsonb_build_object(
      'status', ii.status,
      'issued_to', ii.issued_to,
      'due_date', ii.due_date,
      'is_overdue', ii.is_overdue
    ) order by ii.issued_date desc)
   from public.issued_items ii
   where ii.item_id = i.id
  ) as current_borrow_status,
  (select jsonb_agg(jsonb_build_object(
      'status', mr.status,
      'assigned_to', mr.assigned_to,
      'assigned_date', mr.assigned_date,
      'completion_date', mr.completion_date,
      'maintenance_type', mr.maintenance_type
    ) order by mr.assigned_date desc)
   from public.maintenance_records mr
   where mr.item_id = i.id
  ) as maintenance_history,
  (select jsonb_agg(jsonb_build_object(
      'cost_type', ct.cost_type,
      'amount', ct.amount,
      'recorded_at', ct.recorded_at,
      'recorded_by', ct.recorded_by
    ) order by ct.recorded_at desc)
   from public.cost_tracking ct
   where ct.related_item_id = i.id
  ) as cost_history
from public.items i
join public.departments d on d.id = i.department_id
join public.categories c on c.id = i.category_id
where not i.is_deleted;

create or replace view public.financial_summary as
select
  d.id as department_id,
  d.name as department_name,
  d.budget_allocated,
  d.budget_spent,
  d.budget_remaining,
  coalesce(sum(case when ct.cost_type = 'purchase' then ct.amount end), 0) as purchases,
  coalesce(sum(case when ct.cost_type = 'repair' then ct.amount end), 0) as repairs,
  coalesce(sum(case when ct.cost_type = 'maintenance' then ct.amount end), 0) as maintenance,
  coalesce(sum(case when ct.cost_type = 'replacement' then ct.amount end), 0) as replacements,
  count(distinct i.id) as total_items,
  count(distinct mr.id) filter (where mr.status = 'in_progress') as maintenance_in_progress
from public.departments d
left join public.cost_tracking ct on ct.department_id = d.id
left join public.items i on i.department_id = d.id and not i.is_deleted
left join public.maintenance_records mr on mr.item_id = i.id
where not d.is_deleted
group by d.id;

-- =====================================================================
-- STORAGE BUCKETS & POLICIES
-- =====================================================================
insert into storage.buckets (id, name, public)
values
  ('qr_codes', 'qr_codes', true),
  ('item_images', 'item_images', true),
  ('maintenance_photos', 'maintenance_photos', true),
  ('chemical_msds', 'chemical_msds', true),
  ('user_avatars', 'user_avatars', true)
on conflict (id) do update set public = excluded.public;

create or replace procedure public.ensure_storage_policy(
  policy_name text,
  bucket text,
  policy_cmd text
)
language plpgsql
as $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects' and polname = policy_name
  ) then
    execute policy_cmd;
  end if;
end;
$$;

do $$
begin
  perform public.ensure_storage_policy(
    'lablink_public_read_qr_codes', 'qr_codes',
    $$create policy lablink_public_read_qr_codes on storage.objects for select using (bucket_id = 'qr_codes')$$
  );
  perform public.ensure_storage_policy(
    'lablink_public_read_item_images', 'item_images',
    $$create policy lablink_public_read_item_images on storage.objects for select using (bucket_id = 'item_images')$$
  );
  perform public.ensure_storage_policy(
    'lablink_public_read_maintenance_photos', 'maintenance_photos',
    $$create policy lablink_public_read_maintenance_photos on storage.objects for select using (bucket_id = 'maintenance_photos')$$
  );
  perform public.ensure_storage_policy(
    'lablink_public_read_chemical_msds', 'chemical_msds',
    $$create policy lablink_public_read_chemical_msds on storage.objects for select using (bucket_id = 'chemical_msds')$$
  );
  perform public.ensure_storage_policy(
    'lablink_public_read_user_avatars', 'user_avatars',
    $$create policy lablink_public_read_user_avatars on storage.objects for select using (bucket_id = 'user_avatars')$$
  );
  perform public.ensure_storage_policy(
    'lablink_authenticated_write_qr_codes', 'qr_codes',
    $$create policy lablink_authenticated_write_qr_codes on storage.objects for insert with check (bucket_id = 'qr_codes' and auth.role() = 'authenticated')$$
  );
  perform public.ensure_storage_policy(
    'lablink_authenticated_write_item_images', 'item_images',
    $$create policy lablink_authenticated_write_item_images on storage.objects for insert with check (bucket_id = 'item_images' and auth.role() = 'authenticated')$$
  );
  perform public.ensure_storage_policy(
    'lablink_authenticated_write_maintenance_photos', 'maintenance_photos',
    $$create policy lablink_authenticated_write_maintenance_photos on storage.objects for insert with check (bucket_id = 'maintenance_photos' and auth.role() = 'authenticated')$$
  );
  perform public.ensure_storage_policy(
    'lablink_authenticated_write_chemical_msds', 'chemical_msds',
    $$create policy lablink_authenticated_write_chemical_msds on storage.objects for insert with check (bucket_id = 'chemical_msds' and auth.role() = 'authenticated')$$
  );
  perform public.ensure_storage_policy(
    'lablink_authenticated_write_user_avatars', 'user_avatars',
    $$create policy lablink_authenticated_write_user_avatars on storage.objects for insert with check (bucket_id = 'user_avatars' and auth.role() = 'authenticated')$$
  );
  perform public.ensure_storage_policy(
    'lablink_service_delete', 'qr_codes',
    $$create policy lablink_service_delete on storage.objects for delete using (auth.role() = 'service_role')$$
  );
end;
$$;

-- =====================================================================
-- REALTIME PUBLICATION
-- =====================================================================
alter publication supabase_realtime add table
  public.users,
  public.items,
  public.borrow_requests,
  public.issued_items,
  public.damage_reports,
  public.maintenance_records,
  public.notifications;

commit;
