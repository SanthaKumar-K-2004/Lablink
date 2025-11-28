### LabLink Database Schema Documentation

This document describes the complete database schema for the LabLink Laboratory Inventory Management System, including all tables, relationships, and field descriptions.

## Entity Relationship Overview

```
┌─────────────┐
│   USERS     │
└──────┬──────┘
       │
       ├─ created_by/updated_by ──┐
       │                          │
       ├─ student_id ──┬──────────┼─────────────┐
       │               │          │             │
       │               │          │             │
┌──────▼──────┐ ┌─────▼──────┐ ┌▼────────┐ ┌──▼────────┐
│ DEPARTMENTS │ │ BORROW_REQ │ │  ITEMS  │ │ ISSUED_   │
└──────┬──────┘ └─────┬──────┘ └┬────────┘ │  ITEMS    │
       │              │         │          └───────────┘
       │              └─────────┼──────────┐
       │                        │          │
       │         ┌──────────────┘          │
       │         │                         │
┌──────▼─────────▼──┐         ┌───────────▼──────┐
│   CATEGORIES      │         │  DAMAGE_REPORTS  │
└───────────────────┘         └─────────┬────────┘
                                        │
                              ┌─────────▼─────────┐
                              │ MAINTENANCE_RECS  │
                              └───────────────────┘

HISTORY TABLES:
- audit_logs (all changes)
- item_history (item versions)
- borrow_history (request lifecycle)
- user_login_history (auth tracking)
- inventory_change_history (stock movements)
- cost_tracking (budget audit)
- admin_actions_log (admin operations)
- department_history (department changes)
```

## Core Tables

### 1. USERS
**Purpose**: Central user management with role-based access and metrics

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK, DEFAULT gen_random_uuid() | User identifier |
| auth_user_id | UUID | UNIQUE | Link to Supabase auth.users |
| email | TEXT | NOT NULL, UNIQUE | User email address |
| password_hash | TEXT | NOT NULL | Bcrypt password hash |
| full_name | TEXT | | User's full name |
| role | user_role | NOT NULL, DEFAULT 'student' | One of: admin, staff, student, technician |
| department_ids | UUID[] | DEFAULT [] | Array of department access |
| avatar_url | TEXT | | URL to user avatar in storage |
| status | user_status | NOT NULL, DEFAULT 'active' | active, inactive, or suspended |
| phone_number | TEXT | | Contact number |
| is_email_verified | BOOLEAN | NOT NULL, DEFAULT false | Email verification status |
| last_login | TIMESTAMPTZ | | Last successful login timestamp |
| last_password_change | TIMESTAMPTZ | | Last password update |
| total_borrows | INTEGER | NOT NULL, DEFAULT 0 | Total borrow requests (computed) |
| overdue_items | INTEGER | NOT NULL, DEFAULT 0 | Current overdue count (computed) |
| is_deleted | BOOLEAN | NOT NULL, DEFAULT false | Soft delete flag |
| created_at | TIMESTAMPTZ | NOT NULL | Record creation timestamp |
| updated_at | TIMESTAMPTZ | NOT NULL | Last modification timestamp |
| created_by | UUID | FK → users(id) | User who created this record |
| updated_by | UUID | FK → users(id) | User who last updated |

**Indexes**: email, role, status, is_deleted

---

### 2. DEPARTMENTS
**Purpose**: Organizational units with budget tracking

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | Department identifier |
| name | TEXT | NOT NULL, UNIQUE | Department name |
| head_user_id | UUID | FK → users(id) | Department head |
| contact_email | TEXT | | Department contact |
| phone | TEXT | | Department phone |
| location | TEXT | | Physical location |
| budget_allocated | NUMERIC(12,2) | NOT NULL, ≥0, DEFAULT 0 | Annual budget |
| budget_spent | NUMERIC(12,2) | NOT NULL, ≥0, DEFAULT 0 | Spent amount (auto-calculated) |
| budget_remaining | NUMERIC(12,2) | GENERATED STORED | budget_allocated - budget_spent |
| item_count | INTEGER | NOT NULL, DEFAULT 0 | Item count (auto-calculated) |
| active | BOOLEAN | NOT NULL, DEFAULT true | Active status |
| is_deleted | BOOLEAN | NOT NULL, DEFAULT false | Soft delete flag |
| created_at, updated_at | TIMESTAMPTZ | NOT NULL | Timestamps |
| created_by, updated_by | UUID | FK → users(id) | Tracking fields |

**Indexes**: name, active, is_deleted

---

### 3. CATEGORIES
**Purpose**: Hierarchical item categorization

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | Category identifier |
| name | TEXT | NOT NULL, UNIQUE | Category name |
| parent_category_id | UUID | FK → categories(id) | Parent category (for nesting) |
| icon | TEXT | | Icon name for UI |
| color | TEXT | | Hex color code |
| description | TEXT | | Category description |
| low_stock_threshold | INTEGER | NOT NULL, ≥0, DEFAULT 5 | Default threshold |
| is_deleted | BOOLEAN | NOT NULL, DEFAULT false | Soft delete flag |
| created_at, updated_at | TIMESTAMPTZ | NOT NULL | Timestamps |
| created_by | UUID | FK → users(id) | Creator |

**Indexes**: name, parent_category_id, is_deleted

---

### 4. ITEMS (Core Inventory)
**Purpose**: Complete inventory tracking with versioning and computed metrics

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | Item identifier |
| name | TEXT | NOT NULL | Item name |
| category_id | UUID | NOT NULL, FK → categories(id) | Category |
| department_id | UUID | NOT NULL, FK → departments(id) | Owning department |
| description | TEXT | | Detailed description |
| serial_number | TEXT | UNIQUE | Serial/asset number |
| model_number | TEXT | | Model identifier |
| brand | TEXT | | Manufacturer/brand |
| image_url | TEXT | | URL to item image |
| storage_location | TEXT | | Physical location |
| supplier_name | TEXT | | Supplier name |
| supplier_id | TEXT | | Supplier identifier |
| purchase_date | DATE | | Date of purchase |
| purchase_price | NUMERIC(12,2) | ≥0 | Purchase cost |
| warranty_expiry | DATE | | Warranty end date |
| status | item_status | NOT NULL, DEFAULT 'available' | available, borrowed, maintenance, damaged, retired |
| total_quantity | INTEGER | NOT NULL, ≥0, DEFAULT 1 | Total stock |
| borrowed_quantity | INTEGER | NOT NULL, ≥0, DEFAULT 0 | Currently borrowed (auto-calculated) |
| damaged_quantity | INTEGER | NOT NULL, ≥0, DEFAULT 0 | Damaged units (auto-calculated) |
| maintenance_quantity | INTEGER | NOT NULL, ≥0, DEFAULT 0 | In maintenance (auto-calculated) |
| expiry_date | DATE | | Expiration date (required for chemicals) |
| safety_level | safety_level | | low, medium, high |
| hazard_type | TEXT | | Hazard classification |
| manual_url | TEXT | | Link to manual/datasheet |
| qr_hash | TEXT | NOT NULL, UNIQUE | JWT-signed QR code |
| qr_payload | JSONB | NOT NULL, DEFAULT {} | QR code data |
| low_stock_threshold_value | INTEGER | NOT NULL, ≥0, DEFAULT 5 | Threshold from category |
| available_count | INTEGER | GENERATED STORED | total_quantity - borrowed - damaged - maintenance |
| is_low_stock | BOOLEAN | GENERATED STORED | available_count < threshold |
| days_until_expiry | INTEGER | | Days until expiry |
| version_number | INTEGER | NOT NULL, DEFAULT 1 | Version for history tracking |
| is_deleted | BOOLEAN | NOT NULL, DEFAULT false | Soft delete flag |
| created_at, updated_at | TIMESTAMPTZ | NOT NULL | Timestamps |
| created_by, updated_by | UUID | FK → users(id) | Tracking fields |

**Indexes**: name, serial_number, category_id, department_id, status, expiry_date, is_deleted

---

### 5. BORROW_REQUESTS
**Purpose**: Student borrow request management with approval workflow

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | Request identifier |
| item_id | UUID | NOT NULL, FK → items(id) | Requested item |
| student_id | UUID | NOT NULL, FK → users(id) | Requesting student |
| requested_start_date | DATE | NOT NULL | Desired start date |
| requested_end_date | DATE | NOT NULL | Desired end date |
| purpose | TEXT | NOT NULL | Purpose of borrowing |
| special_requirements | TEXT | | Additional requirements |
| status | request_status | NOT NULL, DEFAULT 'pending' | pending, approved, rejected, issued, returned, cancelled |
| approved_by | UUID | FK → users(id) | Approving staff/admin |
| approved_date | TIMESTAMPTZ | | Approval timestamp |
| rejection_reason | TEXT | | Reason for rejection |
| rejection_reason_code | TEXT | | Rejection category |
| created_at, updated_at | TIMESTAMPTZ | NOT NULL | Timestamps |
| created_by | UUID | NOT NULL, FK → users(id) | Creator (usually student_id) |
| is_cancelled | BOOLEAN | NOT NULL, DEFAULT false | Cancellation flag |

**Constraints**: requested_start_date < requested_end_date
**Indexes**: item_id, student_id, status, created_at

---

### 6. ISSUED_ITEMS
**Purpose**: Active borrow tracking with condition monitoring

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | Issue identifier |
| item_id | UUID | NOT NULL, FK → items(id) | Issued item |
| issued_to | UUID | NOT NULL, FK → users(id) | Borrower (student) |
| issued_by | UUID | NOT NULL, FK → users(id) | Staff who issued |
| borrow_request_id | UUID | FK → borrow_requests(id) | Originating request |
| issued_date | TIMESTAMPTZ | NOT NULL | Issue timestamp |
| due_date | DATE | NOT NULL | Return due date |
| condition_at_issue | item_condition | NOT NULL, DEFAULT 'good' | good, fair, poor, missing_parts |
| condition_notes_at_issue | TEXT | | Condition notes |
| status | issued_item_status | NOT NULL, DEFAULT 'active' | active, returned, overdue, lost, damaged_during_use |
| returned_date | TIMESTAMPTZ | | Return timestamp |
| condition_at_return | item_condition | | Condition when returned |
| condition_notes_at_return | TEXT | | Return condition notes |
| return_notes | TEXT | | General return notes |
| is_overdue | BOOLEAN | NOT NULL, DEFAULT false | Overdue flag (auto-calculated) |
| days_overdue | INTEGER | NOT NULL, DEFAULT 0 | Days overdue (auto-calculated) |
| created_at, updated_at | TIMESTAMPTZ | NOT NULL | Timestamps |

**Indexes**: item_id, issued_to, status, due_date

---

### 7. DAMAGE_REPORTS
**Purpose**: Damage reporting and resolution tracking

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | Report identifier |
| item_id | UUID | NOT NULL, FK → items(id) | Damaged item |
| damage_type | TEXT | NOT NULL | Type of damage (broken, leaked, etc.) |
| severity | damage_severity | NOT NULL | minor, moderate, severe |
| description | TEXT | NOT NULL | Damage description |
| photos | TEXT[] | DEFAULT [], ≤5 elements | Photo URLs |
| reported_by | UUID | NOT NULL, FK → users(id) | Reporter |
| reported_date | TIMESTAMPTZ | NOT NULL | Report timestamp |
| status | damage_report_status | NOT NULL, DEFAULT 'pending' | pending, approved, rejected, in_progress, resolved |
| approved_by | UUID | FK → users(id) | Approver |
| approved_date | TIMESTAMPTZ | | Approval timestamp |
| resolution_date | TIMESTAMPTZ | | Resolution timestamp |
| resolution_notes | TEXT | | Resolution details |
| estimated_repair_cost | NUMERIC(12,2) | ≥0 | Estimated cost |
| actual_repair_cost | NUMERIC(12,2) | ≥0 | Actual cost |
| created_at, updated_at | TIMESTAMPTZ | NOT NULL | Timestamps |

**Indexes**: item_id, status, reported_by, reported_date

---

### 8. MAINTENANCE_RECORDS
**Purpose**: Maintenance and repair tracking

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | Record identifier |
| item_id | UUID | NOT NULL, FK → items(id) | Item under maintenance |
| damage_report_id | UUID | FK → damage_reports(id) | Source damage report |
| assigned_to | UUID | NOT NULL, FK → users(id) | Technician |
| assigned_by | UUID | NOT NULL, FK → users(id) | Admin/staff assigner |
| assigned_date | TIMESTAMPTZ | NOT NULL | Assignment timestamp |
| reason | TEXT | NOT NULL | Maintenance reason |
| maintenance_type | maintenance_type | NOT NULL | routine, repair, inspection, cleaning, parts_replacement |
| status | maintenance_status | NOT NULL, DEFAULT 'assigned' | assigned, in_progress, completed, on_hold, cancelled |
| start_date | TIMESTAMPTZ | | Start timestamp |
| completion_date | TIMESTAMPTZ | | Completion timestamp |
| estimated_completion | DATE | | Estimated completion |
| repair_cost | NUMERIC(12,2) | ≥0 | Repair cost |
| parts_used | TEXT | | Parts list |
| parts_cost | NUMERIC(12,2) | ≥0 | Parts cost |
| labor_hours | NUMERIC(8,2) | ≥0 | Labor hours |
| repair_notes | TEXT | | Technician notes |
| photos | TEXT[] | DEFAULT [], ≤5 elements | Photo URLs |
| quality_check_passed | BOOLEAN | | QA status |
| quality_checker_id | UUID | FK → users(id) | QA checker |
| created_at, updated_at | TIMESTAMPTZ | NOT NULL | Timestamps |

**Constraints**: start_date < completion_date (if both set)
**Indexes**: item_id, assigned_to, status, assigned_date

---

### 9. CHEMICAL_USAGE_LOGS
**Purpose**: Chemical consumption tracking

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | Log identifier |
| item_id | UUID | NOT NULL, FK → items(id) | Chemical item (must have expiry_date) |
| quantity_used | NUMERIC(12,4) | NOT NULL, >0 | Amount consumed |
| usage_date | TIMESTAMPTZ | NOT NULL | Usage timestamp |
| used_by | UUID | NOT NULL, FK → users(id) | User who used |
| experiment_purpose | TEXT | NOT NULL | Purpose/experiment |
| experiment_id | TEXT | | Experiment identifier |
| quantity_remaining | NUMERIC(12,4) | NOT NULL, ≥0 | Remaining quantity |
| storage_temperature | NUMERIC(6,2) | | Storage temperature |
| storage_notes | TEXT | | Storage notes |
| created_at | TIMESTAMPTZ | NOT NULL | Timestamp |

**Indexes**: item_id, used_by, usage_date

---

### 10. NOTIFICATIONS
**Purpose**: User notification management

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | Notification identifier |
| user_id | UUID | NOT NULL, FK → users(id) | Recipient |
| type | notification_type | NOT NULL | approval, reminder, alert, damage, maintenance |
| title | TEXT | NOT NULL | Notification title |
| message | TEXT | NOT NULL | Notification message |
| action_link | TEXT | | Deep link |
| action_data | JSONB | DEFAULT {} | Action metadata |
| read | BOOLEAN | NOT NULL, DEFAULT false | Read status |
| read_at | TIMESTAMPTZ | | Read timestamp |
| is_archived | BOOLEAN | NOT NULL, DEFAULT false | Archive status |
| priority | notification_priority | NOT NULL, DEFAULT 'medium' | low, medium, high, critical |
| created_at | TIMESTAMPTZ | NOT NULL | Creation timestamp |
| expires_at | TIMESTAMPTZ | | Expiration timestamp |

**Indexes**: user_id, read, created_at, priority

---

## History & Audit Tables

### 11. AUDIT_LOGS (Immutable)
**Purpose**: Comprehensive change tracking for all tables

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | PK, Log identifier |
| user_id | UUID | FK → users(id), Actor (null for system) |
| action | TEXT | insert, update, delete |
| entity_type | TEXT | Table name |
| entity_id | UUID | Changed record ID |
| entity_name | TEXT | Display name |
| old_values | JSONB | Before state (full record) |
| new_values | JSONB | After state (full record) |
| changes_summary | TEXT | Human-readable summary |
| ip_address | INET | Client IP |
| user_agent | TEXT | Browser/app info |
| status | audit_status | success, failed, attempted, system_generated |
| error_message | TEXT | Error details |
| request_id | UUID | Request correlation ID |
| timestamp | TIMESTAMPTZ | NOT NULL, Change timestamp |
| retention_until | DATE | DEFAULT now() + 7 years |
| is_archived | BOOLEAN | NOT NULL, DEFAULT false |

**Immutability**: UPDATE/DELETE triggers prevent modification
**Indexes**: timestamp, user_id, entity_type, entity_id, action, request_id

---

### 12. ITEM_HISTORY
**Purpose**: Versioned snapshots of item changes

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | PK |
| item_id | UUID | NOT NULL, FK → items(id) |
| version_number | INTEGER | NOT NULL |
| name, category_id, department_id, serial_number, ... | | Copy of item fields |
| modified_by | UUID | FK → users(id) |
| modification_reason | TEXT | Change reason |
| modified_at | TIMESTAMPTZ | NOT NULL |

**Constraint**: UNIQUE(item_id, version_number)
**Indexes**: item_id, modified_at

---

### 13. BORROW_HISTORY
**Purpose**: Request lifecycle tracking

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | PK |
| borrow_request_id | UUID | NOT NULL, FK → borrow_requests(id) |
| student_id | UUID | NOT NULL, FK → users(id) |
| item_id | UUID | NOT NULL, FK → items(id) |
| status_change | request_status | NOT NULL |
| previous_status | TEXT | Previous status |
| new_status | TEXT | NOT NULL, New status |
| changed_by | UUID | FK → users(id) |
| reason | TEXT | Change reason |
| changed_at | TIMESTAMPTZ | NOT NULL |
| notes | TEXT | Additional notes |

**Indexes**: borrow_request_id, changed_at

---

### 14. USER_LOGIN_HISTORY
**Purpose**: Security audit trail

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | PK |
| user_id | UUID | FK → users(id) |
| login_time | TIMESTAMPTZ | NOT NULL |
| logout_time | TIMESTAMPTZ | |
| session_duration_minutes | INTEGER | |
| ip_address | INET | |
| user_agent | TEXT | |
| device_type | TEXT | mobile/web/tablet |
| login_status | login_status | NOT NULL (success, failed, account_locked, etc.) |
| failure_reason | TEXT | |
| location | TEXT | Geolocation |

**Indexes**: user_id, login_time

---

### 15. INVENTORY_CHANGE_HISTORY
**Purpose**: Stock movement tracking

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | PK |
| item_id | UUID | NOT NULL, FK → items(id) |
| change_type | inventory_change_type | NOT NULL (borrow, return, usage, damage, maintenance, import, adjustment) |
| quantity_before | NUMERIC(14,4) | NOT NULL |
| quantity_after | NUMERIC(14,4) | NOT NULL |
| quantity_changed | NUMERIC(14,4) | NOT NULL |
| reason | TEXT | Change reason |
| related_entity_id | UUID | Link to source entity |
| changed_by | UUID | FK → users(id) |
| changed_at | TIMESTAMPTZ | NOT NULL |
| notes | TEXT | |

**Indexes**: item_id, changed_at, change_type

---

### 16. COST_TRACKING
**Purpose**: Budget auditing

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | PK |
| department_id | UUID | NOT NULL, FK → departments(id) |
| cost_type | cost_type | NOT NULL (purchase, repair, maintenance, replacement) |
| amount | NUMERIC(12,2) | NOT NULL, ≥0 |
| related_item_id | UUID | FK → items(id) |
| related_maintenance_id | UUID | FK → maintenance_records(id) |
| fiscal_year | INTEGER | NOT NULL, ≥2000 |
| recorded_by | UUID | FK → users(id) |
| recorded_at | TIMESTAMPTZ | NOT NULL |
| notes | TEXT | |

**Indexes**: department_id, (department_id, fiscal_year)

---

### 17. ADMIN_ACTIONS_LOG
**Purpose**: Administrative operation audit

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | PK |
| admin_id | UUID | NOT NULL, FK → users(id), must be admin role |
| action_type | admin_action_type | NOT NULL |
| description | TEXT | NOT NULL, Action description |
| affected_entity_type | TEXT | |
| affected_entity_ids | UUID[] | NOT NULL, DEFAULT [] |
| old_config | JSONB | Previous settings |
| new_config | JSONB | New settings |
| action_timestamp | TIMESTAMPTZ | NOT NULL |
| ip_address | INET | |
| success | BOOLEAN | NOT NULL, DEFAULT true |
| error_details | TEXT | |

**Indexes**: admin_id, action_timestamp

---

### 18. DEPARTMENT_HISTORY
**Purpose**: Department change tracking

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | PK |
| department_id | UUID | NOT NULL, FK → departments(id) |
| name, head_user_id, budget_allocated, budget_spent, active, is_deleted | | Department field snapshots |
| change_summary | TEXT | |
| changed_by | UUID | FK → users(id) |
| changed_at | TIMESTAMPTZ | NOT NULL |

**Indexes**: department_id, changed_at

---

## Admin Reporting Views

### admin_dashboard_snapshot
Provides comprehensive dashboard metrics including:
- **inventory_overview**: Total items, available, borrowed, damaged, maintenance, low stock
- **department_breakdown**: Per-department metrics (items, borrows, budget, damage reports)
- **staff_performance**: Approvals, rejections, processing activity
- **student_activity**: Top borrowers, pending requests, overdue items
- **chemical_status**: Hazardous items, expiring soon, usage statistics

### user_activity_summary
User-level activity and compliance metrics:
- Login history (successes, failures this month)
- Borrowing activity (total, current, overdue)
- Actions taken (approvals, damage reports filed)
- Compliance flags

### item_movement_audit
Complete item lifecycle view with:
- Movement history (all inventory changes)
- Current borrow status
- Maintenance history
- Cost history

### financial_summary
Department budget analysis:
- Budget allocation, spent, remaining
- Cost breakdown by type (purchase, repair, maintenance, replacement)
- Inventory value
- Maintenance status

---

## Data Retention

- **Audit Logs**: 7-year retention policy (retention_until field)
- **History Tables**: Indefinite retention for compliance
- **Soft Deletes**: is_deleted flag prevents data loss
- **Immutability**: audit_logs table cannot be modified after insert

---

## Computed Fields & Automation

### Items Table
- `available_count`: Auto-computed as total_quantity - borrowed - damaged - maintenance
- `is_low_stock`: Auto-set when available_count < threshold
- `days_until_expiry`: Calculated from expiry_date

### Departments Table
- `budget_remaining`: Generated column (budget_allocated - budget_spent)
- `item_count`: Auto-updated via triggers
- `budget_spent`: Auto-calculated from cost_tracking

### Users Table
- `total_borrows`: Auto-updated from borrow_requests count
- `overdue_items`: Auto-calculated from issued_items

### Issued Items Table
- `is_overdue`: Auto-set when due_date < current_date and not returned
- `days_overdue`: Auto-calculated

---

## Trigger Automation

1. **Audit Logging**: All INSERT/UPDATE/DELETE operations logged to audit_logs
2. **Version Tracking**: Items track version_number, full history in item_history
3. **Status Changes**: Borrow request status changes logged to borrow_history
4. **Inventory Sync**: Borrowed/damaged/maintenance quantities auto-updated
5. **Budget Sync**: Department budget_spent auto-calculated from cost_tracking
6. **User Metrics**: Borrow counts and overdue items auto-updated
7. **QR Generation**: QR hash auto-generated on item creation
8. **Validation**: Role-based constraints enforced (e.g., only students can borrow)

---

## Indexes for Performance

Strategic indexes on:
- Primary lookups (email, serial_number, names)
- Foreign keys (all relationships)
- Status fields (for filtering)
- Timestamps (for sorting/range queries)
- Composite indexes for common queries (department_id + fiscal_year)

---

## Custom Types (Enums)

- user_role, user_status
- item_status, item_condition
- request_status, issued_item_status
- damage_severity, damage_report_status
- maintenance_type, maintenance_status
- safety_level, notification_priority, notification_type
- audit_status, login_status
- inventory_change_type, cost_type, admin_action_type

---

**Document Version**: 1.0  
**Last Updated**: Phase 1 Implementation  
**Migration Files**: 001_initial_schema.sql, 002_audit_schema.sql, 003_seed_data.sql
