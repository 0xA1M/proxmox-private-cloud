# Infrastructure as Code — Monitoring VM

This directory contains **OpenTofu** (the open-source fork of Terraform) configurations for provisioning the monitoring VM on Proxmox VE.

We use OpenTofu for Infrastructure as Code — consistent, repeatable, version-controlled VM deployments.

## Files

| File | Purpose |
|---|---|
| `monitoring.tf` | Monitoring VM resource (clone from Packer template) |
| `provider.tf` | Proxmox provider config (`bpg/proxmox` v0.90.0) |
| `variables.tf` | Input variables with placeholder defaults |
| `secrets.tfvars` | Gitignored — real API tokens (on mgr VM only) |
| `config/monitoring-user-data.yaml` | Cloud-init bootstrap for the monitoring VM |

## Usage

```bash
tofu init
tofu plan
tofu apply -target=proxmox_virtual_environment_vm.monitoring_vm
```

## Placeholder IPs

| Placeholder | Where | Real value |
|---|---|---|
| `10.0.0.2` | `variables.tf` | Proxmox host IP |
| `10.0.0.55` | (DHCP output) | Monitoring VM IP — get from `tofu output monitoring_vm_ip` |
