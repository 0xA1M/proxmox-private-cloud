# Proxmox Private Cloud

![Architecture](.assets/Architecture.svg)

**Build and operate a local private cloud using Proxmox VE 9.1 (latest as of December 2025), with fully automated VM image creation and lifecycle management via Packer and Terraform/OpenTofu, layered configuration using cloud-init and Ansible, observability with Grafana/Prometheus/Loki, and optional external exposure via Ngrok (including a Docker-based Minecraft server demo).**

This repo accompanies my blog series on Medium:
[How to Build a Local Private Cloud](https://medium.com/@0xA1M) (starting with **Part I: Proxmox**).

## Overview & Goals

- Deploy a **production-ready Proxmox environment** with KVM/QEMU virtualization.
- Automate VM image creation with **Packer** and provisioning with **Terraform/OpenTofu**.
- Configure VMs using **Ansible** (idempotent management).
- Implement observability with **Grafana, Prometheus, and Loki**.
- Securely expose services externally using **Ngrok** (free tier), including a simple **Minecraft Java Edition server** in Docker.

## Project Structure

```
proxmox-private-cloud/
├── 01 - core-setup/                # Proxmox installation & basics
│   ├── post-install.sh             # extremeshok's optimization script
│   └── README.md                   # Documentation for core setup
├── 02 - provisioning/              # Packer + Terraform/OpenTofu
│   ├── 01 - Packer/                # Templates for VM image creation
│   └── 02 - OpenTofu-Terraform/    # Infrastructure as Code for VM deployment
├── 03 - configuration/             # Configuration management
│   └── ansible/                    # Playbooks, inventory, and configuration
├── observability/                  # Monitoring stack
│   └── configs/                    # Grafana, Prometheus, Loki configurations
├── remote-access/                  # External access solutions
│   └── ngrok/                      # Secure tunnel configurations
├── .assets/                        # Project diagrams and assets
├── README.md                       # This file
├── setup-env.sh                    # Environment setup script
└── LICENSE                         # MIT License
```

## Contributing

Feel free to open issues, suggest improvements, or PR configs/scripts. This is a learning project.

## License

[MIT License](LICENSE) – use, modify, share freely.
