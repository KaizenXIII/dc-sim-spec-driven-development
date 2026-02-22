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

## Container Topology

### Naming Convention
```
sim-vmw-vcenter          vCenter metadata service
sim-vmw-esxi-{n}         ESXi host node  (e.g. sim-vmw-esxi-01)
sim-vmw-vm-{nnn}         Virtual machine (e.g. sim-vmw-vm-001)
```

### Docker Networks
| Network name      | Subnet           | Maps to VMware concept         |
|-------------------|-----------------|--------------------------------|
| `dc-vmw-mgmt`     | 172.20.0.0/24   | Management network / vMotion   |
| `dc-vmw-vm-100`   | 172.20.100.0/24 | VM traffic VLAN 100 / vSwitch0 |
| `dc-vmw-vm-200`   | 172.20.200.0/24 | VM traffic VLAN 200 / dvSwitch |

### Docker Object Mapping
| VMware Object    | Docker Implementation                               |
|-----------------|-----------------------------------------------------|
| vCenter          | Metadata-only process, serves vSphere REST API      |
| ESXi Host        | Container on `dc-vmw-mgmt`, acts as hypervisor node |
| VM (powered on)  | Running container, SSH reachable                    |
| VM (powered off) | Stopped container (`docker stop`)                   |
| VM (suspended)   | Paused container (`docker pause`)                   |
| vSwitch          | Docker bridge network                               |
| dvSwitch         | Docker bridge network shared across hosts           |
| Datastore        | Docker named volume pool                            |
| vMotion          | `docker network disconnect` + reconnect to target   |
| Snapshot         | `docker commit` + image tag                         |
| Template clone   | `docker run` from committed image                   |

### Docker Labels (per VM container)
```
sim.platform         = vmware
sim.type             = vm
sim.id               = vm-001
sim.guest_os         = rhel9 | ubuntu22
sim.vcpu             = 2
sim.memory_mb        = 4096
sim.power_state      = on | off | suspended
sim.env              = dev | staging | prod
sim.ansible_user     = root
sim.ssh_port         = <mapped host port>
sim.vmw.cluster      = cluster-01
sim.vmw.host         = sim-vmw-esxi-01
sim.vmw.datastore    = ds-01
sim.vmw.vswitch      = vSwitch0
```

### Default Seed Topology (dev environment)
```
vCenter (sim-vmw-vcenter)
└── Datacenter: dc-west
    └── Cluster: cluster-01
        ├── Host: sim-vmw-esxi-01  (172.20.0.11)
        │   ├── sim-vmw-vm-001  (RHEL 9,    2 vCPU, 4 GB)  → SSH :22001
        │   └── sim-vmw-vm-002  (Ubuntu 22, 2 vCPU, 4 GB)  → SSH :22002
        └── Host: sim-vmw-esxi-02  (172.20.0.12)
            └── sim-vmw-vm-003  (RHEL 9,    4 vCPU, 8 GB)  → SSH :22003
```

### Ansible Inventory Groups
```
[vmware]           all VMware VMs
[vmware_rhel]      sim.guest_os = rhel9
[vmware_ubuntu]    sim.guest_os = ubuntu22
[cluster_01]       sim.vmw.cluster = cluster-01
```

---

## Open Questions

- [x] REST-only vs SOAP/WSDL → **REST-only for v1.**
- [x] Default ESXi host count → **2 hosts, 3 VMs (seed topology above).**
