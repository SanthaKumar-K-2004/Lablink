-- LabLink Phase 1: Seed Data for Testing & Admin Review
-- Part 3: Sample data with complete historical examples

begin;

-- =====================================================================
-- SEED: USERS
-- =====================================================================
insert into public.users (id, email, password_hash, full_name, role, status, phone_number, is_email_verified, last_login, last_password_change, created_at)
values
  ('11111111-1111-1111-1111-111111111111', 'admin@lablink.edu', '$2a$10$abcdefghijklmnopqrstuv', 'Dr. Sarah Chen', 'admin', 'active', '+1234567890', true, now() - interval '1 day', now() - interval '30 days', now() - interval '90 days'),
  ('22222222-2222-2222-2222-222222222222', 'staff1@lablink.edu', '$2a$10$abcdefghijklmnopqrstuv', 'Mike Johnson', 'staff', 'active', '+1234567891', true, now() - interval '2 days', now() - interval '60 days', now() - interval '85 days'),
  ('33333333-3333-3333-3333-333333333333', 'staff2@lablink.edu', '$2a$10$abcdefghijklmnopqrstuv', 'Emily Rodriguez', 'staff', 'active', '+1234567892', true, now() - interval '1 hour', now() - interval '45 days', now() - interval '80 days'),
  ('44444444-4444-4444-4444-444444444444', 'tech1@lablink.edu', '$2a$10$abcdefghijklmnopqrstuv', 'David Lee', 'technician', 'active', '+1234567893', true, now() - interval '3 days', now() - interval '90 days', now() - interval '75 days'),
  ('55555555-5555-5555-5555-555555555555', 'student1@lablink.edu', '$2a$10$abcdefghijklmnopqrstuv', 'Alice Williams', 'student', 'active', '+1234567894', true, now() - interval '5 hours', now() - interval '120 days', now() - interval '70 days'),
  ('66666666-6666-6666-6666-666666666666', 'student2@lablink.edu', '$2a$10$abcdefghijklmnopqrstuv', 'Bob Martinez', 'student', 'active', '+1234567895', true, now() - interval '12 hours', now() - interval '100 days', now() - interval '65 days'),
  ('77777777-7777-7777-7777-777777777777', 'student3@lablink.edu', '$2a$10$abcdefghijklmnopqrstuv', 'Carol Thompson', 'student', 'active', '+1234567896', true, now() - interval '2 days', now() - interval '110 days', now() - interval '60 days'),
  ('88888888-8888-8888-8888-888888888888', 'student4@lablink.edu', '$2a$10$abcdefghijklmnopqrstuv', 'Daniel Brown', 'student', 'active', '+1234567897', true, now() - interval '1 day', now() - interval '95 days', now() - interval '55 days'),
  ('99999999-9999-9999-9999-999999999999', 'tech2@lablink.edu', '$2a$10$abcdefghijklmnopqrstuv', 'Emma Davis', 'technician', 'active', '+1234567898', true, now() - interval '4 days', now() - interval '85 days', now() - interval '50 days'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'student5@lablink.edu', '$2a$10$abcdefghijklmnopqrstuv', 'Frank Wilson', 'student', 'suspended', '+1234567899', true, now() - interval '15 days', now() - interval '105 days', now() - interval '45 days')
on conflict (id) do nothing;

-- =====================================================================
-- SEED: DEPARTMENTS
-- =====================================================================
insert into public.departments (id, name, head_user_id, contact_email, phone, location, budget_allocated, budget_spent, created_by, created_at)
values
  ('d1111111-1111-1111-1111-111111111111', 'Chemistry Department', '22222222-2222-2222-2222-222222222222', 'chemistry@lablink.edu', '+1234561000', 'Building A, Floor 2', 150000.00, 45000.00, '11111111-1111-1111-1111-111111111111', now() - interval '180 days'),
  ('d2222222-2222-2222-2222-222222222222', 'Physics Department', '33333333-3333-3333-3333-333333333333', 'physics@lablink.edu', '+1234562000', 'Building B, Floor 3', 200000.00, 78000.00, '11111111-1111-1111-1111-111111111111', now() - interval '175 days'),
  ('d3333333-3333-3333-3333-333333333333', 'Biology Department', null, 'biology@lablink.edu', '+1234563000', 'Building C, Floor 1', 175000.00, 52000.00, '11111111-1111-1111-1111-111111111111', now() - interval '170 days'),
  ('d4444444-4444-4444-4444-444444444444', 'Engineering Lab', '22222222-2222-2222-2222-222222222222', 'engineering@lablink.edu', '+1234564000', 'Building D, Floor 4', 250000.00, 95000.00, '11111111-1111-1111-1111-111111111111', now() - interval '165 days'),
  ('d5555555-5555-5555-5555-555555555555', 'Computer Science Lab', null, 'cslab@lablink.edu', '+1234565000', 'Building E, Floor 2', 180000.00, 67000.00, '11111111-1111-1111-1111-111111111111', now() - interval '160 days')
on conflict (id) do nothing;

-- =====================================================================
-- SEED: CATEGORIES
-- =====================================================================
insert into public.categories (id, name, parent_category_id, icon, color, description, low_stock_threshold, created_by, created_at)
values
  ('c1111111-1111-1111-1111-111111111111', 'Laboratory Equipment', null, 'microscope', '#3B82F6', 'General laboratory equipment and instruments', 3, '11111111-1111-1111-1111-111111111111', now() - interval '150 days'),
  ('c2222222-2222-2222-2222-222222222222', 'Chemicals', null, 'beaker', '#EF4444', 'Chemical substances and reagents', 5, '11111111-1111-1111-1111-111111111111', now() - interval '148 days'),
  ('c3333333-3333-3333-3333-333333333333', 'Glassware', 'c1111111-1111-1111-1111-111111111111', 'flask', '#10B981', 'Laboratory glassware and containers', 10, '11111111-1111-1111-1111-111111111111', now() - interval '145 days'),
  ('c4444444-4444-4444-4444-444444444444', 'Safety Equipment', null, 'shield', '#F59E0B', 'Safety gear and protective equipment', 5, '11111111-1111-1111-1111-111111111111', now() - interval '140 days'),
  ('c5555555-5555-5555-5555-555555555555', 'Electronic Components', null, 'chip', '#8B5CF6', 'Electronic parts and components', 20, '11111111-1111-1111-1111-111111111111', now() - interval '135 days'),
  ('c6666666-6666-6666-6666-666666666666', 'Measurement Tools', 'c1111111-1111-1111-1111-111111111111', 'ruler', '#06B6D4', 'Measuring instruments and tools', 5, '11111111-1111-1111-1111-111111111111', now() - interval '130 days'),
  ('c7777777-7777-7777-7777-777777777777', 'Organic Chemicals', 'c2222222-2222-2222-2222-222222222222', 'molecule', '#DC2626', 'Organic chemical compounds', 3, '11111111-1111-1111-1111-111111111111', now() - interval '125 days')
on conflict (id) do nothing;

-- =====================================================================
-- SEED: ITEMS (QR hash will be auto-generated by trigger)
-- =====================================================================
insert into public.items (id, name, category_id, department_id, description, serial_number, model_number, brand, storage_location, supplier_name, purchase_date, purchase_price, warranty_expiry, status, total_quantity, expiry_date, safety_level, hazard_type, created_by, created_at)
values
  ('i1111111-1111-1111-1111-111111111111', 'Digital Microscope', 'c1111111-1111-1111-1111-111111111111', 'd1111111-1111-1111-1111-111111111111', 'High-resolution digital microscope with 1000x magnification', 'MS-2023-001', 'DM-1000X', 'LabTech Pro', 'Lab A - Shelf 3', 'Scientific Supplies Inc', '2023-01-15', 3500.00, '2026-01-15', 'available', 5, null, 'low', null, '11111111-1111-1111-1111-111111111111', now() - interval '120 days'),
  ('i2222222-2222-2222-2222-222222222222', 'Acetone', 'c7777777-7777-7777-7777-777777777777', 'd1111111-1111-1111-1111-111111111111', 'Pure acetone for laboratory use', 'CHEM-2023-042', 'ACE-500ML', 'ChemPure', 'Chemical Storage Room A', 'Chemical Solutions Ltd', '2023-06-01', 45.00, null, 'available', 20, '2024-12-31', 'high', 'flammable', '11111111-1111-1111-1111-111111111111', now() - interval '110 days'),
  ('i3333333-3333-3333-3333-333333333333', 'Safety Goggles', 'c4444444-4444-4444-4444-444444444444', 'd2222222-2222-2222-2222-222222222222', 'Impact-resistant safety goggles', 'SAF-2023-015', 'SG-200', 'SafetyFirst', 'Safety Equipment Cabinet', 'Safety Gear Co', '2023-03-20', 25.00, null, 'available', 50, null, 'low', null, '11111111-1111-1111-1111-111111111111', now() - interval '105 days'),
  ('i4444444-4444-4444-4444-444444444444', 'Oscilloscope', 'c5555555-5555-5555-5555-555555555555', 'd2222222-2222-2222-2222-222222222222', '4-channel digital oscilloscope', 'OSC-2023-008', 'DS-4000', 'TekScope', 'Electronics Lab - Station 5', 'Electronics World', '2023-02-10', 5200.00, '2026-02-10', 'borrowed', 3, null, 'low', null, '11111111-1111-1111-1111-111111111111', now() - interval '100 days'),
  ('i5555555-5555-5555-5555-555555555555', 'pH Meter', 'c6666666-6666-6666-6666-666666666666', 'd3333333-3333-3333-3333-333333333333', 'Digital pH meter with calibration kit', 'PH-2023-022', 'PM-300', 'MeasureTech', 'Lab B - Bench 2', 'Lab Instruments Inc', '2023-04-05', 450.00, '2025-04-05', 'available', 8, null, 'low', null, '11111111-1111-1111-1111-111111111111', now() - interval '95 days'),
  ('i6666666-6666-6666-6666-666666666666', 'Hydrochloric Acid', 'c2222222-2222-2222-2222-222222222222', 'd1111111-1111-1111-1111-111111111111', 'Concentrated HCl solution 37%', 'CHEM-2023-088', 'HCL-1L', 'ChemPure', 'Chemical Storage Room A', 'Chemical Solutions Ltd', '2023-07-15', 35.00, null, 'available', 15, '2025-06-30', 'high', 'corrosive', '11111111-1111-1111-1111-111111111111', now() - interval '90 days'),
  ('i7777777-7777-7777-7777-777777777777', 'Centrifuge', 'c1111111-1111-1111-1111-111111111111', 'd3333333-3333-3333-3333-333333333333', 'High-speed laboratory centrifuge', 'CENT-2023-005', 'C-5000', 'SpinLab', 'Lab C - Station 1', 'Lab Equipment Plus', '2023-05-20', 2800.00, '2026-05-20', 'maintenance', 4, null, 'medium', null, '11111111-1111-1111-1111-111111111111', now() - interval '85 days'),
  ('i8888888-8888-8888-8888-888888888888', 'Beaker Set 250ml', 'c3333333-3333-3333-3333-333333333333', 'd1111111-1111-1111-1111-111111111111', 'Borosilicate glass beakers 250ml', 'GLASS-2023-031', 'BK-250', 'GlassWorks', 'Glassware Cabinet A', 'Science Glass Co', '2023-03-10', 120.00, null, 'available', 30, null, 'low', null, '11111111-1111-1111-1111-111111111111', now() - interval '80 days'),
  ('i9999999-9999-9999-9999-999999999999', 'Arduino Starter Kit', 'c5555555-5555-5555-5555-555555555555', 'd5555555-5555-5555-5555-555555555555', 'Complete Arduino development kit', 'ARD-2023-012', 'UNO-KIT', 'Arduino', 'CS Lab - Locker 3', 'Tech Components', '2023-08-01', 65.00, null, 'available', 25, null, 'low', null, '11111111-1111-1111-1111-111111111111', now() - interval '75 days'),
  ('iaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Spectrophotometer', 'c1111111-1111-1111-1111-111111111111', 'd3333333-3333-3333-3333-333333333333', 'UV-Vis spectrophotometer', 'SPEC-2023-003', 'SP-2000', 'SpectraLab', 'Lab C - Bench 5', 'Analytical Instruments', '2023-01-20', 6500.00, '2026-01-20', 'available', 2, null, 'low', null, '11111111-1111-1111-1111-111111111111', now() - interval '70 days'),
  ('ibbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Ethanol 95%', 'c7777777-7777-7777-7777-777777777777', 'd3333333-3333-3333-3333-333333333333', 'Laboratory grade ethanol', 'CHEM-2023-055', 'ETH-1L', 'ChemPure', 'Chemical Storage Room B', 'Chemical Solutions Ltd', '2023-06-10', 28.00, null, 'available', 18, '2025-05-31', 'medium', 'flammable', '11111111-1111-1111-1111-111111111111', now() - interval '65 days'),
  ('icccccc-cccc-cccc-cccc-cccccccccccc', 'Power Supply Unit', 'c5555555-5555-5555-5555-555555555555', 'd4444444-4444-4444-4444-444444444444', 'Variable DC power supply 0-30V', 'PSU-2023-019', 'PS-3000', 'PowerTech', 'Engineering Lab - Station 2', 'Electronics World', '2023-04-15', 380.00, '2025-04-15', 'available', 10, null, 'low', null, '11111111-1111-1111-1111-111111111111', now() - interval '60 days'),
  ('idddddd-dddd-dddd-dddd-dddddddddddd', 'Lab Coat', 'c4444444-4444-4444-4444-444444444444', 'd1111111-1111-1111-1111-111111111111', 'White laboratory coat size L', 'SAF-2023-028', 'LC-L', 'LabWear', 'Safety Equipment Cabinet', 'Safety Gear Co', '2023-05-05', 35.00, null, 'available', 40, null, 'low', null, '11111111-1111-1111-1111-111111111111', now() - interval '55 days'),
  ('ieeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'Bunsen Burner', 'c1111111-1111-1111-1111-111111111111', 'd1111111-1111-1111-1111-111111111111', 'Natural gas laboratory burner', 'BURN-2023-010', 'BB-100', 'FlameLab', 'Lab A - Station 4', 'Lab Equipment Plus', '2023-02-28', 85.00, null, 'available', 12, null, 'medium', 'open flame', '11111111-1111-1111-1111-111111111111', now() - interval '50 days'),
  ('iffffff-ffff-ffff-ffff-ffffffffffff', 'Multimeter', 'c6666666-6666-6666-6666-666666666666', 'd4444444-4444-4444-4444-444444444444', 'Digital multimeter with auto-ranging', 'MM-2023-025', 'DM-500', 'MeasureTech', 'Engineering Lab - Tool Cabinet', 'Electronics World', '2023-06-20', 95.00, '2025-06-20', 'damaged', 15, null, 'low', null, '11111111-1111-1111-1111-111111111111', now() - interval '45 days')
on conflict (id) do nothing;

-- =====================================================================
-- SEED: BORROW REQUESTS
-- =====================================================================
insert into public.borrow_requests (id, item_id, student_id, requested_start_date, requested_end_date, purpose, status, approved_by, approved_date, created_by, created_at)
values
  ('b1111111-1111-1111-1111-111111111111', 'i4444444-4444-4444-4444-444444444444', '55555555-5555-5555-5555-555555555555', current_date - interval '10 days', current_date + interval '5 days', 'Electronics project - signal analysis', 'approved', '22222222-2222-2222-2222-222222222222', now() - interval '9 days', '55555555-5555-5555-5555-555555555555', now() - interval '10 days'),
  ('b2222222-2222-2222-2222-222222222222', 'i1111111-1111-1111-1111-111111111111', '66666666-6666-6666-6666-666666666666', current_date + interval '2 days', current_date + interval '7 days', 'Biology lab experiment - cell observation', 'pending', null, null, '66666666-6666-6666-6666-666666666666', now() - interval '2 days'),
  ('b3333333-3333-3333-3333-333333333333', 'i5555555-5555-5555-5555-555555555555', '77777777-7777-7777-7777-777777777777', current_date - interval '5 days', current_date + interval '2 days', 'Chemistry experiment - solution pH testing', 'approved', '33333333-3333-3333-3333-333333333333', now() - interval '4 days', '77777777-7777-7777-7777-777777777777', now() - interval '5 days'),
  ('b4444444-4444-4444-4444-444444444444', 'iaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '88888888-8888-8888-8888-888888888888', current_date - interval '20 days', current_date - interval '15 days', 'Research project - UV spectroscopy', 'returned', '22222222-2222-2222-2222-222222222222', now() - interval '19 days', '88888888-8888-8888-8888-888888888888', now() - interval '20 days'),
  ('b5555555-5555-5555-5555-555555555555', 'i9999999-9999-9999-9999-999999999999', '55555555-5555-5555-5555-555555555555', current_date + interval '5 days', current_date + interval '12 days', 'IoT project development', 'rejected', '33333333-3333-3333-3333-333333333333', now() - interval '1 day', '55555555-5555-5555-5555-555555555555', now() - interval '3 days')
on conflict (id) do nothing;

-- =====================================================================
-- SEED: ISSUED ITEMS
-- =====================================================================
insert into public.issued_items (id, item_id, issued_to, issued_by, borrow_request_id, issued_date, due_date, condition_at_issue, status, is_overdue, created_at)
values
  ('is111111-1111-1111-1111-111111111111', 'i4444444-4444-4444-4444-444444444444', '55555555-5555-5555-5555-555555555555', '22222222-2222-2222-2222-222222222222', 'b1111111-1111-1111-1111-111111111111', now() - interval '9 days', current_date + interval '5 days', 'good', 'active', false, now() - interval '9 days'),
  ('is222222-2222-2222-2222-222222222222', 'i5555555-5555-5555-5555-555555555555', '77777777-7777-7777-7777-777777777777', '33333333-3333-3333-3333-333333333333', 'b3333333-3333-3333-3333-333333333333', now() - interval '4 days', current_date + interval '2 days', 'good', 'active', false, now() - interval '4 days'),
  ('is333333-3333-3333-3333-333333333333', 'iaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '88888888-8888-8888-8888-888888888888', '22222222-2222-2222-2222-222222222222', 'b4444444-4444-4444-4444-444444444444', now() - interval '19 days', current_date - interval '15 days', 'good', 'returned', false, now() - interval '19 days')
on conflict (id) do nothing;

-- Update returned item
update public.issued_items
set returned_date = now() - interval '14 days', condition_at_return = 'good', return_notes = 'Item returned in excellent condition'
where id = 'is333333-3333-3333-3333-333333333333';

-- =====================================================================
-- SEED: DAMAGE REPORTS
-- =====================================================================
insert into public.damage_reports (id, item_id, damage_type, severity, description, reported_by, reported_date, status, estimated_repair_cost, created_at)
values
  ('dr111111-1111-1111-1111-111111111111', 'iffffff-ffff-ffff-ffff-ffffffffffff', 'broken', 'moderate', 'Display screen cracked, buttons still functional', '66666666-6666-6666-6666-666666666666', now() - interval '7 days', 'approved', 45.00, now() - interval '7 days'),
  ('dr222222-2222-2222-2222-222222222222', 'i7777777-7777-7777-7777-777777777777', 'malfunction', 'severe', 'Motor not spinning, unusual noise detected', '44444444-4444-4444-4444-444444444444', now() - interval '12 days', 'in_progress', 350.00, now() - interval '12 days')
on conflict (id) do nothing;

-- =====================================================================
-- SEED: MAINTENANCE RECORDS
-- =====================================================================
insert into public.maintenance_records (id, item_id, damage_report_id, assigned_to, assigned_by, assigned_date, reason, maintenance_type, status, repair_cost, labor_hours, created_at)
values
  ('mr111111-1111-1111-1111-111111111111', 'iffffff-ffff-ffff-ffff-ffffffffffff', 'dr111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444', '22222222-2222-2222-2222-222222222222', now() - interval '6 days', 'Replace damaged display screen', 'repair', 'assigned', 45.00, 2.0, now() - interval '6 days'),
  ('mr222222-2222-2222-2222-222222222222', 'i7777777-7777-7777-7777-777777777777', 'dr222222-2222-2222-2222-222222222222', '99999999-9999-9999-9999-999999999999', '22222222-2222-2222-2222-222222222222', now() - interval '11 days', 'Diagnose and repair centrifuge motor', 'repair', 'in_progress', 350.00, 5.5, now() - interval '11 days'),
  ('mr333333-3333-3333-3333-333333333333', 'i1111111-1111-1111-1111-111111111111', null, '44444444-4444-4444-4444-444444444444', '22222222-2222-2222-2222-222222222222', now() - interval '30 days', 'Routine calibration and cleaning', 'routine', 'completed', 0.00, 1.5, now() - interval '30 days')
on conflict (id) do nothing;

-- Update completed maintenance
update public.maintenance_records
set start_date = now() - interval '29 days', completion_date = now() - interval '28 days', status = 'completed', repair_notes = 'Calibration successful, all systems functioning normally'
where id = 'mr333333-3333-3333-3333-333333333333';

-- =====================================================================
-- SEED: CHEMICAL USAGE LOGS
-- =====================================================================
insert into public.chemical_usage_logs (id, item_id, quantity_used, usage_date, used_by, experiment_purpose, quantity_remaining, created_at)
values
  ('cu111111-1111-1111-1111-111111111111', 'i2222222-2222-2222-2222-222222222222', 0.5, now() - interval '15 days', '77777777-7777-7777-7777-777777777777', 'Organic chemistry experiment - solvent extraction', 19.5, now() - interval '15 days'),
  ('cu222222-2222-2222-2222-222222222222', 'i6666666-6666-6666-6666-666666666666', 0.1, now() - interval '10 days', '55555555-5555-5555-5555-555555555555', 'Acid-base titration experiment', 14.9, now() - interval '10 days'),
  ('cu333333-3333-3333-3333-333333333333', 'ibbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 0.25, now() - interval '8 days', '66666666-6666-6666-6666-666666666666', 'DNA extraction lab', 17.75, now() - interval '8 days'),
  ('cu444444-4444-4444-4444-444444444444', 'i2222222-2222-2222-2222-222222222222', 0.3, now() - interval '5 days', '88888888-8888-8888-8888-888888888888', 'Chemical synthesis - cleaning glassware', 19.2, now() - interval '5 days')
on conflict (id) do nothing;

-- =====================================================================
-- SEED: NOTIFICATIONS
-- =====================================================================
insert into public.notifications (id, user_id, type, title, message, priority, read, created_at)
values
  ('n1111111-1111-1111-1111-111111111111', '55555555-5555-5555-5555-555555555555', 'approval', 'Borrow Request Approved', 'Your request for Oscilloscope has been approved', 'high', true, now() - interval '9 days'),
  ('n2222222-2222-2222-2222-222222222222', '77777777-7777-7777-7777-777777777777', 'reminder', 'Return Reminder', 'pH Meter is due for return in 2 days', 'medium', false, now() - interval '1 day'),
  ('n3333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222', 'damage', 'New Damage Report', 'Multimeter has been reported damaged by Bob Martinez', 'high', false, now() - interval '7 days'),
  ('n4444444-4444-4444-4444-444444444444', '44444444-4444-4444-4444-444444444444', 'maintenance', 'Maintenance Assigned', 'You have been assigned to repair Multimeter', 'medium', true, now() - interval '6 days'),
  ('n5555555-5555-5555-5555-555555555555', '55555555-5555-5555-5555-555555555555', 'alert', 'Request Rejected', 'Your request for Arduino Starter Kit has been rejected - Insufficient availability', 'medium', false, now() - interval '1 day')
on conflict (id) do nothing;

-- =====================================================================
-- SEED: USER LOGIN HISTORY
-- =====================================================================
insert into public.user_login_history (user_id, login_time, logout_time, session_duration_minutes, ip_address, device_type, login_status)
values
  ('11111111-1111-1111-1111-111111111111', now() - interval '1 day', now() - interval '23 hours', 60, '192.168.1.100', 'web', 'success'),
  ('22222222-2222-2222-2222-222222222222', now() - interval '2 days', now() - interval '47 hours', 45, '192.168.1.101', 'web', 'success'),
  ('55555555-5555-5555-5555-555555555555', now() - interval '5 hours', null, null, '192.168.1.105', 'mobile', 'success'),
  ('66666666-6666-6666-6666-666666666666', now() - interval '12 hours', now() - interval '11 hours', 55, '192.168.1.106', 'web', 'success'),
  ('77777777-7777-7777-7777-777777777777', now() - interval '2 days', now() - interval '47 hours', 32, '192.168.1.107', 'tablet', 'success'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now() - interval '16 days', null, null, '192.168.1.110', 'web', 'account_locked')
on conflict do nothing;

-- =====================================================================
-- SEED: COST TRACKING
-- =====================================================================
insert into public.cost_tracking (department_id, cost_type, amount, related_item_id, fiscal_year, recorded_by, recorded_at)
values
  ('d1111111-1111-1111-1111-111111111111', 'purchase', 3500.00, 'i1111111-1111-1111-1111-111111111111', 2023, '11111111-1111-1111-1111-111111111111', now() - interval '120 days'),
  ('d2222222-2222-2222-2222-222222222222', 'purchase', 5200.00, 'i4444444-4444-4444-4444-444444444444', 2023, '11111111-1111-1111-1111-111111111111', now() - interval '100 days'),
  ('d1111111-1111-1111-1111-111111111111', 'repair', 45.00, 'iffffff-ffff-ffff-ffff-ffffffffffff', 2024, '22222222-2222-2222-2222-222222222222', now() - interval '6 days'),
  ('d3333333-3333-3333-3333-333333333333', 'repair', 350.00, 'i7777777-7777-7777-7777-777777777777', 2024, '22222222-2222-2222-2222-222222222222', now() - interval '11 days'),
  ('d3333333-3333-3333-3333-333333333333', 'purchase', 6500.00, 'iaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 2023, '11111111-1111-1111-1111-111111111111', now() - interval '70 days')
on conflict do nothing;

-- =====================================================================
-- SEED: ADMIN ACTIONS LOG
-- =====================================================================
insert into public.admin_actions_log (admin_id, action_type, description, affected_entity_type, affected_entity_ids, action_timestamp, success)
values
  ('11111111-1111-1111-1111-111111111111', 'department_created', 'Created new department: Chemistry Department', 'departments', array['d1111111-1111-1111-1111-111111111111']::uuid[], now() - interval '180 days', true),
  ('11111111-1111-1111-1111-111111111111', 'user_created', 'Created staff account for Mike Johnson', 'users', array['22222222-2222-2222-2222-222222222222']::uuid[], now() - interval '85 days', true),
  ('11111111-1111-1111-1111-111111111111', 'user_role_changed', 'Changed user role from student to staff', 'users', array['33333333-3333-3333-3333-333333333333']::uuid[], now() - interval '60 days', true),
  ('11111111-1111-1111-1111-111111111111', 'bulk_import', 'Imported 15 items from Excel spreadsheet', 'items', array['i1111111-1111-1111-1111-111111111111', 'i2222222-2222-2222-2222-222222222222']::uuid[], now() - interval '45 days', true)
on conflict do nothing;

commit;
