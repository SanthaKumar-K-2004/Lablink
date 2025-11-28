# Access Control Matrix (ACM)

Complete Role-Based Access Control matrix for LabLink Phase 1 RLS implementation.

## Quick Reference

### Legend

- **C** = CREATE (INSERT)
- **R** = READ (SELECT)
- **U** = UPDATE
- **D** = DELETE
- **(d)** = Department-scoped (staff/students in same dept)
- **(own)** = Own record/action only
- **(asgn)** = Assigned to user only
- **(maint)** = Active maintenance assignments only
- **-** = No access
- **✓** = Full access
- **partial** = Conditional access

---

## Core Tables

### USERS Table

| Operation | Admin | Staff | Student | Technician |
|-----------|-------|-------|---------|------------|
| **SELECT** | ✓ | R(d) | R(own) | R(own) |
| **INSERT** | ✓ | - | - | - |
| **UPDATE** | ✓ | U(own) | U(own) | U(own) |
| **DELETE** | ✓ | - | - | - |

**Details:**
- Admin: Unlimited access
- Staff: Can see own + department colleagues
- Student: Own profile only
- Technician: Own profile only

---

### DEPARTMENTS Table

| Operation | Admin | Staff | Student | Technician |
|-----------|-------|-------|---------|------------|
| **SELECT** | ✓ | R(asgn) | R(own) | R(asgn) |
| **INSERT** | ✓ | - | - | - |
| **UPDATE** | ✓ | U(asgn) | - | - |
| **DELETE** | ✓ | - | - | - |

**Details:**
- Admin: Full CRUD
- Staff: Can manage assigned departments
- Student: Can see own department only
- Technician: Can see assigned departments

---

### CATEGORIES Table

| Operation | Admin | Staff | Student | Technician |
|-----------|-------|-------|---------|------------|
| **SELECT** | ✓ | ✓ | ✓ | ✓ |
| **INSERT** | ✓ | - | - | - |
| **UPDATE** | ✓ | - | - | - |
| **DELETE** | ✓ | - | - | - |

**Details:**
- All roles: Can read categories (public reference data)
- Admin: Manages categories
- Others: Read-only access

---

### ITEMS Table

| Operation | Admin | Staff | Student | Technician |
|-----------|-------|-------|---------|------------|
| **SELECT** | ✓ | R(d) | R(d) | R(maint) |
| **INSERT** | ✓ | C(d) | - | - |
| **UPDATE** | ✓ | U(d) | - | - |
| **DELETE** | D* | - | - | - |

**Details:**
- Admin: Full access including soft-delete (status='retired')
- Staff: Create/manage department items
- Student: Read department items (no modify)
- Technician: Read items with active maintenance assignments only
- **Notes**: Hard delete prevented at DB layer, soft delete enforced

---

## Workflow Tables

### BORROW_REQUESTS Table

| Operation | Admin | Staff | Student | Technician |
|-----------|-------|-------|---------|------------|
| **SELECT** | ✓ | R(d) | R(own) | - |
| **INSERT** | ✓ | - | C(own)* | - |
| **UPDATE** | ✓ | U(d)** | U(own)+ | - |
| **DELETE** | - | - | - | - |

**Details:**
- Admin: Full access to all requests
- Staff: Can see/approve department requests
- Student: Can create/modify own pending requests only
- Technician: No access
- **Notes**:
  - \* Student INSERT only for available items (status != 'retired'/'damaged')
  - \*\* Staff UPDATE limited to approval status
  - \+ Student UPDATE limited to status='pending'
  - Date validation enforced (start_date < end_date)

---

### ISSUED_ITEMS Table

| Operation | Admin | Staff | Student | Technician |
|-----------|-------|-------|---------|------------|
| **SELECT** | ✓ | R(d) | R(own) | - |
| **INSERT** | ✓ | C(d) | - | - |
| **UPDATE** | ✓ | U(d)* | - | - |
| **DELETE** | - | - | - | - |

**Details:**
- Admin: Full access
- Staff: Issue/return items from own department
- Student: View own borrowed items (read-only)
- Technician: No access
- **Notes**:
  - \* Staff UPDATE tracks return date and condition
  - Students cannot modify to prevent fraud
  - Status tracking: active → returned/overdue/lost

---

### DAMAGE_REPORTS Table

| Operation | Admin | Staff | Student | Technician |
|-----------|-------|-------|---------|------------|
| **SELECT** | ✓ | R(d) | R(own) | - |
| **INSERT** | ✓ | C(d) | C(own)* | - |
| **UPDATE** | ✓ | U(own)+ | - | - |
| **DELETE** | - | - | - | - |

**Details:**
- Admin: Full access and approval authority
- Staff: Report/track damage in own department
- Student: Report damage on borrowed items only
- Technician: No access
- **Notes**:
  - \* Student INSERT only for items they actively borrowed
  - \+ Staff UPDATE limited to pre-approval (status='pending')
  - Only admin can approve/reject (status='approved'/'rejected')
  - Photos limit enforced (max 5)

---

## Maintenance & Equipment

### MAINTENANCE_RECORDS Table

| Operation | Admin | Staff | Student | Technician |
|-----------|-------|-------|---------|------------|
| **SELECT** | ✓ | R(d) | - | R(asgn) |
| **INSERT** | ✓ | - | - | - |
| **UPDATE** | ✓ | - | - | U(asgn)* |
| **DELETE** | - | - | - | - |

**Details:**
- Admin: Full access and assignment authority
- Staff: Monitor department maintenance (read-only)
- Student: No access
- Technician: Work on assigned records only
- **Notes**:
  - \* Technician UPDATE limited to status/notes/photos/costs
  - Technician CANNOT reassign or change assignments
  - with check constraint enforces assigned_to = assigned_to
  - Prevents reassignment attempts

---

### CHEMICAL_USAGE_LOGS Table

| Operation | Admin | Staff | Student | Technician |
|-----------|-------|-------|---------|------------|
| **SELECT** | ✓ | R(d) | R(own) | - |
| **INSERT** | - | - | C(own) | - |
| **UPDATE** | - | - | - | - |
| **DELETE** | - | - | - | - |

**Details:**
- Admin: Audit access (read-only)
- Staff: Monitor department chemical usage
- Student: Log own chemical usage only
- Technician: No access
- **Notes**:
  - Append-only (no UPDATE/DELETE)
  - Validates quantity_remaining >= 0
  - Supports chemistry/biology experiments
  - Auto-logged after return with condition

---

## Notifications & Audit

### NOTIFICATIONS Table

| Operation | Admin | Staff | Student | Technician |
|-----------|-------|-------|---------|------------|
| **SELECT** | ✓ (all) | R(own) | R(own) | R(own) |
| **INSERT** | - | - | - | - |
| **UPDATE** | - | U(read)* | U(read)* | U(read)* |
| **DELETE** | - | - | - | - |

**Details:**
- Admin: Monitor all notifications (read-only)
- Staff/Student/Technician: See own notifications
- All users: Can mark notifications as read
- System: Only service role INSERTs notifications
- **Notes**:
  - \* Users can only update read status and is_archived flag
  - Service role bypasses RLS (backend only)
  - Immutable notification content (no client UPDATE/DELETE)
  - Used for approvals, reminders, alerts

---

### AUDIT_LOGS Table

| Operation | Admin | Staff | Student | Technician |
|-----------|-------|-------|---------|------------|
| **SELECT** | ✓ (all) | R(own+d)* | R(own) | R(own) |
| **INSERT** | - | - | - | - |
| **UPDATE** | - | - | - | - |
| **DELETE** | - | - | - | - |

**Details:**
- Admin: Full audit trail access (forensics)
- Staff: Own actions + department entity changes
- Student: Own actions only (GDPR compliance)
- Technician: Own actions only
- **Notes**:
  - \* Staff can filter by entity_type and department_id
  - Service role INSERT only (audit_log_trigger function)
  - Append-only (immutable after insertion)
  - 7-year retention policy enforced
  - Supports GDPR subject access requests (DSAR)

---

## Special Operations

### Admin-Only Functions

| Operation | Availability | Notes |
|-----------|--------------|-------|
| Create users | Admin | Requires role = 'admin' |
| Change user roles | Admin | Role transitions |
| Delete users | Admin | Hard delete (soft available) |
| Create departments | Admin | Department setup |
| Manage departments | Admin | Budget, assignments |
| Create/manage categories | Admin | Reference data |
| Approve/reject requests | Admin | Final authority |
| Approve damage reports | Admin | Liability decisions |
| Assign maintenance | Admin | Technician dispatch |
| Generate reports | Admin | System analytics |
| Bulk operations | Service Role | Via Edge Functions |
| Export data | Admin | GDPR/backup |

### Service Role Only (Backend)

| Operation | Used By | Purpose |
|-----------|---------|---------|
| INSERT notifications | Edge Functions | Approval alerts, reminders |
| INSERT audit_logs | Trigger functions | Automatic audit trail |
| Bulk imports | Admin API | Data imports |
| Scheduled tasks | Cron jobs | Expiry checks, cleanup |
| QR code generation | QR service | Device management |

---

## Cross-Table Access Patterns

### Department-Based Filtering

**Pattern**: Staff/Students limited to own department

Tables affected:
- items (staff C/R/U own dept, student R own dept)
- borrow_requests (staff R/U own dept, student R/U own)
- issued_items (staff C/R/U own dept)
- damage_reports (staff C/R/U own dept)
- maintenance_records (staff R own dept)
- chemical_usage_logs (staff R own dept)

**Implementation**: `can_access_department(dept_id)` function

---

### Ownership-Based Filtering

**Pattern**: Users see only their own records

Tables affected:
- users (R/U own profile)
- borrow_requests (student R/U own requests)
- issued_items (student R own items)
- damage_reports (student R/C own reports)
- chemical_usage_logs (student R/C own logs)
- notifications (R/U own notifications)
- audit_logs (R own actions)

**Implementation**: `auth.uid() = user_id` checks

---

### Assignment-Based Filtering

**Pattern**: Technician sees only assigned work

Tables affected:
- maintenance_records (R/U assigned work)

**Implementation**: `assigned_to = auth.uid()`

---

## Policy Coverage Summary

| Table | SELECT | INSERT | UPDATE | DELETE |
|-------|--------|--------|--------|--------|
| users | 5 policies | 1 policy | 3 policies | 1 policy |
| departments | 4 policies | 1 policy | 2 policies | 1 policy |
| categories | 1 policy | 1 policy | 1 policy | 1 policy |
| items | 5 policies | 2 policies | 3 policies | 1 policy |
| borrow_requests | 4 policies | 2 policies | 3 policies | 0 policies |
| issued_items | 3 policies | 1 policy | 2 policies | 0 policies |
| damage_reports | 4 policies | 2 policies | 2 policies | 0 policies |
| maintenance_records | 3 policies | 1 policy | 2 policies | 0 policies |
| chemical_usage_logs | 3 policies | 1 policy | 0 policies | 0 policies |
| notifications | 2 policies | 0 policies | 1 policy | 0 policies |
| audit_logs | 4 policies | 0 policies | 0 policies | 0 policies |

**Total**: 45 RLS policies

---

## Permission Combinations

### Common User Workflows

#### Admin Workflow
```
Dashboard          → SELECT * FROM users, departments, items
User Management    → INSERT/UPDATE/DELETE users
Item Management    → INSERT/UPDATE items, soft-delete via status
Request Approval   → UPDATE borrow_requests (approve/reject)
Damage Approval    → UPDATE damage_reports (approve/reject)
Maintenance Assign → INSERT maintenance_records
Report Generation  → SELECT * (full audit trail)
```

#### Staff Workflow
```
Department Items   → SELECT items WHERE department_id IN (own_depts)
Item Management    → INSERT/UPDATE items (own department)
Issue Items        → INSERT issued_items
Process Returns    → UPDATE issued_items (with condition tracking)
Approve Requests   → UPDATE borrow_requests (own department)
Monitor Damage     → SELECT damage_reports (own department)
Track Maintenance  → SELECT maintenance_records (read-only)
Chemical Usage     → SELECT chemical_usage_logs (own department)
```

#### Student Workflow
```
Browse Items       → SELECT items WHERE department_id = own_dept
Borrow Items       → INSERT borrow_requests
View Requests      → SELECT borrow_requests WHERE student_id = self
Modify Requests    → UPDATE borrow_requests (pending only)
View Borrowed      → SELECT issued_items WHERE issued_to = self
Report Damage      → INSERT damage_reports (own borrowed items)
Log Chemical Use   → INSERT chemical_usage_logs (self)
View Notifications → SELECT notifications WHERE user_id = self
```

#### Technician Workflow
```
View Assignments   → SELECT maintenance_records WHERE assigned_to = self
Update Progress    → UPDATE maintenance_records (status/notes/photos)
View Department    → SELECT departments (assigned to)
View Own Profile   → SELECT users WHERE id = self
View Notifications → SELECT notifications WHERE user_id = self
```

---

## Compliance & Security

### GDPR Compliance

| Requirement | Implementation |
|-------------|----------------|
| Data Subject Access | Students can SELECT own audit_logs |
| Right to Erasure | Soft deletes preserve audit trail |
| Data Minimization | Role-based filtering limits exposure |
| Retention Policy | 7-year retention in audit_logs.retention_until |
| Audit Trail | Complete audit_logs with 45 policies |

### Security Features

| Feature | Implementation |
|---------|----------------|
| Department Isolation | RLS policies enforce department_id scoping |
| User Segregation | is_admin/is_staff/is_student functions |
| Immutable Audit | No UPDATE/DELETE on audit_logs |
| Soft Deletes | Prevent hard deletion for compliance |
| Service Role Separation | Backend-only service_role.key |
| JWT Validation | Supabase Auth manages auth.uid() |
| Policy Versioning | Migration-based policy management |
| Principle of Least Privilege | Each role sees minimum necessary |

---

## Future Enhancements

- [ ] Time-based access windows (e.g., maintenance staff 9-5)
- [ ] Attribute-based access control (ABAC) on user attributes
- [ ] Temporary elevated permissions (approval workflow)
- [ ] Cross-department collaboration with audit trails
- [ ] IP-based restrictions for sensitive operations
- [ ] Device fingerprinting for mobile access
- [ ] Real-time permission revocation
- [ ] Role inheritance hierarchy
- [ ] Delegation of approval authority
- [ ] API key scoping by department

---

## Quick Reference by Operation

### CREATE (INSERT)

```
✓ Admin can INSERT: users, departments, items, categories, 
                    borrow_requests, issued_items, damage_reports, 
                    maintenance_records

✓ Staff can INSERT: items (own dept), damage_reports (own dept)

✓ Student can INSERT: borrow_requests (own, available items),
                      damage_reports (own borrowed items),
                      chemical_usage_logs (self)

✓ Service Role: notifications (via functions), audit_logs (via triggers)
```

### READ (SELECT)

```
✓ Admin can SELECT: everything

✓ Staff can SELECT: users (own + dept), departments (assigned),
                    items (own dept), categories, borrow_requests (own dept),
                    issued_items (own dept), damage_reports (own dept),
                    maintenance_records (own dept), chemical_usage_logs (own dept),
                    notifications (own), audit_logs (own + dept)

✓ Student can SELECT: users (self), departments (own),
                      items (own dept), categories, borrow_requests (own),
                      issued_items (own), damage_reports (own),
                      notifications (own), audit_logs (own)

✓ Technician can SELECT: users (self), departments (assigned),
                         items (active maintenance), categories,
                         maintenance_records (assigned),
                         notifications (own), audit_logs (own)
```

### UPDATE

```
✓ Admin can UPDATE: everything

✓ Staff can UPDATE: users (own), departments (assigned),
                    items (own dept), borrow_requests (own dept),
                    issued_items (own dept), damage_reports (own pre-approval)

✓ Student can UPDATE: users (own profile), borrow_requests (pending),
                      notifications (read status)

✓ Technician can UPDATE: users (own profile), maintenance_records (assigned),
                         notifications (read status)
```

### DELETE

```
✓ Admin can DELETE: users (hard), departments, categories

✓ Soft Deletes: items (status='retired'), borrow_requests (logical cancel)

✗ No one: damage_reports, maintenance_records, issued_items,
          chemical_usage_logs, notifications, audit_logs
```

---

## Related Documentation

- `RLS_POLICIES.md` - Detailed policy descriptions
- `PHASE1_TESTING.md` - Test cases and execution
- `SCHEMA.md` - Database table structures
- `AUDIT_LOGGING.md` - Audit trail implementation
