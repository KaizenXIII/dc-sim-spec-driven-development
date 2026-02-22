# SPEC-110: Ansible & Configuration Management

**Status:** Draft
**Author:** DatacenterOS Team
**Created:** 2026-02-22
**GitHub Issue:** #13
**Depends on:** SPEC-010, SPEC-050

---

## Summary

This spec defines how Ansible is integrated into dc-sim for configuration management, patch operations, drift remediation, and infrastructure automation. Ansible targets simulated VMs (Docker containers with sshd) via a dynamic inventory sourced from the CMDB.

---

## Architecture

```
┌─────────────┐      dynamic inventory      ┌──────────┐
│   Ansible   │ ──────────────────────────> │   CMDB   │
│   Runner    │                              └──────────┘
│             │      SSH                    ┌──────────────────┐
│             │ ──────────────────────────> │ Simulated VMs    │
└─────────────┘                             │ (containers with │
       │                                    │  sshd running)   │
       │ reports results                    └──────────────────┘
       ▼
┌─────────────┐
│  CMDB /     │
│  Patch Mgr  │
│  Drift Det  │
└─────────────┘
```

---

## Dynamic Inventory

The CMDB exposes an Ansible-compatible dynamic inventory endpoint:

```
GET /cmdb/ansible/inventory
```

Returns Ansible inventory JSON format:
```json
{
  "_meta": { "hostvars": { "vm-001": { "ansible_host": "172.20.0.10", "ansible_user": "sim-admin" } } },
  "all": { "hosts": ["vm-001", "vm-002"] },
  "rhel": { "hosts": ["vm-001"] },
  "ubuntu": { "hosts": ["vm-002"] },
  "env_dev": { "hosts": ["vm-001", "vm-002"] },
  "vmware": { "hosts": ["vm-001"] },
  "openstack": { "hosts": ["vm-002"] }
}
```

Groups are derived from CI tags in CMDB (OS, environment, platform, role).

---

## Playbook Library

All playbooks live under `/services/ansible/playbooks/`:

### Infrastructure Provisioning
```
provision-vm-vmware.yml      # Create VM via VMware sim API + configure OS
provision-instance-os.yml    # Boot OpenStack instance + bootstrap
associate-ucs-blade.yml      # Assign UCS service profile + configure blade
```

### Configuration Management
```
baseline-rhel.yml            # Apply RHEL hardening + baseline config
baseline-ubuntu.yml          # Apply Ubuntu hardening + baseline config
configure-networking.yml     # Apply NIC config, DNS, NTP
configure-storage.yml        # Mount volumes, configure fstab
```

### Patch Management
```
scan-compliance.yml          # Detect available updates, write results to CMDB
patch-rhel.yml               # Apply RHEL patches
patch-ubuntu.yml             # Apply Ubuntu patches
reboot-managed.yml           # Rolling reboot with health checks
rollback-snapshot.yml        # Restore VM to pre-patch snapshot
```

### Drift Remediation
```
remediate-config-drift.yml   # Re-apply desired config from CMDB vars
remediate-package-drift.yml  # Remove unauthorized packages
remediate-network-drift.yml  # Restore network configuration
```

### Compliance & Audit
```
audit-cis-rhel.yml           # Run CIS benchmark checks
audit-cis-ubuntu.yml         # Run CIS benchmark checks
collect-facts.yml            # Gather and push facts to CMDB
```

---

## Ansible Roles

Reusable roles in `/services/ansible/roles/`:

| Role | Purpose |
|------|---------|
| `sim_vm_base` | Common VM bootstrapping |
| `sim_patch` | OS-agnostic patch wrapper |
| `sim_hardening` | Security baseline |
| `sim_monitoring` | Install/configure node_exporter + Promtail |
| `sim_cmdb_facts` | Push gathered facts to CMDB API |

---

## Ansible Runner API

The ansible service wraps `ansible-runner` and exposes:

```
POST   /ansible/run              Trigger a playbook run
GET    /ansible/runs             List past runs
GET    /ansible/runs/{id}        Get run status + logs
POST   /ansible/runs/{id}/cancel Cancel in-progress run
GET    /ansible/inventory        Return current dynamic inventory
```

---

## Simulated VM SSH Access

Each simulated VM container runs `sshd`:
- Port 22 mapped to a Docker-managed port.
- SSH key pair generated at container creation, public key stored in CMDB.
- Ansible uses the stored private key for authentication.
- Containers use base images: `sim-rhel9`, `sim-ubuntu22` (custom images with sshd + Python).

---

## Open Questions

- [ ] Use AWX (Ansible Tower OSS) for a GUI runner? → Stretch goal.
- [ ] Ansible Galaxy integration for pulling community roles? → Yes, for cisco.ucs and community.vmware.
- [ ] Ansible Vault for secrets management in sim environment? → Yes, even in sim, practice good habits.
