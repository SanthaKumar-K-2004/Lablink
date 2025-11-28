# Row-Level Security (RLS) Policies Documentation

## Overview

LabLink implements comprehensive Row-Level Security (RLS) policies to enforce role-based access control at the database layer. This ensures that users can only access data they are authorized to see and modify, providing security isolation between departments and user roles.

## RLS Framework

### Helper Functions

#### `auth_jwt_metadata()`
Extracts user role from JWT metadata.
```sql
select public.auth_jwt_metadata()->>'role' as role;
```

#### Role Check Functions
- `is_admin()` → Returns true if current user is admin
- `is_staff()` → Returns true if current user is staff  
- `is_student()` → Returns true if current user is student
- `is_technician()` → Returns true if current user is technician

#### Department Access Functions
- `can_access_department(dept_id)` → Check if user has access to specific department
- `get_user_departments()` → Get array of department IDs user has access to

## Access Control Matrix

| Table | Admin | Staff | Student | Technician |
|-------|-------|-------|---------|------------|
| **users** | Full CRUD | SELECT dept users, UPDATE own dept | SELECT/UPDATE own only | SELECT/UPDATE own only |
| **departments** | Full CRUD | SELECT assigned, UPDATE own | SELECT own only | SELECT assigned only |
| **categories** | Full CRUD | SELECT only | SELECT only | SELECT only |
| **items** | Full CRUD | SELECT/INSERT/UPDATE dept items | SELECT dept items (read-only) | SELECT assigned items only |
| **borrow_requests** | SELECT/UPDATE all | SELECT/UPDATE dept requests | SELECT/INSERT/UPDATE own pending | No access |
| **issued_items** | Full CRUD | SELECT/UPDATE dept issued | SELECT own issued | No access |
| **damage_reports** | SELECT/UPDATE all | SELECT/INSERT/UPDATE dept reports | SELECT/INSERT own reports | No access |
| **maintenance_records** | Full CRUD | SELECT dept records (read-only) | No access | SELECT/UPDATE assigned only |
| **chemical_usage_logs** | SELECT all (audit) | SELECT dept usage | SELECT/INSERT own usage | No access |
| **notifications** | SELECT all (monitoring) | SELECT/UPDATE own | SELECT/UPDATE own | SELECT/UPDATE own |
| **audit_logs** | SELECT all (audit) | SELECT dept + own | SELECT own only | SELECT own only |

## Per-Table Policy Details

### Users Table
- **Self-access**: All users can always SELECT their own record (`auth.uid() = id`)
- **Admin**: Full CRUD access to all users
- **Staff**: Can SELECT users in same department, UPDATE own department users
- **Student/Technician**: Can SELECT and UPDATE their own profile only

### Departments Table
- **Admin**: Full CRUD access to all departments
- **Staff**: Can SELECT assigned departments, UPDATE own department settings
- **Student**: Can SELECT own department only (from profile)
- **Technician**: Can SELECT assigned department only

### Categories Table
- **All roles**: SELECT access (read-only reference data)
- **Admin**: Full INSERT/UPDATE/DELETE access

### Items Table
- **Admin**: Full CRUD access (including soft delete)
- **Staff**: Full access to items in their departments, cannot hard delete
- **Student**: Read-only access to items in their departments
- **Technician**: Can only see items assigned to them for maintenance
- **Soft deletes**: Use `status='retired'` instead of actual deletion

### Borrow Requests Table
- **Admin**: Can SELECT all, UPDATE all (approve/reject)
- **Staff**: Can SELECT/UPDATE requests for items in their department
- **Student**: Can SELECT/INSERT own requests, UPDATE own pending requests only
- **Business rules**: 
  - Students can only request available items
  - End date must be > start date
  - Cannot request expired chemicals or damaged items

### Issued Items Table
- **Admin**: Full CRUD access
- **Staff**: Can SELECT/UPDATE items issued in their department
- **Student**: Can SELECT own issued items only
- **Business rules**: Staff can only issue items from their department

### Damage Reports Table
- **Admin**: Can SELECT all, UPDATE status/approval
- **Staff**: Can SELECT/INSERT department reports, UPDATE own pre-approval reports
- **Student**: Can SELECT/INSERT own reports for borrowed items
- **Business rules**: Users can see reports for items they're responsible for

### Maintenance Records Table
- **Admin**: Full CRUD access
- **Staff**: Read-only access to department maintenance records
- **Technician**: Can SELECT/UPDATE their own assigned tasks only
- **Business rules**: Technicians can only update their assigned records

### Chemical Usage Logs Table
- **Admin**: Full SELECT access (audit trail)
- **Staff**: SELECT access for department items
- **Student**: SELECT/INSERT usage for chemicals they borrowed
- **Business rules**: Usage logs auto-created after return, quantity validation

### Notifications Table
- **All users**: Can SELECT/UPDATE their own notifications
- **Admin**: Can SELECT all notifications (system monitoring)
- **Service role**: Can INSERT notifications (bypasses RLS)

### Audit Logs Table
- **Admin**: Full SELECT access with filters
- **Staff**: SELECT own actions + department actions
- **Student/Technician**: SELECT own actions only (GDPR compliance)
- **Immutability**: No UPDATE/DELETE from any role (append-only)
- **Retention**: 7-year retention with automated archival

## Edge Cases & Advanced Policies

### Maintenance Windows
- Items with `status='maintenance'` block all borrow attempts
- Implemented via item status checks in borrow request policies

### Expired Chemicals
- Chemicals with `expiry_date < now()` automatically marked `status='retired'`
- Cannot be borrowed due to status checks in policies

### Bulk Operations
- Import operations use `BYPASSING RLS` with service_role.key
- Admin only access to service role credentials

### QR Code Scans
- QR scan operations logged regardless of user role
- Audit trail maintained for compliance

### Deleted/Retired Items
- Still visible in audit logs for compliance
- Soft deletes maintain data integrity

## Security Considerations

### Service Role Key Usage
- Service role key bypasses all RLS policies
- Used only for:
  - System operations (notifications, audit logging)
  - Bulk import operations (admin only)
  - Background jobs and maintenance tasks
- Stored securely in environment variables

### JWT Token Structure
```json
{
  "sub": "user-uuid",
  "role": "admin|staff|student|technician",
  "exp": timestamp,
  "iat": timestamp
}
```

### GDPR Compliance
- Students can only access their own audit trail
- 7-year data retention policy
- Right to deletion implemented via soft deletes
- Data portability through department-based exports

## Testing RLS Policies

### Test Script
Run the comprehensive test script to validate RLS policies:
```bash
psql -f supabase/migrations/test_rls.sql
```

### Test Scenarios
The test script validates:
- ✅ Happy paths (authorized access works)
- ✅ Sad paths (unauthorized access blocked)  
- ✅ Cross-department isolation
- ✅ Student self-isolation
- ✅ Technician assignment restrictions
- ✅ Admin override capabilities

### Manual Testing
Use these patterns to test RLS manually:
```sql
-- Set JWT context for testing
SELECT set_config('request.jwt.claim.sub', 'user-uuid', true);
SELECT set_config('request.jwt.claim.role', 'staff', true);

-- Test access
SELECT count(*) FROM public.items;

-- Clear context
SELECT set_config('request.jwt.claim.sub', '', true);
```

## Performance Considerations

### Indexing
- All foreign key columns indexed
- RLS policy columns indexed where appropriate
- Department access patterns optimized

### Query Optimization
- RLS policies use efficient EXISTS subqueries
- Department access checks leverage array operations
- Role checks are simple string comparisons

### Connection Pooling
- RLS policies evaluated per connection
- Connection pooling maintained by Supabase
- JWT context properly isolated

## Troubleshooting

### Common Issues

#### "Permission denied" errors
- Check JWT token is properly set
- Verify user role in JWT matches expected
- Ensure user has department assignments

#### Performance issues
- Check RLS policy execution plans
- Verify appropriate indexes exist
- Consider policy simplification for complex queries

#### Cross-department access
- Verify user department_ids array
- Check department access logic in policies
- Test with actual department relationships

### Debugging RLS
```sql
-- Check current JWT context
SELECT current_setting('request.jwt.claim.sub', true);
SELECT current_setting('request.jwt.claim.role', true);

-- Test helper functions
SELECT public.is_admin();
SELECT public.get_user_departments();
SELECT public.can_access_department('dept-uuid');
```

## Migration Notes

### RLS Enablement
All tables have RLS enabled:
```sql
ALTER TABLE table_name ENABLE ROW LEVEL SECURITY;
```

### Policy Application Order
Policies are applied in this order:
1. SELECT policies (most restrictive first)
2. INSERT policies (WITH CHECK clauses)
3. UPDATE policies (USING + WITH CHECK clauses)
4. DELETE policies (USING clauses)

### Backward Compatibility
- Existing applications continue to work
- JWT tokens must include role claim
- Service role operations unaffected

## Future Enhancements

### Planned Improvements
- Time-based access controls
- Dynamic role assignments
- Fine-grained permission system
- Audit log analysis tools

### Security Hardening
- Multi-factor authentication integration
- Session timeout enforcement
- IP-based access restrictions
- Automated security scanning

---

**Last Updated**: 2024-11-28
**Version**: 1.0
**Maintainer**: LabLink Development Team