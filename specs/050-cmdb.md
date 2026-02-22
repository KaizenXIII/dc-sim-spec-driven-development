# SPEC-050: CMDB (Configuration Management Database)

**Status:** Draft
**Author:** DatacenterOS Team
**Created:** 2026-02-22
**GitHub Issue:** #7
**Depends on:** SPEC-010

---

## Summary

The CMDB is the authoritative source of truth for all configuration items (CIs) in the simulated datacenter. It is continuously synced from the sim-engine and serves as the foundation for ITSM, patch management, drift detection, and the glass pane dashboard.

---

## Configuration Item (CI) Types

| CI Type | Attributes |
|---------|-----------|
| `host` | hostname, IP, rack, role, OS, CPU/RAM, power state |
| `vm` | name, host, cluster, OS, IP, vCPU, RAM, disks, power state |
| `cluster` | name, datacenter, host_count, type (VMware/OpenStack/UCS) |
| `network` | name, VLAN, CIDR, type (vSwitch/Neutron/UCS VLAN) |
| `storage` | name, type (datastore/volume/vSAN), capacity, used |
| `service_profile` | name, blade, template, vNICs, boot_policy |
| `application` | name, owner, VMs, tier (web/app/db) |
| `datacenter` | name, location, environment (dev/staging/prod) |

---

## Relationships

The CMDB models relationships between CIs:

```
datacenter ──contains──> cluster
cluster    ──contains──> host
host       ──runs──────> vm
vm         ──member_of─> application
vm         ──connected_to──> network
vm         ──uses──────> storage
blade      ──assigned──> service_profile
```

---

## API Endpoints

```
# Configuration Items
GET    /cmdb/cis                     List CIs (filterable by type, tags)
POST   /cmdb/cis                     Create CI (manual or sync)
GET    /cmdb/cis/{id}                Get CI details
PATCH  /cmdb/cis/{id}                Update CI attributes
DELETE /cmdb/cis/{id}                Decommission CI

# Relationships
GET    /cmdb/cis/{id}/relationships  List relationships for a CI
POST   /cmdb/relationships           Create relationship
DELETE /cmdb/relationships/{id}      Remove relationship

# Impact Analysis
GET    /cmdb/cis/{id}/impact         Upstream/downstream impact graph
GET    /cmdb/cis/{id}/history        Change history for a CI

# Sync
POST   /cmdb/sync                    Trigger full sync from sim-engine
GET    /cmdb/sync/status             Last sync timestamp and result
```

---

## Sync Strategy

1. **Bootstrap sync:** On startup, CMDB pulls full state snapshot from sim-engine (`GET /sim/state`).
2. **Event-driven updates:** CMDB subscribes to sim-engine events (`vm.created`, `vm.destroyed`, etc.) and updates incrementally.
3. **Periodic reconciliation:** Every 5 minutes, CMDB diffs its state against sim-engine and self-heals.

---

## Data Storage

- **Database:** PostgreSQL with JSONB for flexible CI attributes.
- **Schema:** `cis(id, type, name, attributes JSONB, created_at, updated_at)` + `relationships(id, source_ci, target_ci, type)`.
- **Search:** Full-text search on CI name and attributes via PostgreSQL `tsvector`.
- **History:** Append-only `ci_history` table for audit trail.

---

## Open Questions

- [ ] Use Neo4j for richer graph traversal (impact analysis)? → ADR-002
- [ ] Should CMDB be the write-master for desired state, or is sim-engine the master? → CMDB is desired state; sim-engine is actual state.
- [ ] Tag taxonomy: define standard tag keys (env, owner, tier, cost-center)?
