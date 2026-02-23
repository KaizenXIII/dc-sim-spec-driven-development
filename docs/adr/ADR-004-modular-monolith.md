# ADR-004: Modular Monolith — 3 Deployable Units

**Status:** Accepted
**Date:** 2026-02-22
**Deciders:** DatacenterOS Team

---

## Context

The original SPEC-001 defined 9 independent microservices:
`api-gateway`, `sim-engine`, `cmdb`, `itsm`, `patch-manager`, `drift-detector`, `observability`, `ui`, `ansible`.

For a local simulation platform at this scale, 9 independently deployable services introduces significant operational overhead:
- 9 separate Docker images to build, tag, and push.
- 9 separate health checks, startup probes, and inter-service retry logic.
- Network round-trips between services running on the same host.
- Complex distributed tracing needed just to follow a single request path.

---

## Decision

**Consolidate 9 services into 3 deployable units + infrastructure components:**

| Unit | Contains | Rationale |
|------|---------|-----------|
| `core-api` | CMDB proxy, ITSM, patch, drift, ws-hub | All business logic; shares domain model and PostgreSQL |
| `sim-engine` | VMware (vcsim), OpenStack, UCS adapters | Infrastructure simulation; owns container lifecycle |
| `ansible-runner` | Ansible runner API, playbook library | Stateless automation; must scale and restart independently |

Infrastructure components (not units): `api-gateway`, `ui`, `observability`, `netbox`, `redis`, `postgresql`.

---

## Rationale

**Why merge CMDB + ITSM + patch + drift into `core-api`:**
- All four modules operate on the same domain model (CIs, change records).
- All four share the same PostgreSQL database.
- Intra-module calls are in-process function calls — no network, no serialization, no retry logic.
- Module boundaries are preserved via internal package structure (not service boundaries).

**Why keep `sim-engine` separate:**
- Owns Docker container lifecycle — needs its own event loop and daemon socket.
- Different language candidate (Go for vcsim integration) vs `core-api` (Python).
- Failure domain should not take down `core-api`.

**Why keep `ansible-runner` separate:**
- Long-running playbook executions must not block `core-api` request handling.
- May need independent horizontal scaling (many concurrent playbook runs).
- Stateless between runs — restarts safely without data loss.

---

## Consequences

**Positive:**
- Reduces Docker Compose service count from 9 to 3 core + 4 infrastructure (netbox, redis, postgresql, observability).
- Eliminates inter-service HTTP calls for CMDB→ITSM, CMDB→patch, CMDB→drift.
- Simpler local development: `docker compose up` starts fewer containers.
- Single `core-api` log stream covers most debug scenarios.

**Negative:**
- `core-api` is a larger codebase requiring internal module discipline.
- All modules share the same deployment lifecycle — a `core-api` deploy restarts CMDB, ITSM, patch, and drift simultaneously.
- Cannot scale ITSM independently of CMDB if one becomes a bottleneck (unlikely at sim scale).

**Mitigation:**
- Enforce module boundaries via internal package structure: `core_api/cmdb/`, `core_api/itsm/`, `core_api/patch/`, `core_api/drift/`. No cross-module imports outside of explicit dependency injection.
- If a module outgrows the monolith, it can be extracted as a separate service later — the API contracts (REST + Redis events) are already well-defined.
