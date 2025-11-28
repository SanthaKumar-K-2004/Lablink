-- LabLink Phase 1: Row-Level Security (RLS) Policies
-- Part 3: RLS Framework, Helper Functions, and Per-Table Policies

begin;

-- =====================================================================
-- RLS HELPER FUNCTIONS
-- =====================================================================

-- Extract user role from JWT metadata
create or replace function public.auth_jwt_metadata()
returns jsonb
language sql
stable
as $$
  select coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), 'student')::text as role;
$$;

-- Helper function to check if current user is admin
create or replace function public.is_admin()
returns boolean
language sql
stable
as $$
  select public.auth_jwt_metadata()->>'role' = 'admin';
$$;

-- Helper function to check if current user is staff
create or replace function public.is_staff()
returns boolean
language sql
stable
as $$
  select public.auth_jwt_metadata()->>'role' = 'staff';
$$;

-- Helper function to check if current user is student
create or replace function public.is_student()
returns boolean
language sql
stable
as $$
  select public.auth_jwt_metadata()->>'role' = 'student';
$$;

-- Helper function to check if current user is technician
create or replace function public.is_technician()
returns boolean
language sql
stable
as $$
  select public.auth_jwt_metadata()->>'role' = 'technician';
$$;

-- Helper function to check if user can access department
create or replace function public.can_access_department(dept_id uuid)
returns boolean
language plpgsql
stable
as $$
declare
  current_user_id uuid;
  user_role public.user_role;
  user_depts uuid[];
begin
  -- Get current user ID and role
  begin
    current_user_id := nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
    user_role := public.auth_jwt_metadata()->>'role'::public.user_role;
  exception when others then
    return false;
  end;

  -- Admin can access all departments
  if user_role = 'admin' then
    return true;
  end if;

  -- Check if user has access to this department
  select department_ids into user_depts 
  from public.users 
  where id = current_user_id;
  
  return dept_id = any(user_depts);
end;
$$;

-- Helper function to get current user's departments
create or replace function public.get_user_departments()
returns uuid[]
language plpgsql
stable
as $$
declare
  current_user_id uuid;
  user_depts uuid[];
begin
  begin
    current_user_id := nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
  exception when others then
    return array[]::uuid[];
  end;

  select department_ids into user_depts 
  from public.users 
  where id = current_user_id;
  
  return coalesce(user_depts, array[]::uuid[]);
end;
$$;

-- =====================================================================
-- ENABLE RLS ON ALL TABLES
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
-- USERS TABLE RLS POLICIES
-- =====================================================================

-- Users can always SELECT their own record
create policy "Users can view own profile" on public.users
  for select using (auth.uid() = id);

-- Admins can SELECT all users
create policy "Admins can view all users" on public.users
  for select using (public.is_admin());

-- Staff can SELECT users in same department
create policy "Staff can view department users" on public.users
  for select using (
    public.is_staff() and 
    (id = any(public.get_user_departments()) or 
     department_ids && public.get_user_departments())
  );

-- Students can only SELECT own profile
create policy "Students can view own profile" on public.users
  for select using (public.is_student() and auth.uid() = id);

-- Technicians can only SELECT own profile
create policy "Technicians can view own profile" on public.users
  for select using (public.is_technician() and auth.uid() = id);

-- Admins can INSERT users
create policy "Admins can insert users" on public.users
  for insert with check (public.is_admin());

-- Users can UPDATE their own profile (limited fields)
create policy "Users can update own profile" on public.users
  for update using (
    auth.uid() = id and
    (public.is_student() or public.is_technician())
  )
  with check (
    auth.uid() = id and
    (public.is_student() or public.is_technician())
  );

-- Staff can UPDATE users in same department
create policy "Staff can update department users" on public.users
  for update using (
    public.is_staff() and 
    (id = any(public.get_user_departments()) or 
     department_ids && public.get_user_departments())
  )
  with check (
    public.is_staff() and 
    (id = any(public.get_user_departments()) or 
     department_ids && public.get_user_departments())
  );

-- Admins can UPDATE all users
create policy "Admins can update users" on public.users
  for update using (public.is_admin())
  with check (public.is_admin());

-- Admins can DELETE users
create policy "Admins can delete users" on public.users
  for delete using (public.is_admin());

-- =====================================================================
-- DEPARTMENTS TABLE RLS POLICIES
-- =====================================================================

-- Users can SELECT departments they're assigned to
create policy "Users can view assigned departments" on public.departments
  for select using (
    public.is_admin() or
    id = any(public.get_user_departments())
  );

-- Admins can INSERT departments
create policy "Admins can insert departments" on public.departments
  for insert with check (public.is_admin());

-- Department heads can UPDATE their own department
create policy "Department heads can update own department" on public.departments
  for update using (
    head_user_id = auth.uid() or public.is_admin()
  )
  with check (
    head_user_id = auth.uid() or public.is_admin()
  );

-- Admins can UPDATE all departments
create policy "Admins can update departments" on public.departments
  for update using (public.is_admin())
  with check (public.is_admin());

-- Admins can DELETE departments
create policy "Admins can delete departments" on public.departments
  for delete using (public.is_admin());

-- =====================================================================
-- CATEGORIES TABLE RLS POLICIES
-- =====================================================================

-- All authenticated users can SELECT categories (read-only reference data)
create policy "All authenticated users can view categories" on public.categories
  for select using (auth.role() = 'authenticated');

-- Admins can INSERT categories
create policy "Admins can insert categories" on public.categories
  for insert with check (public.is_admin());

-- Admins can UPDATE categories
create policy "Admins can update categories" on public.categories
  for update using (public.is_admin())
  with check (public.is_admin());

-- Admins can DELETE categories
create policy "Admins can delete categories" on public.categories
  for delete using (public.is_admin());

-- =====================================================================
-- ITEMS TABLE RLS POLICIES
-- =====================================================================

-- Admins can SELECT all items
create policy "Admins can view all items" on public.items
  for select using (public.is_admin());

-- Staff can SELECT items in their departments
create policy "Staff can view department items" on public.items
  for select using (
    public.is_staff() and 
    public.can_access_department(department_id)
  );

-- Students can SELECT items in their departments (read-only browsing)
create policy "Students can view department items" on public.items
  for select using (
    public.is_student() and 
    public.can_access_department(department_id)
  );

-- Technicians can SELECT items assigned to them during maintenance
create policy "Technicians can view assigned items" on public.items
  for select using (
    public.is_technician() and 
    exists (
      select 1 from public.maintenance_records mr
      where mr.item_id = items.id 
        and mr.assigned_to = auth.uid()
        and mr.status in ('assigned', 'in_progress')
    )
  );

-- Admins can INSERT items
create policy "Admins can insert items" on public.items
  for insert with check (public.is_admin());

-- Staff can INSERT items in their departments
create policy "Staff can insert department items" on public.items
  for insert with check (
    public.is_staff() and 
    public.can_access_department(department_id)
  );

-- Admins can UPDATE all items
create policy "Admins can update items" on public.items
  for update using (public.is_admin())
  with check (public.is_admin());

-- Staff can UPDATE items in their departments (but cannot hard delete)
create policy "Staff can update department items" on public.items
  for update using (
    public.is_staff() and 
    public.can_access_department(department_id)
  )
  with check (
    public.is_staff() and 
    public.can_access_department(department_id) and
    is_deleted = false  -- Prevent staff from deleting items
  );

-- Admins can DELETE (soft delete) items
create policy "Admins can delete items" on public.items
  for delete using (public.is_admin());

-- =====================================================================
-- BORROW_REQUESTS TABLE RLS POLICIES
-- =====================================================================

-- Admins can SELECT all requests
create policy "Admins can view all borrow requests" on public.borrow_requests
  for select using (public.is_admin());

-- Staff can SELECT requests for items in their department
create policy "Staff can view department borrow requests" on public.borrow_requests
  for select using (
    public.is_staff() and 
    exists (
      select 1 from public.items i
      where i.id = borrow_requests.item_id
        and public.can_access_department(i.department_id)
    )
  );

-- Students can SELECT their own requests
create policy "Students can view own borrow requests" on public.borrow_requests
  for select using (public.is_student() and student_id = auth.uid());

-- Students can INSERT their own requests (if item is available)
create policy "Students can insert borrow requests" on public.borrow_requests
  for insert with check (
    public.is_student() and 
    student_id = auth.uid() and
    exists (
      select 1 from public.items i
      where i.id = item_id
        and i.status = 'available'
        and i.available_count > 0
        and (i.expiry_date is null or i.expiry_date > current_date)
        and public.can_access_department(i.department_id)
    ) and
    requested_end_date > requested_start_date
  );

-- Admins can UPDATE all requests
create policy "Admins can update borrow requests" on public.borrow_requests
  for update using (public.is_admin())
  with check (public.is_admin());

-- Staff can UPDATE approval status for department requests
create policy "Staff can update department borrow requests" on public.borrow_requests
  for update using (
    public.is_staff() and 
    exists (
      select 1 from public.items i
      where i.id = borrow_requests.item_id
        and public.can_access_department(i.department_id)
    )
  )
  with check (
    public.is_staff() and 
    exists (
      select 1 from public.items i
      where i.id = item_id
        and public.can_access_department(i.department_id)
    )
  );

-- Students can UPDATE own pending requests only
create policy "Students can update own pending requests" on public.borrow_requests
  for update using (
    public.is_student() and 
    student_id = auth.uid() and 
    status = 'pending'
  )
  with check (
    public.is_student() and 
    student_id = auth.uid() and 
    status = 'pending'
  );

-- =====================================================================
-- ISSUED_ITEMS TABLE RLS POLICIES
-- =====================================================================

-- Admins can SELECT all issued items
create policy "Admins can view all issued items" on public.issued_items
  for select using (public.is_admin());

-- Staff can SELECT issued items in their department
create policy "Staff can view department issued items" on public.issued_items
  for select using (
    public.is_staff() and 
    exists (
      select 1 from public.items i
      where i.id = issued_items.item_id
        and public.can_access_department(i.department_id)
    )
  );

-- Students can SELECT their own issued items
create policy "Students can view own issued items" on public.issued_items
  for select using (public.is_student() and issued_to = auth.uid());

-- Admins can INSERT issued items
create policy "Admins can insert issued items" on public.issued_items
  for insert with check (public.is_admin());

-- Staff can INSERT issued items for their department
create policy "Staff can insert department issued items" on public.issued_items
  for insert with check (
    public.is_staff() and 
    exists (
      select 1 from public.items i
      where i.id = item_id
        and public.can_access_department(i.department_id)
    )
  );

-- Admins can UPDATE all issued items
create policy "Admins can update issued items" on public.issued_items
  for update using (public.is_admin())
  with check (public.is_admin());

-- Staff can UPDATE status/condition/return info for department items
create policy "Staff can update department issued items" on public.issued_items
  for update using (
    public.is_staff() and 
    exists (
      select 1 from public.items i
      where i.id = issued_items.item_id
        and public.can_access_department(i.department_id)
    )
  )
  with check (
    public.is_staff() and 
    exists (
      select 1 from public.items i
      where i.id = item_id
        and public.can_access_department(i.department_id)
    )
  );

-- =====================================================================
-- DAMAGE_REPORTS TABLE RLS POLICIES
-- =====================================================================

-- Admins can SELECT all damage reports
create policy "Admins can view all damage reports" on public.damage_reports
  for select using (public.is_admin());

-- Staff can SELECT damage reports for items in their department
create policy "Staff can view department damage reports" on public.damage_reports
  for select using (
    public.is_staff() and 
    exists (
      select 1 from public.items i
      where i.id = damage_reports.item_id
        and public.can_access_department(i.department_id)
    )
  );

-- Students can SELECT their own damage reports
create policy "Students can view own damage reports" on public.damage_reports
  for select using (public.is_student() and reported_by = auth.uid());

-- Users can see damage reports for items they're responsible for
create policy "Users can view responsible damage reports" on public.damage_reports
  for select using (
    exists (
      select 1 from public.issued_items ii
      where ii.item_id = damage_reports.item_id
        and ii.issued_to = auth.uid()
        and ii.returned_date is null
    )
  );

-- Staff can INSERT damage reports for department items
create policy "Staff can insert damage reports" on public.damage_reports
  for insert with check (
    public.is_staff() and 
    exists (
      select 1 from public.items i
      where i.id = item_id
        and public.can_access_department(i.department_id)
    )
  );

-- Students can INSERT damage reports for borrowed items
create policy "Students can insert damage reports" on public.damage_reports
  for insert with check (
    public.is_student() and 
    reported_by = auth.uid() and
    exists (
      select 1 from public.issued_items ii
      where ii.item_id = damage_reports.item_id
        and ii.issued_to = auth.uid()
        and ii.returned_date is null
    )
  );

-- Admins can UPDATE all damage reports
create policy "Admins can update damage reports" on public.damage_reports
  for update using (public.is_admin())
  with check (public.is_admin());

-- Staff can UPDATE own reports (pre-approval)
create policy "Staff can update own damage reports" on public.damage_reports
  for update using (
    public.is_staff() and 
    reported_by = auth.uid() and
    status in ('pending', 'in_progress')
  )
  with check (
    public.is_staff() and 
    reported_by = auth.uid() and
    status in ('pending', 'in_progress')
  );

-- Students can UPDATE their own reports (pre-approval)
create policy "Students can update own damage reports" on public.damage_reports
  for update using (
    public.is_student() and 
    reported_by = auth.uid() and
    status = 'pending'
  )
  with check (
    public.is_student() and 
    reported_by = auth.uid() and
    status = 'pending'
  );

-- =====================================================================
-- MAINTENANCE_RECORDS TABLE RLS POLICIES
-- =====================================================================

-- Admins can SELECT all maintenance records
create policy "Admins can view all maintenance records" on public.maintenance_records
  for select using (public.is_admin());

-- Staff can SELECT maintenance for department items (read-only)
create policy "Staff can view department maintenance records" on public.maintenance_records
  for select using (
    public.is_staff() and 
    exists (
      select 1 from public.items i
      where i.id = maintenance_records.item_id
        and public.can_access_department(i.department_id)
    )
  );

-- Technicians can SELECT assigned tasks only
create policy "Technicians can view assigned maintenance records" on public.maintenance_records
  for select using (public.is_technician() and assigned_to = auth.uid());

-- Admins can INSERT maintenance records
create policy "Admins can insert maintenance records" on public.maintenance_records
  for insert with check (public.is_admin());

-- Admins can UPDATE all maintenance records
create policy "Admins can update maintenance records" on public.maintenance_records
  for update using (public.is_admin())
  with check (public.is_admin());

-- Technicians can UPDATE status/notes/photos/costs for own assignments
create policy "Technicians can update assigned maintenance records" on public.maintenance_records
  for update using (
    public.is_technician() and 
    assigned_to = auth.uid()
  )
  with check (
    public.is_technician() and 
    assigned_to = auth.uid()
  );

-- =====================================================================
-- CHEMICAL_USAGE_LOGS TABLE RLS POLICIES
-- =====================================================================

-- Admins can SELECT all usage logs (audit)
create policy "Admins can view all chemical usage logs" on public.chemical_usage_logs
  for select using (public.is_admin());

-- Staff can SELECT usage for department items
create policy "Staff can view department chemical usage logs" on public.chemical_usage_logs
  for select using (
    public.is_staff() and 
    exists (
      select 1 from public.items i
      where i.id = chemical_usage_logs.item_id
        and public.can_access_department(i.department_id)
    )
  );

-- Students can SELECT/INSERT usage logs for chemicals they borrowed
create policy "Students can view own chemical usage logs" on public.chemical_usage_logs
  for select using (public.is_student() and used_by = auth.uid());

create policy "Students can insert chemical usage logs" on public.chemical_usage_logs
  for insert with check (
    public.is_student() and 
    used_by = auth.uid() and
    exists (
      select 1 from public.issued_items ii
      where ii.item_id = chemical_usage_logs.item_id
        and ii.issued_to = auth.uid()
    ) and
    quantity_remaining <= (
      select total_quantity from public.items i 
      where i.id = chemical_usage_logs.item_id
    )
  );

-- =====================================================================
-- NOTIFICATIONS TABLE RLS POLICIES
-- =====================================================================

-- All users can SELECT their own notifications
create policy "Users can view own notifications" on public.notifications
  for select using (user_id = auth.uid());

-- Admins can SELECT all notifications (system monitoring)
create policy "Admins can view all notifications" on public.notifications
  for select using (public.is_admin());

-- Users can UPDATE their own notification read status
create policy "Users can update own notifications" on public.notifications
  for update using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Service role can INSERT notifications (bypasses RLS)
-- This is handled by the service role key, not a policy

-- =====================================================================
-- AUDIT_LOGS TABLE RLS POLICIES
-- =====================================================================

-- Admins can SELECT all audit logs with filters
create policy "Admins can view all audit logs" on public.audit_logs
  for select using (public.is_admin());

-- Staff can SELECT own actions + department actions
create policy "Staff can view department audit logs" on public.audit_logs
  for select using (
    public.is_staff() and (
      user_id = auth.uid() or
      user_id in (
        select id from public.users u
        where u.department_ids && public.get_user_departments()
      )
    )
  );

-- Students can SELECT own actions only (limited audit trail for GDPR)
create policy "Students can view own audit logs" on public.audit_logs
  for select using (public.is_student() and user_id = auth.uid());

-- Technicians can SELECT own actions only
create policy "Technicians can view own audit logs" on public.audit_logs
  for select using (public.is_technician() and user_id = auth.uid());

-- No INSERT/UPDATE/DELETE policies - audit_logs is append-only
-- Service role can INSERT (bypasses RLS)

commit;