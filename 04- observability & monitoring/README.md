# Observability & Monitoring — Grafana, Prometheus, Loki, Alloy

A complete observability stack for monitoring Proxmox VMs with node-level metrics, container metrics, centralized log aggregation, and Discord alerting — deployed entirely via Ansible.

- Corresponding post: [Phase IV — Your Own Little Palantír w/ LGTM Stack](https://medium.com/@0xA1M/phase-vi-your-own-little-palantir-w-lgtm-stack-fcdeb8a40304)

## Overview

The stack is split into two parts:

1. **Monitoring VM** — runs Prometheus, Loki, Grafana, Alertmanager, alertmanager-discord, and PVE Exporter as Docker containers via `docker-compose.yml`. All configs live in `configs/` and secrets are injected from Ansible Vault.
2. **Target VMs** — run Grafana Alloy as a single privileged Docker container that collects node metrics, container metrics (cAdvisor), system logs, and Docker container logs, then pushes everything to the monitoring VM via remote write. Alloy is also scraped directly by Prometheus for health monitoring (`up == 0` alerts).

## Key Concepts

- **Alloy as a unified collector** — replaces three separate agents (Node Exporter, Promtail, cAdvisor) with one container. One config language (River) for all telemetry types. Deployed via Ansible in a single role.
- **Hybrid push+pull** — target VMs push metrics and logs to the monitoring VM (resilient across NAT, subnets, and reboots). Prometheus pulls only from the PVE Exporter on the monitoring VM itself, and scrapes Alloy agents directly for health status.
- **Remote Write + file_sd service discovery** — new VMs appear in Grafana automatically the moment Alloy starts pushing. Prometheus discovers Alloy agents via `file_sd_configs` reading target files written by the `register-vm` playbook.
- **Auto-provisioned Grafana** — datasources (Prometheus, Loki) and three dashboards (Node Exporter, Docker, Proxmox) are loaded on startup via provisioning files. No manual configuration.
- **Ansible Vault for secrets** — Discord webhook URL, Grafana admin password, and Discord bot username stored encrypted in `group_vars/monitoring/vault.yml`. Templated to `.env` at deploy time.

## Architecture

```
                          Monitoring VM (Docker Compose)
  ┌──────────────────────────────────────────────────────────────┐
  │  ┌──────────┐   ┌─────────┐   ┌──────────┐                 │
  │  │Prometheus│   │  Loki   │   │ Grafana  │  PVE Exporter   │
  │  │  :9090   │   │ :3100   │   │  :3000   │  :9221          │
  │  └────┬─────┘   └───┬─────┘   └──────────┘  └──────┬───────┘
  │       │              │                               │
  │  ┌────▼──────────────▼───────────────────────────────▼────┐
  │  │         Alertmanager + alertmanager-discord            │
  │  │   (internal Docker network, no host ports exposed)     │
  │  └────────────────────────────────────────────────────────┘
  └──────────────────────────────────────────────────────────────┘
           ▲                          ▲
           │ Push metrics via         │ Push logs via
           │ remote_write             │ HTTP to Loki API
           │                          │
           │         +                │
           │ Scrape via file_sd       │
           │ (health check)           │
           │                          │
  ┌──────────────────────────────────────────────────────────────┐
  │    Target VM (Alloy, privileged Docker container)            │
  │                                                              │
  │  ┌──────────────────────────────────────────────────────┐    │
  │  │  prometheus.exporter.unix "local"   → node metrics   │    │
  │  │  prometheus.exporter.cadvisor       → container met. │    │
  │  │  loki.source.docker "docker_logs"   → Docker logs    │    │
  │  │  loki.source.file "logs"            → syslog         │    │
  │  │  prometheus.remote_write            → Prometheus     │    │
  │  │  loki.write                         → Loki           │    │
  │  └──────────────────────────────────────────────────────┘    │
  └──────────────────────────────────────────────────────────────┘
```

### Data Flow

- **Metrics from target VMs (Push)**: Alloy scrapes system and container metrics locally, pushes to Prometheus via `remote_write` at `/api/v1/write`. Alloy's Write-Ahead Log buffers data during network interruptions.
- **Health checks for Alloy agents (Pull)**: Prometheus scrapes each Alloy agent's HTTP endpoint (`:12345`) using `file_sd_configs` target files. This allows `up == 0` to fire when an Alloy agent goes down.
- **Proxmox host metrics (Pull)**: Prometheus scrapes the PVE Exporter container at `pve-exporter:9221/pve` with the Proxmox host IP as a parameter.
- **Logs from target VMs (Push)**: Alloy tails `/var/log` files and streams Docker container logs via the Docker API, pushing to Loki via HTTP.
- **Prometheus self-monitoring (Pull)**: Prometheus scrapes itself at `localhost:9090`.
- **Alerts (Push)**: Prometheus evaluates alert rules and pushes firing alerts to Alertmanager, which routes them to `alertmanager-discord` for Discord delivery.

## Prerequisites

1. A VM to run the monitoring stack (Docker installed, 4GB+ RAM, 20GB+ disk).
2. Target VMs with Docker (for Alloy to collect container metrics).
3. SSH access to both VMs (the playbooks use `ansible_user` from the inventory).
4. Ansible installed (or use `devbox`).
5. `community.docker` Ansible collection: `ansible-galaxy collection install -r ansible/requirements.yml`.
6. A Proxmox monitoring user with API token — see the blog post for setup steps.

## Setup

See the blog post for a full walkthrough. The short version:

```bash
# Deploy the monitoring VM (targets [monitoring] group in inventory.ini)
ansible-playbook -i ansible/inventory.ini ansible/playbooks/setup-monitoring-vm.yaml --ask-vault-pass

# Register a target VM (replace with your VM's IP or inventory host)
ansible-playbook -i ansible/inventory.ini -l 10.0.0.115 ansible/playbooks/register-vm.yaml
```

### What Each Playbook Does

**`setup-monitoring-vm.yaml`**:
1. Installs Docker if missing
2. Copies `docker-compose.yml` and all configs to `/opt/monitoring`
3. Substitutes `CHANGEME_PROXMOX_HOST_IP` in `prometheus.yml` with the real Proxmox host IP
4. Templates `.env` from Ansible Vault (mode 0600)
5. Runs `docker compose up -d` with `pull: always` and `remove_orphans: true`
6. Restarts Grafana so provisioned dashboards take effect
7. Prints running containers and Grafana credentials

**`register-vm.yaml`**:
1. Runs the `grafana_alloy` role (installs Docker, deploys Alloy config, runs Alloy container)
2. Writes a Prometheus file_sd target file to the monitoring VM at `/opt/monitoring/configs/prometheus/targets/alloy-<hostname>.yml`
3. The target file contains `__meta_hostname` so Prometheus can label scraped metrics with the VM's hostname

**`unregister-vm.yaml`**:
1. Stops and removes the alloy container and config
2. Removes the corresponding target file from the monitoring VM

## Grafana Access

- URL: `http://YOUR_MONITORING_VM_IP:3000`
- User: `admin`
- Password: from Ansible Vault (`gf_security_admin_password`)

Credentials are printed at the end of `setup-monitoring-vm.yaml`. Three dashboards are auto-imported:

| Dashboard | ID | Source | What It Shows |
|-----------|-----|--------|---------------|
| Docker Monitoring | 19724 | cAdvisor | Container CPU, memory, network, filesystem |
| Node Exporter Full | 1860 | `prometheus.exporter.unix` | Host CPU, memory, disk, network, processes |
| Proxmox via Prometheus | 10347 | PVE Exporter | Host resources, VM list, storage, network |

## Configuration Files

### `docker-compose.yml`

Defines all services on the monitoring VM. Key design choices and edge cases:

- **No custom network** — services communicate on Docker's default bridge. Service names resolve as hostnames.
- **No `depends_on`** — services retry connections on failure; strict ordering isn't needed.
- **Alertmanager port not exposed** (`alertmanager` has no `ports:`) — internal to Docker only. Prometheus reaches it via service name `alertmanager:9093`.
- **`--web.enable-remote-write-receiver`** on Prometheus — accepts incoming remote_write pushes from Alloy agents. Without this flag, remote_write requests are rejected with a 404.
- **`--web.enable-admin-api`** on Prometheus — enables the admin HTTP API (e.g., `POST /api/v1/admin/tsdb/delete_series`). Used for cleaning stale time series when you remove a VM from monitoring or rename a host. The `register-vm.yaml` / `unregister-vm.yaml` playbooks manage target files, but stale TSDB data is cleaned manually via the admin API.
- **`benjojo/alertmanager-discord`** — the popular `rogerrum` image has a bug (sends `{"embeds": [0]}` which Discord rejects). The `benjojo` fork works correctly.
- **No `GF_INSTALL_PLUGINS`** — no extra plugins needed for this setup.
- **Named volumes** for persistent data: `prometheus_data`, `loki_data`, `grafana_data`.

### `configs/prometheus/prometheus.yml`

Three scrape jobs:

| Job | Target | Interval | Purpose |
|-----|--------|----------|---------|
| `prometheus` | `localhost:9090` | 15s | Prometheus self-metrics |
| `pve` | `pve-exporter:9221/pve` | 30s | Proxmox host metrics (slower API, longer timeout) |
| `alloy` | `file_sd` targets in `targets/alloy-*.yml` | 15s | Alloy agent health (enables `up == 0` alerts) |

**`pve` job details**:
- Passes `module=default` and `target=CHANGEME_PROXMOX_HOST_IP` as query parameters.
- The relabel config overrides `instance` to show the Proxmox host IP instead of the PVE Exporter container's IP.
- `CHANGEME_PROXMOX_HOST_IP` is substituted at deploy time by the `setup-monitoring-vm.yaml` playbook (uses `ansible.builtin.replace`). Set the value in `ansible/group_vars/monitoring/vars.yml` or pass it with `-e proxmox_host_ip=10.0.0.2`.

**`alloy` job details**:
- Uses `file_sd_configs` to discover Alloy targets from the `configs/prometheus/targets/` directory. Each registered VM gets a file like `alloy-my-vm.yml`.
- Two relabel rules:
  1. Extracts IP from `__address__` (which includes `:12345` port) and sets it as `instance` — gives a unique identifier per VM.
  2. Copies `__meta_hostname` (written by the `register-vm.yaml` playbook) to a `hostname` label — enables `{{ $labels.hostname }}` in alert annotations.
- The `targets/` directory is a shared volume mounted at `/etc/prometheus/targets`. It starts empty (`.gitkeep`). Target files are created by `register-vm.yaml` and cleaned up by `unregister-vm.yaml`.

### `configs/prometheus/alert.rules.yml`

Two alert rules:

```yaml
- alert: InstanceDown
  expr: up == 0
  for: 1m
  annotations:
    summary: "{{ if $labels.hostname }}{{ $labels.hostname }}{{ else }}{{ $labels.instance }}{{ end }} ({{ $labels.instance }}) is down"
```

- Fires when any scraped target (`prometheus`, `pve-exporter`, or any alloy agent) is unreachable for 1 minute.
- The annotation uses `$labels.hostname` if available (Alloy agents), falling back to `$labels.instance` (for Prometheus self or PVE exporter). This gives human-readable hostnames in Discord alerts.

```yaml
- alert: ContainerDown
  expr: (time() - container_last_seen{name=~".+", job="integrations/cadvisor"}) > 120
  for: 1m
  annotations:
    summary: "Container {{ $labels.name }} on {{ $labels.instance }} hasn't reported for > 2 minutes"
```

- Fires when a container stops sending cAdvisor metrics for more than 2 minutes (120 seconds).
- `container_last_seen` is a metric emitted by the cAdvisor component inside Alloy. The `{name=~".+"}` filter excludes the empty-name cAdvisor aggregate row.
- Useful for detecting crashed containers without waiting for a full VM-level alert. Severity is `warning` rather than `critical`.

### `configs/alertmanager/alertmanager.yml`

Routes all alerts to a single Discord receiver:

- **`group_by: ['alertname']`** — groups alerts by name, so multiple `InstanceDown` alerts are bundled into one notification.
- **`group_wait: 30s`** — waits 30 seconds before sending the first notification for a group (allows more alerts to arrive and be grouped).
- **`group_interval: 5m`** — waits 5 minutes before sending new alerts that join an existing group.
- **`repeat_interval: 4h`** — re-sends resolved alerts every 4 hours.
- **`send_resolved: true`** — sends a notification when an alert recovers (e.g., "InstanceDown resolved — alloy-vm-02 is back up"). Without this, you only get fire notifications, never resolve notifications.

The `discord` receiver posts to `alertmanager-discord:9094` (internal Docker network).

### `configs/loki/loki-config.yml`

Single-binary Loki with:

- **TSDB index** (schema v13) — modern, performant. No `boltdb-shipper` or `table_manager` needed.
- **Filesystem storage** — chunks written to `/loki/chunks`, index to `/loki/tsdb`.
- **`reject_old_samples: false`** — without this, Loki drops log entries older than the out-of-order ingestion window (~30m). When Alloy restarts and replays its Write-Ahead Log, old entries get silently dropped. This setting prevents that data loss.
- **Retention: 720h (30 days)** — the compactor handles automatic deletion.

### `configs/grafana/provisioning/datasources/datasources.yml`

Auto-creates two datasources:

| Name | Type | URL |
|------|------|-----|
| Prometheus | prometheus | `http://prometheus:9090` |
| Loki | loki | `http://loki:3100` |

Existing datasources with the same names are deleted first (`deleteDatasources`) to prevent drift from manual changes.

### `configs/grafana/provisioning/dashboards/dashboards.yml`

Loads all JSON files from the same directory. Three dashboards included (IDs 1860, 19724, 10347).

> **Datasource patching**: Community dashboard JSONs ship with `${DS_PROMETHEUS}` placeholders that aren't resolved by file provisioning. Each JSON in this repo is patched: `__inputs` removed, `${DS_PROMETHEUS}` replaced with `Prometheus`, and `ds_prometheus` template variables have a `current` default value set.

### `configs/pve-exporter/pve.yml`

```yaml
default:
  user: "CHANGEME_PROXMOX_USER@CHANGEME_REALM"
  token_name: "CHANGEME_TOKEN_NAME"
  token_value: "CHANGEME_TOKEN_SECRET"
  verify_ssl: false
```

Replace `CHANGEME_*` placeholders with your Proxmox API token credentials. The `default` module name matches `module=default` in the Prometheus scrape config. Set `verify_ssl: true` if your Proxmox host has a valid TLS certificate.

### `configs/alloy/alloy.river`

Reference River config for manual deployment (hardcoded `CHANGEME_MONITORING_VM_IP` placeholders). The Ansible role uses a templated version (`config.alloy.j2`) that substitutes Ansible facts and real URLs.

**Pipeline summary** (see the blog post for component-level explanation):

| Component | Function |
|-----------|----------|
| `prometheus.exporter.unix "local"` | Node-level metrics (CPU, memory, disk, network) |
| `prometheus.exporter.cadvisor "docker"` | Container-level metrics (cAdvisor) |
| `discovery.relabel "cadvisor"` | Copies `name` → `container` label, sets `instance` to hostname |
| `discovery.docker "containers"` | Discovers running containers for log collection |
| `discovery.relabel "docker_containers"` | Maps `__meta_docker_container_name` → `container` label (strips leading `/`) |
| `loki.source.docker "docker_logs"` | Streams container stdout/stderr to Loki |
| `loki.source.file "logs"` | Tails `/var/log/**log` and `/var/log/syslog` |
| `prometheus.scrape "default"` | Scrapes all exporters, forwards to remote write |
| `loki.write "monitoring"` | Pushes logs to Loki (URL from `config.alloy.j2`) |
| `prometheus.remote_write "monitoring"` | Pushes metrics to Prometheus (URL from `config.alloy.j2`) |

**Two versions**:
- `configs/alloy/alloy.river` — static config with `constants.hostname` for self-identification and hardcoded `CHANGEME_MONITORING_VM_IP` URLs. Use for manual Docker runs.
- `ansible/roles/grafana_alloy/templates/config.alloy.j2` — Ansible-templated version. Uses `{{ ansible_facts["hostname"] }}` instead of `constants.hostname`, and `{{ loki_push_url }}` / `{{ prometheus_remote_write_url }}` instead of hardcoded IPs. Set `monitoring_host` in `defaults/main.yaml` or override via inventory/group vars.

**Key differences between static and templated versions**:
- The Ansible template uses `discovery.relabel.cadvisor.output` for the scrape target (the relabeled cAdvisor targets), while the static config uses `prometheus.exporter.cadvisor.docker.targets` (raw targets before relabeling). The templated version is the canonical one.
- The Ansible template resolves URLs at deploy time; the static config requires manual editing of `CHANGEME_MONITORING_VM_IP`.

### `ansible/roles/grafana_alloy/tasks/main.yaml`

Installs Docker (if missing), deploys the Alloy config, pulls the image, and runs the container:

```yaml
- name: Run alloy container
  docker_container:
    name: alloy
    image: "{{ alloy_image }}"          # grafana/alloy:latest
    hostname: "{{ ansible_facts['hostname'] }}"  # Self-identify for labeling
    privileged: true                     # Required for host filesystem access
    volumes:
      - "/etc/alloy:/etc/alloy:ro"       # River config
      - "/var/log:/var/log:ro"           # System logs
      - "/var/run/docker.sock:/var/run/docker.sock:ro"  # Docker API
      - "/proc:/host/proc:ro"           # Node metrics
      - "/sys:/host/sys:ro"             # Node metrics
      # ... more volumes for cgroups, /rootfs, /dev/disk
    command:
      - "run"
      - "--server.http.listen-addr=0.0.0.0:12345"  # Health check endpoint for Prometheus scraping
      - "/etc/alloy/config.alloy"
```

- The container runs privileged for host filesystem access. Read-only mounts (`:ro`) are used where possible.
- Port `12345` is Alloy's internal HTTP server. It's the endpoint Prometheus scrapes for `up == 0` health checks via the `alloy` job.
- A handler (`handlers/main.yml`) restarts Alloy when the config template changes.

## Secrets Chain

```
Ansible Vault (encrypted)           Template (.env.j2)        VM filesystem (.env)
─────────────────────────          ─────────────────          ────────────────────
group_vars/monitoring/             ansible/templates/         /opt/monitoring/.env
  vault.yml                         .env.j2                   mode 0600
  ├── discord_webhook_url      →    DISCORD_WEBHOOK_URL=   →  DISCORD_WEBHOOK_URL=https://...
  ├── gf_security_admin_password →  GF_SECURITY_ADMIN_PASSWORD= → GF_SECURITY_ADMIN_PASSWORD=...
  └── discord_bot_username     →    DISCORD_BOT_USERNAME=  →  DISCORD_BOT_USERNAME=AlertManager
```

The vault password lives in `ansible/.vault_pass` (gitignored). The template task uses `no_log: true` to prevent secret values from appearing in Ansible output.

**CHANGEME placeholders** that must be customized before deployment:

| File | Placeholder | Set In |
|------|-------------|--------|
| `configs/prometheus/prometheus.yml` | `CHANGEME_PROXMOX_HOST_IP` | `group_vars/monitoring/vars.yml` (`proxmox_host_ip`) |
| `configs/pve-exporter/pve.yml` | `CHANGEME_PROXMOX_USER`, `CHANGEME_REALM`, `CHANGEME_TOKEN_NAME`, `CHANGEME_TOKEN_SECRET` | Ansible vault (`group_vars/monitoring/vault.yml`) |
| `ansible/roles/grafana_alloy/defaults/main.yaml` | `CHANGEME_MONITORING_VM_IP` | `defaults/main.yaml` or inventory group var |
| `configs/alloy/alloy.river` (static) | `CHANGEME_MONITORING_VM_IP` | Edit manually if using static config |

## Security Considerations

- **Secrets chain**: Ansible Vault → `.env.j2` template → `.env` (on VM, mode `0600`).
- **No TLS on any endpoint**: All services run on a private network. Enable TLS and authentication before exposing to untrusted networks.
- **PVE Exporter token**: The Proxmox API token uses `--privsep 0` with the read-only `PVEAuditor` role. Store the token secret in Ansible Vault, not plaintext.
- **Privileged Alloy container**: Necessary for host filesystem access. Restrict access to the target VM and consider running with `--security-opt` flags in production.
- **Loki auth disabled**: `auth_enabled: false` is acceptable on an isolated private network. Enable multi-tenant auth if expanding to untrusted tenants.

## Known Issues & Fixes

| Issue | Symptom | Root Cause | Fix |
|-------|---------|-----------|-----|
| Loki drops old logs | `ingester_error: entry too far behind` | Default out-of-order window rejects WAL replays after Alloy restarts | `reject_old_samples: false` in `limits_config` |
| Missing container labels in Loki | Docker logs lack `container` label | `__meta_docker_container_name` is a meta label, not included without explicit relabel | `discovery.relabel` with `source_labels = ["__meta_docker_container_name"]` → `target_label = "container"` |
| Discord alerts fail silently | No notifications, `{"embeds": ["0"]}` in logs | `rogerrum/alertmanager-discord` v1.0.7 sends malformed embed payloads | Use `benjojo/alertmanager-discord` |
| Dashboard panels show no data | `Datasource $(DS_PROMETHEUS) was not found` | File provisioning doesn't resolve `__inputs` or `${DS_PROMETHEUS}` placeholders | Patch JSON: remove `__inputs`, replace `${DS_PROMETHEUS}` with `Prometheus`, set `current` default in template variables |
| Ansible compose fails | `value of pull must be one of: always, missing, never, policy, got: True` | `community.docker.docker_compose_v2.pull` expects a string, not a boolean | `pull: true` → `pull: "always"` |
| Alloy down alert never fires | `up == 0` never true for Alloy agents | Prometheus only sets `up` for scraped targets, not remote write clients. With remote-write-only, `up` is never generated for Alloy | Added `alloy` scrape job using `file_sd_configs` + exposed Alloy HTTP port `12345` + `register-vm.yaml` writes target files with `__meta_hostname`. The `alloy` scrape job in `prometheus.yml` now ensures `up == 0` fires when an agent goes down. |

## What's Omitted

- **Loki multi-tenant auth** — `auth_enabled: false` for simplicity in a private network
- **Loki microservices mode** — single-binary is sufficient at this scale
- **Alertmanager high availability** — single instance, no gossip clustering
- **Grafana SMTP / email alerts** — Discord-only via webhook
- **Long-term metrics storage (Thanos, Mimir)** — 30-day retention is adequate for a home lab
- **TLS/SSL on any endpoint** — private network; add reverse proxy with cert-manager for external access
- **Distributed tracing (Tempo)** — requires application instrumentation, which is out of scope
- **Alloy on the Proxmox host** — PVE Exporter handles this on the monitoring VM instead
- **Grafana alerting** — we use Prometheus Alertmanager for alert evaluation and routing

## References

- [Blog Post: Phase IV — Your Own Little Palantír w/ LGTM Stack](https://medium.com/@0xA1M/phase-vi-your-own-little-palantir-w-lgtm-stack-fcdeb8a40304)
- [Grafana Alloy Documentation](https://grafana.com/docs/alloy/latest/)
- [Prometheus Configuration](https://prometheus.io/docs/prometheus/latest/configuration/configuration/)
- [Loki Configuration](https://grafana.com/docs/loki/latest/configure/)
- [PVE Exporter](https://github.com/prometheus-pve/prometheus-pve-exporter)
- [benjojo/alertmanager-discord](https://github.com/benjojo/alertmanager-discord)
- [Docker Monitoring Dashboard #19724](https://grafana.com/grafana/dashboards/19724)
- [Node Exporter Full Dashboard #1860](https://grafana.com/grafana/dashboards/1860)
- [Proxmox via Prometheus Dashboard #10347](https://grafana.com/grafana/dashboards/10347)
