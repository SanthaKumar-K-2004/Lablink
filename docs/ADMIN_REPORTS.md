# LabLink Admin Reports & Dashboard Views

This document describes the views and queries available to administrators for monitoring, compliance, and reporting.

## Overview

LabLink provides four comprehensive SQL views designed for administrative dashboards and reporting:

1. **admin_dashboard_snapshot** – Real-time system overview
2. **user_activity_summary** – Per-user compliance and activity metrics
3. **item_movement_audit** – Complete item lifecycle with history
4. **financial_summary** – Department-level budget analysis

All views use computed fields and aggregate functions for performance, providing instant insights without complex joins at query time.

---

## 1. admin_dashboard_snapshot

**Purpose**: Executive dashboard for system health, usage, and alert metrics.

**Returns**: Single row with 5 JSONB fields:

### inventory_overview
```json
{
  "total_items": 350,
  "available_items": 298,
  "borrowed_items": 32,
  "damaged_items": 12,
  "maintenance_items": 8,
  "low_stock_items": 5
}
```

### department_breakdown
Array of department metrics:
```json
[
  {
    "department_id": "...",
    "department_name": "Chemistry Department",
    "item_count": 120,
    "budget_allocated": 150000.00,
    "budget_spent": 45000.00,
    "budget_remaining": 105000.00,
    "active_borrows": 15,
    "open_damage_reports": 3
  }
]
```

### staff_performance
Staff activity metrics:
```json
[
  {
    "staff_id": "...",
    "full_name": "Mike Johnson",
    "role": "staff",
    "approvals": 85,
    "rejections": 12,
    "damage_approvals": 7
  }
]
```

### student_activity
Student compliance overview:
```json
[
  {
    "student_id": "...",
    "full_name": "Alice Williams",
    "total_borrows": 23,
    "overdue_items": 0,
    "pending_requests": 1,
    "active_overdue": 0
  }
]
```

### chemical_status
Chemical safety metrics:
```json
{
  "hazardous_items": 45,
  "hazardous_low_stock": 3,
  "expiring_soon": 8,
  "low_risk_items": 156,
  "usage_last_30_days": 67
}
```

**Usage**:
```sql
select * from public.admin_dashboard_snapshot;
```

**Use Cases**:
- Executive dashboard widget
- Alerting system (low stock, expiring chemicals)
- Performance monitoring
- Compliance reporting

---

## 2. user_activity_summary

**Purpose**: Detailed user activity, login patterns, and compliance metrics.

**Columns**:
- `id`, `full_name`, `email`, `role`, `status`
- `primary_department` – First department from department_ids array
- `last_login` – Most recent successful login
- `total_borrows` – Lifetime borrow request count
- `overdue_items` – Current overdue item count
- `login_count_this_month` – Successful logins this month
- `failed_logins_this_month` – Failed login attempts this month
- `items_issued` – (For staff) Items issued to students
- `approvals_made` – (For staff) Borrow requests approved
- `damage_reports_filed` – Damage reports submitted
- `active_overdue_items` – Currently overdue borrows

**Usage**:
```sql
-- Find users with failed logins this month
select full_name, email, failed_logins_this_month
from public.user_activity_summary
where failed_logins_this_month > 3
order by failed_logins_this_month desc;

-- Staff performance report
select full_name, role, approvals_made, items_issued
from public.user_activity_summary
where role in ('staff', 'admin')
order by approvals_made desc;

-- Students with overdue items
select full_name, email, overdue_items, active_overdue_items
from public.user_activity_summary
where role = 'student' and overdue_items > 0
order by overdue_items desc;
```

**Use Cases**:
- User compliance dashboards
- Security monitoring (failed logins)
- Staff workload analysis
- Student accountability tracking

---

## 3. item_movement_audit

**Purpose**: Complete item lifecycle with movement history, maintenance, and cost tracking.

**Columns**:
- `item_id`, `name`, `serial_number`, `status`
- `total_quantity`, `available_count`, `is_low_stock`
- `department_name`, `category_name`
- `movement_history` – JSONB array of inventory changes
- `current_borrow_status` – JSONB array of active borrows
- `maintenance_history` – JSONB array of maintenance records
- `cost_history` – JSONB array of costs

**Movement History Example**:
```json
[
  {
    "change_type": "borrow",
    "quantity_before": 10,
    "quantity_after": 9,
    "quantity_changed": -1,
    "reason": "Item issued to borrower",
    "changed_at": "2024-03-15T14:30:00Z",
    "changed_by": "..."
  }
]
```

**Usage**:
```sql
-- Items with frequent damage reports
select name, serial_number,
       jsonb_array_length(maintenance_history) as maintenance_count
from public.item_movement_audit
where maintenance_history is not null
order by maintenance_count desc
limit 20;

-- High-cost items
select name, department_name,
       (select sum((c->>'amount')::numeric) from jsonb_array_elements(cost_history) c) as total_cost
from public.item_movement_audit
where cost_history is not null
order by total_cost desc;

-- Currently borrowed items
select name, serial_number, current_borrow_status
from public.item_movement_audit
where current_borrow_status is not null
  and jsonb_array_length(current_borrow_status) > 0;
```

**Use Cases**:
- Item lifecycle analysis
- High-wear item identification
- Cost allocation reporting
- Borrowing pattern analysis

---

## 4. financial_summary

**Purpose**: Department budget tracking and cost breakdown.

**Columns**:
- `department_id`, `department_name`
- `budget_allocated`, `budget_spent`, `budget_remaining`
- `purchases` – Total purchase costs
- `repairs` – Total repair costs
- `maintenance` – Total maintenance costs
- `replacements` – Total replacement costs
- `total_items` – Item count in department
- `maintenance_in_progress` – Active maintenance count

**Usage**:
```sql
-- Budget utilization report
select department_name,
       budget_allocated,
       budget_spent,
       budget_remaining,
       round(100.0 * budget_spent / nullif(budget_allocated, 0), 2) as utilization_percent
from public.financial_summary
order by utilization_percent desc;

-- Cost breakdown by type
select department_name,
       purchases,
       repairs,
       maintenance,
       replacements,
       purchases + repairs + maintenance + replacements as total_costs
from public.financial_summary
order by total_costs desc;

-- Departments over budget
select department_name, budget_remaining
from public.financial_summary
where budget_remaining < 0
order by budget_remaining;

-- Maintenance workload
select department_name, maintenance_in_progress, total_items
from public.financial_summary
where maintenance_in_progress > 0
order by maintenance_in_progress desc;
```

**Use Cases**:
- Budget compliance monitoring
- Fiscal year reporting
- Cost forecasting
- Maintenance workload planning

---

## Advanced Query Examples

### Cross-View Analytics

**Top borrowers with overdue history**:
```sql
select u.full_name,
       u.total_borrows,
       u.overdue_items,
       u.active_overdue_items
from public.user_activity_summary u
where u.role = 'student'
order by u.overdue_items desc, u.total_borrows desc
limit 10;
```

**Items with high maintenance costs**:
```sql
select ima.name,
       ima.department_name,
       fs.maintenance as dept_maintenance_total,
       (select sum((c->>'amount')::numeric)
        from jsonb_array_elements(ima.cost_history) c
        where c->>'cost_type' = 'maintenance') as item_maintenance_cost
from public.item_movement_audit ima
join public.financial_summary fs on fs.department_name = ima.department_name
where ima.cost_history is not null
order by item_maintenance_cost desc nulls last
limit 20;
```

**Department efficiency (borrows per item)**:
```sql
select d.name,
       d.item_count,
       count(br.id) as total_borrow_requests,
       round(count(br.id)::numeric / nullif(d.item_count, 0), 2) as borrows_per_item
from public.departments d
left join public.items i on i.department_id = d.id
left join public.borrow_requests br on br.item_id = i.id
where not d.is_deleted
group by d.id
order by borrows_per_item desc;
```

---

## Export Recommendations

For large dataset exports:

1. **CSV Export**:
   ```sql
   copy (
     select * from public.user_activity_summary
   ) to '/tmp/user_activity.csv' with csv header;
   ```

2. **JSON Export**:
   ```sql
   copy (
     select jsonb_agg(to_jsonb(ads))
     from public.admin_dashboard_snapshot ads
   ) to '/tmp/dashboard.json';
   ```

3. **Paginated Queries**:
   ```sql
   select * from public.item_movement_audit
   order by item_id
   limit 100 offset 0;
   ```

---

## Performance Notes

- All views use indexed columns for filtering (status, timestamps, user_id, item_id).
- JSONB aggregation columns are computed on-demand; consider caching for high-frequency dashboards.
- For real-time dashboards, query views directly; for scheduled reports, materialize to temp tables.
- Views exclude soft-deleted records (`is_deleted = false`) automatically.

---

## Related Documentation

- [SCHEMA.md](./SCHEMA.md) – Complete table structure
- [AUDIT_LOGGING.md](./AUDIT_LOGGING.md) – History and audit tables
- [QUERY_EXAMPLES.md](./QUERY_EXAMPLES.md) – More SQL examples
- [DATA_RETENTION.md](./DATA_RETENTION.md) – Retention policies
