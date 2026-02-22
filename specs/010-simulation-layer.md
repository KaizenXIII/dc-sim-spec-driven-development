# SPEC-010: Simulation Engine

**Status:** Draft
**Author:** DatacenterOS Team
**Created:** 2026-02-22
**GitHub Issue:** #3
**Depends on:** SPEC-001

---

## Summary

The Simulation Engine (`sim-engine`) is the core service responsible for creating and managing simulated datacenter infrastructure. It uses Docker/Podman containers as fake VMs and exposes internal adapter APIs that mimic VMware, OpenStack, and Cisco UCS behavior.

---

## Responsibilities

1. Manage the lifecycle of simulated infrastructure objects (hosts, clusters, VMs, networks, storage).
2. Spin up / tear down Docker containers that represent VMs.
3. Expose adapter sub-APIs: VMware, OpenStack, UCS (see SPEC-020/030/040).
4. Publish state change events to the event bus.
5. Provide a query API for current infrastructure state consumed by CMDB and other services.

---

## Simulated Object Model

```
Datacenter
└── Cluster
    ├── Host (baremetal node — container or mock)
    │   ├── VM (Docker container)
    │   │   ├── vNIC (virtual network interface)
    │   │   └── vDisk (volume mount)
    │   └── vSwitch (Docker network)
    └── Datastore (Docker volume pool)

UCS Domain
└── FabricInterconnect
    └── ChassisGroup
        └── Blade (Host)
            └── ServiceProfile

OpenStack Region
└── Project
    ├── Instance (VM / container)
    ├── Network (Neutron network)
    └── Volume (Cinder volume)
```

---

## Container-as-VM Model

Each simulated VM is a Docker container with:

| Property | Implementation |
|----------|---------------|
| OS identity | Container image tag (e.g., `sim-rhel9`, `sim-ubuntu22`) |
| IP address | Docker network assignment |
| Hostname | Container name |
| CPU/RAM | Docker `--cpus` / `--memory` limits |
| Disk | Named Docker volume |
| Power state | Container running / stopped / paused |
| SSH access | Optional: sshd in container for Ansible targeting |

---

## API Endpoints (Internal)

### Infrastructure Lifecycle
```
POST   /sim/vms              Create a VM (starts a container)
DELETE /sim/vms/{id}         Destroy a VM
POST   /sim/vms/{id}/power   Power on/off/reset/suspend
GET    /sim/vms              List all VMs
GET    /sim/vms/{id}         Get VM details

POST   /sim/hosts            Register a simulated host
GET    /sim/hosts            List all hosts
GET    /sim/clusters         List all clusters
GET    /sim/datastores       List all datastores
GET    /sim/networks         List all networks
```

### State Snapshot
```
GET    /sim/state            Full dump of all simulated objects
GET    /sim/state/diff       Diff vs last known good state (for drift)
```

---

## Events Published

| Event | Trigger |
|-------|---------|
| `vm.created` | VM container started |
| `vm.destroyed` | VM container removed |
| `vm.power_changed` | Power state transition |
| `host.degraded` | Simulated host failure injected |
| `drift.detected` | State diverges from desired config |

---

## Failure Injection

The sim engine supports injecting failures for SRE practice:

```
POST /sim/inject/host-failure    { "host_id": "...", "type": "power_off" }
POST /sim/inject/network-partition { "network": "...", "duration_sec": 30 }
POST /sim/inject/disk-full       { "vm_id": "...", "datastore": "..." }
```

---

## Open Questions

- [ ] Event bus choice (NATS vs Redis Streams) — see ADR-001
- [ ] Should containers run real sshd for Ansible targeting, or mock SSH? → SPEC-110
- [ ] How to simulate VMware-specific metrics (vSAN, vMotion)? → SPEC-020
