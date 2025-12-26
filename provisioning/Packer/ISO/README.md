# ISO-based Packer Templates

This directory contains Packer templates that build VMs from ISO images. These templates automate the installation of operating systems like Ubuntu from scratch, creating standardized VM templates for consistent deployments across your infrastructure.

## Overview

The ISO-based templates perform complete OS installations from ISO images. This approach is used for creating base images from scratch with a standardized configuration. The templates use cloud-init to perform unattended installations, allowing for fully automated VM creation with minimal human intervention.

### When to Use ISO-based Templates
- When creating a base image from scratch
- When you need a clean installation with specific packages pre-installed
- When you want to start with the official OS distribution without any modifications

## Components

### Template File
- **`ubuntu-server.pkr.hcl`**: Main Packer template for creating Ubuntu Server (24.04.x) VM
  - Uses Proxmox ISO builder
  - Configures VM with 2 cores and 2GB RAM
  - 16GB disk size with virtio interface
  - Cloud-init enabled for post-installation configuration

### Variables
- **`variables.pkr.hcl`**: Proxmox connection variables (should not be committed)
- **`variables.pkr.hcl.example`**: Example variables file with placeholders

### HTTP Directory
- **`http/`**: Contains cloud-init configuration files
  - `user-data`: Autoinstall configuration for Ubuntu - defines the installation process, user creation, packages to install, and initial configuration
  - `meta-data`: Cloud-init metadata (currently empty) - could contain instance metadata but is typically empty for local templates

### Files Directory
- **`files/`**: Contains cloud-init datasource configuration
  - `99-pve.cfg`: Ensures NoCloud and ConfigDrive datasources are available - configures cloud-init to work properly in Proxmox environment
  - `99-pve.cfg.example`: Example configuration file (copy to 99-pve.cfg)

### Scripts Directory
- **`scripts/`**: Contains post-installation scripts
  - `provision.sh`: Finalizes the image preparation for template use - performs cleanup, installs Docker, updates system packages, and prepares the VM for conversion to a template

## Template Configuration Explained

### VM Settings in `ubuntu-server.pkr.hcl`
- `vm_id`: The ID used to reference the virtual machine during the build process (default: 100)
- `vm_name`: Name of the virtual machine during creation (default: "ubuntu-server-noble")
- `cores`: Number of CPU cores (default: 2)
- `memory`: Amount of memory in MB (default: 2048)
- `qemu_agent`: Enables QEMU Guest Agent for enhanced Proxmox integration (default: true)
- `cloud_init`: Adds an empty Cloud-Init CDROM drive after converting to template (default: true)

### Disk Settings
- `disk_size`: Size of the virtual disk (default: "16G")
- `storage_pool`: Proxmox storage pool for the virtual machine disk (default: "local-lvm")
- `format`: Format of the virtual disk (default: "raw")

### Network Settings
- `model`: Virtual network adapter model (default: "virtio")
- `bridge`: Proxmox bridge to attach the adapter to (default: "vmbr0")
- `firewall`: Whether the interface should be protected by the firewall (default: false)

### Boot Configuration
- `boot`: Override default boot order (default: "order=virtio0;scsi0;ide2;net0")
- `boot_wait`: Time to wait after booting before typing boot_command (default: "10s")
- `boot_command`: Keys to type when VM is first booted to start the installer
- `iso_checksum`: SHA256 checksum for the ISO file to ensure integrity

### Cloud-Init Configuration
- `http_directory`: Path to directory served via HTTP for cloud-init (default: "http")
- `ssh_username`: SSH username for connecting to the VM during build (default: "ubuntu")
- `ssh_private_key_file`: Path to SSH private key file for authentication

## Variables Configuration

The following variables need to be configured in `variables.pkr.hcl`:

- `proxmox_api_url`: Proxmox API URL (e.g., "https://<PROXMOX IP>:8006/api2/json")
- `proxmox_api_token_id`: API token ID in format "user@realm!tokenname" (e.g., "root@pve!packer")
- `proxmox_api_token_secret`: API token secret key
- `ssh_private_key_file`: Path to SSH private key file for connection to the VM during build
- `proxmox_node`: Node in the Proxmox cluster to run the build on (default: "pve")
- `proxmox_iso_pool`: Storage pool where ISO files are located (default: "local:iso")
- `proxmox_storage_pool`: Storage pool for the VM disk (default: "local-lvm")
- `proxmox_storage_format`: Format for the VM disk (default: "raw")
- `ubuntu_image`: Name of the Ubuntu ISO image file (default: "ubuntu-24.04.3-live-server-amd64.iso")
- `http_directory`: Directory containing cloud-init files (default: "http")
- `ssh_username`: SSH username used during the build process (default: "ubuntu")

## Cloud-init Autoinstall Configuration

The `http/user-data` file contains the Ubuntu autoinstall configuration with cloud-init integration. Key features include:

### Locale and Keyboard
- `locale`: Sets the system locale (default: en_US)
- `keyboard`: Configures keyboard layout (default: us layout)

### SSH Configuration
- `install-server`: Whether to install OpenSSH server (default: true)
- `allow-pw`: Whether to allow password authentication for SSH (default: false)
- `disable_root`: Whether to disable root login via SSH (default: false)
- `ssh_quiet_keygen`: Suppress output during SSH key generation (default: true)
- `allow_public_ssh_keys`: Allow public SSH keys for authentication (default: true)

### Package Installation
During installation, the following packages are installed:
- `qemu-guest-agent`: Essential for Proxmox integration
- `openssh-server`: SSH server for remote access
- `sudo`: For privilege escalation
- `curl`: Command-line tool for transferring data
- `jq`: Utility for processing JSON data
- `vim`: Text editor
- `net-tools`: Networking utilities like ifconfig and netstat

### Storage Configuration
- `layout`: Direct disk layout (uses entire disk without partitioning)
- `swap`: Swap space size (default: 0, meaning no swap created)

### Network Configuration
- `all-en`: Matches all network interfaces starting with 'en' (DHCP enabled)
- `all-eth`: Matches all network interfaces starting with 'eth' (DHCP enabled)

### User Configuration
- Creates an 'ubuntu' user with sudo privileges
- Sets up the user with passwordless sudo access (NOT recommended for production!)
- Configures the shell to /bin/bash
- Can include hashed passwords and SSH public keys for authentication

### Post-Installation Configuration
- Enables automatic package updates and upgrades
- Sets timezone (default: Europe/Amsterdam)
- Configures root login settings

## Provision Script (`scripts/provision.sh`) Details

The provision script performs final cleanup and installation tasks:

1. **Wait for cloud-init completion**: Ensures installation is fully finished
2. **Security cleanup**:
   - Removes SSH host keys to prevent security issues when cloning
   - Truncates machine-id to prevent conflicts between VMs
3. **Package cleanup**:
   - Removes unnecessary packages with `apt autoremove --purge`
   - Cleans package cache with `apt clean` and `apt autoclean`
4. **Cloud-init cleanup**:
   - Performs `cloud-init clean` to reset cloud-init state
   - Removes netplan and subiquity cloud-init configuration files
5. **System updates**: Updates system packages
6. **Docker installation**: Installs Docker CE and related components
7. **Docker configuration**: Enables and starts Docker service
8. **Verification**: Checks Docker installation with `docker --version`

## Building Templates

To build an ISO-based template:

1. Copy `variables.pkr.hcl.example` to `variables.pkr.hcl`
2. Update the variables in `variables.pkr.hcl` with your Proxmox configuration
3. Download the Packer Proxmox Integration
   ```bash
   packer init ubuntu-server.pkr.hcl
   ```
4. Validate the Packer config
   ```bash
   packer validate -var-file=variables.pkr.hcl ubuntu-server.pkr.hcl
   ```
5. Run packer build:
   ```bash
   packer build -var-file=variables.pkr.hcl ubuntu-server.pkr.hcl
   ```

## Security Considerations

- API tokens should never be committed to the repository
- SSH keys should be properly secured with appropriate file permissions
- The default template grants passwordless sudo to the ubuntu user, which is a security risk in production environments
- Production environments should use stronger SSH key algorithms and disable password authentication
- Consider using more secure defaults for user creation and permissions

## What's Omitted in Default Configurations and Why

### Security Settings
- SSH key-based authentication is commented out in cloud-init - you should add your SSH public keys for production use
- Root login is enabled - this should be disabled in production environments
- Password authentication is allowed - should be disabled in production

### Additional Network Interfaces
- The template only configures the primary network interface - additional interfaces would require template modifications
- Static IP configuration is not included by default - uses DHCP for simplicity

### Advanced Storage Options
- Uses simple direct layout with no swap - may need adjustment for specific use cases
- No advanced storage configurations like LVM or RAID are included by default

### Firewall Configuration
- Firewall is disabled in the template - should be enabled with proper rules for production

## Using Templates

After creating a VM template with Packer, you can deploy new VMs by cloning the template:

### 1. Clone the template (full clone, not linked)
```bash
qm clone <template-id> <vm-id> --name <vm-name> --full --storage local-lvm
```

### 2. Configure Cloud-Init networking
For DHCP:
```bash
qm set <vm-id> --ipconfig0 ip=dhcp
```

For static IP:
```bash
qm set <vm-id> --ipconfig0 ip=<IP/MASK>,gw=<IP>
```

### 3. Set DNS servers
```bash
qm set <vm-id> --nameserver "<dns> <alt-dns>"
```

### 4. Configure user authentication (choose one)
Option A: SSH key (recommended)
```bash
qm set <vm-id> --ciuser ubuntu --sshkeys /path/to/ssh/pub/key
```

Option B: Password
```bash
qm set <vm-id> --ciuser ubuntu --cipassword "YourSecurePassword"
```

### 5. Optional: Resize disk
```bash
qm resize <vm-id> scsi0 +20G
```

### 6. Optional: Adjust resources
```bash
qm set <vm-id> --cores 2 --memory 2048
```

### 7. Regenerate Cloud-Init drive
```bash
qm set <vm-id> --ide2 local-lvm:cloudinit
```

### 8. Start the VM
```bash
qm start <vm-id>
```

## Sources and Examples

### Ubuntu Autoinstall Documentation
- [Ubuntu Autoinstall Guide](https://ubuntu.com/server/docs/install/autoinstall)
- [Cloud-init Documentation](https://cloudinit.readthedocs.io/)

### Packer Proxmox Integration
- [Packer Proxmox Builder](https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox)
- [Packer Proxmox ISO Builder](https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox/latest/components/builder/iso)

### Related Resources
- [Packer Proxmox GitHub Repository by Dustin Rue](https://github.com/dustinrue/proxmox-packer)
- [Christian Lempa's Boilerplates](https://github.com/ChristianLempa/boilerplates/tree/main/library)
- [Automating Proxmox VM Provisioning with Packer](https://justtothepoint.com/software/homeserverpacker/)
- [Create Cloud-Init VM Templates with Packer on Proxmox by Uncommon Engineer](https://ronamosa.io/docs/engineer/LAB/proxmox-packer-vm/)

## Customization Examples

### Adding Additional Packages
Modify the `http/user-data` file to include additional packages in the `packages` section:

```yaml
packages:
  - qemu-guest-agent
  - openssh-server
  - sudo
  - curl
  - jq
  - vim
  - net-tools
  # Add your packages here
  - htop
  - git
```

### Configuring Static IP
Update the network section in `http/user-data`:

```yaml
network:
  version: 2
  ethernets:
    enp0s3:  # Replace with your actual interface name
      dhcp4: false
      addresses: [192.168.1.100/24]
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
```

### Adding Additional Users
Add new users in the `users` section of `http/user-data`:

```yaml
users:
  - name: ubuntu
    # ... existing config
  - name: developer
    groups: [adm, sudo]
    lock-passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - "ssh-rsa AAAAB3NzaC1yc2E... developer@example.com"
```

### Creating the 99-pve.cfg file
Copy the example file to create the actual configuration:
```bash
cp files/99-pve.cfg.example files/99-pve.cfg
```

## References

- [Ubuntu Autoinstall Documentation](https://ubuntu.com/server/docs/install/autoinstall)
- [Cloud-init Documentation](https://cloudinit.readthedocs.io/)
- [Packer Proxmox Builder](https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox)
- [Packer Proxmox ISO Builder](https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox/latest/components/builder/iso)
- [Ubuntu Server 24.04 LTS](https://releases.ubuntu.com/noble/)
