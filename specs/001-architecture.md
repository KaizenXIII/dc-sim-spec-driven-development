# SPEC-001: System Architecture

**Status:** Draft
**Author:** DatacenterOS Team
**Created:** 2026-02-22
**GitHub Issue:** #2
**Depends on:** SPEC-000

---

## Summary

This spec defines the technical architecture for the dc-sim platform: deployable unit boundaries, communication patterns, data storage strategy, and deployment model.

The architecture follows a **modular monolith + specialist workers** pattern: business logic is consolidated into three deployable units rather than nine independent microservices. This keeps operational complexity low while retaining clear internal module boundaries.

---

## Deployable Units

### Unit 1: `core-api`
The platform's main API server — a modular monolith containing all business-logic modules.

**Internal modules:**

| Module | Responsibilities |
|--------|-----------------|
| `cmdb` | NetBox proxy + CI wrapper; source of truth for all configuration items (see SPEC-050) |
| `itsm` | Incident, problem, and change management (see SPEC-060) |
| `patch` | Patch compliance tracking, policy management, patch run orchestration (see SPEC-070) |
| `drift` | Desired-vs-actual state diffing; emits drift events (see SPEC-080) |
| `ws-hub` | WebSocket broadcaster for real-time UI updates |

- Single deployable binary/container, single PostgreSQL database.
- All modules share one REST router under `/cmdb/`, `/itsm/`, `/patch/`, `/drift/`.
- Internal module calls are in-process; only cross-unit communication uses the event bus.

---

### Unit 2: `sim-engine`
Owns all simulated infrastructure objects and their lifecycle.

**Sub-adapters:**

| Adapter | Backed by | Exposes |
|---------|-----------|---------|
| VMware | `vmware/govcsim` (vcsim) — real vSphere API stub | `/vcenter/*` — SPEC-020 |
| OpenStack | Lightweight Nova/Neutron mock | `/nova/*`, `/neutron/*` — SPEC-030 |
| Cisco UCS | Custom UCS XML/REST mock | `/ucsm/*` — SPEC-040 |

- Manages Docker containers as simulated VMs (create, power, snapshot).
- Publishes lifecycle events (`vm.created`, `vm.destroyed`, `power.changed`) to Redis Streams.
- vcsim runs as a sidecar: `sim-engine` delegates vSphere API calls to it.

---

### Unit 3: `ansible-runner`
Standalone automation engine — event-triggered or API-triggered.

- Wraps the `ansible-runner` Python library.
- Dynamic inventory sourced from NetBox via `pynetbox` (`GET /netbox/ansible/inventory`).
- SSH targets: sim node containers (sshd running, ed25519 key auth).
- Exposes REST API: `POST /ansible/run`, `GET /ansible/runs/{id}`.
- Subscribes to Redis Streams: `drift.detected` → auto-remediation, `patch.scheduled` → patch runs.
- See SPEC-110 for full playbook library and runner API.

---

### Infrastructure Components (not counted as units)

| Component | Role |
|-----------|------|
| `api-gateway` | Single entry point: request routing, JWT auth, rate limiting, TLS termination |
| `ui` | React + TypeScript SPA — Glass Pane dashboard (SPEC-120) |
| `observability` | PLT stack: Prometheus + Loki + Tempo + Grafana (SPEC-090) |
| `netbox` | `netboxcommunity/netbox` Docker image — DCIM/IPAM as the CMDB backend |
| `redis` | Event bus (Redis Streams, ADR-001) |
| `postgresql` | `core-api` application data (ITSM, patch, drift state) |

---

## Communication Patterns

| Pattern | Used by |
|---------|---------|
| REST (sync) | All units for CRUD and queries |
| WebSocket | UI ↔ api-gateway for live updates |
| Event Bus (async) | sim-engine → core-api → drift → itsm |
| inotify (in-node) | Drift detector watches file/config changes inside sim containers |

**Event Bus:** Redis Streams — resolved in [ADR-001](../docs/adr/ADR-001-event-bus.md).

---

## Data Storage

| Service | Store | Rationale |
|---------|-------|-----------|
| `netbox` (CMDB) | PostgreSQL (built-in to NetBox) | Full DCIM/IPAM — see [ADR-003](../docs/adr/ADR-003-netbox-cmdb.md) |
| `core-api` | PostgreSQL | ITSM tickets, patch records, drift policies |
| `sim-engine` | In-memory + SQLite | Simulation state, fast R/W |
| `drift-detector` | Redis | Fast ephemeral diff state + inotify event buffer |
| `observability` | Prometheus, Loki | Purpose-built time-series/log stores |

---

## Deployment Model

- **Local dev:** `docker compose up` — all units + infrastructure in one command.
- **CI:** GitHub Actions — lint, test, build per unit on PR.
- **Future:** Kubernetes manifests in `/infra/k8s` for production-like deployment.

---

## Directory Layout

```
dc-sim-spec-driven-development/
├── specs/                  # All SDD spec files
├── docs/
│   ├── adr/                # Architecture Decision Records
│   └── rfcs/               # Request for Comments (major design discussions)
├── services/
│   ├── core-api/           # Monolith: CMDB proxy, ITSM, patch, drift, ws-hub
│   ├── sim-engine/         # Simulation: VMware (vcsim), OpenStack, UCS adapters
│   ├── ansible-runner/     # Ansible runner API + playbook library
│   ├── api-gateway/        # Routing config (nginx / Traefik)
│   └── ui/                 # React + TypeScript SPA
├── infra/
│   ├── docker/             # docker-compose files
│   └── k8s/                # Kubernetes manifests
├── scripts/                # Dev/ops helper scripts
├── .github/
│   ├── ISSUE_TEMPLATE/     # GitHub Issue templates (spec, bug, task)
│   └── workflows/          # GitHub Actions CI workflows
└── README.md
```

---

## Resolved Decisions

| Question | Decision | Reference |
|----------|----------|-----------|
| Event bus: NATS vs Redis Streams? | **Redis Streams** | [ADR-001](../docs/adr/ADR-001-event-bus.md) |
| CMDB: custom PostgreSQL JSONB vs NetBox? | **NetBox** (`netboxcommunity/netbox`) | [ADR-003](../docs/adr/ADR-003-netbox-cmdb.md) |
| Service granularity: 9 microservices vs modular monolith? | **3 deployable units** (core-api + sim-engine + ansible-runner) | [ADR-004](../docs/adr/ADR-004-modular-monolith.md) |
| Drift detection: polling vs event-driven? | **inotify + Docker events** (event-driven) | [ADR-005](../docs/adr/ADR-005-inotify-drift.md) |
| VMware API: custom implementation vs vcsim? | **vcsim** (`vmware/govcsim`) | [ADR-006](../docs/adr/ADR-006-vcsim.md) |
| UI framework: React vs Vue? | **React + TypeScript** | [SPEC-120](120-glass-pane-ui.md) |
| Ansible: embedded vs standalone unit? | **Standalone unit** (`ansible-runner`) | This spec |
