# SPEC-020: VMware / ESXi Simulation

**Status:** Draft
**Author:** DatacenterOS Team
**Created:** 2026-02-22
**GitHub Issue:** #4
**Depends on:** SPEC-010

---

## Summary

This spec defines the VMware/ESXi simulation adapter within the sim-engine. It exposes a vSphere-compatible REST API so that existing VMware tooling (govc, PowerCLI scripts, Terraform VMware provider) can interact with the simulated environment without modification.

---

## Simulated VMware Objects

| Object | Description |
|--------|-------------|
| vCenter | Single simulated vCenter instance |
| Datacenter | One or more logical datacenters |
| Cluster | ESXi host clusters with DRS/HA flags |
| ESXi Host | Simulated host node (container or mock) |
| VM | Docker container with VMware metadata |
| vSwitch / dvSwitch | Docker network with VLAN tagging |
| Datastore | Docker volume pool (NFS / VMFS mock) |
| Resource Pool | Logical grouping of VMs |
| vSAN Cluster | Mock shared storage pool |

---

## API Surface (vSphere-compatible)

The adapter exposes a subset of the VMware vSphere REST API v7.0+:

```
GET    /vcenter/datacenter                List datacenters
GET    /vcenter/cluster                   List clusters
GET    /vcenter/host                      List ESXi hosts
GET    /vcenter/vm                        List VMs
POST   /vcenter/vm                        Create VM
DELETE /vcenter/vm/{vm}                   Delete VM
POST   /vcenter/vm/{vm}/power             Power operations
GET    /vcenter/vm/{vm}/hardware          VM hardware config
PATCH  /vcenter/vm/{vm}/hardware/cpu      Reconfigure CPU
PATCH  /vcenter/vm/{vm}/hardware/memory   Reconfigure memory
GET    /vcenter/datastore                 List datastores
GET    /vcenter/network                   List networks
```

---

## VMware-Specific Behaviors to Simulate

| Behavior | Simulation Approach |
|----------|-------------------|
| vMotion | Move container to different Docker host network |
| DRS recommendations | Mock scoring algorithm returns suggestions |
| HA failover | Kill container on host-A, restart on host-B |
| Snapshot | Docker commit + tag |
| Template clone | Docker image pull + container create |
| vSAN health | Mock metrics endpoint with configurable health |

---

## Metrics Simulation

The adapter exposes fake performance metrics matching vCenter API format:

```
GET /vcenter/vm/{vm}/metrics?names=cpu.usage,mem.usage,disk.read
```

Returns randomized-but-realistic values with configurable noise/trend.

---

## Tooling Compatibility Targets

- `govc` CLI — basic VM and host operations
- Terraform `vsphere` provider — VM provisioning workflows
- Ansible `community.vmware` collection — VM management playbooks

---

## Open Questions

- [ ] Implement full SOAP/WSDL interface (vSphere SDK) or REST-only? → Start with REST-only.
- [ ] How many ESXi hosts to simulate by default? → TBD in seed data config.
