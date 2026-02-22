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

## Open Questions

- [ ] Implement token expiry and refresh or use long-lived tokens for simplicity in v1?
- [ ] Swift (Object Storage) in scope for v1? → No, deferred.
- [ ] Heat (Orchestration) in scope for v1? → Stretch goal.
