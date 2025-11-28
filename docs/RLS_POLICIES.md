# Row-Level Security (RLS) Policies Documentation

## Overview

This document describes the comprehensive Row-Level Security implementation for the LabLink system. RLS provides database-level access control ensuring that users can only access data appropriate to their role and department.

## Architecture

### Authentication Flow

1. **Auth Functions** - Helper functions that check user roles and permissions
2. **RLS Policies** - Database-level rules that enforce access control
3. **Department Isolation** - Staff/students can only access their own departments
4. **Audit Logging** - All access is logged for compliance

### Security Levels

- **Admin**: Full system access
- **Staff**: Department-scoped access
- **Student**: Own record + department items
- **Technician**: Assignment-based access

## Auth Helper Functions

All auth helpers are located in `public` schema and use stable query functions for performance.

### `get_user_role()` → `public.user_role`

Returns the current user's role from the `users` table.

```sql
select public.get_user_role();  -- Returns: 'admin', 'staff', 'student', or 'technician'
```

**Usage**: Core helper for all role checks

### `is_admin()` → boolean

Checks if current user has admin role.

```sql
select public.is_admin();  -- Returns: true/false
```

**Use Cases**:
- System configuration changes
- User management
- Report generation
- Cross-department access

### `is_staff()` → boolean

Checks if current user has staff role.

```sql
select public.is_staff();  -- Returns: true/false
```

**Use Cases**:
- Department item management
- Request approval
- Maintenance assignment
- Return processing

### `is_student()` → boolean

Checks if current user has student role.

```sql
select public.is_student();  -- Returns: true/false
```

**Use Cases**:
- Borrow requests
- Damage reporting
- Chemical usage logging
- Personal notifications

### `is_technician()` → boolean

Checks if current user has technician role.

```sql
select public.is_technician();  -- Returns: true/false
```

**Use Cases**:
- Maintenance assignment work
- Equipment condition tracking
- Repair completion

### `can_access_department(dept_id uuid)` → boolean

Checks if current user can access a specific department. Admins always return true.

```sql
select public.can_access_department('550e8400-e29b-41d4-a716-446655440000'::uuid);
```

**Access Logic**:
- Admins: Always true
- Others: Check if `dept_id` is in user's `department_ids` array

## Per-Table RLS Policies

### USERS Table

**Purpose**: User account management and profile access

#### Policies

| Role | SELECT | INSERT | UPDATE | DELETE |
|------|--------|--------|--------|--------|
| Admin | ✓ All | ✓ All | ✓ All | ✓ All |
| Staff | ✓ Own + Dept | ✗ | ✓ Own Profile | ✗ |
| Student | ✓ Own | ✗ | ✓ Own Profile | ✗ |
| Technician | ✓ Own | ✗ | ✓ Own Profile | ✗ |

#### Policy Details

**`users_admin_select`**: Admins see all users
```sql
using (public.is_admin());
```

**`users_admin_insert`**: Admins create new users
```sql
with check (public.is_admin());
```

**`users_admin_update`**: Admins modify any user
```sql
using (public.is_admin()) with check (public.is_admin());
```

**`users_admin_delete`**: Admins delete users
```sql
using (public.is_admin());
```

**`users_staff_select_own`**: Staff see own record + department colleagues
```sql
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
```

**`users_staff_update_own`**: Staff modify own profile only
```sql
using (public.is_staff() and auth.uid() = id)
with check (public.is_staff() and auth.uid() = id);
```

**`users_student_select_own`**: Students see own record only
```sql
using (public.is_student() and auth.uid() = id);
```

**`users_student_update_own`**: Students update own profile
```sql
using (public.is_student() and auth.uid() = id)
with check (public.is_student() and auth.uid() = id);
```

**`users_technician_select_own`**: Technicians see own record only
```sql
using (public.is_technician() and auth.uid() = id);
```

**`users_technician_update_own`**: Technicians update own profile
```sql
using (public.is_technician() and auth.uid() = id)
with check (public.is_technician() and auth.uid() = id);
```

**`users_self_access`**: All auth users see themselves (override policy)
```sql
using (auth.uid() = id);
```

---

### DEPARTMENTS Table

**Purpose**: Department management and budget tracking

#### Policies

| Role | SELECT | INSERT | UPDATE | DELETE |
|------|--------|--------|--------|--------|
| Admin | ✓ All | ✓ | ✓ | ✓ |
| Staff | ✓ Assigned | ✗ | ✓ Assigned | ✗ |
| Student | ✓ Own | ✗ | ✗ | ✗ |
| Technician | ✓ Assigned | ✗ | ✗ | ✗ |

#### Policy Details

**`departments_admin_*`**: Admins have full CRUD access
```sql
using (public.is_admin()); / with check (public.is_admin());
```

**`departments_staff_select`**: Staff see assigned departments
```sql
using (public.is_staff() and public.can_access_department(id));
```

**`departments_staff_update`**: Staff update department settings
```sql
using (public.is_staff() and public.can_access_department(id))
with check (public.is_staff() and public.can_access_department(id));
```

**`departments_student_select`**: Students see own department
```sql
using (public.is_student() and public.can_access_department(id));
```

**`departments_technician_select`**: Technicians see assigned departments
```sql
using (public.is_technician() and public.can_access_department(id));
```

**Rationale**: Department isolation prevents cross-department data access

---

### CATEGORIES Table

**Purpose**: Item categorization (reference data)

#### Policies

| Role | SELECT | INSERT | UPDATE | DELETE |
|------|--------|--------|--------|--------|
| Admin | ✓ | ✓ | ✓ | ✓ |
| Staff | ✓ | ✗ | ✗ | ✗ |
| Student | ✓ | ✗ | ✗ | ✗ |
| Technician | ✓ | ✗ | ✗ | ✗ |

#### Policy Details

**`categories_authenticated_select`**: All authenticated users see categories
```sql
using (auth.role() = 'authenticated');
```

**`categories_admin_*`**: Admins manage categories
```sql
using (public.is_admin()); / with check (public.is_admin());
```

**Rationale**: Categories are public reference data, managed by admins

---

### ITEMS Table

**Purpose**: Inventory management (core entity)

#### Policies

| Role | SELECT | INSERT | UPDATE | DELETE |
|------|--------|--------|--------|--------|
| Admin | ✓ All | ✓ | ✓ | ✓ Retired |
| Staff | ✓ Dept | ✓ Dept | ✓ Dept | ✗ |
| Student | ✓ Dept | ✗ | ✗ | ✗ |
| Technician | ✓ Active Maintenance | ✗ | ✗ | ✗ |

#### Policy Details

**`items_admin_select`**: Admins see all items
```sql
using (public.is_admin());
```

**`items_admin_insert`**: Admins create items
```sql
with check (public.is_admin());
```

**`items_admin_update`**: Admins modify items
```sql
using (public.is_admin()) with check (public.is_admin());
```

**`items_admin_soft_delete`**: Admins soft-delete via status='retired'
```sql
using (public.is_admin() and status = 'retired'::public.item_status);
```

**`items_staff_select`**: Staff see department items
```sql
using (public.is_staff() and public.can_access_department(department_id));
```

**`items_staff_insert`**: Staff add items to their department
```sql
with check (public.is_staff() and public.can_access_department(department_id));
```

**`items_staff_update`**: Staff modify department items
```sql
using (public.is_staff() and public.can_access_department(department_id))
with check (public.is_staff() and public.can_access_department(department_id));
```

**`items_student_select`**: Students see department items (read-only)
```sql
using (public.is_student() and public.can_access_department(department_id));
```

**`items_technician_select`**: Technicians see assigned maintenance items only
```sql
using (
  public.is_technician()
  and exists (
    select 1 from public.maintenance_records mr
    where mr.item_id = public.items.id
      and mr.assigned_to = auth.uid()
      and mr.status != 'completed'::public.maintenance_status
  )
);
```

**Rationale**: 
- Soft deletes via status flag (hard deletes prevented)
- Maintenance window blocks borrows
- Technician sees only active assignments

---

### BORROW_REQUESTS Table

**Purpose**: Item checkout workflow

#### Policies

| Role | SELECT | INSERT | UPDATE | DELETE |
|------|--------|--------|--------|--------|
| Admin | ✓ All | ✓ | ✓ | ✗ |
| Staff | ✓ Dept | ✗ | ✓ Approve | ✗ |
| Student | ✓ Own | ✓ Own | ✓ Pending | ✗ |
| Technician | ✗ | ✗ | ✗ | ✗ |

#### Policy Details

**`borrow_requests_admin_*`**: Admins have full access
```sql
using (public.is_admin()); / with check (public.is_admin());
```

**`borrow_requests_staff_select`**: Staff see department requests
```sql
using (
  public.is_staff()
  and exists (
    select 1 from public.items i
    where i.id = borrow_requests.item_id
      and public.can_access_department(i.department_id)
  )
);
```

**`borrow_requests_staff_update`**: Staff approve/reject requests
```sql
using (... exists department check ...)
with check (... exists department check ...);
```

**`borrow_requests_student_select`**: Students see own requests
```sql
using (public.is_student() and student_id = auth.uid());
```

**`borrow_requests_student_insert`**: Students create requests for available items
```sql
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
```

**`borrow_requests_student_update_pending`**: Students modify own pending requests
```sql
using (public.is_student() and student_id = auth.uid() and status = 'pending'::public.request_status)
with check (public.is_student() and student_id = auth.uid() and status = 'pending'::public.request_status);
```

**Rationale**:
- Date validation enforced at schema level (check constraint)
- Blocks requests for expired/damaged items
- Students can only modify pending requests

---

### ISSUED_ITEMS Table

**Purpose**: Active item checkouts and returns

#### Policies

| Role | SELECT | INSERT | UPDATE | DELETE |
|------|--------|--------|--------|--------|
| Admin | ✓ All | ✓ | ✓ | ✗ |
| Staff | ✓ Dept | ✓ | ✓ | ✗ |
| Student | ✓ Own | ✗ | ✗ | ✗ |
| Technician | ✗ | ✗ | ✗ | ✗ |

#### Policy Details

**`issued_items_admin_*`**: Admins have full access
```sql
using (public.is_admin()); / with check (public.is_admin());
```

**`issued_items_staff_select`**: Staff see department issued items
```sql
using (
  public.is_staff()
  and exists (
    select 1 from public.items i
    where i.id = issued_items.item_id
      and public.can_access_department(i.department_id)
  )
);
```

**`issued_items_staff_update`**: Staff track returns and conditions
```sql
using (... exists department check ...)
with check (... exists department check ...);
```

**`issued_items_student_select`**: Students see own borrowed items
```sql
using (public.is_student() and issued_to = auth.uid());
```

**Rationale**:
- Staff processes returns with condition tracking
- Students cannot modify issued items (prevents fraud)
- Condition_at_return and return_date tracked for auditing

---

### DAMAGE_REPORTS Table

**Purpose**: Damage tracking and liability

#### Policies

| Role | SELECT | INSERT | UPDATE | DELETE |
|------|--------|--------|--------|--------|
| Admin | ✓ All | ✓ | ✓ | ✗ |
| Staff | ✓ Dept | ✓ | ✓ Own Pending | ✗ |
| Student | ✓ Own | ✓ Own | ✗ | ✗ |
| Technician | ✗ | ✗ | ✗ | ✗ |

#### Policy Details

**`damage_reports_admin_*`**: Admins have full access
```sql
using (public.is_admin()); / with check (public.is_admin());
```

**`damage_reports_staff_select`**: Staff see department damage reports
```sql
using (
  public.is_staff()
  and exists (
    select 1 from public.items i
    where i.id = damage_reports.item_id
      and public.can_access_department(i.department_id)
  )
);
```

**`damage_reports_staff_insert`**: Staff report damage
```sql
with check (
  public.is_staff()
  and exists (
    select 1 from public.items i
    where i.id = item_id
      and public.can_access_department(i.department_id)
  )
);
```

**`damage_reports_staff_update_own`**: Staff edit own pre-approval reports
```sql
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
```

**`damage_reports_student_select`**: Students see own reports
```sql
using (public.is_student() and reported_by = auth.uid());
```

**`damage_reports_student_insert`**: Students report damage on borrowed items
```sql
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
```

**Rationale**:
- Only admins can approve/reject
- Users see reports for their items only
- Prevents unauthorized damage claims

---

### MAINTENANCE_RECORDS Table

**Purpose**: Equipment maintenance workflow

#### Policies

| Role | SELECT | INSERT | UPDATE | DELETE |
|------|--------|--------|--------|--------|
| Admin | ✓ All | ✓ | ✓ | ✗ |
| Staff | ✓ Dept | ✗ | ✗ | ✗ |
| Student | ✗ | ✗ | ✗ | ✗ |
| Technician | ✓ Assigned | ✗ | ✓ Assigned | ✗ |

#### Policy Details

**`maintenance_records_admin_*`**: Admins have full access
```sql
using (public.is_admin()); / with check (public.is_admin());
```

**`maintenance_records_staff_select`**: Staff see department maintenance (read-only)
```sql
using (
  public.is_staff()
  and exists (
    select 1 from public.items i
    where i.id = maintenance_records.item_id
      and public.can_access_department(i.department_id)
  )
);
```

**`maintenance_records_technician_select`**: Technicians see assigned work
```sql
using (public.is_technician() and assigned_to = auth.uid());
```

**`maintenance_records_technician_update`**: Technicians update progress/notes/photos
```sql
using (public.is_technician() and assigned_to = auth.uid())
with check (
  public.is_technician()
  and assigned_to = auth.uid()
  and assigned_to = assigned_to  -- Cannot reassign
  and assigned_by = assigned_by  -- Cannot change assignments
);
```

**Rationale**:
- Technician restricted to assigned records only
- Technician cannot reassign or change assignments
- Status/notes/photos/costs can be updated
- Prevents unauthorized work reassignment

---

### CHEMICAL_USAGE_LOGS Table

**Purpose**: Chemical inventory and experiment tracking

#### Policies

| Role | SELECT | INSERT | UPDATE | DELETE |
|------|--------|--------|--------|--------|
| Admin | ✓ All | ✗ | ✗ | ✗ |
| Staff | ✓ Dept | ✗ | ✗ | ✗ |
| Student | ✓ Own | ✓ Own | ✗ | ✗ |
| Technician | ✗ | ✗ | ✗ | ✗ |

#### Policy Details

**`chemical_usage_logs_admin_select`**: Admins audit all usage
```sql
using (public.is_admin());
```

**`chemical_usage_logs_staff_select`**: Staff see department usage
```sql
using (
  public.is_staff()
  and exists (
    select 1 from public.items i
    where i.id = chemical_usage_logs.item_id
      and public.can_access_department(i.department_id)
  )
);
```

**`chemical_usage_logs_student_select`**: Students see own usage
```sql
using (public.is_student() and used_by = auth.uid());
```

**`chemical_usage_logs_student_insert`**: Students log chemical usage
```sql
with check (public.is_student() and used_by = auth.uid());
```

**Rationale**:
- Append-only (no UPDATE/DELETE)
- Usage validated against quantity_remaining
- Auto-logged after return with condition check
- Supports GDPR data subject access requests

---

### NOTIFICATIONS Table

**Purpose**: User notifications (alerts, approvals, reminders)

#### Policies

| Role | SELECT | INSERT | UPDATE | DELETE |
|------|--------|--------|--------|--------|
| Admin | ✓ All | ✗ | ✗ | ✗ |
| Staff | ✓ Own | ✗ | ✓ Read Status | ✗ |
| Student | ✓ Own | ✗ | ✓ Read Status | ✗ |
| Technician | ✓ Own | ✗ | ✓ Read Status | ✗ |

#### Policy Details

**`notifications_admin_select`**: Admins monitor all notifications
```sql
using (public.is_admin());
```

**`notifications_user_select`**: All users see own notifications
```sql
using (auth.role() = 'authenticated' and user_id = auth.uid());
```

**`notifications_user_update_read`**: Users mark notifications as read
```sql
using (auth.role() = 'authenticated' and user_id = auth.uid())
with check (auth.role() = 'authenticated' and user_id = auth.uid());
```

**Service Role INSERTs**: System (service role) creates notifications
- Service role bypasses RLS - no policy needed
- Used for approval notifications, reminders, alerts
- Only service role can INSERT

**Rationale**:
- System (edge functions) INSERTs notifications via service role
- No UPDATE/DELETE from regular users (immutable)
- Users only update read status
- Prevents notification tampering

---

### AUDIT_LOGS Table

**Purpose**: Compliance and forensics (append-only)

#### Policies

| Role | SELECT | INSERT | UPDATE | DELETE |
|------|--------|--------|--------|--------|
| Admin | ✓ All | ✗ | ✗ | ✗ |
| Staff | ✓ Own + Dept | ✗ | ✗ | ✗ |
| Student | ✓ Own | ✗ | ✗ | ✗ |
| Technician | ✓ Own | ✗ | ✗ | ✗ |

#### Policy Details

**`audit_logs_admin_select`**: Admins see full audit trail
```sql
using (public.is_admin());
```

**`audit_logs_staff_select`**: Staff see own + department actions
```sql
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
```

**`audit_logs_student_select`**: Students see own actions (GDPR SAR)
```sql
using (public.is_student() and user_id = auth.uid());
```

**`audit_logs_technician_select`**: Technicians see own actions
```sql
using (public.is_technician() and user_id = auth.uid());
```

**No UPDATE/DELETE**: Audit logs are immutable
- Service role INSERT only (no client access)
- No UPDATE/DELETE from any role
- 7-year retention policy enforced

**Rationale**:
- Compliance with data retention regulations
- GDPR subject access request support (students can access own logs)
- Prevent audit trail tampering
- Forensic investigation capability

---

## Access Control Matrix

Complete role × table × action matrix:

```
TABLE               | ADMIN | STAFF    | STUDENT  | TECH
--------------------|-------|----------|----------|------
users               | CRUD  | R(own+d) | RU(own)  | RU(own)
departments         | CRUD  | RU(asgn) | R(own)   | R(asgn)
categories          | CRUD  | R        | R        | R
items               | CRUD* | CRU(d)   | R(d)     | R(maint)
borrow_requests     | CRU   | RU(d)    | CRU(own) | -
issued_items        | CRUD  | CRU(d)   | R(own)   | -
damage_reports      | CRU   | CRU(d)   | CR(own)  | -
maintenance_records | CRUD  | R(d)     | -        | RU(asgn)
chemical_usage_logs | R     | R(d)     | CR(own)  | -
notifications       | R     | RU       | RU       | RU
audit_logs          | R     | R(own+d) | R(own)   | R(own)

Legend:
C = CREATE (INSERT)
R = READ (SELECT)
U = UPDATE
D = DELETE
* = Soft delete only (status='retired')
(d)   = Department scoped
(own) = Own record/action only
(asgn) = Assigned to user only
(maint) = Active maintenance assignments only
- = No access
```

## Performance Considerations

### Query Optimization

All auth helper functions use `stable` functions for plan caching:
- `get_user_role()` - User role lookup
- `is_admin()`, `is_staff()`, etc. - Role checks
- `can_access_department()` - Department access checks

### Indexes for Policy Execution

Performance indexes created:
```sql
users_department_ids_idx              -- GIN index for array operations
items_department_status_idx           -- Composite for item filtering
issued_items_item_issued_to_idx       -- Issued items lookup
damage_reports_item_reported_by_idx   -- Damage report filtering
maintenance_records_item_assigned_to_idx -- Maintenance assignment
chemical_usage_logs_item_used_by_idx  -- Usage log filtering
audit_logs_entity_type_id_idx         -- Audit trail queries
```

### Expected Performance

- Policy checks: < 10ms for typical queries
- Department access: < 5ms (indexed array overlap)
- Role-based filtering: < 15ms per query
- Aggregated queries: < 50ms with proper indexing

## Security Assumptions

1. **Auth.uid() is trusted**: PostgreSQL `auth.uid()` is populated by Supabase Auth and cannot be spoofed from client
2. **Service role is secure**: Service role key stored securely in environment, used only by backend
3. **RLS cannot be bypassed**: Authenticated users cannot use service role key
4. **Database is isolated**: Only Supabase trusted IPs can connect
5. **JWT is signed**: Auth claims verified by Supabase Auth before reaching database

## GDPR Compliance

### Data Subject Access Requests (DSAR)

Students can access their own audit logs:
```sql
select * from public.audit_logs where user_id = auth.uid();
```

### Data Retention

- Audit logs: 7-year retention (enforced by `retention_until` column)
- Automatic archival of logs older than retention period
- Hard deletion after retention expires

### Right to Erasure

- Soft deletes used for items/records (maintains audit trail)
- Hard delete prevented at database layer for compliance records
- Personal data in `users` table can be anonymized (not deleted)

## Service Role Security

The service role key is used by backend Edge Functions for:
- Creating notifications (bypasses RLS)
- Bulk operations (admin imports)
- Scheduled tasks (expiry checks)

**Security Best Practices**:
1. Never expose service role key to client
2. Store in `.env.local` (never in `.env.example`)
3. Rotate key quarterly
4. Audit service role API calls
5. Restrict IP addresses for service role connections

## Testing

See `PHASE1_TESTING.md` for comprehensive RLS test scenarios:
- Happy paths (authorized access works)
- Sad paths (unauthorized access blocked)
- Cross-department isolation
- Role transitions
- Edge cases (maintenance locks, expiry, soft deletes)

## Troubleshooting

### "RLS denied access to table"

**Cause**: User doesn't match any policy conditions
**Solution**: Check user role and department assignment

### "No rows returned from SELECT"

**Cause**: Policy `using` clause evaluated to false
**Solution**: Verify user credentials and policy logic

### "Cannot INSERT due to RLS policy"

**Cause**: `with check` clause conditions not met
**Solution**: Review INSERT values against policy constraints

### Performance Issues

**Symptoms**: Queries timeout or are very slow
**Causes**: 
- Missing indexes on policy-checked columns
- Complex subqueries in policy conditions
- Cross-table joins in policies

**Solutions**:
- Add indexes per performance section
- Simplify policy logic
- Use database statistics: `analyze`

## Future Enhancements

1. **Attribute-Based Access Control (ABAC)**: Extended attributes beyond role
2. **Time-Based Restrictions**: Access windows per department
3. **Audit Log Analysis**: ML-based anomaly detection
4. **Policy Versioning**: Track policy changes over time
5. **Role Hierarchy**: Parent-child roles with inheritance

## Related Documentation

- `SCHEMA.md` - Database schema details
- `AUDIT_LOGGING.md` - Audit trail design
- `DATA_RETENTION.md` - Compliance and retention
- `TROUBLESHOOTING.md` - Common issues
- `PHASE1_TESTING.md` - RLS test cases
