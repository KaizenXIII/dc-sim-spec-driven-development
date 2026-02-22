# SPEC-060: ITSM (IT Service Management)

**Status:** Draft
**Author:** DatacenterOS Team
**Created:** 2026-02-22
**GitHub Issue:** #8
**Depends on:** SPEC-050

---

## Summary

The ITSM service provides incident, problem, and change management workflows for the simulated datacenter. It integrates with the CMDB for CI impact analysis and with the observability stack for alert-to-incident correlation.

---

## ITSM Modules

### 1. Incident Management
Tracks unplanned service disruptions.

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Unique incident ID |
| `title` | string | Short description |
| `severity` | enum | P1 / P2 / P3 / P4 |
| `status` | enum | open / in_progress / resolved / closed |
| `affected_cis` | CI[] | Linked CMDB CIs |
| `assigned_to` | string | Owner/team |
| `created_at` | datetime | Auto |
| `resolved_at` | datetime | Set on resolution |
| `root_cause` | string | Post-resolution RCA |

### 2. Problem Management
Tracks recurring or root-cause issues behind multiple incidents.

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | |
| `title` | string | |
| `linked_incidents` | Incident[] | Related incidents |
| `status` | enum | investigating / known_error / resolved |
| `workaround` | string | Temporary fix documented |

### 3. Change Management
Tracks planned changes to the environment (infra changes, patches, config updates).

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Change request ID (CRQ) |
| `title` | string | |
| `type` | enum | standard / normal / emergency |
| `status` | enum | draft / pending_approval / approved / in_progress / completed / failed |
| `affected_cis` | CI[] | CIs impacted by this change |
| `risk` | enum | low / medium / high |
| `rollback_plan` | string | |
| `scheduled_at` | datetime | Maintenance window start |

---

## API Endpoints

```
# Incidents
GET    /itsm/incidents              List incidents (filterable by status, severity)
POST   /itsm/incidents              Create incident
GET    /itsm/incidents/{id}         Get incident
PATCH  /itsm/incidents/{id}         Update incident (status, assignment, RCA)
POST   /itsm/incidents/{id}/resolve Resolve incident

# Problems
GET    /itsm/problems               List problems
POST   /itsm/problems               Create problem
PATCH  /itsm/problems/{id}          Update problem

# Changes
GET    /itsm/changes                List change requests
POST   /itsm/changes                Create change request
PATCH  /itsm/changes/{id}           Update CRQ
POST   /itsm/changes/{id}/approve   Approve change
POST   /itsm/changes/{id}/execute   Mark as in progress
POST   /itsm/changes/{id}/complete  Mark as completed
```

---

## Integrations

| Integration | Behavior |
|-------------|---------|
| CMDB | CI lookup + impact analysis on incident/change create |
| Observability | Alert → auto-create incident via webhook |
| Drift Detector | Drift event → auto-create change request |
| Patch Manager | Patch run → linked change request required |

---

## Automation Rules

- **Alert → Incident:** When observability fires a P1/P2 alert, auto-create an incident with linked CIs.
- **Drift → Change:** When drift is detected, suggest or auto-create a change request for remediation.
- **Patch → Change:** Patch operations require a linked, approved change request (enforced by patch-manager).

---

## Open Questions

- [ ] Approval workflow: single approver or multi-stage CAB (Change Advisory Board) model?
- [ ] Integrate with external ITSM (ServiceNow webhook)? → Stretch goal.
- [ ] SLA tracking (e.g., P1 must be resolved in 4h)? → v2.
