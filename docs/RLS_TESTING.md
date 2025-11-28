# RLS Testing Documentation

## Overview

This document describes the comprehensive testing approach for Row-Level Security (RLS) policies in LabLink. The testing ensures that all access control rules are working correctly and that data isolation between roles and departments is properly enforced.

## Test Environment Setup

### Test Users and Roles

The test script creates the following test users:

| User ID | Email | Role | Departments |
|---------|-------|------|-------------|
| 11111111-1111-1111-1111-111111111111 | admin@test.com | admin | Chemistry, Physics |
| 22222222-2222-2222-2222-222222222222 | staff@test.com | staff | Chemistry |
| 33333333-3333-3333-3333-333333333333 | student@test.com | student | Chemistry |
| 44444444-4444-4444-4444-444444444444 | tech@test.com | technician | Chemistry |
| 55555555-5555-5555-5555-555555555555 | staff.physics@test.com | staff | Physics |

### Test Departments

| Department ID | Name | Head |
|--------------|------|------|
| 22222222-2222-2222-2222-222222222222 | Chemistry | Admin |
| 33333333-3333-3333-3333-333333333333 | Physics | Admin |

## Running the Tests

### Prerequisites
1. Apply all migrations including RLS policies
2. Ensure test data exists in the database
3. Have sufficient permissions to run SQL scripts

### Execute Test Script
```bash
# Connect to your Supabase database
psql $DATABASE_URL -f supabase/migrations/test_rls.sql
```

### Expected Output
The test script will output:
- Individual test results with PASS/FAIL status
- Summary statistics showing total tests passed/failed
- Overall status indicating if all tests passed

## Test Categories

### 1. Users Table Tests

| Test ID | Description | Expected Result |
|---------|-------------|-----------------|
| 1 | Admin can view all users | ✅ SUCCESS |
| 2 | Staff can view department users | ✅ SUCCESS |
| 3 | Staff cannot view other department users | ✅ FAILED (permission denied) |
| 4 | Student can view own profile | ✅ SUCCESS |
| 5 | Student cannot view other users | ✅ FAILED (permission denied) |

### 2. Items Table Tests

| Test ID | Description | Expected Result |
|---------|-------------|-----------------|
| 6 | Admin can view all items | ✅ SUCCESS |
| 7 | Staff can view department items | ✅ SUCCESS |
| 8 | Staff cannot view other department items | ✅ FAILED (permission denied) |
| 9 | Student can view department items | ✅ SUCCESS |

### 3. Borrow Requests Table Tests

| Test ID | Description | Expected Result |
|---------|-------------|-----------------|
| 10 | Student can view own requests | ✅ SUCCESS |
| 11 | Student cannot view other students' requests | ✅ FAILED (permission denied) |
| 12 | Staff can view department requests | ✅ SUCCESS |

### 4. Issued Items Table Tests

| Test ID | Description | Expected Result |
|---------|-------------|-----------------|
| 13 | Student can view own issued items | ✅ SUCCESS |
| 14 | Student cannot view others issued items | ✅ FAILED (permission denied) |
| 15 | Staff can view department issued items | ✅ SUCCESS |

### 5. Maintenance Records Table Tests

| Test ID | Description | Expected Result |
|---------|-------------|-----------------|
| 16 | Technician can view assigned maintenance records | ✅ SUCCESS |
| 17 | Technician cannot view unassigned maintenance records | ✅ FAILED (permission denied) |
| 18 | Staff can view department maintenance records | ✅ SUCCESS |

### 6. Notifications Table Tests

| Test ID | Description | Expected Result |
|---------|-------------|-----------------|
| 19 | User can view own notifications | ✅ SUCCESS |
| 20 | User cannot view others notifications | ✅ FAILED (permission denied) |
| 21 | Admin can view all notifications | ✅ SUCCESS |

### 7. Audit Logs Table Tests

| Test ID | Description | Expected Result |
|---------|-------------|-----------------|
| 22 | Student can view own audit logs | ✅ SUCCESS |
| 23 | Student cannot view others audit logs | ✅ FAILED (permission denied) |
| 24 | Admin can view all audit logs | ✅ SUCCESS |

### 8. Cross-Department Isolation Tests

| Test ID | Description | Expected Result |
|---------|-------------|-----------------|
| 25 | Chemistry staff cannot access Physics items | ✅ FAILED (permission denied) |
| 26 | Physics staff cannot access Chemistry items | ✅ FAILED (permission denied) |
| 27 | Admin can access all departments | ✅ SUCCESS |

## Test Results Interpretation

### Success Criteria
- ✅ **AUTHORIZED ACCESS**: Query succeeds when user should have access
- ✅ **UNAUTHORIZED ACCESS**: Query fails with permission denied when user shouldn't have access

### Failure Analysis
If tests fail, check:

1. **JWT Context Issues**
   ```sql
   SELECT current_setting('request.jwt.claim.sub', true);
   SELECT current_setting('request.jwt.claim.role', true);
   ```

2. **Policy Logic Issues**
   - Review RLS policy definitions
   - Check helper function logic
   - Verify department assignments

3. **Data Issues**
   - Ensure test users exist
   - Verify department relationships
   - Check sample data presence

## Manual Testing Procedures

### Testing Different Roles

#### Admin Role Testing
```sql
-- Set admin context
SELECT set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
SELECT set_config('request.jwt.claim.role', 'admin', true);

-- Test full access
SELECT count(*) FROM public.users;
SELECT count(*) FROM public.items;
SELECT count(*) FROM public.borrow_requests;
```

#### Staff Role Testing
```sql
-- Set staff context
SELECT set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
SELECT set_config('request.jwt.claim.role', 'staff', true);

-- Test department access
SELECT count(*) FROM public.items WHERE department_id = '22222222-2222-2222-2222-222222222222';

-- Test cross-department restriction (should fail)
SELECT count(*) FROM public.items WHERE department_id = '33333333-3333-3333-3333-333333333333';
```

#### Student Role Testing
```sql
-- Set student context
SELECT set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', true);
SELECT set_config('request.jwt.claim.role', 'student', true);

-- Test self-access
SELECT count(*) FROM public.users WHERE id = '33333333-3333-3333-3333-333333333333';

-- Test other user access (should fail)
SELECT count(*) FROM public.users WHERE id != '33333333-3333-3333-3333-333333333333';
```

#### Technician Role Testing
```sql
-- Set technician context
SELECT set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', true);
SELECT set_config('request.jwt.claim.role', 'technician', true);

-- Test assigned maintenance
SELECT count(*) FROM public.maintenance_records WHERE assigned_to = '44444444-4444-4444-4444-444444444444';
```

### Clear Test Context
```sql
-- Clear JWT context
SELECT set_config('request.jwt.claim.sub', '', true);
SELECT set_config('request.jwt.claim.role', '', true);
```

## Performance Testing

### Query Performance Analysis
```sql
-- Check RLS policy execution plans
EXPLAIN ANALYZE SELECT count(*) FROM public.items;

-- Test with different user contexts
EXPLAIN ANALYZE SELECT count(*) FROM public.borrow_requests 
WHERE student_id = '33333333-3333-3333-3333-333333333333';
```

### Index Usage Verification
```sql
-- Check if indexes are being used effectively
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;
```

## Security Testing

### SQL Injection Prevention
RLS policies automatically protect against SQL injection by enforcing access at the database level. Test with:

```sql
-- Attempt to bypass RLS with malicious input
SELECT count(*) FROM public.users WHERE id = '33333333-3333-3333-3333-333333333333' OR '1'='1';
```

### Privilege Escalation Tests
```sql
-- Test if users can modify their role
UPDATE public.users SET role = 'admin' WHERE id = auth.uid();

-- Test if users can access other departments
UPDATE public.users SET department_ids = array['22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333'] WHERE id = auth.uid();
```

## Continuous Testing

### Automated Test Integration
The test script can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions step
- name: Test RLS Policies
  run: |
    psql $DATABASE_URL -f supabase/migrations/test_rls.sql
    # Check exit code to ensure all tests pass
```

### Regression Testing
Run tests after:
- Schema changes
- Policy modifications
- Role definition updates
- New table additions

## Troubleshooting Guide

### Common Test Failures

#### 1. JWT Context Not Set
**Error**: Tests fail with unexpected results
**Solution**: Verify JWT context is properly set before each test

#### 2. Missing Test Data
**Error**: Tests return 0 rows when data expected
**Solution**: Ensure seed data is properly loaded

#### 3. Policy Logic Errors
**Error**: Tests fail with incorrect access patterns
**Solution**: Review RLS policy definitions and helper functions

#### 4. Index Performance Issues
**Error**: Tests run slowly
**Solution**: Check query execution plans and add missing indexes

### Debug Mode
Enable detailed logging for troubleshooting:

```sql
-- Enable RLS logging
SET rls.force_row_security = on;
SET log_statement = 'all';

-- Run problematic query
SELECT count(*) FROM public.items;
```

## Test Maintenance

### Updating Tests
When adding new tables or policies:
1. Add corresponding test scenarios
2. Update test users if new roles needed
3. Modify test expectations based on new access rules
4. Update this documentation

### Test Data Management
- Use consistent test data across environments
- Clean up test data after runs
- Maintain referential integrity in test data

## Compliance Verification

### GDPR Compliance Testing
- Verify students can only access their own audit logs
- Test data retention policies
- Validate right to deletion functionality

### Security Audit Testing
- Test privilege escalation attempts
- Verify cross-department isolation
- Validate admin override capabilities

---

**Test Coverage**: 27 comprehensive test scenarios
**Last Updated**: 2024-11-28
**Version**: 1.0
**Maintainer**: LabLink Development Team