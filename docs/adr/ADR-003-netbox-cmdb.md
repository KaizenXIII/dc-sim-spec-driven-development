# ADR-003: NetBox as the CMDB Backend

**Status:** Accepted
**Date:** 2026-02-22
**Deciders:** DatacenterOS Team

---

## Context

SPEC-050 requires a CMDB that stores configuration items (VMs, hosts, clusters, networks), their relationships, change history, and an Ansible dynamic inventory endpoint. Two approaches were evaluated:

1. **Custom PostgreSQL service** — build a `cmdb` microservice from scratch using PostgreSQL + JSONB for flexible CI attributes and a custom REST API.
2. **NetBox** — deploy `netboxcommunity/netbox` as a Docker service and wrap it with a thin `pynetbox` client inside `core-api`.

---

## Decision

**Use NetBox** (`netboxcommunity/netbox`) as the CMDB backend.

---

## Rationale

| Requirement | Custom build | NetBox |
|-------------|-------------|--------|
| CI types: VMs, devices, clusters, networks | Must build all models | Native: VirtualMachine, Device, Cluster, VLAN, Prefix |
| Relationships between CIs | Must build graph schema | Native: cluster membership, interfaces, cables |
| Change history / audit trail | Must build `ci_history` table | Built-in: object changelog + journal entries |
| REST API | Must build and document | Full REST + GraphQL out of the box |
| Full-text search | Must integrate pg `tsvector` | Built-in |
| Tags + custom fields (JSONB equivalent) | Must build | Built-in |
| Impact analysis | Must build traversal queries | GraphQL relationship traversal |
| Ansible inventory endpoint | Must build | Built-in: `/api/dcim/devices/?tag=ansible` pattern + pynetbox query |
| Dev-to-production continuity | Toy implementation | Real tool used in production datacenters |

NetBox is a **production DCIM/IPAM tool** used in real datacenters. Running it in dc-sim means operators practice against tooling that behaves identically to what they'd encounter in production.

---

## Consequences

**Positive:**
- Eliminates an entire microservice (no custom CMDB to build, test, and maintain).
- Immediate full-featured CMDB with relationships, history, search, tags, and custom fields.
- Ansible dynamic inventory via `pynetbox` queries (filter by tag, platform, cluster).
- Real-world tool familiarity for operators.

**Negative:**
- NetBox is a heavier Docker image (~500 MB) with its own PostgreSQL + Redis dependencies.
- Custom CI types (UCS service profiles, vcsim-specific fields) require NetBox custom fields rather than a purpose-built schema.
- The pynetbox wrapper in `core-api` must translate between dc-sim's domain model and NetBox's models.

**Mitigation:**
- NetBox's built-in PostgreSQL and Redis can be shared with `core-api`'s Redis (event bus) in dev, keeping compose services minimal.
- Custom fields are defined via NetBox's API during bootstrap — no manual UI configuration needed.
