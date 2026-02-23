# SPEC-100: CI/CD Pipelines

**Status:** Draft
**Author:** DatacenterOS Team
**Created:** 2026-02-22
**GitHub Issue:** #12
**Depends on:** SPEC-001

---

## Summary

This spec defines the CI/CD strategy for the dc-sim platform itself and for pipelines that deploy workloads into the simulated datacenter. GitHub Actions is the CI/CD engine for platform code. The simulated environment also exposes a deployment target so users can practice CD pipelines against fake infrastructure.

---

## Two Layers of CI/CD

### Layer 1: Platform CI/CD (building dc-sim itself)
Automated testing and delivery of the dc-sim platform code.

### Layer 2: Simulated Deployment Pipelines (deploying INTO dc-sim)
Example pipelines that deploy applications into the simulated datacenter — used for practicing CD workflows against VMware/OpenStack/UCS targets.

---

## Layer 1: Platform CI/CD

### Pipeline Stages

```
PR Opened
    │
    ▼
┌─────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
│  Lint   │──>│  Build   │──>│  Test    │──>│  Scan    │
│ (per    │   │ (Docker  │   │ (unit +  │   │ (Trivy + │
│ service)│   │  images) │   │ integr.) │   │ semgrep) │
└─────────┘   └──────────┘   └──────────┘   └────┬─────┘
                                                   │ main branch only
                                                   ▼
                                          ┌──────────────┐
                                          │   Release    │
                                          │ (tag + push  │
                                          │  to GHCR)    │
                                          └──────────────┘
```

### Deployable Units (3 core + infrastructure)

Per SPEC-001, the platform builds three deployable unit images:

| Image | Directory | Build trigger |
|-------|-----------|--------------|
| `dc-sim/core-api` | `services/core-api/` | Changes under `services/core-api/**` |
| `dc-sim/sim-engine` | `services/sim-engine/` | Changes under `services/sim-engine/**` |
| `dc-sim/ansible-runner` | `services/ansible-runner/` | Changes under `services/ansible-runner/**` |
| `dc-sim/ui` | `services/ui/` | Changes under `services/ui/**` |

### GitHub Actions Workflows

| Workflow File | Trigger | Purpose |
|---------------|---------|---------|
| `ci.yml` | PR open / push | Lint, build, unit test per deployable unit |
| `integration.yml` | PR merge to main | Full docker-compose up + integration tests |
| `security-scan.yml` | Nightly | Trivy image scan + Semgrep SAST |
| `release.yml` | Tag push `v*` | Build + push Docker images to GHCR |
| `spec-check.yml` | PR open | Verify each changed service has a linked spec |

### Spec-Check Enforcement

Every PR that modifies a service under `/services/` must reference a spec file:
- PR description must contain `Spec: SPEC-XXX` or `Closes #N`.
- `spec-check.yml` fails the PR if no spec reference is found.

---

## Layer 2: Simulated Deployment Pipelines

Example pipelines in `/infra/pipelines/` that deploy workloads into the sim:

### VMware Deployment Pipeline
```yaml
# deploy-to-vmware.yml
steps:
  - terraform init/plan/apply  # using vsphere provider → sim VMware API
  - ansible-playbook configure-vm.yml
  - run smoke tests against new VM
```

### OpenStack Deployment Pipeline
```yaml
# deploy-to-openstack.yml
steps:
  - openstack server create (via sim OpenStack API)
  - heat stack deploy (stretch)
  - ansible-playbook bootstrap.yml
```

### UCS Service Profile Pipeline
```yaml
# deploy-ucs-profile.yml
steps:
  - ansible cisco.ucs.ucs_service_profile
  - associate blade
  - PXE boot simulation
  - report blade ready
```

---

## CD to Simulated Environments

| Environment | Target | Trigger |
|-------------|--------|---------|
| dev | sim-engine dev namespace | Push to `develop` branch |
| staging | sim-engine staging namespace | PR merge to `main` |
| prod-sim | sim-engine prod namespace | Manual approval after staging |

---

## Open Questions

- [ ] Use ArgoCD for GitOps-style CD into Kubernetes (infra/k8s)?
- [ ] Implement deployment approval gates (ITSM change required) in pipelines?
- [ ] Publish build status badges to Glass Pane dashboard?
