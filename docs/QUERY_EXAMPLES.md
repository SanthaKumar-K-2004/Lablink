# LabLink SQL Query Examples

This document provides practical SQL queries for administrators and developers working with the LabLink database. Examples cover common reporting needs, forensic analysis, and operational tasks.

## Table of Contents
1. [Inventory Queries](#inventory-queries)
2. [Borrowing & Returns](#borrowing--returns)
3. [Maintenance & Damage](#maintenance--damage)
4. [User Management](#user-management)
5. [Budget & Costs](#budget--costs)
6. [Audit & History](#audit--history)
7. [Chemical Safety](#chemical-safety)
8. [Performance Queries](#performance-queries)

---

## Inventory Queries

### Items Below Low Stock Threshold
```sql
select i.name,
       i.serial_number,
       i.available_count,
       i.low_stock_threshold_value,
       c.name as category,
       d.name as department
from public.items i
join public.categories c on c.id = i.category_id
join public.departments d on d.id = i.department_id
where i.is_low_stock
  and not i.is_deleted
order by i.available_count;
```

### Items Never Borrowed
```sql
select i.id,
       i.name,
       i.serial_number,
       i.purchase_date,
       i.purchase_price,
       d.name as department
from public.items i
join public.departments d on d.id = i.department_id
where not exists (
  select 1 from public.borrow_requests br where br.item_id = i.id
)
and not i.is_deleted
order by i.purchase_date;
```

### Most Frequently Borrowed Items
```sql
select i.name,
       i.serial_number,
       count(br.id) as borrow_count,
       d.name as department
from public.items i
join public.borrow_requests br on br.item_id = i.id
join public.departments d on d.id = i.department_id
where not i.is_deleted
group by i.id, d.name
order by borrow_count desc
limit 20;
```

### Items Expiring Soon (Within 30 Days)
```sql
select i.name,
       i.serial_number,
       i.expiry_date,
       i.days_until_expiry,
       i.safety_level,
       i.hazard_type,
       d.name as department
from public.items i
join public.departments d on d.id = i.department_id
where i.expiry_date is not null
  and i.expiry_date <= current_date + 30
  and not i.is_deleted
order by i.expiry_date;
```

### Items by Status Distribution
```sql
select d.name as department,
       i.status,
       count(*) as item_count,
       sum(i.total_quantity) as total_quantity
from public.items i
join public.departments d on d.id = i.department_id
where not i.is_deleted
group by d.name, i.status
order by d.name, i.status;
```

---

## Borrowing & Returns

### Overdue Items
```sql
select ii.id,
       i.name as item_name,
       i.serial_number,
       u.full_name as borrower,
       u.email,
       ii.due_date,
       ii.days_overdue,
       ii.issued_date
from public.issued_items ii
join public.items i on i.id = ii.item_id
join public.users u on u.id = ii.issued_to
where ii.is_overdue
  and ii.status = 'active'
order by ii.days_overdue desc;
```

### Pending Borrow Requests
```sql
select br.id,
       i.name as item_name,
       u.full_name as student,
       u.email,
       br.requested_start_date,
       br.requested_end_date,
       br.purpose,
       br.created_at
from public.borrow_requests br
join public.items i on i.id = br.item_id
join public.users u on u.id = br.student_id
where br.status = 'pending'
order by br.created_at;
```

### Average Borrow Duration
```sql
select i.name,
       i.serial_number,
       avg(extract(day from (ii.returned_date - ii.issued_date))) as avg_borrow_days,
       count(*) as total_borrows
from public.issued_items ii
join public.items i on i.id = ii.item_id
where ii.returned_date is not null
group by i.id
having count(*) >= 5
order by avg_borrow_days desc;
```

### Request Approval Rate by Staff
```sql
select s.full_name as staff_member,
       count(*) filter (where br.status = 'approved') as approved,
       count(*) filter (where br.status = 'rejected') as rejected,
       count(*) as total_reviewed,
       round(100.0 * count(*) filter (where br.status = 'approved') / nullif(count(*), 0), 2) as approval_rate
from public.users s
left join public.borrow_requests br on br.approved_by = s.id
where s.role in ('staff', 'admin')
  and not s.is_deleted
group by s.id
having count(*) > 0
order by total_reviewed desc;
```

---

## Maintenance & Damage

### Items Currently in Maintenance
```sql
select i.name,
       i.serial_number,
       mr.maintenance_type,
       mr.status,
       mr.assigned_date,
       mr.estimated_completion,
       u.full_name as technician,
       mr.reason
from public.maintenance_records mr
join public.items i on i.id = mr.item_id
join public.users u on u.id = mr.assigned_to
where mr.status in ('assigned', 'in_progress')
order by mr.assigned_date;
```

### Damage Reports Awaiting Approval
```sql
select dr.id,
       i.name as item_name,
       i.serial_number,
       dr.damage_type,
       dr.severity,
       dr.description,
       u.full_name as reported_by,
       dr.reported_date,
       dr.estimated_repair_cost
from public.damage_reports dr
join public.items i on i.id = dr.item_id
join public.users u on u.id = dr.reported_by
where dr.status = 'pending'
order by dr.severity desc, dr.reported_date;
```

### Maintenance Cost Summary by Item
```sql
select i.name,
       i.serial_number,
       count(mr.id) as maintenance_count,
       sum(coalesce(mr.repair_cost, 0) + coalesce(mr.parts_cost, 0)) as total_maintenance_cost,
       max(mr.completion_date) as last_maintenance
from public.items i
left join public.maintenance_records mr on mr.item_id = i.id
where not i.is_deleted
group by i.id
having count(mr.id) > 0
order by total_maintenance_cost desc;
```

### High-Maintenance Items (> 3 Repairs)
```sql
select i.name,
       i.serial_number,
       d.name as department,
       count(mr.id) as repair_count,
       string_agg(distinct mr.maintenance_type::text, ', ') as maintenance_types
from public.items i
join public.maintenance_records mr on mr.item_id = i.id
join public.departments d on d.id = i.department_id
where mr.maintenance_type = 'repair'
group by i.id, d.name
having count(mr.id) > 3
order by repair_count desc;
```

---

## User Management

### Inactive Users (No Login in 90 Days)
```sql
select u.id,
       u.full_name,
       u.email,
       u.role,
       u.last_login,
       extract(day from (current_timestamp - u.last_login)) as days_since_login
from public.users u
where u.last_login < current_timestamp - interval '90 days'
  and u.status = 'active'
  and not u.is_deleted
order by u.last_login;
```

### Users with Multiple Failed Logins
```sql
select u.full_name,
       u.email,
       u.role,
       count(*) as failed_attempts,
       max(ulh.login_time) as last_failed_attempt
from public.user_login_history ulh
join public.users u on u.id = ulh.user_id
where ulh.login_status != 'success'
  and ulh.login_time >= current_date - interval '7 days'
group by u.id
having count(*) >= 3
order by failed_attempts desc;
```

### User Activity Heatmap (Logins by Hour of Day)
```sql
select extract(hour from ulh.login_time) as hour_of_day,
       count(*) as login_count
from public.user_login_history ulh
where ulh.login_status = 'success'
  and ulh.login_time >= current_date - 30
group by hour_of_day
order by hour_of_day;
```

### Top Students by Borrow Count
```sql
select u.full_name,
       u.email,
       count(br.id) as total_requests,
       count(*) filter (where br.status = 'approved') as approved,
       count(*) filter (where br.status = 'rejected') as rejected
from public.users u
join public.borrow_requests br on br.student_id = u.id
where u.role = 'student'
  and not u.is_deleted
group by u.id
order by total_requests desc
limit 20;
```

---

## Budget & Costs

### Department Budget Utilization
```sql
select d.name as department,
       d.budget_allocated,
       d.budget_spent,
       d.budget_remaining,
       round(100.0 * d.budget_spent / nullif(d.budget_allocated, 0), 2) as utilization_percent,
       case
         when d.budget_spent > d.budget_allocated then 'OVER BUDGET'
         when d.budget_spent > 0.9 * d.budget_allocated then 'WARNING'
         else 'OK'
       end as status
from public.departments d
where not d.is_deleted
order by utilization_percent desc;
```

### Monthly Spending Trend
```sql
select date_trunc('month', ct.recorded_at) as month,
       d.name as department,
       ct.cost_type,
       sum(ct.amount) as total_amount
from public.cost_tracking ct
join public.departments d on d.id = ct.department_id
where ct.recorded_at >= current_date - interval '12 months'
group by month, d.name, ct.cost_type
order by month desc, d.name, ct.cost_type;
```

### Top 10 Most Expensive Items
```sql
select i.name,
       i.serial_number,
       i.purchase_price,
       coalesce(sum(ct.amount), 0) as lifetime_maintenance_cost,
       i.purchase_price + coalesce(sum(ct.amount), 0) as total_cost_of_ownership
from public.items i
left join public.cost_tracking ct on ct.related_item_id = i.id
where not i.is_deleted
group by i.id
order by total_cost_of_ownership desc nulls last
limit 10;
```

### Annual Cost Breakdown by Department
```sql
select d.name as department,
       extract(year from ct.recorded_at) as fiscal_year,
       sum(case when ct.cost_type = 'purchase' then ct.amount else 0 end) as purchases,
       sum(case when ct.cost_type = 'repair' then ct.amount else 0 end) as repairs,
       sum(case when ct.cost_type = 'maintenance' then ct.amount else 0 end) as maintenance,
       sum(case when ct.cost_type = 'replacement' then ct.amount else 0 end) as replacements,
       sum(ct.amount) as total_costs
from public.cost_tracking ct
join public.departments d on d.id = ct.department_id
group by d.name, fiscal_year
order by d.name, fiscal_year desc;
```

---

## Audit & History

### Recent Changes to Items
```sql
select al.timestamp,
       u.full_name as changed_by,
       al.action,
       al.entity_name as item_name,
       al.changes_summary
from public.audit_logs al
left join public.users u on u.id = al.user_id
where al.entity_type = 'items'
  and al.timestamp >= current_timestamp - interval '7 days'
order by al.timestamp desc
limit 50;
```

### Item Version History
```sql
select ih.version_number,
       ih.name,
       ih.status,
       ih.total_quantity,
       u.full_name as modified_by,
       ih.modification_reason,
       ih.modified_at
from public.item_history ih
left join public.users u on u.id = ih.modified_by
where ih.item_id = 'ITEM_ID_HERE'
order by ih.version_number desc;
```

### Inventory Changes Timeline
```sql
select ich.changed_at,
       ich.change_type,
       ich.quantity_before,
       ich.quantity_after,
       ich.quantity_changed,
       ich.reason,
       u.full_name as changed_by
from public.inventory_change_history ich
left join public.users u on u.id = ich.changed_by
where ich.item_id = 'ITEM_ID_HERE'
order by ich.changed_at desc;
```

### Borrow Request Lifecycle
```sql
select bh.changed_at,
       bh.previous_status,
       bh.new_status,
       u.full_name as changed_by,
       bh.reason,
       bh.notes
from public.borrow_history bh
left join public.users u on u.id = bh.changed_by
where bh.borrow_request_id = 'REQUEST_ID_HERE'
order by bh.changed_at;
```

### Admin Actions Report
```sql
select aal.action_timestamp,
       u.full_name as admin,
       aal.action_type,
       aal.description,
       aal.success
from public.admin_actions_log aal
join public.users u on u.id = aal.admin_id
where aal.action_timestamp >= current_date - interval '30 days'
order by aal.action_timestamp desc;
```

---

## Chemical Safety

### Chemicals Expiring Within 60 Days
```sql
select i.name as chemical,
       i.serial_number,
       i.expiry_date,
       i.days_until_expiry,
       i.safety_level,
       i.hazard_type,
       i.total_quantity,
       i.storage_location,
       d.name as department
from public.items i
join public.departments d on d.id = i.department_id
where i.expiry_date is not null
  and i.expiry_date <= current_date + 60
  and not i.is_deleted
order by i.expiry_date;
```

### Hazardous Materials Inventory
```sql
select i.name,
       i.serial_number,
       i.safety_level,
       i.hazard_type,
       i.total_quantity,
       i.available_count,
       i.storage_location,
       d.name as department
from public.items i
join public.departments d on d.id = i.department_id
where (i.safety_level in ('medium', 'high') or i.hazard_type is not null)
  and not i.is_deleted
order by i.safety_level desc, i.name;
```

### Chemical Usage by Student
```sql
select u.full_name as student,
       i.name as chemical,
       cul.quantity_used,
       cul.usage_date,
       cul.experiment_purpose
from public.chemical_usage_logs cul
join public.items i on i.id = cul.item_id
join public.users u on u.id = cul.used_by
where u.id = 'USER_ID_HERE'
order by cul.usage_date desc;
```

### Chemical Consumption Rate (Last 90 Days)
```sql
select i.name as chemical,
       i.serial_number,
       count(cul.id) as usage_events,
       sum(cul.quantity_used) as total_consumed,
       i.total_quantity as current_stock,
       round(sum(cul.quantity_used) / 90.0, 4) as avg_daily_consumption
from public.chemical_usage_logs cul
join public.items i on i.id = cul.item_id
where cul.usage_date >= current_date - 90
group by i.id
order by avg_daily_consumption desc;
```

---

## Performance Queries

### Database Growth Trends
```sql
select schemaname,
       tablename,
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
       pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size,
       pg_size_pretty(pg_indexes_size(schemaname||'.'||tablename)) as indexes_size
from pg_tables
where schemaname = 'public'
order by pg_total_relation_size(schemaname||'.'||tablename) desc;
```

### Slow Query Identification (Requires pg_stat_statements)
```sql
select calls,
       total_exec_time / 1000 as total_seconds,
       mean_exec_time / 1000 as mean_seconds,
       query
from pg_stat_statements
where dbid = (select oid from pg_database where datname = current_database())
order by mean_exec_time desc
limit 20;
```

### Index Usage Statistics
```sql
select schemaname,
       tablename,
       indexname,
       idx_scan as index_scans,
       idx_tup_read as tuples_read,
       idx_tup_fetch as tuples_fetched
from pg_stat_user_indexes
where schemaname = 'public'
order by idx_scan desc;
```

---

**Document Version**: 1.0  
**Last Updated**: Phase 1 Schema Release  
**Related Docs**: [SCHEMA.md](./SCHEMA.md), [ADMIN_REPORTS.md](./ADMIN_REPORTS.md), [AUDIT_LOGGING.md](./AUDIT_LOGGING.md)
