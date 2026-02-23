# SPEC-120: Glass Pane Dashboard (UI)

**Status:** Draft
**Author:** DatacenterOS Team
**Created:** 2026-02-22
**GitHub Issue:** #14
**Depends on:** SPEC-001, SPEC-050, SPEC-060, SPEC-080, SPEC-090

---

## Summary

The Glass Pane is the single-pane-of-glass web dashboard for the dc-sim platform. It provides a unified view of the simulated datacenter: infrastructure health, CMDB, ITSM tickets, drift events, patch compliance, and observability. Built as a React + TypeScript SPA connecting to the API Gateway.

**Deployment:** `services/ui/` — static SPA served via `api-gateway`. Connects to `api-gateway` which routes to `core-api`, `sim-engine`, and `ansible-runner` (the 3 units — see SPEC-001). CMDB views are powered by the `core-api` NetBox proxy (SPEC-050).

---

## Core Views

### 1. Datacenter Overview (Home)
- Health score widget (0–100, aggregated from all CIs).
- Summary tiles: VM count, host count, open incidents, compliance %.
- Topology map: interactive graph of clusters → hosts → VMs.
- Live event feed (WebSocket): last 20 events (drift, incidents, patch runs).

### 2. Infrastructure Explorer
- Tree view: Datacenter → Cluster → Host → VM.
- Tabs: VMware / OpenStack / Cisco UCS.
- Click a CI to open detail side-panel: attributes, relationships, health, history.
- Inline power actions: start / stop / reset VM.

### 3. CMDB View
- Searchable CI table with type filter, tag filter, full-text search.
- CI detail page: attributes, relationships graph, change history, linked tickets.
- Export to CSV.

### 4. ITSM View
- Incident list with severity badges and status columns.
- Create / update incident form.
- Change request calendar (upcoming maintenance windows).
- Problem tracker.

### 5. Drift Dashboard
- Active drift events table: CI, field, desired vs. actual, detected at.
- Drift heatmap: which CIs drift most frequently.
- One-click remediate button (triggers Ansible run).
- Acknowledge / suppress controls.

### 6. Patch Compliance
- Compliance scorecard per policy (% compliant, # non-compliant CIs).
- CVE exposure list: CVE ID, CVSS score, affected CI count.
- Patch run history with status and logs.
- Trigger patch run button (requires change request).

### 7. Observability
- Embedded Grafana dashboards via iframe (Datacenter Overview, VM Performance, etc.).
- Quick links to Grafana, Prometheus, and Loki UIs.

### 8. Ansible Runs
- Active and recent playbook runs.
- Run logs streamed in real-time via WebSocket.
- Trigger playbook form (select playbook, target group, extra vars).

---

## Navigation Structure

```
├── / (Dashboard / Overview)
├── /infrastructure
│   ├── /vmware
│   ├── /openstack
│   └── /ucs
├── /cmdb
│   ├── /cis
│   └── /cis/:id
├── /itsm
│   ├── /incidents
│   ├── /changes
│   └── /problems
├── /drift
├── /patch
├── /observability
└── /automation
    ├── /ansible
    └── /pipelines
```

---

## Tech Stack

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Framework | React 18 + TypeScript | Wide ecosystem, strong typing |
| State | Zustand or React Query | Lightweight, server-state focused |
| UI Library | shadcn/ui + Tailwind CSS | Headless, customizable |
| Charts | Recharts | Lightweight, composable |
| Topology map | React Flow | Interactive node/edge graphs |
| WebSocket | Native browser WebSocket | Simple, no extra lib needed |
| Build | Vite | Fast HMR, modern tooling |

---

## Real-Time Updates

The UI connects to `ws://api-gateway/ws` and subscribes to event streams:

| Event | UI Reaction |
|-------|-------------|
| `vm.power_changed` | Update VM power indicator in topology map |
| `drift.detected` | Increment drift badge, append to event feed |
| `incident.created` | Show toast + increment incident counter |
| `patch.run.completed` | Update compliance scorecard |
| `ansible.run.log` | Append to live log view |

---

## Open Questions

- [ ] Dark mode support from day 1?
- [ ] Mobile-responsive layout or desktop-only for v1? → Desktop-only v1.
- [ ] Authentication UI: local users only or SSO (OIDC)? → Local users v1.
