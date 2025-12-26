# Packer Templates for Proxmox

This directory contains Packer templates for creating VM images on Proxmox VE. The templates automate the process of creating standardized VM images that can be used for consistent deployments. The structure follows the Infrastructure as Code (IaC) principle to ensure reproducible and maintainable environments.

## Overview

Packer is used to create VM templates that follow the Infrastructure as Code principle. These templates ensure that all VMs deployed in the environment have a consistent and reproducible configuration. The project uses two main approaches for VM creation:

- **ISO-based**: Creates VM images from scratch using ISO images with unattended installation
- **Clone-based**: Creates VM images by cloning existing VMs or templates, making it faster for creating variations of existing images

Both approaches integrate with cloud-init for post-installation configuration and include QEMU Guest Agent for enhanced Proxmox integration.

## Subdirectories

- **[ISO](./ISO/README.md)**: Templates that create VMs from ISO images (e.g., Ubuntu server installation)
- **[Clone](./Clone/README.md)**: Templates that create VMs by cloning existing VMs or templates

## Key Concepts

- **Unattended Installation**: Uses cloud-init for automated OS installation and configuration
- **Standardized Base Images**: Creates consistent base images for all deployments
- **Proxmox Integration**: Optimized for Proxmox VE environment with QEMU Guest Agent
- **Security**: Implements security best practices during image creation
- **Infrastructure as Code**: Templates are versioned and reproducible
- **Multi-Stage Configuration**: Template building + post-creation configuration

## Why Use Packer for VM Image Creation?

1. **Consistency**: Ensures all VMs start from an identical, tested base image
2. **Automation**: Eliminates manual installation steps, reducing human error
3. **Version Control**: Images can be tracked and managed with Git
4. **Reproducibility**: Anyone can recreate the same image from the template
5. **Efficiency**: Faster deployment of new VMs from pre-configured templates
6. **Security**: Base images can be hardened during template creation

## When to Use Each Template Type

### ISO-based Templates
- When creating a base image from scratch
- When you need a clean installation with specific packages pre-installed
- When you want to start with the official OS distribution without any modifications
- When you need to customize the installation process from the beginning

### Clone-based Templates
- When you want to create a new VM based on an existing VM or template
- When you need faster build times compared to ISO-based templates
- When you want to modify an existing image slightly without starting from scratch
- When you have an already configured base image you want to use as a starting point

## Prerequisites

Before using these Packer templates, ensure you have:

1. Proxmox VE 9.1+ installed and configured
2. Packer installed (can be installed with `./setup-env.sh`)
3. API tokens configured in Proxmox for Packer to use
4. SSH keys available for Packer to connect to the VM during build
5. Required ISO files uploaded to the Proxmox storage (for ISO-based templates)
6. An existing VM or template to clone from (for Clone-based templates)

## How Templates Work

### ISO-based Templates
1. Packer creates a new VM from an ISO image
2. Uses boot commands to initiate unattended installation
3. Configures the system with cloud-init during installation
4. Runs post-installation provisioners for final setup
5. Creates a template from the finished VM

### Clone-based Templates
1. Packer clones an existing VM or template
2. Configures the cloned VM for the new purpose using cloud-init
3. Runs post-configuration provisioners
4. Creates a new template from the customized VM

## Template Variables

All templates use variables to allow customization. These are defined in the `.pkr.hcl` files and configured via `variables.pkr.hcl` files. The `variables.pkr.hcl.example` files provide examples for your own configuration.

## Security Considerations

- API tokens should never be committed to the repository
- Use dedicated API tokens with minimal required permissions
- SSH keys should be properly secured
- Production environments should use stronger security settings
- Templates are cleaned to remove host-specific data before becoming templates
- The default ISO template grants passwordless sudo to the ubuntu user, which is a security risk in production environments

## Using the Templates

### Building Templates

To build any template:

1. Copy the `variables.pkr.hcl.example` to `variables.pkr.hcl`
2. Update the variables in `variables.pkr.hcl` with your Proxmox configuration
3. Initialize the Packer build:
   ```bash
   packer init <template-file>.pkr.hcl
   ```
4. Validate the configuration:
   ```bash
   packer validate -var-file=variables.pkr.hcl <template-file>.pkr.hcl
   ```
5. Run the build:
   ```bash
   packer build -var-file=variables.pkr.hcl <template-file>.pkr.hcl
   ```

## Common Configurations and Options

### VM Settings
- CPU cores: Configurable (default 2)
- Memory: Configurable (default 2048MB)
- Disk size: Configurable (default 16G)
- Storage pool: Configurable (default local-lvm)
- Network: Configurable (default vmbr0)

### Proxmox Integration
- QEMU Guest Agent: Enabled by default for enhanced monitoring
- Cloud-init: Enabled for post-installation configuration
- Storage formats: Support for various formats (default raw)

## What's Omitted in Default Configurations

### ISO-based Templates
- More complex disk layouts (direct layout is used)
- Additional network interfaces
- GPU passthrough settings
- Advanced security settings (like SSH hardening)
- Custom firewall configurations
- Additional storage devices
- Static IP configuration (DHCP is used by default)

### Clone-based Templates
- More complex cloning options
- Multiple snapshots as sources
- Different storage targets for cloned disks
- Advanced VM features beyond basic settings
- Static IP configuration (DHCP is used by default)

## References

- [Packer Documentation](https://www.packer.io/docs)
- [Proxmox Integration for Packer](https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox)
- [Cloud-init Documentation](https://cloudinit.readthedocs.io/)
- [Packer Proxmox GitHub Repository by Dustin Rue](https://github.com/dustinrue/proxmox-packer)
- [Christian Lempa's Boilerplates](https://github.com/ChristianLempa/boilerplates/tree/main/library)
- [Automating Proxmox VM Provisioning with Packer](https://justtothepoint.com/software/homeserverpacker/)
- [Create Cloud-Init VM Templates with Packer on Proxmox by Uncommon Engineer](https://ronamosa.io/docs/engineer/LAB/proxmox-packer-vm/)