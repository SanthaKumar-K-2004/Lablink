-- LabLink Phase 1: Core Schema with Historical Tracking & Admin Audit
-- Part 1: Extensions, Enums, Core Tables, and History Tables

begin;

-- =====================================================================
-- EXTENSIONS
-- =====================================================================
create extension if not exists "pgcrypto" with schema public;
create extension if not exists "pgjwt" with schema public;

-- =====================================================================
-- CUSTOM ENUMS
-- =====================================================================
create type if not exists public.user_role as enum ('admin', 'staff', 'student', 'technician');
create type if not exists public.item_status as enum ('available', 'borrowed', 'maintenance', 'damaged', 'retired');
create type if not exists public.request_status as enum ('pending', 'approved', 'rejected', 'issued', 'returned', 'cancelled');
create type if not exists public.user_status as enum ('active', 'inactive', 'suspended');
create type if not exists public.damage_severity as enum ('minor', 'moderate', 'severe');
create type if not exists public.damage_report_status as enum ('pending', 'approved', 'rejected', 'in_progress', 'resolved');
create type if not exists public.item_condition as enum ('good', 'fair', 'poor', 'missing_parts');
create type if not exists public.issued_item_status as enum ('active', 'returned', 'overdue', 'lost', 'damaged_during_use');
create type if not exists public.maintenance_type as enum ('routine', 'repair', 'inspection', 'cleaning', 'parts_replacement');
create type if not exists public.maintenance_status as enum ('assigned', 'in_progress', 'completed', 'on_hold', 'cancelled');
create type if not exists public.safety_level as enum ('low', 'medium', 'high');
create type if not exists public.notification_priority as enum ('low', 'medium', 'high', 'critical');
create type if not exists public.notification_type as enum ('approval', 'reminder', 'alert', 'damage', 'maintenance');
create type if not exists public.audit_status as enum ('success', 'failed', 'attempted', 'system_generated');
create type if not exists public.login_status as enum ('success', 'failed', 'account_locked', 'invalid_credentials', 'mfa_required');
create type if not exists public.inventory_change_type as enum ('borrow', 'return', 'usage', 'damage', 'maintenance', 'import', 'adjustment');
create type if not exists public.cost_type as enum ('purchase', 'repair', 'maintenance', 'replacement');
create type if not exists public.admin_action_type as enum ('user_created', 'user_deleted', 'user_role_changed', 'department_created', 'settings_changed', 'report_generated', 'export_requested', 'bulk_import');

-- =====================================================================
-- HELPER FUNCTIONS
-- =====================================================================
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

-- =====================================================================
-- CORE TABLES
-- =====================================================================

create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete cascade,
  email text not null unique,
  password_hash text not null,
  full_name text,
  role public.user_role not null default 'student',
  department_ids uuid[] not null default array[]::uuid[],
  avatar_url text,
  status public.user_status not null default 'active',
  phone_number text,
  is_email_verified boolean not null default false,
  last_login timestamptz,
  last_password_change timestamptz,
  total_borrows integer not null default 0,
  overdue_items integer not null default 0,
  is_deleted boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  created_by uuid references public.users(id),
  updated_by uuid references public.users(id),
  constraint users_email_not_empty check (email <> '')
);

create index if not exists users_email_idx on public.users (email);
create index if not exists users_role_idx on public.users (role);
create index if not exists users_status_idx on public.users (status);
create index if not exists users_is_deleted_idx on public.users (is_deleted);

create table if not exists public.departments (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  head_user_id uuid references public.users(id) on delete set null,
  contact_email text,
  phone text,
  location text,
  budget_allocated numeric(12, 2) not null default 0 check (budget_allocated >= 0),
  budget_spent numeric(12, 2) not null default 0 check (budget_spent >= 0),
  budget_remaining numeric(12, 2) generated always as (budget_allocated - budget_spent) stored,
  item_count integer not null default 0,
  active boolean not null default true,
  is_deleted boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  created_by uuid references public.users(id),
  updated_by uuid references public.users(id),
  constraint departments_name_not_empty check (name <> '')
);

create index if not exists departments_name_idx on public.departments (name);
create index if not exists departments_active_idx on public.departments (active);
create index if not exists departments_is_deleted_idx on public.departments (is_deleted);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  parent_category_id uuid references public.categories(id) on delete set null,
  icon text,
  color text,
  description text,
  low_stock_threshold integer not null default 5 check (low_stock_threshold >= 0),
  is_deleted boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  created_by uuid references public.users(id)
);

create index if not exists categories_name_idx on public.categories (name);
create index if not exists categories_parent_idx on public.categories (parent_category_id);
create index if not exists categories_is_deleted_idx on public.categories (is_deleted);

create table if not exists public.items (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category_id uuid not null references public.categories(id),
  department_id uuid not null references public.departments(id),
  description text,
  serial_number text unique,
  model_number text,
  brand text,
  image_url text,
  storage_location text,
  supplier_name text,
  supplier_id text,
  purchase_date date,
  purchase_price numeric(12, 2) check (purchase_price >= 0),
  warranty_expiry date,
  status public.item_status not null default 'available',
  total_quantity integer not null default 1 check (total_quantity >= 0),
  borrowed_quantity integer not null default 0 check (borrowed_quantity >= 0),
  damaged_quantity integer not null default 0 check (damaged_quantity >= 0),
  maintenance_quantity integer not null default 0 check (maintenance_quantity >= 0),
  expiry_date date,
  safety_level public.safety_level,
  hazard_type text,
  manual_url text,
  qr_hash text not null unique,
  qr_payload jsonb not null default '{}'::jsonb,
  low_stock_threshold_value integer not null default 5 check (low_stock_threshold_value >= 0),
  available_count integer generated always as (greatest(total_quantity - borrowed_quantity - damaged_quantity - maintenance_quantity, 0)) stored,
  is_low_stock boolean generated always as (available_count < low_stock_threshold_value) stored,
  days_until_expiry integer,
  version_number integer not null default 1,
  is_deleted boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  created_by uuid references public.users(id),
  updated_by uuid references public.users(id),
  constraint items_name_not_empty check (name <> '')
);

create index if not exists items_name_idx on public.items (name);
create index if not exists items_serial_number_idx on public.items (serial_number);
create index if not exists items_category_idx on public.items (category_id);
create index if not exists items_department_idx on public.items (department_id);
create index if not exists items_status_idx on public.items (status);
create index if not exists items_expiry_date_idx on public.items (expiry_date);
create index if not exists items_is_deleted_idx on public.items (is_deleted);

create table if not exists public.borrow_requests (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.items(id) on delete cascade,
  student_id uuid not null references public.users(id) on delete cascade,
  requested_start_date date not null,
  requested_end_date date not null,
  purpose text not null,
  special_requirements text,
  status public.request_status not null default 'pending',
  approved_by uuid references public.users(id),
  approved_date timestamptz,
  rejection_reason text,
  rejection_reason_code text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  created_by uuid not null references public.users(id),
  is_cancelled boolean not null default false,
  constraint borrow_requests_dates_valid check (requested_start_date < requested_end_date)
);

create index if not exists borrow_requests_item_idx on public.borrow_requests (item_id);
create index if not exists borrow_requests_student_idx on public.borrow_requests (student_id);
create index if not exists borrow_requests_status_idx on public.borrow_requests (status);
create index if not exists borrow_requests_created_at_idx on public.borrow_requests (created_at);

create table if not exists public.issued_items (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.items(id) on delete cascade,
  issued_to uuid not null references public.users(id) on delete cascade,
  issued_by uuid not null references public.users(id),
  borrow_request_id uuid references public.borrow_requests(id),
  issued_date timestamptz not null default timezone('utc', now()),
  due_date date not null,
  condition_at_issue public.item_condition not null default 'good',
  condition_notes_at_issue text,
  status public.issued_item_status not null default 'active',
  returned_date timestamptz,
  condition_at_return public.item_condition,
  condition_notes_at_return text,
  return_notes text,
  is_overdue boolean not null default false,
  days_overdue integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists issued_items_item_idx on public.issued_items (item_id);
create index if not exists issued_items_issued_to_idx on public.issued_items (issued_to);
create index if not exists issued_items_status_idx on public.issued_items (status);
create index if not exists issued_items_due_date_idx on public.issued_items (due_date);

create table if not exists public.damage_reports (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.items(id) on delete cascade,
  damage_type text not null,
  severity public.damage_severity not null,
  description text not null,
  photos text[] default array[]::text[],
  reported_by uuid not null references public.users(id),
  reported_date timestamptz not null default timezone('utc', now()),
  status public.damage_report_status not null default 'pending',
  approved_by uuid references public.users(id),
  approved_date timestamptz,
  resolution_date timestamptz,
  resolution_notes text,
  estimated_repair_cost numeric(12, 2) check (estimated_repair_cost >= 0),
  actual_repair_cost numeric(12, 2) check (actual_repair_cost >= 0),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint damage_reports_photos_limit check (array_length(photos, 1) is null or array_length(photos, 1) <= 5)
);

create index if not exists damage_reports_item_idx on public.damage_reports (item_id);
create index if not exists damage_reports_status_idx on public.damage_reports (status);
create index if not exists damage_reports_reported_by_idx on public.damage_reports (reported_by);
create index if not exists damage_reports_reported_date_idx on public.damage_reports (reported_date);

create table if not exists public.maintenance_records (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.items(id) on delete cascade,
  damage_report_id uuid references public.damage_reports(id),
  assigned_to uuid not null references public.users(id),
  assigned_by uuid not null references public.users(id),
  assigned_date timestamptz not null default timezone('utc', now()),
  reason text not null,
  maintenance_type public.maintenance_type not null,
  status public.maintenance_status not null default 'assigned',
  start_date timestamptz,
  completion_date timestamptz,
  estimated_completion date,
  repair_cost numeric(12, 2) check (repair_cost >= 0),
  parts_used text,
  parts_cost numeric(12, 2) check (parts_cost >= 0),
  labor_hours numeric(8, 2) check (labor_hours >= 0),
  repair_notes text,
  photos text[] default array[]::text[],
  quality_check_passed boolean,
  quality_checker_id uuid references public.users(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint maintenance_records_photos_limit check (array_length(photos, 1) is null or array_length(photos, 1) <= 5)
);

create index if not exists maintenance_records_item_idx on public.maintenance_records (item_id);
create index if not exists maintenance_records_assigned_to_idx on public.maintenance_records (assigned_to);
create index if not exists maintenance_records_status_idx on public.maintenance_records (status);
create index if not exists maintenance_records_assigned_date_idx on public.maintenance_records (assigned_date);

create table if not exists public.chemical_usage_logs (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.items(id) on delete cascade,
  quantity_used numeric(12, 4) not null check (quantity_used > 0),
  usage_date timestamptz not null default timezone('utc', now()),
  used_by uuid not null references public.users(id),
  experiment_purpose text not null,
  experiment_id text,
  quantity_remaining numeric(12, 4) not null check (quantity_remaining >= 0),
  storage_temperature numeric(6, 2),
  storage_notes text,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists chemical_usage_logs_item_idx on public.chemical_usage_logs (item_id);
create index if not exists chemical_usage_logs_used_by_idx on public.chemical_usage_logs (used_by);
create index if not exists chemical_usage_logs_usage_date_idx on public.chemical_usage_logs (usage_date);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  type public.notification_type not null,
  title text not null,
  message text not null,
  action_link text,
  action_data jsonb not null default '{}'::jsonb,
  read boolean not null default false,
  read_at timestamptz,
  is_archived boolean not null default false,
  priority public.notification_priority not null default 'medium',
  created_at timestamptz not null default timezone('utc', now()),
  expires_at timestamptz
);

create index if not exists notifications_user_idx on public.notifications (user_id);
create index if not exists notifications_read_idx on public.notifications (read);
create index if not exists notifications_created_at_idx on public.notifications (created_at);
create index if not exists notifications_priority_idx on public.notifications (priority);

-- =====================================================================
-- HISTORY TABLES
-- =====================================================================

create table if not exists public.item_history (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.items(id) on delete cascade,
  version_number integer not null,
  name text not null,
  category_id uuid references public.categories(id),
  department_id uuid references public.departments(id),
  serial_number text,
  model_number text,
  brand text,
  status public.item_status,
  total_quantity integer,
  expiry_date date,
  safety_level public.safety_level,
  hazard_type text,
  storage_location text,
  purchase_price numeric(12, 2),
  warranty_expiry date,
  modified_by uuid references public.users(id),
  modification_reason text,
  modified_at timestamptz not null default timezone('utc', now()),
  constraint item_history_unique_version unique (item_id, version_number)
);

create index if not exists item_history_item_idx on public.item_history (item_id);
create index if not exists item_history_modified_at_idx on public.item_history (modified_at);

create table if not exists public.borrow_history (
  id uuid primary key default gen_random_uuid(),
  borrow_request_id uuid not null references public.borrow_requests(id) on delete cascade,
  student_id uuid not null references public.users(id),
  item_id uuid not null references public.items(id),
  status_change public.request_status not null,
  previous_status text,
  new_status text not null,
  changed_by uuid references public.users(id),
  reason text,
  changed_at timestamptz not null default timezone('utc', now()),
  notes text
);

create index if not exists borrow_history_request_idx on public.borrow_history (borrow_request_id);
create index if not exists borrow_history_changed_at_idx on public.borrow_history (changed_at);

create table if not exists public.user_login_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  login_time timestamptz not null default timezone('utc', now()),
  logout_time timestamptz,
  session_duration_minutes integer,
  ip_address inet,
  user_agent text,
  device_type text,
  login_status public.login_status not null,
  failure_reason text,
  location text
);

create index if not exists user_login_history_user_idx on public.user_login_history (user_id);
create index if not exists user_login_history_login_time_idx on public.user_login_history (login_time);

create table if not exists public.inventory_change_history (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.items(id) on delete cascade,
  change_type public.inventory_change_type not null,
  quantity_before numeric(14, 4) not null,
  quantity_after numeric(14, 4) not null,
  quantity_changed numeric(14, 4) not null,
  reason text,
  related_entity_id uuid,
  changed_by uuid references public.users(id),
  changed_at timestamptz not null default timezone('utc', now()),
  notes text
);

create index if not exists inventory_change_history_item_idx on public.inventory_change_history (item_id);
create index if not exists inventory_change_history_changed_at_idx on public.inventory_change_history (changed_at);
create index if not exists inventory_change_history_type_idx on public.inventory_change_history (change_type);

create table if not exists public.cost_tracking (
  id uuid primary key default gen_random_uuid(),
  department_id uuid not null references public.departments(id) on delete cascade,
  cost_type public.cost_type not null,
  amount numeric(12, 2) not null check (amount >= 0),
  related_item_id uuid references public.items(id),
  related_maintenance_id uuid references public.maintenance_records(id),
  fiscal_year integer not null check (fiscal_year >= 2000),
  recorded_by uuid references public.users(id),
  recorded_at timestamptz not null default timezone('utc', now()),
  notes text
);

create index if not exists cost_tracking_department_idx on public.cost_tracking (department_id);
create index if not exists cost_tracking_fiscal_idx on public.cost_tracking (department_id, fiscal_year);

create table if not exists public.admin_actions_log (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references public.users(id) on delete cascade,
  action_type public.admin_action_type not null,
  description text not null,
  affected_entity_type text,
  affected_entity_ids uuid[] not null default array[]::uuid[],
  old_config jsonb,
  new_config jsonb,
  action_timestamp timestamptz not null default timezone('utc', now()),
  ip_address inet,
  success boolean not null default true,
  error_details text
);

create index if not exists admin_actions_log_admin_idx on public.admin_actions_log (admin_id);
create index if not exists admin_actions_log_timestamp_idx on public.admin_actions_log (action_timestamp);

create table if not exists public.department_history (
  id uuid primary key default gen_random_uuid(),
  department_id uuid not null references public.departments(id) on delete cascade,
  name text not null,
  head_user_id uuid references public.users(id),
  budget_allocated numeric(12, 2),
  budget_spent numeric(12, 2),
  active boolean,
  is_deleted boolean,
  change_summary text,
  changed_by uuid references public.users(id),
  changed_at timestamptz not null default timezone('utc', now())
);

create index if not exists department_history_department_idx on public.department_history (department_id);
create index if not exists department_history_changed_at_idx on public.department_history (changed_at);

-- =====================================================================
-- TRIGGERS FOR UPDATED_AT MANAGEMENT
-- =====================================================================
create trigger trg_users_updated_at before update on public.users for each row execute function public.update_updated_at();
create trigger trg_departments_updated_at before update on public.departments for each row execute function public.update_updated_at();
create trigger trg_categories_updated_at before update on public.categories for each row execute function public.update_updated_at();
create trigger trg_items_updated_at before update on public.items for each row execute function public.update_updated_at();
create trigger trg_borrow_requests_updated_at before update on public.borrow_requests for each row execute function public.update_updated_at();
create trigger trg_issued_items_updated_at before update on public.issued_items for each row execute function public.update_updated_at();
create trigger trg_damage_reports_updated_at before update on public.damage_reports for each row execute function public.update_updated_at();
create trigger trg_maintenance_records_updated_at before update on public.maintenance_records for each row execute function public.update_updated_at();

commit;
