# ADR-006: vcsim for VMware API Simulation

**Status:** Accepted
**Date:** 2026-02-22
**Deciders:** DatacenterOS Team

---

## Context

SPEC-020 requires the VMware adapter to expose a vSphere-compatible REST/SOAP API so that tools like `govc`, Terraform's `vsphere` provider, and Ansible's `community.vmware` collection can connect without modification. Two implementation approaches were evaluated:

1. **Custom mock** — Write a stub vSphere API in Python/Go that handles only the endpoints dc-sim needs.
2. **vcsim** — Use `vmware/govcsim`, an open-source vSphere API simulator written in Go by the VMware team, as a sidecar container.

---

## Decision

**Use `vmware/govcsim` (vcsim) as a sidecar container inside `sim-engine`.**

---

## Rationale

| Criterion | Custom mock | vcsim |
|-----------|------------|-------|
| API coverage | Only endpoints we implement | Full vSphere REST + SOAP/SDK |
| `govc` compatibility | Partial (must chase govc calls) | Full — tested by the VMware team |
| Terraform `vsphere` provider | Partial | Full — vcsim is the provider's test target |
| Ansible `community.vmware` | Partial | Full |
| PowerCLI | Not supported | Supported |
| Maintenance burden | High (must keep up with vSphere API changes) | Low (upstream govmomi team maintains) |
| Realism for operators | Limited by stub quality | Indistinguishable from real vCenter for most ops workflows |
| Implementation effort | High | Low (add sidecar, set GOVC_URL) |

vcsim is the **reference simulator used by the govmomi project itself** (which powers govc and the Terraform vsphere provider). Using it in dc-sim gives operators a simulator that behaves identically to what the production tooling tests against.

---

## Implementation

vcsim runs as a sidecar inside the `sim-engine` container or as a companion service:

```yaml
# docker-compose.platform.yml (excerpt)
sim-engine:
  image: dc-sim/sim-engine
  ...

vcsim:
  image: vmware/govcsim:latest
  command: ["vcsim", "-l", "0.0.0.0:8989"]
  environment:
    VCSIM_USERNAME: user
    VCSIM_PASSWORD: pass
  networks:
    - dc-internal
```

`sim-engine` synchronizes its container-as-VM state to vcsim via the govmomi Go client:
- When a sim node container starts → register VM object in vcsim.
- When a container stops → update VM power state in vcsim.
- When a container is removed → deregister from vcsim.

**Client tools connect to:**
```
GOVC_URL=https://user:pass@vcsim:8989/sdk
GOVC_INSECURE=1
```

---

## Consequences

**Positive:**
- `govc`, Terraform `vsphere` provider, and Ansible `community.vmware` work against dc-sim out of the box.
- No custom vSphere API implementation to maintain.
- vcsim's seed topology (hosts, datastores, networks) matches the Container Topology in SPEC-020.
- Operators can practice real VMware automation workflows.

**Negative:**
- vcsim state is independent of Docker container state — `sim-engine` must keep them in sync.
- vcsim's simulated behaviors (DRS, HA, vMotion) are simplistic; complex scenarios may not match production behavior.
- Adding vcsim as a dependency means `sim-engine` requires the govmomi Go client for synchronization.

**Mitigation:**
- State sync is one-directional in v1: Docker container events → vcsim updates. Bidirectional sync (vcsim API call → container action) is v2.
- vcsim behavioral limitations are documented as known constraints in SPEC-020.
