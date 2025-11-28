-- LabLink Phase 1: Row-Level Security (RLS) Policies
-- Complete role-based database access control with auth helper functions

begin;

-- =====================================================================
-- AUTH HELPER FUNCTIONS
-- =====================================================================

-- Get current user's role from JWT
create or replace function public.get_user_role()
returns public.user_role
language plpgsql
stable
set search_path = public
as $$
declare
  v_role public.user_role;
  v_user_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return null;
  end if;

  select role into v_role
  from public.users
  where id = v_user_id
  limit 1;

  return coalesce(v_role, 'student'::public.user_role);
end;
$$;

-- Check if current user is admin
create or replace function public.is_admin()
returns boolean
language plpgsql
stable
set search_path = public
as $$
declare
  v_user_id uuid;
  v_role public.user_role;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return false;
  end if;

  select role into v_role
  from public.users
  where id = v_user_id
  limit 1;

  return v_role = 'admin'::public.user_role;
end;
$$;

-- Check if current user is staff
create or replace function public.is_staff()
returns boolean
language plpgsql
stable
set search_path = public
as $$
declare
  v_user_id uuid;
  v_role public.user_role;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return false;
  end if;

  select role into v_role
  from public.users
  where id = v_user_id
  limit 1;

  return v_role = 'staff'::public.user_role;
end;
$$;

-- Check if current user is student
create or replace function public.is_student()
returns boolean
language plpgsql
stable
set search_path = public
as $$
declare
  v_user_id uuid;
  v_role public.user_role;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return false;
  end if;

  select role into v_role
  from public.users
  where id = v_user_id
  limit 1;

  return v_role = 'student'::public.user_role;
end;
$$;

-- Check if current user is technician
create or replace function public.is_technician()
returns boolean
language plpgsql
stable
set search_path = public
as $$
declare
  v_user_id uuid;
  v_role public.user_role;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return false;
  end if;

  select role into v_role
  from public.users
  where id = v_user_id
  limit 1;

  return v_role = 'technician'::public.user_role;
end;
$$;

-- Check if current user can access department
create or replace function public.can_access_department(dept_id uuid)
returns boolean
language plpgsql
stable
set search_path = public
as $$
declare
  v_user_id uuid;
  v_role public.user_role;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return false;
  end if;

  if public.is_admin() then
    return true;
  end if;

  select role into v_role
  from public.users
  where id = v_user_id
  limit 1;

  if v_role = 'admin'::public.user_role then
    return true;
  end if;

  return exists (
    select 1
    from public.users
    where id = v_user_id
      and dept_id = any(department_ids)
  );
end;
$$;

-- =====================================================================
-- ENABLE RLS ON ALL 11 TABLES
-- =====================================================================

alter table public.users enable row level security;
alter table public.departments enable row level security;
alter table public.categories enable row level security;
alter table public.items enable row level security;
alter table public.borrow_requests enable row level security;
alter table public.issued_items enable row level security;
alter table public.damage_reports enable row level security;
alter table public.maintenance_records enable row level security;
alter table public.chemical_usage_logs enable row level security;
alter table public.notifications enable row level security;
alter table public.audit_logs enable row level security;

-- =====================================================================
-- USERS TABLE POLICIES
-- =====================================================================

-- Admin: Full CRUD
create policy if not exists "users_admin_select"
  on public.users for select
  using (public.is_admin());

create policy if not exists "users_admin_insert"
  on public.users for insert
  with check (public.is_admin());

create policy if not exists "users_admin_update"
  on public.users for update
  using (public.is_admin())
  with check (public.is_admin());

create policy if not exists "users_admin_delete"
  on public.users for delete
  using (public.is_admin());

-- Staff: SELECT own + same department users, UPDATE own profile only
create policy if not exists "users_staff_select_own"
  on public.users for select
  using (
    public.is_staff()
    and (
      auth.uid() = id
      or exists (
        select 1 from public.users u1
        where u1.id = auth.uid()
          and u1.role = 'staff'::public.user_role
          and (
            select array_agg(dept_id) 
            from unnest(u1.department_ids) as dept_id
          ) && department_ids
      )
    )
  );

create policy if not exists "users_staff_update_own"
  on public.users for update
  using (
    public.is_staff() and auth.uid() = id
  )
  with check (
    public.is_staff() and auth.uid() = id
  );

-- Student: SELECT own record only, UPDATE own avatar/name
create policy if not exists "users_student_select_own"
  on public.users for select
  using (
    public.is_student() and auth.uid() = id
  );

create policy if not exists "users_student_update_own"
  on public.users for update
  using (
    public.is_student() and auth.uid() = id
  )
  with check (
    public.is_student() and auth.uid() = id
  );

-- Technician: SELECT own record only, UPDATE own profile
create policy if not exists "users_technician_select_own"
  on public.users for select
  using (
    public.is_technician() and auth.uid() = id
  );

create policy if not exists "users_technician_update_own"
  on public.users for update
  using (
    public.is_technician() and auth.uid() = id
  )
  with check (
    public.is_technician() and auth.uid() = id
  );

-- Auth users always see their own record (override)
create policy if not exists "users_self_access"
  on public.users for select
  using (auth.uid() = id);

-- =====================================================================
-- DEPARTMENTS TABLE POLICIES
-- =====================================================================

-- Admin: SELECT all, INSERT, UPDATE, DELETE
create policy if not exists "departments_admin_select"
  on public.departments for select
  using (public.is_admin());

create policy if not exists "departments_admin_insert"
  on public.departments for insert
  with check (public.is_admin());

create policy if not exists "departments_admin_update"
  on public.departments for update
  using (public.is_admin())
  with check (public.is_admin());

create policy if not exists "departments_admin_delete"
  on public.departments for delete
  using (public.is_admin());

-- Staff: SELECT assigned departments, UPDATE settings
create policy if not exists "departments_staff_select"
  on public.departments for select
  using (
    public.is_staff()
    and public.can_access_department(id)
  );

create policy if not exists "departments_staff_update"
  on public.departments for update
  using (
    public.is_staff()
    and public.can_access_department(id)
  )
  with check (
    public.is_staff()
    and public.can_access_department(id)
  );

-- Student: SELECT own department only
create policy if not exists "departments_student_select"
  on public.departments for select
  using (
    public.is_student()
    and public.can_access_department(id)
  );

-- Technician: SELECT assigned department only
create policy if not exists "departments_technician_select"
  on public.departments for select
  using (
    public.is_technician()
    and public.can_access_department(id)
  );

-- =====================================================================
-- CATEGORIES TABLE POLICIES
-- =====================================================================

-- All authenticated users: SELECT (read-only)
create policy if not exists "categories_authenticated_select"
  on public.categories for select
  using (auth.role() = 'authenticated');

-- Admin: INSERT, UPDATE, DELETE
create policy if not exists "categories_admin_insert"
  on public.categories for insert
  with check (public.is_admin());

create policy if not exists "categories_admin_update"
  on public.categories for update
  using (public.is_admin())
  with check (public.is_admin());

create policy if not exists "categories_admin_delete"
  on public.categories for delete
  using (public.is_admin());

-- =====================================================================
-- ITEMS TABLE POLICIES
-- =====================================================================

-- Admin: SELECT all, INSERT all, UPDATE all, soft DELETE all (via status)
create policy if not exists "items_admin_select"
  on public.items for select
  using (public.is_admin());

create policy if not exists "items_admin_insert"
  on public.items for insert
  with check (public.is_admin());

create policy if not exists "items_admin_update"
  on public.items for update
  using (public.is_admin())
  with check (public.is_admin());

create policy if not exists "items_admin_soft_delete"
  on public.items for delete
  using (
    public.is_admin()
    and status = 'retired'::public.item_status
  );

-- Staff: SELECT own dept items, INSERT/UPDATE own dept items
create policy if not exists "items_staff_select"
  on public.items for select
  using (
    public.is_staff()
    and public.can_access_department(department_id)
  );

create policy if not exists "items_staff_insert"
  on public.items for insert
  with check (
    public.is_staff()
    and public.can_access_department(department_id)
  );

create policy if not exists "items_staff_update"
  on public.items for update
  using (
    public.is_staff()
    and public.can_access_department(department_id)
  )
  with check (
    public.is_staff()
    and public.can_access_department(department_id)
  );

-- Student: SELECT own dept items (read-only)
create policy if not exists "items_student_select"
  on public.items for select
  using (
    public.is_student()
    and public.can_access_department(department_id)
  );

-- Technician: SELECT assigned items during maintenance only
create policy if not exists "items_technician_select"
  on public.items for select
  using (
    public.is_technician()
    and exists (
      select 1 from public.maintenance_records mr
      where mr.item_id = public.items.id
        and mr.assigned_to = auth.uid()
        and mr.status != 'completed'::public.maintenance_status
    )
  );

-- =====================================================================
-- BORROW_REQUESTS TABLE POLICIES
-- =====================================================================

-- Admin: SELECT all, UPDATE all
create policy if not exists "borrow_requests_admin_select"
  on public.borrow_requests for select
  using (public.is_admin());

create policy if not exists "borrow_requests_admin_update"
  on public.borrow_requests for update
  using (public.is_admin())
  with check (public.is_admin());

-- Staff: SELECT own dept requests, UPDATE approval status
create policy if not exists "borrow_requests_staff_select"
  on public.borrow_requests for select
  using (
    public.is_staff()
    and exists (
      select 1 from public.items i
      where i.id = borrow_requests.item_id
        and public.can_access_department(i.department_id)
    )
  );

create policy if not exists "borrow_requests_staff_update"
  on public.borrow_requests for update
  using (
    public.is_staff()
    and exists (
      select 1 from public.items i
      where i.id = borrow_requests.item_id
        and public.can_access_department(i.department_id)
    )
  )
  with check (
    public.is_staff()
    and exists (
      select 1 from public.items i
      where i.id = borrow_requests.item_id
        and public.can_access_department(i.department_id)
    )
  );

-- Student: SELECT own requests, INSERT own, UPDATE own pending only
create policy if not exists "borrow_requests_student_select"
  on public.borrow_requests for select
  using (
    public.is_student()
    and student_id = auth.uid()
  );

create policy if not exists "borrow_requests_student_insert"
  on public.borrow_requests for insert
  with check (
    public.is_student()
    and student_id = auth.uid()
    and exists (
      select 1 from public.items i
      where i.id = item_id
        and i.status != 'retired'::public.item_status
        and i.status != 'damaged'::public.item_status
        and public.can_access_department(i.department_id)
    )
  );

create policy if not exists "borrow_requests_student_update_pending"
  on public.borrow_requests for update
  using (
    public.is_student()
    and student_id = auth.uid()
    and status = 'pending'::public.request_status
  )
  with check (
    public.is_student()
    and student_id = auth.uid()
    and status = 'pending'::public.request_status
  );

-- =====================================================================
-- ISSUED_ITEMS TABLE POLICIES
-- =====================================================================

-- Admin: SELECT all, INSERT all, UPDATE all
create policy if not exists "issued_items_admin_select"
  on public.issued_items for select
  using (public.is_admin());

create policy if not exists "issued_items_admin_insert"
  on public.issued_items for insert
  with check (public.is_admin());

create policy if not exists "issued_items_admin_update"
  on public.issued_items for update
  using (public.is_admin())
  with check (public.is_admin());

-- Staff: SELECT own dept issued, UPDATE status/condition/return
create policy if not exists "issued_items_staff_select"
  on public.issued_items for select
  using (
    public.is_staff()
    and exists (
      select 1 from public.items i
      where i.id = issued_items.item_id
        and public.can_access_department(i.department_id)
    )
  );

create policy if not exists "issued_items_staff_update"
  on public.issued_items for update
  using (
    public.is_staff()
    and exists (
      select 1 from public.items i
      where i.id = issued_items.item_id
        and public.can_access_department(i.department_id)
    )
  )
  with check (
    public.is_staff()
    and exists (
      select 1 from public.items i
      where i.id = issued_items.item_id
        and public.can_access_department(i.department_id)
    )
  );

-- Student: SELECT own issued items (active borrows)
create policy if not exists "issued_items_student_select"
  on public.issued_items for select
  using (
    public.is_student()
    and issued_to = auth.uid()
  );

-- =====================================================================
-- DAMAGE_REPORTS TABLE POLICIES
-- =====================================================================

-- Admin: SELECT all, UPDATE status/approval
create policy if not exists "damage_reports_admin_select"
  on public.damage_reports for select
  using (public.is_admin());

create policy if not exists "damage_reports_admin_update"
  on public.damage_reports for update
  using (public.is_admin())
  with check (public.is_admin());

-- Staff: SELECT own dept reports, INSERT, UPDATE own pre-approval
create policy if not exists "damage_reports_staff_select"
  on public.damage_reports for select
  using (
    public.is_staff()
    and exists (
      select 1 from public.items i
      where i.id = damage_reports.item_id
        and public.can_access_department(i.department_id)
    )
  );

create policy if not exists "damage_reports_staff_insert"
  on public.damage_reports for insert
  with check (
    public.is_staff()
    and exists (
      select 1 from public.items i
      where i.id = item_id
        and public.can_access_department(i.department_id)
    )
  );

create policy if not exists "damage_reports_staff_update_own"
  on public.damage_reports for update
  using (
    public.is_staff()
    and reported_by = auth.uid()
    and status = 'pending'::public.damage_report_status
  )
  with check (
    public.is_staff()
    and reported_by = auth.uid()
    and status = 'pending'::public.damage_report_status
  );

-- Student: SELECT own reports, INSERT for borrowed items
create policy if not exists "damage_reports_student_select"
  on public.damage_reports for select
  using (
    public.is_student()
    and reported_by = auth.uid()
  );

create policy if not exists "damage_reports_student_insert"
  on public.damage_reports for insert
  with check (
    public.is_student()
    and reported_by = auth.uid()
    and exists (
      select 1 from public.issued_items ii
      where ii.item_id = item_id
        and ii.issued_to = auth.uid()
        and ii.status = 'active'::public.issued_item_status
    )
  );

-- =====================================================================
-- MAINTENANCE_RECORDS TABLE POLICIES
-- =====================================================================

-- Admin: SELECT all, INSERT, UPDATE all
create policy if not exists "maintenance_records_admin_select"
  on public.maintenance_records for select
  using (public.is_admin());

create policy if not exists "maintenance_records_admin_insert"
  on public.maintenance_records for insert
  with check (public.is_admin());

create policy if not exists "maintenance_records_admin_update"
  on public.maintenance_records for update
  using (public.is_admin())
  with check (public.is_admin());

-- Staff: SELECT own dept maintenance (read-only)
create policy if not exists "maintenance_records_staff_select"
  on public.maintenance_records for select
  using (
    public.is_staff()
    and exists (
      select 1 from public.items i
      where i.id = maintenance_records.item_id
        and public.can_access_department(i.department_id)
    )
  );

-- Technician: SELECT assigned only, UPDATE status/notes/photos/costs
create policy if not exists "maintenance_records_technician_select"
  on public.maintenance_records for select
  using (
    public.is_technician()
    and assigned_to = auth.uid()
  );

create policy if not exists "maintenance_records_technician_update"
  on public.maintenance_records for update
  using (
    public.is_technician()
    and assigned_to = auth.uid()
  )
  with check (
    public.is_technician()
    and assigned_to = auth.uid()
    and assigned_to = assigned_to
    and assigned_by = assigned_by
  );

-- =====================================================================
-- CHEMICAL_USAGE_LOGS TABLE POLICIES
-- =====================================================================

-- Admin: SELECT all (audit)
create policy if not exists "chemical_usage_logs_admin_select"
  on public.chemical_usage_logs for select
  using (public.is_admin());

-- Staff: SELECT own dept usage
create policy if not exists "chemical_usage_logs_staff_select"
  on public.chemical_usage_logs for select
  using (
    public.is_staff()
    and exists (
      select 1 from public.items i
      where i.id = chemical_usage_logs.item_id
        and public.can_access_department(i.department_id)
    )
  );

-- Student: SELECT/INSERT own usage logs
create policy if not exists "chemical_usage_logs_student_select"
  on public.chemical_usage_logs for select
  using (
    public.is_student()
    and used_by = auth.uid()
  );

create policy if not exists "chemical_usage_logs_student_insert"
  on public.chemical_usage_logs for insert
  with check (
    public.is_student()
    and used_by = auth.uid()
  );

-- =====================================================================
-- NOTIFICATIONS TABLE POLICIES
-- =====================================================================

-- Admin: SELECT all (monitoring)
create policy if not exists "notifications_admin_select"
  on public.notifications for select
  using (public.is_admin());

-- All users: SELECT own notifications
create policy if not exists "notifications_user_select"
  on public.notifications for select
  using (
    auth.role() = 'authenticated'
    and user_id = auth.uid()
  );

-- All users: UPDATE read status (own notifications only)
create policy if not exists "notifications_user_update_read"
  on public.notifications for update
  using (
    auth.role() = 'authenticated'
    and user_id = auth.uid()
  )
  with check (
    auth.role() = 'authenticated'
    and user_id = auth.uid()
  );

-- =====================================================================
-- AUDIT_LOGS TABLE POLICIES
-- =====================================================================

-- Admin: SELECT all with full history
create policy if not exists "audit_logs_admin_select"
  on public.audit_logs for select
  using (public.is_admin());

-- Staff: SELECT own + department actions
create policy if not exists "audit_logs_staff_select"
  on public.audit_logs for select
  using (
    public.is_staff()
    and (
      user_id = auth.uid()
      or exists (
        select 1 from public.users u
        where u.id = auth.uid()
          and (
            select array_agg(dept_id)
            from unnest(u.department_ids) as dept_id
          ) && (
            select array_agg(i.department_id)
            from public.items i
            where i.id = audit_logs.entity_id
              and audit_logs.entity_type = 'items'
            union all
            select array_agg(d.id)
            from public.departments d
            where d.id = audit_logs.entity_id
              and audit_logs.entity_type = 'departments'
          )
      )
    )
  );

-- Student: SELECT own actions only (GDPR)
create policy if not exists "audit_logs_student_select"
  on public.audit_logs for select
  using (
    public.is_student()
    and user_id = auth.uid()
  );

-- Technician: SELECT own actions only
create policy if not exists "audit_logs_technician_select"
  on public.audit_logs for select
  using (
    public.is_technician()
    and user_id = auth.uid()
  );

-- =====================================================================
-- INDEXES FOR POLICY PERFORMANCE
-- =====================================================================

create index if not exists users_department_ids_idx on public.users using gin (department_ids);
create index if not exists items_department_status_idx on public.items (department_id, status);
create index if not exists issued_items_item_issued_to_idx on public.issued_items (item_id, issued_to);
create index if not exists damage_reports_item_reported_by_idx on public.damage_reports (item_id, reported_by);
create index if not exists maintenance_records_item_assigned_to_idx on public.maintenance_records (item_id, assigned_to);
create index if not exists chemical_usage_logs_item_used_by_idx on public.chemical_usage_logs (item_id, used_by);
create index if not exists audit_logs_entity_type_id_idx on public.audit_logs (entity_type, entity_id);

commit;
