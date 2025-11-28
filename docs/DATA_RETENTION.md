# LabLink Data Retention & Compliance Policy

This document outlines LabLink's data retention strategy, aligned with institutional and regulatory requirements (e.g., lab safety compliance, audit readiness). The policy is enforced through database design, immutable logs, and explicit retention timestamps.

## Summary of Retention Periods

| Data Domain | Tables / Views | Retention Policy | Notes |
|-------------|----------------|------------------|-------|
| **Audit Logs** | `audit_logs` | 7 years (configured via `retention_until`) | Immutable, append-only; deletions require compliance approval |
| **Inventory History** | `item_history`, `inventory_change_history`, `item_movement_audit` | Indefinite | Supports traceability for equipment lifecycle |
| **Borrow Lifecycle** | `borrow_requests`, `borrow_history`, `issued_items` | Indefinite (soft delete) | Historical borrow data required for safety & accountability |
| **Maintenance & Damage** | `maintenance_records`, `damage_reports`, `department_history` | Indefinite | Required for insurance & safety audits |
| **Budget / Finance** | `cost_tracking`, `financial_summary` | 7+ years (institutional standard) | Supports fiscal audits; cleanup only after export |
| **Security** | `user_login_history`, `admin_actions_log` | 5 years minimum | Tracks login attempts, admin actions |
| **Notifications** | `notifications` | 1 year (cleanup job recommended) | Operational data; safe to purge after expiration |
| **Soft-Deleted Data** | All tables with `is_deleted` | Never physically removed by default | Maintains referential integrity, accessible for audits |

## Enforcement Mechanisms

1. **Immutable Tables**: `audit_logs` protected by BEFORE UPDATE/DELETE trigger; modifications throw exceptions.
2. **Soft Deletes**: `is_deleted` flags preserve data while hiding from day-to-day queries.
3. **History Tables**: `item_history`, `department_history`, `borrow_history`, etc. capture snapshots even if base records change.
4. **Retention Timestamp**: `audit_logs.retention_until` allows scheduler jobs to remove entries after 7 years while demonstrating policy compliance.
5. **Triggers & Functions**: Automated logging ensures no manual intervention required to capture audit events.

## Recommended Cleanup Procedures

### Audit Logs (after 7 years)
```sql
delete from public.audit_logs
where retention_until < current_date
  and is_archived = true;
```
- Set `is_archived = true` after exporting logs to external storage.
- Keep exported archives in secure, redundant storage.

### Notifications
```sql
delete from public.notifications
where (expires_at is not null and expires_at < current_date - 30)
   or created_at < current_date - interval '1 year';
```

### Login History (after 5 years)
```sql
delete from public.user_login_history
where login_time < current_date - interval '5 years';
```

### Cost Tracking (after 7+ years)
Coordinate with finance before deleting. Export to CSV/Parquet, then:
```sql
delete from public.cost_tracking
where recorded_at < date_trunc('year', current_date) - interval '7 years';
```

## Export & Backup Recommendations

- **Audit Archives**: Export annual snapshots (CSV/JSON) to secure archive before cleanup.
- **Budget Data**: Align exports with fiscal year closing.
- **Item History**: Retain indefinitely; export only if extended analytics required.
- **Backups**: Standard nightly backups + weekly full snapshots recommended.

## Compliance Notes

- **Chain of Custody**: Inventory and borrow records are never deleted (soft delete only), ensuring full traceability.
- **Security**: Login and admin logs retained ≥5 years to support investigations.
- **Chemical Safety**: Usage logs (chemical_usage_logs) linked to inventory history; no deletions recommended.
- **Regulatory Audits**: Provide `audit_logs`, `inventory_change_history`, `item_history`, and `cost_tracking` exports as evidence.

## Scheduling Automation

Use Supabase cron / serverless jobs or CI pipelines to run cleanup scripts monthly:
1. Export & archive data exceeding retention.
2. Delete records only after successful archive validation.
3. Record cleanup actions in `admin_actions_log` for transparency.

Example pseudo-process:
```
1. Export audit logs > 7 years to storage bucket
2. Insert entry into admin_actions_log (action_type = report_generated)
3. Soft-delete vs hard-delete depending on policy
4. Document results in compliance register
```

## Incident Response

- If tampering suspected, query `audit_logs` (immutable) and `admin_actions_log` to reconstruct events.
- Preserve backups before performing cleanup or large exports.
- Coordinate with compliance officer for any data removal beyond policy.

---

**Document Owner**: LabLink Platform Team  
**Version**: 1.0  
**Last Updated**: Phase 1 Schema Release
