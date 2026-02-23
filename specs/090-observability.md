# SPEC-090: Observability & Logging

**Status:** Draft
**Author:** DatacenterOS Team
**Created:** 2026-02-22
**GitHub Issue:** #11
**Depends on:** SPEC-010

---

## Summary

The observability stack provides metrics, logs, and traces for both the simulated infrastructure and the platform services themselves. It uses the industry-standard PLT stack (Prometheus, Loki, Tempo) with Grafana as the unified visualization layer.

**Deployment:** Infrastructure component (not one of the 3 core units — see SPEC-001). Deployed alongside `core-api`, `sim-engine`, and `ansible-runner` via `docker compose`. All three units expose `/metrics` and ship structured logs to Loki.

---

## Three Pillars

### 1. Metrics (Prometheus)
- All platform services expose `/metrics` in Prometheus format.
- Sim-engine generates fake infrastructure metrics (CPU, memory, disk, network) for simulated VMs/hosts.
- Alertmanager routes alerts to ITSM for incident auto-creation.

**Key metric namespaces:**

| Namespace | Description |
|-----------|-------------|
| `dcsim_vm_*` | Per-VM: cpu_usage, memory_usage, disk_io, net_io |
| `dcsim_host_*` | Per-host: power_state, temperature, uptime |
| `dcsim_cluster_*` | Cluster: capacity_used, vm_count, overcommit_ratio |
| `dcsim_patch_*` | Patch compliance %, pending CVEs |
| `dcsim_drift_*` | Drift events per hour, open drift count |
| `dcsim_itsm_*` | Open incidents by severity, MTTR |

### 2. Logs (Loki)
- All platform services ship structured JSON logs to Loki via Promtail.
- Simulated VMs generate mock syslog / application logs (seeded from log templates).
- Log labels: `service`, `env`, `ci_id`, `severity`.

**Log retention:** 30 days (configurable).

### 3. Traces (Tempo)
- Distributed tracing via OpenTelemetry SDK across all services.
- Trace propagation: `api-gateway` → downstream services.
- Grafana Tempo datasource for trace exploration.

---

## Stack Components

| Component | Role | Port |
|-----------|------|------|
| Prometheus | Metrics collection + alerting | 9090 |
| Alertmanager | Alert routing | 9093 |
| Loki | Log aggregation | 3100 |
| Promtail | Log shipper (sidecar) | 9080 |
| Tempo | Trace backend | 3200 |
| Grafana | Unified dashboards | 3000 |
| OpenTelemetry Collector | Metrics/traces pipeline | 4317 |

---

## Pre-built Grafana Dashboards

| Dashboard | Purpose |
|-----------|---------|
| Datacenter Overview | VM count, host health, cluster capacity |
| VM Performance | Per-VM CPU/memory/disk/net sparklines |
| Patch Compliance | Compliance % over time, CVE heatmap |
| Drift Tracker | Drift events timeline, top drifting CIs |
| ITSM Health | Incident volume, MTTR, open changes |
| Service Latency | API gateway p50/p95/p99 latency |

---

## Alert Rules (Prometheus)

```yaml
- alert: HighCPUUsage
  expr: dcsim_vm_cpu_usage > 90
  for: 5m
  labels: { severity: warning }
  annotations:
    summary: "VM {{ $labels.vm_id }} CPU > 90%"
    action: "auto_create_incident=true"

- alert: DriftDetected
  expr: dcsim_drift_open_count > 0
  labels: { severity: info }

- alert: PatchNonCompliance
  expr: dcsim_patch_compliance_pct < 80
  labels: { severity: high }
```

---

## Simulated Metric Generation

The sim-engine generates realistic metric noise for all simulated VMs:
- Base values seeded from VM flavor (size).
- Gaussian noise applied per scrape interval.
- Configurable load profiles: idle / normal / stressed / spiking.
- Failure injection triggers metric anomalies.

---

## Open Questions

- [ ] Use Victoria Metrics instead of Prometheus for better performance at scale?
- [ ] Integrate OpenSearch/Elasticsearch as an alternative log backend? → No, Loki for v1.
- [ ] Synthetic monitoring (Blackbox exporter) for simulated service endpoints?
