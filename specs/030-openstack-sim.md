# SPEC-030: OpenStack Simulation

**Status:** Draft
**Author:** DatacenterOS Team
**Created:** 2026-02-22
**GitHub Issue:** #5
**Depends on:** SPEC-010

---

## Summary

This spec defines the OpenStack simulation adapter. It exposes OpenStack-compatible REST APIs for the core services (Keystone, Nova, Neutron, Cinder, Glance) so that standard OpenStack clients (`openstack` CLI, Terraform OpenStack provider, Ansible `openstack.cloud` collection) work against the simulation unchanged.

---

## Simulated OpenStack Services

| Service | Role | Simulated |
|---------|------|-----------|
| Keystone | Identity / auth | Token issuance, project/user CRUD |
| Nova | Compute | Instance lifecycle, flavors, keypairs |
| Neutron | Networking | Networks, subnets, routers, security groups |
| Cinder | Block storage | Volumes, snapshots, attach/detach |
| Glance | Image registry | Image list, upload stub, metadata |

---

## API Surface

### Keystone (Identity)
```
POST   /identity/v3/auth/tokens       Issue token
GET    /identity/v3/projects          List projects
POST   /identity/v3/projects          Create project
GET    /identity/v3/users             List users
```

### Nova (Compute)
```
GET    /compute/v2.1/servers          List instances
POST   /compute/v2.1/servers          Boot instance (starts container)
DELETE /compute/v2.1/servers/{id}     Terminate instance
POST   /compute/v2.1/servers/{id}/action  Power ops (start/stop/reboot/pause)
GET    /compute/v2.1/flavors          List flavors
GET    /compute/v2.1/os-keypairs      List keypairs
```

### Neutron (Networking)
```
GET    /network/v2.0/networks         List networks
POST   /network/v2.0/networks         Create network
GET    /network/v2.0/subnets          List subnets
POST   /network/v2.0/routers          Create router
GET    /network/v2.0/security-groups  List security groups
```

### Cinder (Storage)
```
GET    /volume/v3/volumes             List volumes
POST   /volume/v3/volumes             Create volume
POST   /volume/v3/volumes/{id}/action Attach/detach
GET    /volume/v3/snapshots           List snapshots
```

### Glance (Images)
```
GET    /image/v2/images               List images
GET    /image/v2/images/{id}          Get image metadata
```

---

## Instance-to-Container Mapping

| OpenStack Concept | Docker Implementation |
|-------------------|-----------------------|
| Instance (VM) | Docker container |
| Flavor | Docker resource limits |
| Network | Docker network |
| Security group | Docker network policy (iptables stub) |
| Keypair | SSH key injected into container |
| Volume | Docker named volume |
| Image | Docker image |

---

## Tooling Compatibility Targets

- `openstack` CLI (python-openstackclient)
- Terraform `openstack` provider
- Ansible `openstack.cloud` collection
- Heat templates (stretch goal)

---

## Container Topology

### Naming Convention
```
sim-os-keystone          Keystone identity service container
sim-os-nova              Nova compute API container
sim-os-neutron           Neutron network API container
sim-os-cinder            Cinder volume API container
sim-os-instance-{nnn}    Tenant instance / VM  (e.g. sim-os-instance-001)
```

### Docker Networks
| Network name        | Subnet           | Maps to OpenStack concept      |
|---------------------|-----------------|--------------------------------|
| `dc-os-mgmt`        | 172.21.0.0/24   | OpenStack management network   |
| `dc-os-tenant-100`  | 172.21.100.0/24 | Neutron tenant network (proj A)|
| `dc-os-provider`    | 172.21.200.0/24 | Provider / external network    |

### Docker Object Mapping
| OpenStack Object     | Docker Implementation                                      |
|---------------------|------------------------------------------------------------|
| Keystone             | Stateless API container, in-memory token store             |
| Nova API             | Stateless API container, delegates to sim-engine           |
| Neutron              | Stateless API container, manages `dc-os-*` Docker networks |
| Cinder               | Stateless API container, manages Docker named volumes      |
| Instance (ACTIVE)    | Running container with SSH access                          |
| Instance (SHUTOFF)   | Stopped container                                          |
| Instance (PAUSED)    | Paused container (`docker pause`)                          |
| Flavor               | Docker `--cpus` + `--memory` resource limits               |
| Keypair              | SSH public key written to `/root/.ssh/authorized_keys`     |
| Security group rule  | Container `--publish` port mapping (iptables stub v1)      |
| Volume               | Docker named volume, attached via bind mount               |
| Image                | Docker image tag (e.g. `sim-ubuntu22:latest`)              |

### Docker Labels (per instance container)
```
sim.platform         = openstack
sim.type             = instance
sim.id               = instance-001
sim.guest_os         = rhel9 | ubuntu22
sim.vcpu             = 1
sim.memory_mb        = 2048
sim.power_state      = on | off | suspended
sim.env              = dev | staging | prod
sim.ansible_user     = root
sim.ssh_port         = <mapped host port>
sim.os.project       = demo
sim.os.flavor        = m1.small
sim.os.network       = private-net
sim.os.image         = ubuntu-22.04
sim.os.keypair       = default-key
```

### Default Seed Topology (dev environment)
```
OpenStack Region: RegionOne
└── Project: demo
    ├── Network: private-net  (dc-os-tenant-100)
    ├── Flavor:  m1.small     (1 vCPU, 2 GB RAM)
    ├── Image:   ubuntu-22.04 (sim-ubuntu22:latest)
    │
    ├── sim-os-instance-001  (Ubuntu 22, m1.small)  → SSH :22004
    ├── sim-os-instance-002  (Ubuntu 22, m1.small)  → SSH :22005
    └── sim-os-instance-003  (RHEL 9,    m1.small)  → SSH :22006
```

### Ansible Inventory Groups
```
[openstack]            all OpenStack instances
[openstack_ubuntu]     sim.guest_os = ubuntu22
[openstack_rhel]       sim.guest_os = rhel9
[project_demo]         sim.os.project = demo
```

---

## Open Questions

- [x] Token expiry → **Long-lived tokens for v1 simplicity.**
- [x] Swift object storage → **Out of scope for v1.**
- [x] Heat orchestration → **Stretch goal.**
