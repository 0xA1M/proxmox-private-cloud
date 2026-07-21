# Proxmox Private Cloud

![Architecture](.assets/Architecture.svg)

**Build and operate a local private cloud on Proxmox VE, from bare-metal hypervisor setup to full-stack observability — all automated with Packer, OpenTofu, and Ansible.**

This repository provides a complete, production-oriented workflow: harden a Proxmox host, create standardized VM images via Packer, provision infrastructure with OpenTofu, manage configuration with Ansible, deploy a Minecraft server demo, and monitor everything with a Grafana/Prometheus/Loki/Alloy observability stack. Every phase is documented step by step and pairs with the accompanying Medium blog series.

---

## Quick Start with Devbox

This project uses [devbox](https://www.jetify.com/devbox) to manage tooling. All required tools (Packer, OpenTofu, Ansible) are installed automatically.

```bash
# Enter the devbox shell (installs all packages)
devbox shell

# Or run individual commands without entering the shell
devbox run help
```

### Available Devbox Commands

| Command | Phase | Description |
|---------|-------|-------------|
| `devbox run help` | — | Show all available commands |
| `devbox run packer:build-iso` | II | Build a VM template from an ISO image |
| `devbox run packer:build-clone` | II | Build a VM template from an existing VM |
| `devbox run tofu:plan` | II | Preview OpenTofu infrastructure changes |
| `devbox run tofu:apply` | II | Apply OpenTofu infrastructure |
| `devbox run ansible:setup-monitoring` | IV | Deploy the monitoring stack (set IP in inventory.ini first) |
| `devbox run ansible:register-vm` | IV | Register a VM with Alloy (`-l IP` to target) |
| `devbox run ansible:unregister-vm` | IV | Remove Alloy from a VM (`-l IP` to target) |

Without devbox, run `./setup-env.sh` to install Packer, OpenTofu, and Ansible manually.

> **Before deploying** — replace all `CHANGEME_*` placeholders across the repo
> with your actual values (IPs, API tokens, passwords). They appear in:
> `04- observability & monitoring/configs/`, `04- observability & monitoring/ansible/`,
> `04- observability & monitoring/terraform/`, `02 - provisioning/02 - OpenTofu-Terraform/variables.tf`,
> and `devbox.json`.

---

## Project Structure

```
proxmox-private-cloud/
├── 01 - core-setup/                       # Phase I — Proxmox installation & hardening
│   ├── post-install.sh                    #   extremeshok's optimization script
│   └── README.md                          #   Setup guide & production recommendations
├── 02 - provisioning/                     # Phase II — VM image creation & provisioning
│   ├── 01 - Packer/                       #   Packer templates (ISO + Clone)
│   │   ├── ISO/                           #     Build from ISO with cloud-init
│   │   ├── Clone/                         #     Build from existing template
│   │   └── README.md
│   └── 02 - OpenTofu-Terraform/           #   Infrastructure as Code for VM deployment
│       ├── main.tf                        #     VM resource definitions
│       ├── provider.tf                    #     Proxmox provider config
│       ├── variables.tf                   #     Input variables
│       └── README.md
├── 03 - configuration/                    # Phase III — Ansible configuration management
│   └── ansible/
│       ├── main.yaml                      #   Playbook orchestrator
│       ├── playbooks/                     #   init, users, security, minecraft
│       └── README.md
├── 04- observability & monitoring/        # Phase IV — Observability stack
│   ├── ansible/                           #   Playbooks for monitoring VM & target VMs
│   ├── configs/                           #   Grafana, Prometheus, Loki, Alloy configs
│   ├── terraform/                         #   OpenTofu for the monitoring VM itself
│   ├── docker-compose.yml                 #   Monitoring services definition
│   └── README.md
├── 05- minecraft/                         # Minecraft demo (placeholder)
├── .assets/                               # Project diagrams & assets
│   ├── Architecture.svg
│   └── Observation_Architecture.svg
├── devbox.json                            # Devbox package & script configuration
├── devbox.lock                            # Devbox lockfile
├── setup-env.sh                           # Legacy environment setup script
├── README.md                              # This file
└── LICENSE                                # MIT License
```

---

## Phase Summaries

### Phase I — Core Setup

**Production-ready Proxmox foundation.**

- Hardens a fresh Proxmox VE 9.1 installation
- Configures repositories, firewall, 2FA, and SSH
- Applies extremeshok's community optimization script
- Provides post-installation recommendations (timezone, DNS, email notifications)

**Directory:** [`01 - core-setup/`](./01%20-%20core-setup/README.md)

---

### Phase II — Provisioning (Packer + OpenTofu)

**Automated VM image creation and infrastructure-as-code deployment.**

- **Packer** builds standardized VM templates from ISO or existing VMs using cloud-init for unattended installation
- **OpenTofu** (Terraform-compatible) deploys VMs from those templates with reproducible configuration
- Both phases use API token authentication and produce ready-to-use VMs with QEMU Guest Agent

**Directories:**
- [`02 - provisioning/01 - Packer/`](./02%20-%20provisioning/01%20-%20Packer/README.md)
- [`02 - provisioning/02 - OpenTofu-Terraform/`](./02%20-%20provisioning/02%20-%20OpenTofu-Terraform/README.md)

**Key technologies:** Packer, OpenTofu, HCL, cloud-init, Proxmox VE API

---

### Phase III — Configuration (Ansible)

**Idempotent configuration management for all provisioned VMs.**

- Modular playbooks for system init, user management, security hardening, and application deployment
- Security hardening: SSH key-only auth, fail2ban, UFW firewall with default-deny policy
- Minecraft server deployment as a Docker container via `itzg/minecraft-server`
- Ansible Vault integration for secrets management

**Directory:** [`03 - configuration/ansible/`](./03%20-%20configuration/ansible/README.md)

**Key technologies:** Ansible, Jinja2, Ansible Vault, Docker

---

### Phase IV — Observability & Monitoring

**Full-stack observability with Grafana, Prometheus, Loki, and Grafana Alloy.**

- **Grafana Alloy** as a unified collector (replaces Node Exporter + cAdvisor + Promtail) on every target VM
- **Prometheus** for metrics storage and alert evaluation with remote write from Alloy agents
- **Loki** for centralized log aggregation with 30-day retention
- **PVE Exporter** bridges Proxmox host metrics into Prometheus
- **Alertmanager + Discord** for instant notifications
- Auto-provisioned Grafana dashboards (Node Exporter, Docker, Proxmox)
- All secrets managed via Ansible Vault

**Directory:** [`04- observability & monitoring/`](./04-%20observability%20&%20monitoring/README.md)

**Key technologies:** Grafana, Prometheus, Loki, Grafana Alloy, Alertmanager, PVE Exporter, Docker Compose, Ansible Vault

---

### Minecraft Server Demo

A Minecraft Java Edition server deployed as a Docker container, provisioned through the Phase III Ansible playbooks. The server runs `itzg/minecraft-server` with Paper server type, 2 GB RAM allocation, and exposes port 25565. Configured via Ansible playbooks targeting the `minecraft` host group.

**Directory:** [`05- minecraft/`](./05-%20minecraft/)

---

## References

This project accompanies a multi-part blog series on Medium:

- [How to Build a Local Private Cloud — Part I: Proxmox](https://medium.com/@0xA1M/how-to-build-a-local-private-cloud-part-i-proxmox-f118b146ebd8)
- [Phase II — Part 1: Automating VM Provisioning in Proxmox w/ Packer](https://medium.com/@0xA1M/phase-ii-part-1-automating-vm-provisioning-in-proxmox-w-packer-aafdd4231db2)
- [Phase II — Part 2: Automating VM Provisioning in Proxmox w/ Terraform/OpenTofu](https://medium.com/@0xA1M/phase-ii-part-2-automating-vm-provisioning-in-proxmox-w-terraform-opentofu-ec14ad931bfb)
- [Phase IV — Your Own Little Palantír w/ LGTM Stack](https://medium.com/@0xA1M/phase-vi-your-own-little-palantir-w-lgtm-stack-fcdeb8a40304)

---

## License

[MIT License](LICENSE) — use, modify, share freely.
