# SPEC-070: Patch Management

**Status:** Draft
**Author:** DatacenterOS Team
**Created:** 2026-02-22
**GitHub Issue:** #9
**Depends on:** SPEC-050, SPEC-060, SPEC-110

---

## Summary

The patch-manager service tracks patch compliance across all simulated CIs and orchestrates patch operations via Ansible. Every patch run is linked to an approved ITSM change request.

---

## Patch Compliance Model

Each CI (VM or host) has a patch state:

| Field | Description |
|-------|-------------|
| `ci_id` | Reference to CMDB CI |
| `os_type` | RHEL / Ubuntu / Windows |
| `current_patch_level` | Installed package version set or OS patch date |
| `target_patch_level` | Desired baseline (from patch policy) |
| `compliance_status` | compliant / non_compliant / unknown |
| `last_scanned` | Last time compliance was checked |
| `last_patched` | Last successful patch run |
| `pending_patches` | List of CVEs / packages with available updates |

---

## Patch Policies

A patch policy defines the baseline for a group of CIs:

```json
{
  "id": "policy-rhel9-baseline",
  "name": "RHEL 9 Monthly Baseline",
  "os_type": "rhel9",
  "schedule": "0 2 * * 0",
  "target_ci_tags": { "env": "dev", "os": "rhel9" },
  "patch_level": "2026-02",
  "pre_patch_snapshot": true,
  "reboot_required": true,
  "max_parallel": 5
}
```

---

## Patch Run Lifecycle

```
1. SCHEDULE  → Cron trigger or manual kick-off
2. PLAN      → Query CMDB for CIs matching policy tags
3. VALIDATE  → Check each CI has an approved Change Request
4. SNAPSHOT  → (If policy.pre_patch_snapshot) Create VM snapshot via sim-engine
5. EXECUTE   → Run Ansible patch playbook against target CIs
6. VERIFY    → Re-scan compliance after patching
7. REPORT    → Update CI patch state in CMDB, close Change Request
8. ALERT     → Notify via ITSM incident if any CI failed patching
```

---

## API Endpoints

```
# Compliance
GET    /patch/compliance              Dashboard: compliance % by policy/env/OS
GET    /patch/compliance/{ci_id}      CI-level patch state
POST   /patch/compliance/scan         Trigger compliance scan (all or filtered CIs)

# Policies
GET    /patch/policies                List patch policies
POST   /patch/policies                Create patch policy
PATCH  /patch/policies/{id}           Update policy
DELETE /patch/policies/{id}           Delete policy

# Patch Runs
GET    /patch/runs                    List patch runs (history)
POST   /patch/runs                    Trigger a patch run
GET    /patch/runs/{id}               Get run status and logs
POST   /patch/runs/{id}/cancel        Cancel in-progress run

# CVE / Advisories
GET    /patch/advisories              List known advisories (seeded/mock data)
GET    /patch/advisories/{cve_id}     Get CVE details and affected CIs
```

---

## Ansible Integration

Patch execution uses Ansible playbooks located in `/services/patch-manager/playbooks/`:

```
playbooks/
├── scan-compliance.yml      # Detect available updates, report back
├── patch-rhel.yml           # Apply patches on RHEL systems
├── patch-ubuntu.yml         # Apply patches on Ubuntu systems
├── reboot-managed.yml       # Rolling reboot with health checks
└── rollback-snapshot.yml    # Revert to pre-patch snapshot on failure
```

---

## Open Questions

- [ ] Mock CVE data or pull from a real advisory feed (NVD API)? → Mock seeded data for v1.
- [ ] Windows patching simulation in v1? → Deferred.
- [ ] Pre-patch snapshot rollback: auto-trigger on failure or manual? → Policy-driven.
