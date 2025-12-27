# OpenTofu/Terraform Infrastructure as Code

This directory contains OpenTofu/Terraform configurations for deploying VMs on Proxmox VE. The configurations follow Infrastructure as Code (IaC) principles to ensure reproducible and maintainable environments. The project uses OpenTofu (community fork of Terraform) to deploy VMs from templates created with Packer, enabling fully automated infrastructure provisioning.

- Corresponding post: [Phase II — Part 2 — Automating VM Provisioning in Proxmox w/ Terraform/OpenTofu](https://medium.com/@0xA1M/phase-ii-part-2-automating-vm-provisioning-in-proxmox-w-terraform-opentofu-ec14ad931bfb)

## Overview

OpenTofu/Terraform is used to deploy VMs from existing templates on Proxmox VE. This approach allows for consistent, automated deployment of VMs by defining the desired infrastructure in code. The configuration includes:

- A data source that finds VM templates with specific tags
- Storage of cloud-init configurations in Proxmox snippets
- A VM resource that clones from a template and applies cloud-init configuration
- Output values for retrieving information about deployed VMs

### When to Use OpenTofu/Terraform Configuration

- When you want to deploy multiple VMs consistently from Packer templates
- When you need infrastructure automation and version control
- When you want to scale VM deployments easily
- When you need to manage infrastructure state and dependencies

## Components

### Configuration Files

- **`main.tf`**: Defines the resources to be created, including VMs and cloud-init configurations
- **`provider.tf`**: Configures the Proxmox provider for OpenTofu/Terraform
- **`variables.tf`**: Defines input variables for the configuration
- **`config/user-data.yaml`**: Cloud-init configuration file applied to deployed VMs

## What Was Done

This configuration sets up a Ubuntu server VM (for Minecraft, we gotta define a purpose if you ask me) by cloning from a template created with Packer. It includes:

1. A data source that finds template VMs on the Proxmox node
2. A mechanism to upload cloud-config data to Proxmox snippets
3. A VM resource that clones from the Packer template
4. Network configuration using vmbr0 bridge
5. QEMU Guest Agent for enhanced Proxmox integration
6. Cloud-init initialization with DNS and IP configuration
7. An output that retrieves the VM's IP address

## What Could Have Been Done

Additional capabilities that could have been implemented (Explore them yourself):

1. **Scalability**: Using `count` or `for_each` to deploy multiple VMs
2. **Custom Resources**: Creating custom resources for storage, networks, or users
3. **Environment Management**: Using workspaces for dev/staging/prod environments
4. **Remote State**: Implementing remote state storage for team collaboration
5. **Advanced VM Configuration**: Custom CPU, memory, and disk settings
6. **Firewall Rules**: Proxmox firewall configuration
7. **Pools**: Grouping VMs into Proxmox pools for management
8. **Snapshots**: Automated snapshot management

## Optional Features Included

This configuration includes several optional features that are currently commented out:

1. **CPU Configuration**: Optional CPU settings (cores, architecture)
2. **Disk Configuration**: Optional disk settings (AIO mode, format, size)
3. **Memory Configuration**: Optional memory allocation settings
4. **VM Migration**: Optional migration capability
5. **Advanced Cloud-Init Settings**: Optional datastore, interface, and file format settings
6. **User Account Configuration**: Optional user account creation with SSH keys
7. **SSH Key Generation**: Optional automatic SSH key generation
8. **Additional Outputs**: Optional SSH key outputs

These features can be easily enabled by uncommenting the relevant sections.

## Prerequisites

Before using these OpenTofu/Terraform configurations, ensure you have:

1. Proxmox VE 9.1+ installed and configured
2. OpenTofu (or Terraform) installed (can be installed with `./setup-env.sh`)
3. API tokens configured in Proxmox for OpenTofu to use
4. A VM template created with Packer (tagged with "template")
5. SSH keys available for connection to Proxmox
6. Snippets enabled in Proxmox storage configuration (for cloud-config files)

## Using the Configuration

To use these OpenTofu/Terraform configurations:

1. Ensure you have a Packer template with the "template" tag
2. Set up your API tokens and variables
3. Initialize OpenTofu:
   ```bash
   tofu init
   ```
4. Review the execution plan:
   ```bash
   tofu plan
   ```
5. Apply the configuration:
   ```bash
   tofu apply
   ```
6. Destroy the infrastructure when no longer needed:
   ```bash
   tofu destroy
   ```

## Security Considerations

- API tokens should never be committed to the repository
- Use dedicated API tokens with minimal required permissions
- SSH keys should be properly secured
- The configuration currently uses self-signed certificates (insecure = true) which should be changed in production
- The ubuntu user has passwordless sudo access which could be a security risk in production

## Tips and Tricks

- Scale with `count` or `for_each` if you need multiple VMs
- The configuration assumes a Minecraft server VM but can be adapted for other purposes
- Uncomment and modify the commented sections to customize CPU, memory, disk, or networking settings
- Consider using remote state storage for production environments
- Use proper SSL certificates instead of setting `insecure = true`

## Why Use OpenTofu/Terraform for VM Deployment?

1. **Infrastructure as Code**: Define your infrastructure in code with version control
2. **Reproducibility**: Deploy identical VMs consistently across environments
3. **Automation**: Eliminate manual VM creation steps, reducing human error
4. **State Management**: Track deployed resources and manage changes efficiently
5. **Scalability**: Easily deploy multiple VMs from the same configuration
6. **Idempotency**: Applying the same configuration multiple times produces the same result

The combination of Packer for image creation and OpenTofu/Terraform for deployment provides a complete automation pipeline for VM lifecycle management in Proxmox.

## References:
- [HashiCorp - Terraform official docs](https://developer.hashicorp.com/terraform)
- [OpenTofu official docs](https://opentofu.org/docs/v1.11/intro/)
- [Proxmox virtual machine _automation_ in Terraform by Christian Lempa](https://youtu.be/dvyeoDBUtsU?si=8vH6om5tjrqVbrK1&referrer=grok.com)
- [bpg/proxmox Guides](https://search.opentofu.org/provider/bpg/proxmox/latest/docs/guides/clone-vm?referrer=grok.com)
- [Automate Homelab Deployment With Terraform & Proxmox by Jim's Garage](https://www.youtube.com/watch?v=ZGWn6xREdDE&referrer=grok.com)
- [Terraform + Proxmox: FULL VM Automation Guide (Faster Deployment) by Joe Horseman](https://www.youtube.com/watch?v=sJlnXwZDdso&referrer=grok.com)
- [Uncommon Engineer Blog](https://ronamosa.io/docs/engineer/LAB/proxmox-terraform/)
