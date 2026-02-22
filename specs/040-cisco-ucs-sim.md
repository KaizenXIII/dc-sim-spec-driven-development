# SPEC-040: Cisco UCS Simulation

**Status:** Draft
**Author:** DatacenterOS Team
**Created:** 2026-02-22
**GitHub Issue:** #6
**Depends on:** SPEC-010

---

## Summary

This spec defines the Cisco UCS (Unified Computing System) simulation adapter. It models UCS Manager XML API behavior so that standard UCS tooling (ucsmsdk, Ansible `cisco.ucs` collection, Terraform UCS provider) can interact with the simulated environment.

---

## Simulated UCS Objects

| Object | Description |
|--------|-------------|
| UCS Domain | Top-level UCS Manager instance |
| Fabric Interconnect (FI) | A/B pair of management switches |
| Chassis | Blade server chassis (e.g., UCS 5108) |
| Blade | Individual server blade (e.g., B200 M6) |
| Service Profile | Policy-driven hardware config applied to a blade |
| Service Profile Template | Reusable SP definition |
| vNIC | Virtual NIC defined in service profile |
| vHBA | Virtual HBA for storage connectivity |
| VLAN Pool | Named VLAN set assigned to vNICs |
| Boot Policy | Boot order definition (SAN, PXE, local) |
| Firmware Policy | Firmware version target per component |

---

## Object Hierarchy

```
UCS Domain
└── FabricInterconnect (FI-A, FI-B)
    └── Chassis (chassis-1..N)
        └── Blade (blade-1..8 per chassis)
            └── ServiceProfile (assigned or unassociated)
                ├── vNIC (eth0, eth1)
                ├── vHBA (fc0, fc1)
                ├── BootPolicy
                └── FirmwarePolicy
```

---

## API Surface (UCS Manager XML API compatible)

The UCS Manager exposes an XML API. The sim adapter implements a REST-to-XML bridge:

```
POST   /nuova                         UCS XML API endpoint (aaLogin, configResolveClass, etc.)
GET    /ucs/api/v1/domains            List UCS domains (REST convenience)
GET    /ucs/api/v1/blades             List all blades
GET    /ucs/api/v1/service-profiles   List service profiles
POST   /ucs/api/v1/service-profiles   Create service profile
PUT    /ucs/api/v1/service-profiles/{id}/associate   Associate SP to blade
GET    /ucs/api/v1/chassis            List chassis
GET    /ucs/api/v1/fabric-interconnects  List FIs
```

### Key XML API Methods Simulated
| UCS XML Method | Action |
|---------------|--------|
| `aaLogin` | Return auth cookie |
| `aaLogout` | Invalidate session |
| `configResolveClass` | Query objects by class (e.g., `computeBlade`) |
| `configResolveDn` | Query object by distinguished name |
| `configConfMo` | Create/update/delete a managed object |
| `configScope` | Query objects in a subtree |

---

## Service Profile Lifecycle

1. **Create** service profile from template.
2. **Associate** service profile to available blade.
3. **Power on** blade → container starts with SP config applied.
4. **Disassociate** → blade returns to pool.
5. **Firmware** update → triggers simulated firmware policy check.

---

## Blade-to-Container Mapping

| UCS Concept | Docker Implementation |
|-------------|-----------------------|
| Blade (powered on) | Running Docker container |
| Blade (powered off) | Stopped container |
| vNIC | Container network interface |
| Firmware version | Container label `ucs.firmware.version` |
| Service Profile | Container labels + env vars |

---

## Tooling Compatibility Targets

- `ucsmsdk` (Python) — basic blade and SP operations
- Ansible `cisco.ucs` collection — service profile automation
- Terraform `CiscoDevNet/ucs` provider (stretch goal)

---

## Container Topology

### Naming Convention
```
sim-ucs-ucsm             UCS Manager API service
sim-ucs-blade-c{cc}s{ss} Blade container — chassis cc, slot ss
                         e.g. sim-ucs-blade-c01s01  (chassis 01, slot 01)
```

### Docker Networks
| Network name     | Subnet          | Maps to UCS concept                  |
|------------------|----------------|--------------------------------------|
| `dc-ucs-mgmt`    | 172.22.0.0/24  | UCS management / CIMC / KVM          |
| `dc-ucs-data-a`  | 172.22.1.0/24  | Fabric A data path (vNIC eth0)       |
| `dc-ucs-data-b`  | 172.22.2.0/24  | Fabric B data path (vNIC eth1)       |

### Docker Object Mapping
| UCS Object                | Docker Implementation                                  |
|--------------------------|--------------------------------------------------------|
| UCS Manager (UCSM)        | API container serving XML + REST endpoints             |
| Fabric Interconnect (FI)  | No container — represented as UCSM state only          |
| Chassis                   | No container — logical grouping in UCSM state          |
| Blade (powered on)        | Running container on `dc-ucs-mgmt`                     |
| Blade (powered off)       | Stopped container                                      |
| vNIC eth0                 | Container interface on `dc-ucs-data-a`                 |
| vNIC eth1                 | Container interface on `dc-ucs-data-b`                 |
| vHBA fc0/fc1              | No container interface — mock FC state in UCSM         |
| Service Profile (SP)      | Container labels + environment variables               |
| Service Profile Template  | Docker image tag used as base for blade containers     |
| Boot policy (power on)    | `docker start` with SP labels injected as env vars     |
| Firmware policy           | Container label `sim.ucs.firmware`                     |

### Docker Labels (per blade container)
```
sim.platform             = ucs
sim.type                 = blade
sim.id                   = blade-c01s01
sim.guest_os             = rhel9 | ubuntu22
sim.vcpu                 = 4
sim.memory_mb            = 16384
sim.power_state          = on | off
sim.env                  = dev | staging | prod
sim.ansible_user         = root
sim.ssh_port             = <mapped host port>
sim.ucs.chassis          = chassis-01
sim.ucs.slot             = 1
sim.ucs.sp               = SP-web-01
sim.ucs.sp_template      = SP-Template-RHEL9
sim.ucs.boot_policy      = SAN-Boot | PXE-Boot | Local-Boot
sim.ucs.firmware         = 4.2(3d)
sim.ucs.fi_a             = FI-A
sim.ucs.fi_b             = FI-B
```

### Default Seed Topology (dev environment)
```
UCS Domain: ucs-domain-01
└── FI-A / FI-B  (no containers — UCSM state only)
    └── Chassis: chassis-01  (UCS 5108, 8 slots)
        ├── sim-ucs-blade-c01s01  (RHEL 9,    4 vCPU, 16 GB)  → SSH :22007
        │   SP: SP-web-01  (template: SP-Template-RHEL9)
        ├── sim-ucs-blade-c01s02  (Ubuntu 22, 4 vCPU, 16 GB)  → SSH :22008
        │   SP: SP-app-01  (template: SP-Template-Ubuntu)
        └── sim-ucs-blade-c01s03  (RHEL 9,    4 vCPU, 16 GB)  → SSH :22009
            SP: SP-db-01   (template: SP-Template-RHEL9)
```

### Service Profile Environment Variables (injected at container start)
```bash
UCS_SP_NAME=SP-web-01
UCS_SP_TEMPLATE=SP-Template-RHEL9
UCS_BOOT_POLICY=SAN-Boot
UCS_FIRMWARE=4.2(3d)
UCS_VNIC_ETH0_MAC=00:25:b5:00:00:01
UCS_VNIC_ETH1_MAC=00:25:b5:00:00:02
UCS_CHASSIS=chassis-01
UCS_SLOT=1
```

### Ansible Inventory Groups
```
[ucs_blades]           all UCS blades
[ucs_rhel]             sim.guest_os = rhel9
[ucs_ubuntu]           sim.guest_os = ubuntu22
[chassis_01]           sim.ucs.chassis = chassis-01
[sp_template_rhel9]    sim.ucs.sp_template = SP-Template-RHEL9
```

---

## Open Questions

- [x] XML API WSDL vs REST-only → **REST convenience API + minimal XML endpoint for `ucsmsdk`.**
- [x] UCSPE Docker image feasibility → **Not used. Custom blade containers with sshd + Python.**
- [x] FI failover simulation → **Deferred to v2.**
