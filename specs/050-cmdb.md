# SPEC-050: CMDB (Configuration Management Database)

**Status:** Draft
**Author:** DatacenterOS Team
**Created:** 2026-02-22
**GitHub Issue:** #7
**Depends on:** SPEC-010

---

## Summary

The CMDB is the authoritative source of truth for all configuration items (CIs) in the simulated datacenter. It is built on **NetBox** (`netboxcommunity/netbox`) — a production-grade open-source DCIM/IPAM platform — rather than a custom-built PostgreSQL service. A thin `pynetbox` wrapper in `core-api` translates between dc-sim's domain model and NetBox's data model.

**Resolved:** Custom PostgreSQL CMDB vs NetBox → **NetBox** ([ADR-003](../docs/adr/ADR-003-netbox-cmdb.md)).

---

## Why NetBox

| Requirement | NetBox capability |
|-------------|------------------|
| CI types: VMs, hosts, clusters, networks | Native: VirtualMachine, Device, Cluster, Prefix, VLAN |
| Relationships between CIs | Native: Device Roles, Cluster membership, Interface connections |
| Change history / audit trail | Built-in: object journal + changelog |
| REST API | Full REST + GraphQL API out of the box |
| Search + filtering | Full-text search + field-level filtering |
| Tags and custom fields | Native: tags + custom fields (equivalent to JSONB attributes) |
| Impact analysis | Via custom GraphQL queries on relationships |

---

## Configuration Item (CI) Mapping

| dc-sim CI Type | NetBox Model | Notes |
|----------------|-------------|-------|
| `vm` | `VirtualMachine` | name, cluster, vCPUs, memory, disk, platform, status |
| `host` (ESXi/baremetal) | `Device` | role=hypervisor, device type, site, rack |
| `cluster` (VMware/OpenStack/UCS) | `Cluster` | type=VMware/OpenStack/UCS, site |
| `network` (VLAN/vSwitch/Neutron) | `VLAN` + `Prefix` | vid, name, tenant |
| `storage` | Custom field on Device/VM | capacity, type |
| `service_profile` (UCS) | Custom field on Device | sp_name, template, boot_policy |
| `application` | `Service` on VM | name, port, protocol |
| `datacenter` | `Site` | name, location, status |

Tags in NetBox carry environment (`env:dev`), OS (`os:rhel9`), and platform (`platform:vmware`) semantics.

---

## CMDB Module in `core-api`

The `cmdb` module in `core-api` is a **thin proxy** — it wraps NetBox's REST API with dc-sim-specific validation, event publishing, and compatibility shims.

```
core-api/cmdb/
├── client.py          # pynetbox wrapper + retry logic
├── sync.py            # sim-engine → NetBox sync (bootstrap + incremental)
├── routes.py          # /cmdb/* REST endpoints (maps to NetBox)
└── inventory.py       # Ansible dynamic inventory builder (GET /cmdb/ansible/inventory)
```

**NetBox connection config:**
```yaml
NETBOX_URL: http://netbox:8080
NETBOX_TOKEN: ${NETBOX_API_TOKEN}
```

---

## API Endpoints

The `core-api` exposes dc-sim's CMDB API, backed by NetBox calls:

```
# Configuration Items
GET    /cmdb/cis                     List CIs (filterable by type, tags, platform)
POST   /cmdb/cis                     Create CI (synced to NetBox)
GET    /cmdb/cis/{id}                Get CI details
PATCH  /cmdb/cis/{id}                Update CI attributes
DELETE /cmdb/cis/{id}                Decommission CI

# Relationships
GET    /cmdb/cis/{id}/relationships  List relationships for a CI
POST   /cmdb/relationships           Create relationship

# Impact Analysis
GET    /cmdb/cis/{id}/impact         Upstream/downstream impact graph
GET    /cmdb/cis/{id}/history        Change history for a CI (from NetBox journal)

# Sync
POST   /cmdb/sync                    Trigger full sync from sim-engine
GET    /cmdb/sync/status             Last sync timestamp and result

# Ansible inventory (used by ansible-runner)
GET    /cmdb/ansible/inventory       Dynamic inventory JSON
```

---

## Sync Strategy

1. **Bootstrap sync:** On startup, `core-api/cmdb/sync.py` pulls full state from sim-engine (`GET /sim/state`) and upserts into NetBox via pynetbox.
2. **Event-driven updates:** `core-api` subscribes to `vm.created`, `vm.destroyed`, `power.changed` events on Redis Streams and updates NetBox incrementally.
3. **Reconciliation:** On-demand via `POST /cmdb/sync` (no scheduled polling — see [ADR-005](../docs/adr/ADR-005-inotify-drift.md)).

---

## Data Storage

- **NetBox** owns all CI data in its built-in PostgreSQL instance.
- **`core-api` PostgreSQL** stores only ITSM, patch, and drift records — not CI data directly.
- NetBox's built-in audit log covers CI change history (`/cmdb/cis/{id}/history`).

---

## Ansible Dynamic Inventory

`GET /cmdb/ansible/inventory` queries NetBox and returns Ansible-compatible JSON:

```json
{
  "_meta": {
    "hostvars": {
      "sim-vmw-vm-001": { "ansible_host": "127.0.0.1", "ansible_port": 22001, "ansible_user": "root" }
    }
  },
  "datacenter_nodes": { "hosts": ["sim-vmw-vm-001", "sim-os-instance-001", "sim-ucs-blade-c01s01"] },
  "vmware":    { "hosts": ["sim-vmw-vm-001", "sim-vmw-vm-002", "sim-vmw-vm-003"] },
  "openstack": { "hosts": ["sim-os-instance-001", "sim-os-instance-002", "sim-os-instance-003"] },
  "ucs_blades":{ "hosts": ["sim-ucs-blade-c01s01", "sim-ucs-blade-c01s02", "sim-ucs-blade-c01s03"] },
  "rhel_nodes":{ "hosts": ["sim-vmw-vm-001", "sim-vmw-vm-003", "sim-ucs-blade-c01s01"] },
  "ubuntu_nodes": { "hosts": ["sim-vmw-vm-002", "sim-os-instance-001", "sim-os-instance-002", "sim-os-instance-003", "sim-ucs-blade-c01s02", "sim-ucs-blade-c01s03"] }
}
```

Groups are derived from NetBox tags on each VM/Device object.

---

## Open Questions

- [x] Neo4j for richer graph traversal? → **No. NetBox relationship model covers dc-sim needs.** ([ADR-003](../docs/adr/ADR-003-netbox-cmdb.md))
- [x] CMDB as write-master vs sim-engine as write-master? → **NetBox (via core-api) is desired-state master; sim-engine is actual-state.**
- [ ] Tag taxonomy: define standard tag keys (env, owner, tier, cost-center)?
