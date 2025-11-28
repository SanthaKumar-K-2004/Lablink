-- LabLink RLS Testing Script
-- This script tests all RLS policies for each role and table
-- Run this after applying migrations to verify RLS is working correctly

-- =====================================================================
-- SETUP: Create test users with different roles
-- =====================================================================

-- Note: In a real environment, these would be created via auth.users
-- For testing, we'll create them directly and simulate JWT tokens

-- Test Admin
INSERT INTO public.users (id, email, full_name, role, department_ids) 
VALUES 
  ('11111111-1111-1111-1111-111111111111', 'admin@test.com', 'Test Admin', 'admin', array['22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333'])
ON CONFLICT (id) DO UPDATE SET 
  role = 'admin',
  department_ids = array['22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333'];

-- Test Staff (Chemistry Dept)
INSERT INTO public.users (id, email, full_name, role, department_ids) 
VALUES 
  ('22222222-2222-2222-2222-222222222222', 'staff@test.com', 'Test Staff', 'staff', array['22222222-2222-2222-2222-222222222222'])
ON CONFLICT (id) DO UPDATE SET 
  role = 'staff',
  department_ids = array['22222222-2222-2222-2222-222222222222'];

-- Test Student (Chemistry Dept)
INSERT INTO public.users (id, email, full_name, role, department_ids) 
VALUES 
  ('33333333-3333-3333-3333-333333333333', 'student@test.com', 'Test Student', 'student', array['22222222-2222-2222-2222-222222222222'])
ON CONFLICT (id) DO UPDATE SET 
  role = 'student',
  department_ids = array['22222222-2222-2222-2222-222222222222'];

-- Test Technician
INSERT INTO public.users (id, email, full_name, role, department_ids) 
VALUES 
  ('44444444-4444-4444-4444-444444444444', 'tech@test.com', 'Test Technician', 'technician', array['22222222-2222-2222-2222-222222222222'])
ON CONFLICT (id) DO UPDATE SET 
  role = 'technician',
  department_ids = array['22222222-2222-2222-2222-222222222222'];

-- Test Other Department Staff (Physics Dept)
INSERT INTO public.users (id, email, full_name, role, department_ids) 
VALUES 
  ('55555555-5555-5555-5555-555555555555', 'staff.physics@test.com', 'Physics Staff', 'staff', array['33333333-3333-3333-3333-333333333333'])
ON CONFLICT (id) DO UPDATE SET 
  role = 'staff',
  department_ids = array['33333333-3333-3333-3333-333333333333'];

-- =====================================================================
-- HELPER FUNCTIONS FOR TESTING
-- =====================================================================

-- Function to simulate setting JWT claims for testing
CREATE OR REPLACE FUNCTION test_set_jwt(user_id uuid, user_role text)
RETURNS void AS $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', user_id::text, true);
  PERFORM set_config('request.jwt.claim.role', user_role, true);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', user_id, 'role', user_role)::text, true);
END;
$$ LANGUAGE plpgsql;

-- Function to clear JWT claims
CREATE OR REPLACE FUNCTION test_clear_jwt()
RETURNS void AS $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claim.role', '', true);
  PERFORM set_config('request.jwt.claims', '', true);
END;
$$ LANGUAGE plpgsql;

-- Function to run a test and report results
CREATE OR REPLACE FUNCTION run_test(test_name text, test_sql text, expected_success boolean)
RETURNS TABLE(test_name text, result text, expected text, passed boolean) AS $$
DECLARE
  test_result boolean;
  error_message text;
BEGIN
  BEGIN
    EXECUTE test_sql;
    test_result := true;
  EXCEPTION WHEN OTHERS THEN
    test_result := false;
    error_message := SQLERRM;
  END;
  
  RETURN QUERY SELECT 
    test_name,
    CASE WHEN test_result THEN 'SUCCESS' ELSE 'FAILED: ' || error_message END,
    expected_success::text,
    test_result = expected_success;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- TEST SCENARIOS
-- =====================================================================

-- Create a test results table
CREATE TEMP TABLE IF NOT EXISTS rls_test_results (
  test_name text,
  result text,
  expected text,
  passed boolean
);

-- =====================================================================
-- USERS TABLE TESTS
-- =====================================================================

DO $$
BEGIN
  RAISE NOTICE '=== TESTING USERS TABLE ===';
  
  -- Test 1: Admin can view all users
  PERFORM test_set_jwt('11111111-1111-1111-1111-111111111111', 'admin');
  INSERT INTO rls_test_results
  SELECT * FROM run_test(
    'Admin can view all users',
    'SELECT count(*) FROM public.users',
    true
  );
  
  -- Test 2: Staff can view department users
  PERFORM test_set_jwt('22222222-2222-2222-2222-222222222222', 'staff');
  INSERT INTO rls_test_results
  SELECT * FROM run_test(
    'Staff can view department users',
    'SELECT count(*) FROM public.users WHERE department_ids && array[''22222222-2222-2222-2222-222222222222'']',
    true
  );
  
  -- Test 3: Staff cannot view other department users
  INSERT INTO rls_test_results
  SELECT * FROM run_test(
    'Staff cannot view other department users',
    'SELECT count(*) FROM public.users WHERE department_ids && array[''33333333-3333-3333-3333-333333333333''] AND id != ''55555555-5555-5555-5555-555555555555''',
    false
  );
  
  -- Test 4: Student can view own profile
  PERFORM test_set_jwt('33333333-3333-3333-3333-333333333333', 'student');
  INSERT INTO rls_test_results
  SELECT * FROM run_test(
    'Student can view own profile',
    'SELECT count(*) FROM public.users WHERE id = ''33333333-3333-3333-3333-333333333333''',
    true
  );
  
  -- Test 5: Student cannot view other users
  INSERT INTO rls_test_results
  SELECT * FROM run_test(
    'Student cannot view other users',
    'SELECT count(*) FROM public.users WHERE id != ''33333333-3333-3333-3333-333333333333''',
    false
  );
  
  PERFORM test_clear_jwt();
END $$;

-- =====================================================================
-- ITEMS TABLE TESTS
-- =====================================================================

DO $$
BEGIN
  RAISE NOTICE '=== TESTING ITEMS TABLE ===';
  
  -- Test 6: Admin can view all items
  PERFORM test_set_jwt('11111111-1111-1111-1111-111111111111', 'admin');
  INSERT INTO rls_test_results
  SELECT * FROM run_test(
    'Admin can view all items',
    'SELECT count(*) FROM public.items',
    true
  );
  
  -- Test 7: Staff can view department items
  PERFORM test_set_jwt('22222222-2222-2222-2222-222222222222', 'staff');
  INSERT INTO rls_test_results
  SELECT * FROM run_test(
    'Staff can view department items',
    'SELECT count(*) FROM public.items WHERE department_id = ''22222222-2222-2222-2222-222222222222''',
    true
  );
  
  -- Test 8: Staff cannot view other department items
  INSERT INTO rls_test_results
  SELECT * FROM run_test(
    'Staff cannot view other department items',
    'SELECT count(*) FROM public.items WHERE department_id = ''33333333-3333-3333-3333-333333333333''',
    false
  );
  
  -- Test 9: Student can view department items
  PERFORM test_set_jwt('33333333-3333-3333-3333-333333333333', 'student');
  INSERT INTO rls_test_results
  SELECT * FROM run_test(
    'Student can view department items',
    'SELECT count(*) FROM public.items WHERE department_id = ''22222222-2222-2222-2222-222222222222''',
    true
  );
  
  PERFORM test_clear_jwt();
END $$;

-- =====================================================================
-- BORROW_REQUESTS TABLE TESTS
-- =====================================================================

DO $$
BEGIN
  RAISE NOTICE '=== TESTING BORROW_REQUESTS TABLE ===';
  
  -- Test 10: Student can view own requests
  PERFORM test_set_jwt('33333333-3333-3333-3333-333333333333', 'student');
  INSERT INTO rls_test_results
  SELECT * FROM run_test(
    'Student can view own requests',
    'SELECT count(*) FROM public.borrow_requests WHERE student_id = ''33333333-3333-3333-3333-333333333333''',
    true
  );
  
  -- Test 11: Student cannot view other students' requests
  INSERT INTO rls_test_results
  SELECT * FROM run_test(
    'Student cannot view other students requests',
    'SELECT count(*) FROM public.borrow_requests WHERE student_id != ''33333333-3333-3333-3333-333333333333''',
    false
  );
  
  -- Test 12: Staff can view department requests
  PERFORM test_set_jwt('22222222-2222-2222-2222-222222222222', 'staff');
  INSERT INTO rls_test_results
  SELECT * FROM run_test(
    'Staff can view department requests',
    'SELECT count(*) FROM public.borrow_requests br JOIN public.items i ON br.item_id = i.id WHERE i.department_id = ''22222222-2222-2222-2222-222222222222''',
    true
  );
  
  PERFORM test_clear_jwt();
END $$;

-- =====================================================================
-- ISSUED_ITEMS TABLE TESTS
-- =====================================================================

DO $$
BEGIN
  RAISE NOTICE '=== TESTING ISSUED_ITEMS TABLE ===';
  
  -- Test 13: Student can view own issued items
  PERFORM test_set_jwt('33333333-3333-3333-3333-333333333333', 'student');
  INSERT INTO rls_test_results
  SELECT * FROM run_test(
    'Student can view own issued items',
    'SELECT count(*) FROM public.issued_items WHERE issued_to = ''33333333-3333-3333-3333-333333333333''',
    true
  );
  
  -- Test 14: Student cannot view others issued items
  INSERT INTO rls_test_results
  SELECT * FROM run_test(
    'Student cannot view others issued items',
    'SELECT count(*) FROM public.issued_items WHERE issued_to != ''33333333-3333-3333-3333-333333333333''',
    false
  );
  
  -- Test 15: Staff can view department issued items
  PERFORM test_set_jwt('22222222-2222-2222-2222-222222222222', 'staff');
  INSERT INTO rls_test_results
  SELECT * FROM run_test(
    'Staff can view department issued items',
    'SELECT count(*) FROM public.issued_items ii JOIN public.items i ON ii.item_id = i.id WHERE i.department_id = ''22222222-2222-2222-2222-222222222222''',
    true
  );
  
  PERFORM test_clear_jwt();
END $$;

-- =====================================================================
-- MAINTENANCE_RECORDS TABLE TESTS
-- =====================================================================

DO $$
BEGIN
  RAISE NOTICE '=== TESTING MAINTENANCE_RECORDS TABLE ===';
  
  -- Test 16: Technician can view assigned maintenance records
  PERFORM test_set_jwt('44444444-4444-4444-4444-444444444444', 'technician');
  INSERT INTO rls_test_results
  SELECT * FROM run_test(
    'Technician can view assigned maintenance records',
    'SELECT count(*) FROM public.maintenance_records WHERE assigned_to = ''44444444-4444-4444-4444-444444444444''',
    true
  );
  
  -- Test 17: Technician cannot view unassigned maintenance records
  INSERT INTO rls_test_results
  SELECT * FROM run_test(
    'Technician cannot view unassigned maintenance records',
    'SELECT count(*) FROM public.maintenance_records WHERE assigned_to != ''44444444-4444-4444-4444-444444444444''',
    false
  );
  
  -- Test 18: Staff can view department maintenance records
  PERFORM test_set_jwt('22222222-2222-2222-2222-222222222222', 'staff');
  INSERT INTO rls_test_results
  SELECT * FROM run_test(
    'Staff can view department maintenance records',
    'SELECT count(*) FROM public.maintenance_records mr JOIN public.items i ON mr.item_id = i.id WHERE i.department_id = ''22222222-2222-2222-2222-222222222222''',
    true
  );
  
  PERFORM test_clear_jwt();
END $$;

-- =====================================================================
-- NOTIFICATIONS TABLE TESTS
-- =====================================================================

DO $$
BEGIN
  RAISE NOTICE '=== TESTING NOTIFICATIONS TABLE ===';
  
  -- Test 19: User can view own notifications
  PERFORM test_set_jwt('33333333-3333-3333-3333-333333333333', 'student');
  INSERT INTO rls_test_results
  SELECT * FROM run_test(
    'User can view own notifications',
    'SELECT count(*) FROM public.notifications WHERE user_id = ''33333333-3333-3333-3333-333333333333''',
    true
  );
  
  -- Test 20: User cannot view others notifications
  INSERT INTO rls_test_results
  SELECT * FROM run_test(
    'User cannot view others notifications',
    'SELECT count(*) FROM public.notifications WHERE user_id != ''33333333-3333-3333-3333-333333333333''',
    false
  );
  
  -- Test 21: Admin can view all notifications
  PERFORM test_set_jwt('11111111-1111-1111-1111-111111111111', 'admin');
  INSERT INTO rls_test_results
  SELECT * FROM run_test(
    'Admin can view all notifications',
    'SELECT count(*) FROM public.notifications',
    true
  );
  
  PERFORM test_clear_jwt();
END $$;

-- =====================================================================
-- AUDIT_LOGS TABLE TESTS
-- =====================================================================

DO $$
BEGIN
  RAISE NOTICE '=== TESTING AUDIT_LOGS TABLE ===';
  
  -- Test 22: Student can view own audit logs
  PERFORM test_set_jwt('33333333-3333-3333-3333-333333333333', 'student');
  INSERT INTO rls_test_results
  SELECT * FROM run_test(
    'Student can view own audit logs',
    'SELECT count(*) FROM public.audit_logs WHERE user_id = ''33333333-3333-3333-3333-333333333333''',
    true
  );
  
  -- Test 23: Student cannot view others audit logs
  INSERT INTO rls_test_results
  SELECT * FROM run_test(
    'Student cannot view others audit logs',
    'SELECT count(*) FROM public.audit_logs WHERE user_id != ''33333333-3333-3333-3333-333333333333''',
    false
  );
  
  -- Test 24: Admin can view all audit logs
  PERFORM test_set_jwt('11111111-1111-1111-1111-111111111111', 'admin');
  INSERT INTO rls_test_results
  SELECT * FROM run_test(
    'Admin can view all audit logs',
    'SELECT count(*) FROM public.audit_logs',
    true
  );
  
  PERFORM test_clear_jwt();
END $$;

-- =====================================================================
-- CROSS-DEPARTMENT ISOLATION TESTS
-- =====================================================================

DO $$
BEGIN
  RAISE NOTICE '=== TESTING CROSS-DEPARTMENT ISOLATION ===';
  
  -- Test 25: Chemistry staff cannot access Physics department items
  PERFORM test_set_jwt('22222222-2222-2222-2222-222222222222', 'staff');
  INSERT INTO rls_test_results
  SELECT * FROM run_test(
    'Chemistry staff cannot access Physics items',
    'SELECT count(*) FROM public.items WHERE department_id = ''33333333-3333-3333-3333-333333333333''',
    false
  );
  
  -- Test 26: Physics staff cannot access Chemistry department items
  PERFORM test_set_jwt('55555555-5555-5555-5555-555555555555', 'staff');
  INSERT INTO rls_test_results
  SELECT * FROM run_test(
    'Physics staff cannot access Chemistry items',
    'SELECT count(*) FROM public.items WHERE department_id = ''22222222-2222-2222-2222-222222222222''',
    false
  );
  
  -- Test 27: Admin can access all departments
  PERFORM test_set_jwt('11111111-1111-1111-1111-111111111111', 'admin');
  INSERT INTO rls_test_results
  SELECT * FROM run_test(
    'Admin can access all departments',
    'SELECT count(*) FROM public.departments',
    true
  );
  
  PERFORM test_clear_jwt();
END $$;

-- =====================================================================
-- TEST RESULTS SUMMARY
-- =====================================================================

-- Display test results
SELECT 
  test_name,
  result,
  expected,
  passed,
  CASE WHEN passed THEN '✓ PASS' ELSE '✗ FAIL' END as status
FROM rls_test_results
ORDER BY test_name;

-- Summary statistics
SELECT 
  COUNT(*) as total_tests,
  COUNT(CASE WHEN passed THEN 1 END) as passed_tests,
  COUNT(CASE WHEN NOT passed THEN 1 END) as failed_tests,
  CASE 
    WHEN COUNT(CASE WHEN NOT passed THEN 1 END) = 0 THEN 'ALL TESTS PASSED ✓'
    ELSE 'SOME TESTS FAILED ✗'
  END as overall_status
FROM rls_test_results;

-- =====================================================================
-- CLEANUP
-- =====================================================================

-- Drop test functions
DROP FUNCTION IF EXISTS test_set_jwt(uuid, text);
DROP FUNCTION IF EXISTS test_clear_jwt();
DROP FUNCTION IF EXISTS run_test(text, text, boolean);

-- Drop test results table
DROP TABLE IF EXISTS rls_test_results;