# Phase 1: RLS Testing Documentation

## Overview

This document outlines the comprehensive testing strategy for Row-Level Security (RLS) policies in LabLink Phase 1.

## Test Categories

### 1. Happy Paths (Authorized Access)

Tests verify that authorized users can perform their expected operations.

#### 1.1 Admin Operations

**Test**: Admin Full Access
- Admin can SELECT all users, departments, items, requests
- Admin can INSERT new users, departments, items
- Admin can UPDATE any record
- Admin can DELETE (soft-delete via status field)

**Execution**:
```sql
set role authenticated;
set request.jwt.claim.sub = admin_user_id;
select count(*) from public.users;           -- Should succeed
select count(*) from public.items;           -- Should succeed
update public.users set full_name = 'Test'; -- Should succeed
```

**Expected Result**: ✓ All operations succeed without RLS errors

#### 1.2 Staff Department Access

**Test**: Staff Can Manage Own Department
- Staff can SELECT department items
- Staff can INSERT new items to their department
- Staff can UPDATE department items
- Staff can UPDATE own profile

**Execution**:
```sql
set role authenticated;
set request.jwt.claim.sub = staff_user_id;
select count(*) from public.items where department_id = staff_dept_id;
insert into public.items (...) values (...);
update public.items set status = 'available' where department_id = staff_dept_id;
update public.users set full_name = 'Updated' where id = staff_user_id;
```

**Expected Result**: ✓ All operations within department succeed

#### 1.3 Student Borrow Request

**Test**: Student Can Request Items
- Student can SELECT own requests
- Student can INSERT new borrow request
- Student can UPDATE pending requests
- Student can INSERT damage reports for borrowed items

**Execution**:
```sql
set role authenticated;
set request.jwt.claim.sub = student_user_id;
select * from public.borrow_requests where student_id = student_user_id;
insert into public.borrow_requests (item_id, student_id, ...) values (...);
update public.borrow_requests set ... where id = request_id and status = 'pending';
```

**Expected Result**: ✓ Borrow workflow operations succeed

#### 1.4 Technician Maintenance

**Test**: Technician Can Update Assigned Work
- Technician can SELECT assigned maintenance records
- Technician can UPDATE assigned record progress
- Technician cannot reassign or change assignments

**Execution**:
```sql
set role authenticated;
set request.jwt.claim.sub = technician_user_id;
select * from public.maintenance_records where assigned_to = technician_user_id;
update public.maintenance_records 
  set status = 'in_progress', repair_notes = 'Working...' 
  where assigned_to = technician_user_id;
```

**Expected Result**: ✓ Can update progress, cannot change assignments

---

### 2. Sad Paths (Unauthorized Access Blocked)

Tests verify that unauthorized users are denied access.

#### 2.1 Student Cannot Access Admin Functions

**Test**: Student Cannot Create Users
```sql
set role authenticated;
set request.jwt.claim.sub = student_user_id;
insert into public.users (email, password_hash, role) values (...);
-- Expected: RLS policy error (PGRST204 or PGRST401)
```

**Expected Result**: ✗ INSERT blocked by RLS policy

#### 2.2 Staff Cannot Access Other Departments

**Test**: Department Isolation
```sql
set role authenticated;
set request.jwt.claim.sub = staff_dept1_user_id;
select * from public.items where department_id = dept2_id;
-- Expected: No rows returned (0 items)
```

**Expected Result**: ✗ Cannot see dept2 items

#### 2.3 Student Cannot Modify Issued Items

**Test**: Student Cannot Update Issue Date
```sql
set role authenticated;
set request.jwt.claim.sub = student_user_id;
update public.issued_items set issued_date = now() where id = item_id;
-- Expected: RLS policy error
```

**Expected Result**: ✗ UPDATE blocked by RLS policy

#### 2.4 Technician Cannot Update Unassigned Work

**Test**: Technician Assignment Isolation
```sql
set role authenticated;
set request.jwt.claim.sub = technician1_user_id;
update public.maintenance_records 
  set status = 'completed'
  where assigned_to = technician2_user_id;
-- Expected: RLS policy error
```

**Expected Result**: ✗ UPDATE blocked, cannot see other technician's work

#### 2.5 Non-Admin Cannot Approve Requests

**Test**: Approval Authorization
```sql
set role authenticated;
set request.jwt.claim.sub = staff_user_id;
update public.borrow_requests 
  set status = 'approved', approved_by = staff_user_id
  where id = request_id;
-- Expected: RLS policy error or constraint violation
```

**Expected Result**: ✗ UPDATE blocked or validation fails

---

### 3. Cross-Department Isolation

Comprehensive tests for department-based access control.

#### 3.1 Staff Cannot See Other Department Items

**Test**: Department Item Visibility
```sql
-- Setup: Staff in IT Lab, Chemistry Lab has items
set role authenticated;
set request.jwt.claim.sub = staff_it_user_id;

-- Try to see Chemistry Lab items
select count(*) from public.items where department_id = chem_lab_id;
-- Expected: 0 items
```

**Expected Result**: ✓ 0 items visible (department isolation enforced)

#### 3.2 Staff Cannot See Other Department Requests

**Test**: Department Request Visibility
```sql
set role authenticated;
set request.jwt.claim.sub = staff_it_user_id;

-- Try to see Chemistry Lab requests
select count(*) from public.borrow_requests br
  join public.items i on br.item_id = i.id
  where i.department_id = chem_lab_id;
-- Expected: 0 requests
```

**Expected Result**: ✓ 0 requests visible

#### 3.3 Staff Cannot Approve Requests Outside Department

**Test**: Cross-Department Approval Block
```sql
set role authenticated;
set request.jwt.claim.sub = staff_it_user_id;

-- Try to approve Chemistry Lab request
update public.borrow_requests 
  set status = 'approved'
  where id = chem_request_id;
-- Expected: RLS policy error (record not visible)
```

**Expected Result**: ✗ UPDATE blocked (request not visible)

#### 3.4 Students Isolated by Department

**Test**: Student Department Access
```sql
set role authenticated;
set request.jwt.claim.sub = student_it_user_id;

-- Try to access Chemistry Lab items
select count(*) from public.items where department_id = chem_lab_id;
-- Expected: 0 items
```

**Expected Result**: ✓ 0 items (student sees only own department)

---

### 4. Student Isolation Tests

Verify students cannot modify records after submission.

#### 4.1 Student Cannot Modify Approved Requests

**Test**: Approved Request Lock
```sql
set role authenticated;
set request.jwt.claim.sub = student_user_id;

-- Try to modify approved request
update public.borrow_requests 
  set purpose = 'Different purpose'
  where id = approved_request_id;
-- Expected: RLS policy error (status != 'pending')
```

**Expected Result**: ✗ UPDATE blocked (only 'pending' requests updatable)

#### 4.2 Student Cannot Update Issued Items

**Test**: Issued Item Immutability
```sql
set role authenticated;
set request.jwt.claim.sub = student_user_id;

-- Try to update issued item
update public.issued_items 
  set condition_at_issue = 'good'
  where id = issued_item_id;
-- Expected: RLS policy error
```

**Expected Result**: ✗ UPDATE blocked by RLS policy

#### 4.3 Student Cannot Report Damage on Non-Borrowed Items

**Test**: Damage Report Validation
```sql
set role authenticated;
set request.jwt.claim.sub = student_user_id;

-- Try to report damage on item student didn't borrow
insert into public.damage_reports (
  item_id, damage_type, severity, description, reported_by
) values (
  other_student_item_id, 'broken', 'severe', 'Broken', student_user_id
);
-- Expected: RLS policy error (not in issued_items)
```

**Expected Result**: ✗ INSERT blocked (no active issue for item)

---

### 5. Technician Assignment Tests

Verify technician access restrictions.

#### 5.1 Technician Can Only See Assigned Work

**Test**: Technician Visibility
```sql
set role authenticated;
set request.jwt.claim.sub = technician1_user_id;

select count(*) from public.maintenance_records where assigned_to = technician1_user_id;
-- Expected: X records (those assigned to tech1)

select count(*) from public.maintenance_records where assigned_to = technician2_user_id;
-- Expected: 0 records (tech1 cannot see tech2's work)
```

**Expected Result**: ✓ Technician1 sees only own assignments

#### 5.2 Technician Cannot Reassign Work

**Test**: Reassignment Prevention
```sql
set role authenticated;
set request.jwt.claim.sub = technician1_user_id;

-- Try to reassign maintenance record
update public.maintenance_records 
  set assigned_to = technician2_user_id
  where assigned_to = technician1_user_id;
-- Expected: RLS policy error (with check violation)
```

**Expected Result**: ✗ UPDATE blocked (assigned_to = assigned_to check fails)

#### 5.3 Technician Cannot Change Assignment Timestamp

**Test**: Assignment History Protection
```sql
set role authenticated;
set request.jwt.claim.sub = technician1_user_id;

-- Try to backdate assignment
update public.maintenance_records 
  set assigned_date = assigned_date - interval '1 week'
  where assigned_to = technician1_user_id;
-- Expected: Success (no explicit policy prevents this) or audit trail
```

**Expected Result**: ✓ Allow update (audit logs track changes)

---

### 6. Admin Override Tests

Verify admin access bypasses department restrictions.

#### 6.1 Admin Can Access All Departments

**Test**: Admin Cross-Department Access
```sql
set role authenticated;
set request.jwt.claim.sub = admin_user_id;

select count(*) from public.departments;
-- Expected: All departments (2+)

select count(*) from public.items where department_id = any(
  select id from public.departments
);
-- Expected: All items across all departments
```

**Expected Result**: ✓ Admin sees all data

#### 6.2 Admin Can Approve Requests From Any Department

**Test**: Admin Approval Override
```sql
set role authenticated;
set request.jwt.claim.sub = admin_user_id;

update public.borrow_requests 
  set status = 'approved', approved_by = admin_user_id
  where id = any_request_id;
-- Expected: Success
```

**Expected Result**: ✓ UPDATE succeeds (admin access)

#### 6.3 Admin Can Issue Items from Any Department

**Test**: Admin Issuance Override
```sql
set role authenticated;
set request.jwt.claim.sub = admin_user_id;

insert into public.issued_items (
  item_id, issued_to, issued_by, due_date
) values (
  any_item_id, any_student_id, admin_user_id, tomorrow
);
-- Expected: Success
```

**Expected Result**: ✓ INSERT succeeds

---

### 7. Data Leak Prevention Tests

Ensure no role bleeding or unintended data exposure.

#### 7.1 Student Name Leak

**Test**: User Directory Isolation
```sql
set role authenticated;
set request.jwt.claim.sub = student_user_id;

select count(*) from public.users;
-- Expected: 1 (own record)

select full_name from public.users where email != student_email;
-- Expected: Error or 0 rows
```

**Expected Result**: ✓ Cannot enumerate other users

#### 7.2 Department Budget Leak

**Test**: Budget Visibility Control
```sql
set role authenticated;
set request.jwt.claim.sub = student_user_id;

select budget_allocated from public.departments 
  where id = student_dept_id;
-- Expected: May or may not be visible (depends on spec)
```

**Expected Result**: ✓ Budget info appropriately restricted

#### 7.3 Damage Report Confidentiality

**Test**: Damage Report Privacy
```sql
set role authenticated;
set request.jwt.claim.sub = student1_user_id;

-- Try to see damage reports from other students
select * from public.damage_reports where reported_by = student2_user_id;
-- Expected: 0 rows
```

**Expected Result**: ✓ Cannot see other students' reports

---

### 8. Edge Cases

Special scenarios and boundary conditions.

#### 8.1 Maintenance Lock (Item Status = 'maintenance')

**Test**: Cannot Borrow During Maintenance
```sql
set role authenticated;
set request.jwt.claim.sub = student_user_id;

-- Try to borrow item in maintenance
insert into public.borrow_requests (
  item_id, student_id, ...
) values (
  maintenance_status_item_id, student_user_id, ...
);
-- Expected: Success (constraint enforced elsewhere) or RLS block
```

**Expected Result**: ✓ Blocked by status != 'available' check

#### 8.2 Expired Chemicals

**Test**: Cannot Use Expired Items
```sql
set role authenticated;
set request.jwt.claim.sub = student_user_id;

-- Try to log usage of expired chemical
insert into public.chemical_usage_logs (
  item_id, quantity_used, used_by, ...
) values (
  expired_chemical_id, 10.5, student_user_id, ...
);
-- Expected: Success (usage tracked) or blocked
```

**Expected Result**: ✓ Usage logged (audit trail maintained)

#### 8.3 Soft Deletes Visible in Audit

**Test**: Soft Delete Tracking
```sql
set role authenticated;
set request.jwt.claim.sub = admin_user_id;

-- Soft delete item
update public.items set status = 'retired' where id = item_id;

-- Check audit log
select * from public.audit_logs 
  where entity_type = 'items' and entity_id = item_id
  order by timestamp desc limit 1;
-- Expected: status change recorded
```

**Expected Result**: ✓ Soft delete recorded in audit logs

#### 8.4 Date Validation (start < end)

**Test**: Request Date Order
```sql
set role authenticated;
set request.jwt.claim.sub = student_user_id;

-- Try to create request with end before start
insert into public.borrow_requests (
  item_id, student_id, requested_start_date, requested_end_date, purpose, created_by
) values (
  item_id, student_user_id, '2024-12-31', '2024-12-01', 'Test', student_user_id
);
-- Expected: Constraint violation (check constraint)
```

**Expected Result**: ✗ Constraint violation (database level)

#### 8.5 Role Transitions (Admin → Staff)

**Test**: Permission Changes on Role Update
```sql
-- User as admin
set role authenticated;
set request.jwt.claim.sub = transition_user_id;
select count(*) from public.users;  -- Should see all

-- Admin changes user role to staff
set role authenticated;
set request.jwt.claim.sub = admin_user_id;
update public.users set role = 'staff' where id = transition_user_id;

-- User reconnects as staff
set role authenticated;
set request.jwt.claim.sub = transition_user_id;
select count(*) from public.users;  -- Should see fewer now
```

**Expected Result**: ✓ Permission changes apply to new queries

---

### 9. Performance Tests

Verify RLS policies maintain acceptable performance.

#### 9.1 Policy Check Overhead

**Test**: Auth Function Performance
```sql
set role authenticated;
set request.jwt.claim.sub = admin_user_id;

explain analyze select * from public.users limit 10;
-- Look for: execution time < 100ms
```

**Expected Result**: ✓ < 100ms for small result sets

#### 9.2 Department Query Performance

**Test**: Indexed Access Pattern
```sql
set role authenticated;
set request.jwt.claim.sub = staff_user_id;

explain analyze 
  select * from public.items 
  where department_id = staff_dept_id;
-- Look for: uses items_department_status_idx
```

**Expected Result**: ✓ < 50ms with proper indexes

#### 9.3 Audit Log Query Performance

**Test**: Large Audit Scan
```sql
set role authenticated;
set request.jwt.claim.sub = admin_user_id;

explain analyze 
  select * from public.audit_logs 
  where timestamp > now() - interval '1 month';
-- Look for: < 200ms
```

**Expected Result**: ✓ < 200ms for time-range queries

---

## Test Execution

### Prerequisites

1. Fresh database with migrations applied
2. Test users created (see `test_rls.sql`)
3. Sample data in each department
4. PostgreSQL client with Supabase connection

### Manual Testing

```bash
# Connect to database
psql postgresql://user:password@host/database

# Run test script
\i supabase/migrations/test_rls.sql

# Check results
select * from test_results;
```

### Automated Testing (Future)

```bash
# Run with test framework
npm run test:rls

# Or with pytest
pytest tests/test_rls.py
```

---

## Test Results Template

| Test Case | Status | Details | Duration | 
|-----------|--------|---------|----------|
| Admin Full Access | ✓ PASS | All operations succeeded | 5ms |
| Student Isolation | ✓ PASS | Cannot see other dept items | 3ms |
| Technician Assignment | ✓ PASS | Can only update assigned | 4ms |
| Cross-Dept Block | ✓ PASS | Staff cannot access dept2 | 2ms |
| Soft Delete Audit | ✓ PASS | Recorded in audit_logs | 1ms |
| Date Validation | ✓ PASS | Constraint enforced | 0ms |
| Performance | ✓ PASS | All < 100ms | 10ms avg |

---

## Troubleshooting Test Failures

### "RLS Policy Error on SELECT"

**Cause**: User doesn't match any policy `using` conditions
**Debug**: Check `get_user_role()` function, verify user record exists
**Fix**: Ensure user_id is correctly set in JWT context

### "No rows returned"

**Cause**: Policy filters all rows
**Debug**: Verify department_ids array contains expected values
**Fix**: Check `can_access_department()` logic, add test user to department

### "Permission Denied Error"

**Cause**: INSERT/UPDATE/DELETE `with check` conditions failed
**Debug**: Review policy `with check` clause conditions
**Fix**: Ensure new values satisfy `with check` constraints

### "Timeout or Slow Query"

**Cause**: Missing indexes or complex policy subqueries
**Debug**: Run `explain analyze` on the query
**Fix**: Add appropriate indexes (see RLS_POLICIES.md performance section)

---

## Regression Testing

After any RLS policy changes:

1. Run full test suite
2. Verify no unexpected access grants
3. Check performance hasn't degraded
4. Test with production-like data volumes
5. Review audit logs for any policy violations

---

## Sign-Off

- [ ] All happy path tests passing
- [ ] All sad path tests blocking correctly
- [ ] Cross-department isolation verified
- [ ] Performance acceptable (< 100ms)
- [ ] No data leaks detected
- [ ] Security assumptions validated
- [ ] Production deployment approved

---

## Related Documentation

- `RLS_POLICIES.md` - Policy details and architecture
- `SCHEMA.md` - Database schema reference
- `AUDIT_LOGGING.md` - Audit trail implementation
- `TROUBLESHOOTING.md` - Common issues and solutions
