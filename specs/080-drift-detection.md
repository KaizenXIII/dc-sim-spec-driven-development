# SPEC-080: Drift Detection

**Status:** Draft
**Author:** DatacenterOS Team
**Created:** 2026-02-22
**GitHub Issue:** #10
**Depends on:** SPEC-050, SPEC-110

---

## Summary

The drift module continuously compares the **desired state** (NetBox CMDB / Ansible configs) against the **actual state** (sim-engine + in-node file watchers) and surfaces deviations as drift events. Detected drift triggers ITSM change requests and/or `ansible-runner` remediation runs.

The drift module is part of the `core-api` monolith (see SPEC-001) — not a standalone service.

**Resolved:** Polling vs event-driven drift detection → **inotify + Docker events** ([ADR-005](../docs/adr/ADR-005-inotify-drift.md)).

---

## Drift Detection Model

```
Desired State (NetBox / Git)
         │
         ▼
   Drift Module (core-api) ──── compares ────> Actual State
         │                                           │
         │                               ┌───────────┴────────────┐
         │                               │                        │
         │                       sim-engine events         inotify agents
         │                       (container lifecycle)     (in-node file watchers)
         │
         ▼
   Drift Events (Redis Streams: drift.detected)
   ├── emit to event bus
   ├── create ITSM change request
   └── optionally trigger ansible-runner remediation
```

---

## Detection Sources

### 1. Docker Event Stream (infrastructure drift)
`sim-engine` watches the Docker daemon event stream and publishes to Redis Streams:

| Docker event | Drift type | Example |
|-------------|-----------|---------|
| `container stop` (unexpected) | State drift | VM powered off, CMDB says it should be running |
| `container start` (unexpected) | State drift | VM booted without approved CRQ |
| `network connect/disconnect` | Network drift | Container connected to wrong Docker network |

### 2. inotify File Watchers (in-node configuration drift)
A lightweight `drift-agent` runs inside each sim node container, watching key config paths:

```
/etc/ssh/sshd_config        SSH configuration
/etc/hosts                  Hostname/DNS config
/etc/resolv.conf            DNS resolver config
/etc/sysctl.conf            Kernel parameters
/etc/sudoers                Privilege escalation policy
/etc/passwd, /etc/shadow    User accounts (security drift)
```

When a watched file changes, the agent publishes to Redis Streams:
```json
{
  "event": "drift.file_changed",
  "ci_id": "sim-vmw-vm-001",
  "path": "/etc/sshd_config",
  "diff": "<unified diff>",
  "detected_at": "2026-02-22T10:00:00Z"
}
```

**Drift agent:** minimal shell script using `inotifywait` (from `inotify-tools` package):
```bash
inotifywait -m -r /etc/ssh /etc/sysctl.conf /etc/sudoers \
  --format '{"path":"%w%f","event":"%e"}' \
  | while read -r event; do
      redis-cli -h redis XADD drift.file_changed '*' payload "$event" ci_id "$HOSTNAME"
    done
```

### 3. Ansible Facts (package and compliance drift)
`ansible-runner` runs `collect-facts.yml` on schedule, pushing gathered facts to NetBox. The drift module diffs incoming facts against the NetBox desired-state baseline to detect:
- Unauthorized packages installed
- Service state changes
- CIS benchmark regressions

---

## Drift Categories

| Category | Detection source | Example |
|----------|-----------------|---------|
| **Configuration drift** | inotify file watcher | sshd_config modified outside of Ansible |
| **Package drift** | Ansible facts | Package installed that is not in approved baseline |
| **Network drift** | Docker event stream | VM connected to unexpected Docker network |
| **State drift** | Docker event stream | VM powered off but NetBox says it should be running |
| **Security drift** | inotify + Ansible facts | /etc/sudoers modified, unauthorized user added |
| **Firmware drift** | sim-engine UCS adapter | Blade running firmware not matching UCS service profile |

---

## Detection Cycle (event-driven)

Events flow into the drift module via Redis Streams subscriptions:

1. **Receive event** from `drift.file_changed`, `vm.power_changed`, `network.changed`, or `ansible.facts_collected`.
2. **Fetch desired state** from NetBox for the affected CI.
3. **Diff** actual vs desired for the relevant fields.
4. For each delta:
   - Record drift event: `ci_id`, `field`, `desired_value`, `actual_value`, `detected_at`.
   - Emit `drift.detected` on Redis Streams.
   - Create ITSM change request if `auto_change_request = true` in drift policy.
   - Trigger `ansible-runner` remediation if `auto_remediate = true` in drift policy.

**No scheduled polling.** All detection is event-driven. Reconciliation on demand via `POST /drift/reconcile`.

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
POST   /drift/events/{id}/remediate   Trigger ansible-runner remediation for this drift

# Policies
GET    /drift/policies                List drift policies
POST   /drift/policies                Create policy
PATCH  /drift/policies/{id}           Update policy

# On-demand reconciliation
POST   /drift/reconcile               Full desired-vs-actual sweep for all CIs

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
drift module checks policy.auto_remediate
       │
   YES │                  NO │
       ▼                     ▼
POST /ansible/run        Create ITSM CRQ
(remediation playbook)   (manual remediation)
       │
       ▼
Re-check via next event or /drift/reconcile
       │
   RESOLVED │         STILL DRIFTED │
       ▼                    ▼
Close drift event     Escalate to incident
```

---

## Open Questions

- [ ] How granular should field-level diffing be for NetBox custom fields?
- [ ] Drift suppression: allow approved deviations (exceptions) in v1?
- [x] Real-time drift via event stream vs. polling? → **Event-driven via inotify + Docker events** ([ADR-005](../docs/adr/ADR-005-inotify-drift.md)).
