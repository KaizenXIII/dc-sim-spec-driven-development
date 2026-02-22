# dc-sim-spec-driven-development

A **hybrid datacenter simulation platform** built using **Spec-Driven Development (SDD)** practices on GitHub.

Simulates a realistic enterprise datacenter — VMware/ESXi, OpenStack, and Cisco UCS — using Docker containers as fake VMs. Built on top is a full DevOps/SRE platform: CMDB, ITSM, patch management, drift detection, observability, CI/CD, Ansible automation, and a single-pane-of-glass dashboard.

---

## What This Project Is

| Layer | What it does |
|-------|-------------|
| **Simulation Engine** | Manages simulated hosts, VMs (containers), networks. Exposes vSphere, OpenStack, and UCS APIs. |
| **CMDB** | Source of truth for all configuration items and their relationships. |
| **ITSM** | Incident, problem, and change management. |
| **Patch Manager** | Tracks and orchestrates patch compliance via Ansible. |
| **Drift Detector** | Compares desired vs. actual state; triggers remediation. |
| **Observability** | Prometheus + Loki + Tempo + Grafana stack. |
| **CI/CD** | GitHub Actions pipelines for the platform and simulated deployments. |
| **Ansible** | Configuration management and automation against simulated VMs. |
| **Glass Pane UI** | React dashboard — single pane of glass for the full datacenter. |

---

## How This Project Is Built (Spec-Driven Development)

Every feature follows this workflow:

```
1. Write a spec file in specs/
2. Open a GitHub Issue using the Spec template → gets Issue number
3. Update spec file with Issue number
4. Get spec reviewed and approved on the Issue
5. Open PRs referencing the spec (CI enforces this)
6. Mark spec as Implemented when all criteria are met
```

**Read the specs before writing any code.** The `specs/` directory is the authoritative source for what should be built and why.

---

## Spec Index

| Spec | Title | Status |
|------|-------|--------|
| [SPEC-000](specs/000-overview.md) | Project Overview | Draft |
| [SPEC-001](specs/001-architecture.md) | System Architecture | Draft |
| [SPEC-010](specs/010-simulation-layer.md) | Simulation Engine | Draft |
| [SPEC-020](specs/020-vmware-esxi-sim.md) | VMware/ESXi Simulation | Draft |
| [SPEC-030](specs/030-openstack-sim.md) | OpenStack Simulation | Draft |
| [SPEC-040](specs/040-cisco-ucs-sim.md) | Cisco UCS Simulation | Draft |
| [SPEC-050](specs/050-cmdb.md) | CMDB | Draft |
| [SPEC-060](specs/060-itsm.md) | ITSM | Draft |
| [SPEC-070](specs/070-patch-management.md) | Patch Management | Draft |
| [SPEC-080](specs/080-drift-detection.md) | Drift Detection | Draft |
| [SPEC-090](specs/090-observability.md) | Observability & Logging | Draft |
| [SPEC-100](specs/100-cicd.md) | CI/CD Pipelines | Draft |
| [SPEC-110](specs/110-ansible-config-mgmt.md) | Ansible & Config Mgmt | Draft |
| [SPEC-120](specs/120-glass-pane-ui.md) | Glass Pane Dashboard | Draft |

---

## Repository Structure

```
dc-sim-spec-driven-development/
├── specs/                  # SDD spec files (read these first)
├── docs/
│   ├── adr/                # Architecture Decision Records
│   └── rfcs/               # Request for Comments
├── services/
│   ├── api-gateway/        # SPEC-001
│   ├── sim-engine/         # SPEC-010
│   ├── cmdb/               # SPEC-050
│   ├── itsm/               # SPEC-060
│   ├── patch-manager/      # SPEC-070
│   ├── drift-detector/     # SPEC-080
│   ├── observability/      # SPEC-090
│   └── ui/                 # SPEC-120
├── infra/
│   ├── docker/             # docker-compose files
│   └── k8s/                # Kubernetes manifests
├── scripts/                # Dev/ops helper scripts
└── .github/
    ├── ISSUE_TEMPLATE/     # Spec, Bug, Task templates
    └── workflows/          # GitHub Actions (CI + spec-check)
```

---

## Getting Started

> Services are not yet implemented. Specs are in Draft status. See `specs/` to follow progress.

```bash
# Clone
git clone https://github.com/KaizenXIII/dc-sim-spec-driven-development.git
cd dc-sim-spec-driven-development

# (Once implemented) Start full stack
docker compose -f infra/docker/docker-compose.yml up
```

---

## Architecture Decisions

See [docs/adr/](docs/adr/) for recorded architecture decisions:
- [ADR-001: Event Bus Selection](docs/adr/ADR-001-event-bus.md)
- [ADR-002: CMDB Storage Backend](docs/adr/ADR-002-cmdb-storage.md)

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
