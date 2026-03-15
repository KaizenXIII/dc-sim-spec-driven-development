# dc-sim — Hybrid Datacenter Simulation Platform

A **hybrid datacenter simulation platform** built using **Spec-Driven Development (SDD)** practices on GitHub. It models a realistic enterprise multi-vendor datacenter — VMware/ESXi, OpenStack, and Cisco UCS — using Docker containers as fake VMs, with a full DevOps/SRE platform built on top: CMDB, ITSM, patch management, drift detection, observability, CI/CD pipelines, Ansible configuration management, and a single-pane-of-glass dashboard.

> **Current status:** Specs are in Draft. The simulated node layer (9 containers) and the Ansible hello-world pipeline are working. Application services are not yet implemented.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Glass Pane UI                        │
│              (Single Pane of Glass Dashboard)           │
└────────────────────────┬────────────────────────────────┘
                         │ REST / WebSocket
┌────────────────────────▼────────────────────────────────┐
│                    API Gateway                          │
└──┬──────────┬──────────┬──────────┬──────────┬──────────┘
   │          │          │          │          │
┌──▼──┐  ┌───▼───┐  ┌───▼──┐  ┌───▼───┐  ┌───▼────────┐
│CMDB │  │ ITSM  │  │Patch │  │Drift  │  │Observability│
│     │  │       │  │ Mgr  │  │Detect │  │& Logging   │
└──┬──┘  └───────┘  └───┬──┘  └───┬───┘  └────────────┘
   │                    │         │
┌──▼────────────────────▼─────────▼──────────────────────┐
│                  Simulation Engine                      │
│     VMware API Sim │ OpenStack API Sim │ UCS API Sim   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐             │
│  │ vm-001   │  │ vm-002   │  │ vm-003   │ (fake VMs)  │
│  └──────────┘  └──────────┘  └──────────┘             │
└────────────────────────────────────────────────────────┘
```

---

## Spec-Driven Development

Every feature follows this mandatory workflow — no code ships without an approved spec:

1. Write a spec file in `specs/`
2. Open a GitHub Issue using the Spec template
3. Get spec reviewed and approved
4. Open PRs referencing the spec (CI enforces via `spec-check.yml`)
5. Mark spec as Implemented when all criteria are met

---

## Spec Index

| Spec | Title | Status |
|---|---|---|
| SPEC-000 | Project Overview | Draft |
| SPEC-001 | System Architecture | Draft |
| SPEC-010 | Simulation Engine | Draft |
| SPEC-020 | VMware/ESXi Simulation | Draft |
| SPEC-030 | OpenStack Simulation | Draft |
| SPEC-040 | Cisco UCS Simulation | Draft |
| SPEC-050 | CMDB | Draft |
| SPEC-060 | ITSM | Draft |
| SPEC-070 | Patch Management | Draft |
| SPEC-080 | Drift Detection | Draft |
| SPEC-090 | Observability & Logging | Draft |
| SPEC-100 | CI/CD Pipelines | Draft |
| SPEC-110 | Ansible & Config Mgmt | Draft |
| SPEC-120 | Glass Pane Dashboard | Draft |

---

## Quick Start: Simulated Datacenter Nodes

```bash
git clone https://github.com/KaizenXIII/dc-sim-spec-driven-development.git
cd dc-sim-spec-driven-development

# Start nodes, run hello-world playbook, leave containers up
bash scripts/local-pipeline.sh

# Start, run, then tear everything down
bash scripts/local-pipeline.sh --cleanup

# Tear down running containers
bash scripts/local-pipeline.sh --down
```

### Simulated Node Topology

| Container | Platform | Guest OS | SSH Port |
|---|---|---|---|
| `sim-vmw-vm-001` | VMware | RHEL 9 | 22001 |
| `sim-vmw-vm-002` | VMware | Ubuntu 22 | 22002 |
| `sim-vmw-vm-003` | VMware | RHEL 9 | 22003 |
| `sim-os-instance-001` | OpenStack | Ubuntu 22 | 22004 |
| `sim-os-instance-002` | OpenStack | Ubuntu 22 | 22005 |
| `sim-os-instance-003` | OpenStack | RHEL 9 | 22006 |
| `sim-ucs-blade-c01s01` | Cisco UCS | RHEL 9 | 22007 |
| `sim-ucs-blade-c01s02` | Cisco UCS | Ubuntu 22 | 22008 |
| `sim-ucs-blade-c01s03` | Cisco UCS | RHEL 9 | 22009 |

---

## Running Ansible Playbooks

```bash
cd services/ansible

# Run hello-world against all 9 nodes
ansible-playbook playbooks/hello-world.yml

# Target a single platform
ansible-playbook playbooks/hello-world.yml --limit vmware
ansible-playbook playbooks/hello-world.yml --limit openstack
ansible-playbook playbooks/hello-world.yml --limit ucs_blades
```

---

## CI/CD Workflows

| Workflow | Trigger | What it does |
|---|---|---|
| `ci.yml` | Push to `main`/`develop`, all PRs | Detects changed services, runs lint + test per service |
| `spec-check.yml` | All PRs | Fails if a PR touching `services/` or `infra/` has no spec reference |
| `ansible-pipeline.yml` | Manual dispatch or push to `develop` | Lints playbooks and validates syntax |

---

## Architecture Decisions

- **[ADR-001: Event Bus](docs/adr/ADR-001-event-bus.md)** — Redis Streams chosen over NATS/Kafka
- **[ADR-002: CMDB Storage](docs/adr/ADR-002-cmdb-storage.md)** — PostgreSQL + JSONB chosen over Neo4j

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full Spec-Driven Development workflow. The short version: write a spec first, get it approved, then implement with `Spec: SPEC-XXX` in your PR body.

## License

No license file is present in this repository.
