# SPEC-110: Ansible & Configuration Management

**Status:** Draft
**Author:** DatacenterOS Team
**Created:** 2026-02-22
**GitHub Issue:** #13
**Depends on:** SPEC-010, SPEC-050

---

## Summary

This spec defines how Ansible is integrated into dc-sim for configuration management, patch operations, drift remediation, and infrastructure automation. Ansible targets simulated VMs (Docker containers with sshd) via a dynamic inventory sourced from NetBox (via `core-api`).

**Deployment:** `ansible-runner` is a standalone deployable unit — Unit 3 in SPEC-001. It lives at `services/ansible-runner/` and is event-triggered (Redis Streams) or API-triggered (REST `POST /ansible/run`). Not embedded in `core-api`.

---

## Architecture

```
┌─────────────────┐    GET /cmdb/ansible/inventory    ┌──────────────────┐
│  ansible-runner │ ───────────────────────────────> │  core-api        │
│  (Unit 3)       │                                   │  (NetBox proxy)  │
│                 │      SSH                          └──────────────────┘
│                 │ ──────────────────────────────>  ┌──────────────────┐
└────────┬────────┘                                  │ Simulated VMs    │
         │                                           │ (containers with │
         │  POST /ansible/run  ◄── Redis Streams     │  sshd running)   │
         │  (drift.detected, patch.scheduled)        └──────────────────┘
         │
         │  reports results back via Redis Streams
         ▼
   ansible.run.completed → core-api (patch module, drift module)
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

All playbooks live under `services/ansible-runner/playbooks/`:

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

Reusable roles in `services/ansible-runner/roles/`:

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
- Port 22 mapped to a unique host port (see SSH Port Assignments below).
- SSH key pair generated once per environment, public key bind-mounted into containers.
- Ansible uses the private key for all authentication — no password auth.
- Containers use base images: `sim-rhel9`, `sim-ubuntu22` (Ubuntu 22.04 + openssh-server + Python 3).

---

## SSH Key Management

### Key Generation (dev environment)
Keys are generated once on first run of `scripts/local-pipeline.sh`:

```bash
ssh-keygen -t ed25519 -f infra/docker/sim-dev.key -N "" -C "dc-sim-dev"
```

- Private key: `infra/docker/sim-dev.key` — **gitignored, never committed**
- Public key:  `infra/docker/sim-dev.key.pub` — committed to repo (safe)

### Key Injection into Containers
Each sim node container has the public key bind-mounted at startup:

```yaml
volumes:
  - ./sim-dev.key.pub:/tmp/sim-authorized-key:ro
```

The container entrypoint copies it to `/root/.ssh/authorized_keys` on first boot.

### Ansible Connection Config (`group_vars/all.yml`)
```yaml
ansible_user: root
ansible_ssh_private_key_file: "{{ playbook_dir }}/../../../infra/docker/sim-dev.key"
ansible_python_interpreter: /usr/bin/python3
ansible_ssh_common_args: "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
```

### SSH Port Assignments (dev seed topology)
| Container              | Platform    | Host Port |
|------------------------|-------------|-----------|
| sim-vmw-vm-001         | VMware      | 22001     |
| sim-vmw-vm-002         | VMware      | 22002     |
| sim-vmw-vm-003         | VMware      | 22003     |
| sim-os-instance-001    | OpenStack   | 22004     |
| sim-os-instance-002    | OpenStack   | 22005     |
| sim-os-instance-003    | OpenStack   | 22006     |
| sim-ucs-blade-c01s01   | Cisco UCS   | 22007     |
| sim-ucs-blade-c01s02   | Cisco UCS   | 22008     |
| sim-ucs-blade-c01s03   | Cisco UCS   | 22009     |

### CMDB Key Storage (production model)
When the CMDB service is implemented, the SSH public key fingerprint for each CI is stored as:
```json
{ "ci_id": "vm-001", "attributes": { "ssh_public_key_fingerprint": "SHA256:...", "ssh_port": 22001 } }
```
The ansible service retrieves these via `GET /cmdb/ansible/inventory` to build the dynamic inventory.

---

## Open Questions

- [x] AWX GUI runner → **Stretch goal.**
- [x] Ansible Galaxy community roles → **Yes: `cisco.ucs` and `community.vmware` via `requirements.yml`.**
- [x] Ansible Vault → **Yes, use Vault even in sim. Practice good habits from the start.**
