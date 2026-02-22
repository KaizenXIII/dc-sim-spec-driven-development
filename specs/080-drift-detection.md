# SPEC-080: Drift Detection

**Status:** Draft
**Author:** DatacenterOS Team
**Created:** 2026-02-22
**GitHub Issue:** #10
**Depends on:** SPEC-050, SPEC-110

---

## Summary

The drift-detector service continuously compares the **desired state** (CMDB / Ansible configs) against the **actual state** (sim-engine) and surfaces deviations as drift events. Detected drift triggers ITSM change requests and/or Ansible remediation runs.

---

## Drift Detection Model

```
Desired State (CMDB / Git)
         │
         ▼
   Drift Detector ──── compares ────> Actual State (sim-engine)
         │
         ▼
   Drift Events
   ├── emit to event bus
   ├── create ITSM change request
   └── optionally trigger Ansible remediation
```

---

## Drift Categories

| Category | Example |
|----------|---------|
| **Configuration drift** | VM CPU count changed outside of approved process |
| **Package drift** | Package installed that is not in approved baseline |
| **Network drift** | VM connected to unexpected VLAN |
| **State drift** | VM powered off but CMDB says it should be running |
| **Security drift** | Firewall rule added that is not in policy |
| **Firmware drift** | Blade running firmware not matching UCS policy |

---

## Detection Cycle

1. **Collect desired state** from CMDB (CI attributes + Ansible inventory/vars).
2. **Collect actual state** from sim-engine (`GET /sim/state`).
3. **Diff** the two state representations.
4. For each delta:
   - Record drift event with: `ci_id`, `field`, `desired_value`, `actual_value`, `detected_at`.
   - Emit `drift.detected` event on event bus.
   - Create ITSM change request if `auto_change_request = true` in drift policy.
   - Trigger Ansible remediation if `auto_remediate = true` in drift policy.

**Cycle interval:** Configurable, default 5 minutes.

---

## Drift Policies

```json
{
  "id": "policy-vm-config-drift",
  "name": "VM Configuration Drift",
  "ci_type": "vm",
  "monitored_fields": ["power_state", "cpu_count", "memory_mb", "network"],
  "severity": "high",
  "auto_change_request": true,
  "auto_remediate": false,
  "notify": ["ops-team@example.com"]
}
```

---

## API Endpoints

```
# Drift Events
GET    /drift/events                  List drift events (filterable by status, ci, category)
GET    /drift/events/{id}             Get drift event details
POST   /drift/events/{id}/acknowledge Acknowledge drift (suppress alerts)
POST   /drift/events/{id}/remediate   Trigger Ansible remediation for this drift

# Policies
GET    /drift/policies                List drift policies
POST   /drift/policies                Create policy
PATCH  /drift/policies/{id}           Update policy

# Reports
GET    /drift/report                  Summary: drift count by CI type, category, severity
GET    /drift/report/timeline         Drift events over time (for dashboard charts)
```

---

## Remediation Flow

```
drift.detected event
       │
       ▼
drift-detector checks policy.auto_remediate
       │
   YES │                  NO │
       ▼                     ▼
Trigger Ansible          Create ITSM CRQ
remediation playbook     (manual remediation)
       │
       ▼
Re-check actual state
       │
   RESOLVED │         STILL DRIFTED │
       ▼                    ▼
Close drift event     Escalate to incident
```

---

## Open Questions

- [ ] How granular should field-level diffing be for JSONB CI attributes?
- [ ] Drift suppression: allow approved deviations (exceptions) in v1?
- [ ] Real-time drift via event stream vs. polling? → Polling v1, events v2.
