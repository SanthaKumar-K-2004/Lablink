# LabLink Audit & History Logging

This guide explains how LabLink captures audit information, maintains historical records, and exposes administrator workflows for compliance and forensic analysis.

## Audit Architecture

| Component | Purpose |
|-----------|---------|
| `audit_logs` | Immutable log capturing every INSERT/UPDATE/DELETE with before/after snapshots |
| `item_history` | Versioned snapshots of item data per change |
| `borrow_history` | Borrow request lifecycle entries (submitted ➝ approved ➝ returned) |
| `department_history` | Tracks department budget/head changes |
| `inventory_change_history` | Tracks stock movements (borrow, return, usage, damage, maintenance, adjustments) |
| `cost_tracking` | Budget accountability for purchases, repairs, maintenance, replacements |
| `admin_actions_log` | Records all administrator actions (user management, imports, settings) |
| `user_login_history` | Captures login/logout/failure events for security |

### audit_logs Table
- **Trigger coverage**: users, departments, categories, items, borrow_requests, issued_items, damage_reports, maintenance_records, chemical_usage_logs, notifications, cost_tracking, admin_actions_log.
- **Change summary**: Auto-generated text list of modified columns (`column: old -> new`).
- **Immutability**: BEFORE UPDATE/DELETE trigger raises exception to protect past entries.
- **Retention**: `retention_until` defaults to `current_date + 7 years`, enabling policy-based cleanup.

### Versioning & Snapshots
- **Items**: `before update` trigger increments `version_number` and writes to `item_history`. `after insert` trigger seeds initial snapshot.
- **Borrow Requests**: Initial submit and each status change log entries to `borrow_history`.
- **Departments**: `after insert` + `after update` triggers log budget/head changes.
- **Inventory**: `inventory_change_history` records all availability/total quantity changes, plus chemical usage consumption.

### Role-Validated Logging
Trigger helpers enforce role rules:
- Students can submit borrow requests and are `created_by` by default.
- Issued items ensure borrower is student, issuer is staff/admin.
- Maintenance assignments require technician assignee and staff/admin assigner.
- Admin actions require admin_id with role `admin`.

### QR & Integrity
- QR hashes are generated via `generate_qr_hash` using JWT secrets.
- `assign_qr_hash` ensures QR payloads are stamped consistently at insert time.

## Forensic Workflow
1. **Find entity history**
   ```sql
   select *
   from public.audit_logs
   where entity_type = 'items'
     and entity_id = '...'
   order by timestamp desc;
   ```
2. **Check item versions**
   ```sql
   select version_number, modified_at, modified_by, name, status
   from public.item_history
   where item_id = '...'
   order by version_number desc;
   ```
3. **View stock movements**
   ```sql
   select change_type, quantity_before, quantity_after, reason, changed_at
   from public.inventory_change_history
   where item_id = '...'
   order by changed_at desc;
   ```
4. **Borrow lifecycle**
   ```sql
   select status_change, previous_status, new_status, changed_by, changed_at
   from public.borrow_history
   where borrow_request_id = '...'
   order by changed_at;
   ```

## Automated Metrics
- Department budgets update automatically from `cost_tracking` entries.
- `item_count` recalculated after each item insert/update/delete.
- User metrics (`total_borrows`, `overdue_items`) refreshed through triggers on borrow_requests & issued_items.
- `inventory_change_history` stores numeric quantities with precision for chemicals and assets.

## Best Practices for Administrators
- Use `admin_actions_log` when performing bulk imports, role changes, or settings updates.
- Reference `user_login_history` to investigate suspicious login attempts.
- Leverage `inventory_change_history` for reconciling inventory counts after audits.
- Query `audit_logs` for compliance audits or to trace unauthorized changes.

## Retention & Cleanup
- All history tables are append-only, providing full traceability.
- `audit_logs.retention_until` enables scheduled cleanup while meeting 7-year policy.
- Soft deletes (`is_deleted`) preserve records without removing references, ensuring audit continuity.

## Related Files
- `supabase/migrations/001_initial_schema.sql`
- `supabase/migrations/002_audit_schema.sql`
- `supabase/migrations/003_seed_data.sql`
- `docs/DATA_RETENTION.md`
