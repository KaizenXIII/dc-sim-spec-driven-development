# ADR-005: inotify + Docker Events for Drift Detection

**Status:** Accepted
**Date:** 2026-02-22
**Deciders:** DatacenterOS Team

---

## Context

SPEC-080 requires the drift detector to compare desired state (NetBox) against actual state (sim-engine + in-node configuration). Two detection strategies were evaluated:

1. **Polling** — A cron job runs every N minutes, queries sim-engine for current state, diffs against CMDB, and records deltas.
2. **Event-driven (inotify + Docker events)** — In-node file watchers (`inotifywait`) detect config file changes in real time; the Docker daemon event stream detects container lifecycle changes. Both publish to Redis Streams.

---

## Decision

**Use inotify file watchers inside sim node containers + Docker daemon event stream for container lifecycle changes.**

No scheduled polling. On-demand reconciliation available via `POST /drift/reconcile`.

---

## Rationale

| Criterion | Polling (5-min interval) | inotify + Docker events |
|-----------|------------------------|------------------------|
| Detection latency | Up to 5 minutes | Seconds |
| CPU load | Burst every 5 min (queries all CIs) | Near-zero (kernel-level notifications) |
| False negatives | Changes that revert within interval are invisible | None — every change is recorded |
| Complexity | Simple cron + diff loop | Requires drift-agent in each sim container |
| Scalability | O(n) CI queries per interval | O(1) per change event |
| Real-time dashboard | Stale by up to 5 min | Live updates |

For a simulation platform demonstrating SRE practices, **real-time drift detection** is a core feature — a 5-minute lag undermines the realism of the demo.

---

## Implementation

### Docker Event Stream (infrastructure drift)
`sim-engine` subscribes to the Docker daemon event stream:
```
docker events --filter type=container --format json
```
Events published to Redis Streams channel `vm.power_changed`, `network.changed`.

### inotify Drift Agent (in-node configuration drift)
A minimal `drift-agent` script runs inside each sim node container:
```bash
inotifywait -m -r /etc/ssh /etc/sysctl.conf /etc/sudoers \
  --format '{"path":"%w%f","event":"%e"}' \
  | while read -r event; do
      redis-cli -h redis XADD drift.file_changed '*' payload "$event" ci_id "$HOSTNAME"
    done
```

The agent is installed via the Ansible `sim_monitoring` role during node bootstrap.

### Ansible Facts Collector (package / compliance drift)
`ansible-runner` runs `collect-facts.yml` on a schedule (e.g., every 15 minutes for package baseline checks). Facts are pushed to NetBox; the drift module diffs them against the desired state tags.

---

## Consequences

**Positive:**
- Near-real-time drift detection (seconds vs minutes).
- Kernel-level `inotify` is extremely efficient — no busy polling.
- Docker event stream is already available in `sim-engine` context.
- Redis Streams provide persistent event log for replaying missed events.

**Negative:**
- `drift-agent` must be installed and running in every sim node container (adds ~2 MB + `inotify-tools` package).
- Redis must be reachable from inside sim node containers (requires network configuration).
- Agent failure inside a node silently stops file-change detection for that node.

**Mitigation:**
- `drift-agent` is installed by the `sim_monitoring` Ansible role — bootstrapped as part of the node provisioning playbook.
- `core-api` monitors `ansible.heartbeat` Redis events per node; missing heartbeat after N seconds raises a monitoring alert.
- `POST /drift/reconcile` provides fallback full sweep if agent gaps are suspected.
