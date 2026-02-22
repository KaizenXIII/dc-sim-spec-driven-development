# SPEC-001: System Architecture

**Status:** Draft
**Author:** DatacenterOS Team
**Created:** 2026-02-22
**GitHub Issue:** #2
**Depends on:** SPEC-000

---

## Summary

This spec defines the technical architecture for the dc-sim platform: service boundaries, communication patterns, data storage strategy, and deployment model.

---

## Services

### 1. `api-gateway`
- Single entry point for all external clients (UI, CLI, external tooling).
- Responsibilities: request routing, authentication (JWT), rate limiting, TLS termination.
- Exposes: REST API on port `8080`, WebSocket endpoint on `/ws`.

### 2. `sim-engine`
- Core simulation service. Owns all simulated infrastructure objects.
- Manages the lifecycle of fake VMs (Docker containers).
- Exposes internal APIs consumed by other services.
- Sub-modules: VMware Adapter, OpenStack Adapter, Cisco UCS Adapter.

### 3. `cmdb`
- Source of truth for all configuration items (CIs): hosts, VMs, networks, services.
- Backed by a graph-capable store (PostgreSQL with JSONB or Neo4j).
- Syncs state from `sim-engine` via event bus.

### 4. `itsm`
- Incident, problem, and change management.
- Integrates with `cmdb` for impact analysis.
- Exposes ticket CRUD API and webhook triggers.

### 5. `patch-manager`
- Tracks patch compliance per CI from CMDB.
- Schedules and records patch operations against simulated VMs.
- Integrates with `ansible` runner.

### 6. `drift-detector`
- Periodically compares desired state (stored configs) against actual state (sim-engine).
- Emits drift events to the event bus.
- Integrates with `cmdb` and `ansible` for remediation.

### 7. `observability`
- Collects metrics, logs, and traces from all services and simulated VMs.
- Stack: Prometheus (metrics) + Loki (logs) + Tempo (traces) + Grafana (dashboards).
- Exposes pre-built dashboards for datacenter health.

### 8. `ui`
- Single-page application: the Glass Pane dashboard.
- Connects to `api-gateway` via REST and WebSocket.
- Tech: React + TypeScript (to be finalized in SPEC-120).

---

## Communication Patterns

| Pattern | Used by |
|---------|---------|
| REST (sync) | All services for CRUD and queries |
| WebSocket | UI ↔ api-gateway for live updates |
| Event Bus (async) | sim-engine → cmdb → drift-detector → itsm |

**Event Bus:** NATS or Redis Streams (decision deferred to SPEC-010).

---

## Data Storage

| Service | Store | Rationale |
|---------|-------|-----------|
| cmdb | PostgreSQL + JSONB | Relational + flexible schema for CIs |
| itsm | PostgreSQL | Structured ticket data |
| patch-manager | PostgreSQL | Patch records, schedules |
| drift-detector | Redis | Fast ephemeral diff state |
| sim-engine | In-memory + SQLite | Simulation state, fast R/W |
| observability | Prometheus, Loki | Purpose-built time-series/log stores |

---

## Deployment Model

- **Local dev:** `docker compose up` — all services + infrastructure in one command.
- **CI:** GitHub Actions — lint, test, build per service on PR.
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
│   ├── api-gateway/
│   ├── sim-engine/
│   ├── cmdb/
│   ├── itsm/
│   ├── patch-manager/
│   ├── drift-detector/
│   ├── observability/
│   └── ui/
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

## Open Questions

- [ ] Event bus: NATS vs Redis Streams? → ADR-001
- [ ] CMDB graph queries: PostgreSQL JSONB sufficient or require Neo4j? → ADR-002
- [ ] UI framework: React vs Vue? → SPEC-120
