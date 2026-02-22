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

## Open Questions

- [ ] Implement full UCS XML API WSDL or REST-only convenience API?
  → v1: REST convenience API + minimal XML endpoint for `ucsmsdk` compatibility.
- [ ] Simulate UCSPE (Physical Emulator) Docker image as base? → Investigate feasibility.
- [ ] FI failover simulation in scope for v1? → No, deferred.
