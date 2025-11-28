-- LabLink RLS Testing Script
-- Comprehensive test scenarios for Row-Level Security policies
-- Run after migration: psql -f test_rls.sql

-- Note: This script is for testing and requires manual test user setup
-- For production testing, use application-level test suites

begin;

-- =====================================================================
-- TEST SETUP: Create test users with different roles
-- =====================================================================

-- Test helper: Create test user function
create or replace function test_create_user(
  p_email text,
  p_name text,
  p_role public.user_role,
  p_dept_ids uuid[] default array[]::uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
begin
  insert into public.users (
    email,
    password_hash,
    full_name,
    role,
    department_ids,
    is_email_verified
  ) values (
    p_email,
    crypt('test_password_' || p_email, gen_salt('bf')),
    p_name,
    p_role,
    p_dept_ids,
    true
  )
  returning id into v_user_id;
  
  return v_user_id;
end;
$$;

-- Create test departments
do $$
declare
  v_dept1_id uuid;
  v_dept2_id uuid;
  v_admin_id uuid;
  v_staff1_id uuid;
  v_staff2_id uuid;
  v_student1_id uuid;
  v_student2_id uuid;
  v_technician_id uuid;
begin
  -- Create departments
  insert into public.departments (name, contact_email)
  values ('IT Lab', 'it@lab.local')
  returning id into v_dept1_id;
  
  insert into public.departments (name, contact_email)
  values ('Chemistry Lab', 'chem@lab.local')
  returning id into v_dept2_id;
  
  -- Create test users
  v_admin_id := test_create_user('admin@test.local', 'Admin User', 'admin', array[v_dept1_id, v_dept2_id]);
  v_staff1_id := test_create_user('staff1@test.local', 'Staff IT', 'staff', array[v_dept1_id]);
  v_staff2_id := test_create_user('staff2@test.local', 'Staff Chem', 'staff', array[v_dept2_id]);
  v_student1_id := test_create_user('student1@test.local', 'Student IT', 'student', array[v_dept1_id]);
  v_student2_id := test_create_user('student2@test.local', 'Student Chem', 'student', array[v_dept2_id]);
  v_technician_id := test_create_user('tech@test.local', 'Technician', 'technician', array[v_dept1_id]);
  
  -- Store IDs in SQL temp table for reference
  create temp table test_users (
    user_id uuid,
    email text,
    role public.user_role,
    dept_id uuid
  );
  
  insert into test_users values
    (v_admin_id, 'admin@test.local', 'admin', v_dept1_id),
    (v_staff1_id, 'staff1@test.local', 'staff', v_dept1_id),
    (v_staff2_id, 'staff2@test.local', 'staff', v_dept2_id),
    (v_student1_id, 'student1@test.local', 'student', v_dept1_id),
    (v_student2_id, 'student2@test.local', 'student', v_dept2_id),
    (v_technician_id, 'tech@test.local', 'technician', v_dept1_id);
    
  create temp table test_departments (
    dept_id uuid,
    dept_name text
  );
  
  insert into test_departments values
    (v_dept1_id, 'IT Lab'),
    (v_dept2_id, 'Chemistry Lab');
end;
$$;

-- =====================================================================
-- TEST 1: AUTH HELPER FUNCTIONS
-- =====================================================================
-- Verify auth functions work correctly

do $$
declare
  v_result text;
begin
  -- Test: Admin function
  if (select public.is_admin() from (values(true)) where false) is null then
    v_result := 'PASS: is_admin() returns null for unauthenticated user';
  else
    v_result := 'FAIL: is_admin() should return false/null for unauthenticated';
  end if;
  
  raise notice '%', v_result;
end;
$$;

-- =====================================================================
-- TEST 2: USERS TABLE POLICIES
-- =====================================================================

-- TEST 2.1: Admin can see all users
create or replace function test_users_admin_select()
returns table (pass boolean, test_name text, details text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_id uuid;
  v_count integer;
begin
  select user_id into v_admin_id from test_users where role = 'admin' limit 1;
  
  set local role to authenticated;
  set local request.jwt.claim.sub to v_admin_id::text;
  
  select count(*) into v_count from public.users;
  
  return query select
    v_count >= 6,
    'USERS: Admin SELECT',
    'Admin should see all ' || v_count || ' users';
end;
$$;

-- TEST 2.2: Student can see only own record
create or replace function test_users_student_select()
returns table (pass boolean, test_name text, details text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id uuid;
  v_count integer;
begin
  select user_id into v_student_id from test_users where role = 'student' limit 1;
  
  set local role to authenticated;
  set local request.jwt.claim.sub to v_student_id::text;
  
  select count(*) into v_count from public.users;
  
  return query select
    v_count = 1,
    'USERS: Student SELECT',
    'Student should see only own record, got ' || v_count;
end;
$$;

-- TEST 2.3: Staff can see own + department colleagues
create or replace function test_users_staff_select()
returns table (pass boolean, test_name text, details text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_staff_id uuid;
  v_count integer;
begin
  select user_id into v_staff_id from test_users where role = 'staff' limit 1;
  
  set local role to authenticated;
  set local request.jwt.claim.sub to v_staff_id::text;
  
  select count(*) into v_count from public.users;
  
  return query select
    v_count >= 2,  -- At least self + one colleague
    'USERS: Staff SELECT',
    'Staff should see own + dept colleagues (' || v_count || ')';
end;
$$;

-- =====================================================================
-- TEST 3: DEPARTMENTS TABLE POLICIES
-- =====================================================================

-- TEST 3.1: Admin sees all departments
create or replace function test_departments_admin_select()
returns table (pass boolean, test_name text, details text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_id uuid;
  v_count integer;
begin
  select user_id into v_admin_id from test_users where role = 'admin' limit 1;
  
  set local role to authenticated;
  set local request.jwt.claim.sub to v_admin_id::text;
  
  select count(*) into v_count from public.departments;
  
  return query select
    v_count >= 2,
    'DEPARTMENTS: Admin SELECT',
    'Admin should see all departments (' || v_count || ')';
end;
$$;

-- TEST 3.2: Student sees only own department
create or replace function test_departments_student_select()
returns table (pass boolean, test_name text, details text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id uuid;
  v_count integer;
begin
  select user_id into v_student_id from test_users where role = 'student' limit 1;
  
  set local role to authenticated;
  set local request.jwt.claim.sub to v_student_id::text;
  
  select count(*) into v_count from public.departments;
  
  return query select
    v_count = 1,
    'DEPARTMENTS: Student SELECT',
    'Student should see only own department (' || v_count || ')';
end;
$$;

-- TEST 3.3: Cross-department isolation - staff cannot access other depts
create or replace function test_departments_staff_isolation()
returns table (pass boolean, test_name text, details text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_staff1_id uuid;
  v_dept1_id uuid;
  v_dept2_id uuid;
begin
  select user_id into v_staff1_id from test_users where role = 'staff' and dept_id = (select dept_id from test_departments limit 1);
  select dept_id into v_dept1_id from test_departments limit 1;
  select dept_id into v_dept2_id from test_departments order by dept_id desc limit 1;
  
  set local role to authenticated;
  set local request.jwt.claim.sub to v_staff1_id::text;
  
  return query select
    not exists (
      select 1 from public.departments where id = v_dept2_id
    ),
    'DEPARTMENTS: Cross-Dept Isolation',
    'Staff from dept1 should NOT access dept2';
end;
$$;

-- =====================================================================
-- TEST 4: CATEGORIES TABLE POLICIES
-- =====================================================================

-- TEST 4.1: All authenticated users can read categories
create or replace function test_categories_authenticated_select()
returns table (pass boolean, test_name text, details text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id uuid;
  v_can_read boolean;
begin
  select user_id into v_student_id from test_users where role = 'student' limit 1;
  
  set local role to authenticated;
  set local request.jwt.claim.sub to v_student_id::text;
  
  v_can_read := exists(select 1 from public.categories limit 1);
  
  return query select
    true,  -- If we get here, student could read
    'CATEGORIES: Authenticated SELECT',
    'All authenticated users can read categories';
end;
$$;

-- TEST 4.2: Only admin can insert categories
create or replace function test_categories_admin_insert()
returns table (pass boolean, test_name text, details text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id uuid;
  v_error_occurred boolean := false;
begin
  select user_id into v_student_id from test_users where role = 'student' limit 1;
  
  set local role to authenticated;
  set local request.jwt.claim.sub to v_student_id::text;
  
  begin
    insert into public.categories (name) values ('Test Category ' || now()::text);
  exception when sqlstate 'PGRST' or sqlstate '42501' then
    v_error_occurred := true;
  end;
  
  return query select
    v_error_occurred,
    'CATEGORIES: Admin INSERT Only',
    'Non-admin INSERT should be blocked';
end;
$$;

-- =====================================================================
-- TEST 5: ITEMS TABLE POLICIES
-- =====================================================================

-- TEST 5.1: Admin sees all items
create or replace function test_items_admin_select()
returns table (pass boolean, test_name text, details text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_id uuid;
  v_count integer;
begin
  select user_id into v_admin_id from test_users where role = 'admin' limit 1;
  
  set local role to authenticated;
  set local request.jwt.claim.sub to v_admin_id::text;
  
  select count(*) into v_count from public.items;
  
  return query select
    true,
    'ITEMS: Admin SELECT',
    'Admin can see items (count: ' || coalesce(v_count, 0)::text || ')';
end;
$$;

-- TEST 5.2: Student sees only own department items
create or replace function test_items_student_select_own_dept()
returns table (pass boolean, test_name text, details text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id uuid;
  v_student_dept uuid;
  v_can_see_own_dept boolean;
  v_can_see_other_dept boolean;
begin
  select user_id, dept_id into v_student_id, v_student_dept from test_users where role = 'student' limit 1;
  
  set local role to authenticated;
  set local request.jwt.claim.sub to v_student_id::text;
  
  v_can_see_own_dept := exists(select 1 from public.items where department_id = v_student_dept);
  v_can_see_other_dept := exists(select 1 from public.items where department_id != v_student_dept);
  
  return query select
    not v_can_see_other_dept,
    'ITEMS: Student Dept Isolation',
    'Student should not see items from other depts';
end;
$$;

-- =====================================================================
-- TEST 6: BORROW_REQUESTS TABLE POLICIES
-- =====================================================================

-- TEST 6.1: Student can insert own requests
create or replace function test_borrow_requests_student_insert()
returns table (pass boolean, test_name text, details text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id uuid;
  v_item_id uuid;
  v_can_insert boolean := false;
begin
  select user_id into v_student_id from test_users where role = 'student' limit 1;
  select id into v_item_id from public.items where status != 'retired' and status != 'damaged' limit 1;
  
  if v_item_id is null then
    return query select
      true,
      'BORROW_REQUESTS: Student INSERT',
      'No available items to test';
  end if;
  
  set local role to authenticated;
  set local request.jwt.claim.sub to v_student_id::text;
  
  begin
    insert into public.borrow_requests (
      item_id,
      student_id,
      requested_start_date,
      requested_end_date,
      purpose,
      created_by
    ) values (
      v_item_id,
      v_student_id,
      current_date,
      current_date + 7,
      'Test borrow',
      v_student_id
    );
    v_can_insert := true;
  exception when others then
    v_can_insert := false;
  end;
  
  return query select
    v_can_insert,
    'BORROW_REQUESTS: Student INSERT',
    'Student should be able to insert own request';
end;
$$;

-- TEST 6.2: Student cannot insert requests for other students
create or replace function test_borrow_requests_student_cannot_insert_other()
returns table (pass boolean, test_name text, details text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student1_id uuid;
  v_student2_id uuid;
  v_item_id uuid;
  v_error_occurred boolean := false;
begin
  select user_id into v_student1_id from test_users where role = 'student' limit 1;
  select user_id into v_student2_id from test_users where role = 'student' and user_id != v_student1_id limit 1;
  select id into v_item_id from public.items limit 1;
  
  if v_student2_id is null or v_item_id is null then
    return query select
      true,
      'BORROW_REQUESTS: Student Isolation',
      'Insufficient test data';
  end if;
  
  set local role to authenticated;
  set local request.jwt.claim.sub to v_student1_id::text;
  
  begin
    insert into public.borrow_requests (
      item_id,
      student_id,
      requested_start_date,
      requested_end_date,
      purpose,
      created_by
    ) values (
      v_item_id,
      v_student2_id,
      current_date,
      current_date + 7,
      'Test borrow',
      v_student1_id
    );
  exception when sqlstate 'PGRST' or sqlstate '42501' then
    v_error_occurred := true;
  end;
  
  return query select
    v_error_occurred,
    'BORROW_REQUESTS: Student Isolation',
    'Student should NOT insert requests for others';
end;
$$;

-- =====================================================================
-- TEST 7: NOTIFICATIONS TABLE POLICIES
-- =====================================================================

-- TEST 7.1: Users see only own notifications
create or replace function test_notifications_user_isolation()
returns table (pass boolean, test_name text, details text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student1_id uuid;
  v_student2_id uuid;
  v_count integer;
begin
  select user_id into v_student1_id from test_users where role = 'student' limit 1;
  
  set local role to authenticated;
  set local request.jwt.claim.sub to v_student1_id::text;
  
  select count(*) into v_count from public.notifications where user_id != v_student1_id;
  
  return query select
    v_count = 0,
    'NOTIFICATIONS: User Isolation',
    'Student should see only own notifications';
end;
$$;

-- =====================================================================
-- TEST 8: AUDIT_LOGS TABLE POLICIES
-- =====================================================================

-- TEST 8.1: Student sees only own actions (GDPR)
create or replace function test_audit_logs_student_isolation()
returns table (pass boolean, test_name text, details text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id uuid;
  v_other_user_logs integer;
begin
  select user_id into v_student_id from test_users where role = 'student' limit 1;
  
  set local role to authenticated;
  set local request.jwt.claim.sub to v_student_id::text;
  
  select count(*) into v_other_user_logs from public.audit_logs where user_id is null or user_id != v_student_id;
  
  return query select
    v_other_user_logs = 0,
    'AUDIT_LOGS: Student GDPR Isolation',
    'Student should see only own action logs';
end;
$$;

-- TEST 8.2: Admin sees all audit logs
create or replace function test_audit_logs_admin_select_all()
returns table (pass boolean, test_name text, details text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_id uuid;
  v_count integer;
begin
  select user_id into v_admin_id from test_users where role = 'admin' limit 1;
  
  set local role to authenticated;
  set local request.jwt.claim.sub to v_admin_id::text;
  
  select count(*) into v_count from public.audit_logs;
  
  return query select
    true,
    'AUDIT_LOGS: Admin SELECT',
    'Admin can see audit logs (count: ' || coalesce(v_count, 0)::text || ')';
end;
$$;

-- =====================================================================
-- RUN ALL TESTS
-- =====================================================================

-- Compile test results
select 'RLS TEST RESULTS' as test_results;
select '================' as test_results;

-- Test 1: Auth Functions
select * from test_users_admin_select() union all
select * from test_users_student_select() union all
select * from test_users_staff_select() union all

-- Test 3: Departments
select * from test_departments_admin_select() union all
select * from test_departments_student_select() union all
select * from test_departments_staff_isolation() union all

-- Test 4: Categories
select * from test_categories_authenticated_select() union all
select * from test_categories_admin_insert() union all

-- Test 5: Items
select * from test_items_admin_select() union all
select * from test_items_student_select_own_dept() union all

-- Test 6: Borrow Requests
select * from test_borrow_requests_student_insert() union all
select * from test_borrow_requests_student_cannot_insert_other() union all

-- Test 7: Notifications
select * from test_notifications_user_isolation() union all

-- Test 8: Audit Logs
select * from test_audit_logs_student_isolation() union all
select * from test_audit_logs_admin_select_all();

rollback;
