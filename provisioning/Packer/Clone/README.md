# Clone-based Packer Templates

This directory contains Packer templates that build VMs by cloning existing VMs or templates. These templates provide a faster alternative to ISO-based installation by starting from an existing VM image, making it ideal for creating variations of existing images.

## Overview

The Clone-based templates perform VM creation by cloning an existing VM or template on your Proxmox system. This approach is significantly faster than ISO-based installation as it doesn't need to download and install the OS from scratch. The templates use cloud-init to customize the cloned VM during the build process, allowing for configuration changes without a complete reinstallation.

### When to Use Clone-based Templates
- When you want to create a new VM based on an existing VM or template
- When you need faster build times compared to ISO-based templates
- When you want to modify an existing image slightly without starting from scratch
- When you have an already configured base image you want to use as a starting point

## Components

### Template File
- **`ubuntu-server.pkr.hcl`**: Main Packer template for creating Ubuntu Server Clone VM
  - Uses Proxmox Clone builder
  - Clones from an existing VM named "ubuntu-server-noble" (or any configured source)
  - Configures VM with customizable network settings
  - Cloud-init enabled for post-clone customization

### Variables
- **`variables.pkr.hcl`**: Proxmox connection variables (should not be committed)
- **`variables.pkr.hcl.example`**: Example variables file with placeholders

## Template Configuration Explained

### Authentication and Connection Settings
- `proxmox_api_url`: URL to the Proxmox API (e.g., "https://<PROXMOX IP>:8006/api2/json")
- `username`: API token ID for authenticating to Proxmox in format "user@realm!tokenname"
- `token`: API token secret for authenticating API calls
- `insecure_skip_tls_verify`: Whether to skip certificate validation (default: true, not recommended for production)

### Cluster and General Settings
- `node`: Node in the Proxmox cluster where the VM will be built (default: "pve")
- `task_timeout`: Timeout for Proxmox API operations (default: "30m" to avoid timeout errors)
- `vm_name`: Name for the new VM being created (default: "ubuntu-server")
- `clone_vm`: Name of the existing VM or template to clone from (default: "ubuntu-server-noble")

### VM Settings
- `full_clone`: Whether to run a full or shallow clone (default: true for full clone)
- `qemu_agent`: Enables QEMU Guest Agent for enhanced Proxmox integration (default: true)
- `cloud_init`: Adds an empty Cloud-Init CDROM drive after the build (default: true)

### Disk Settings
- `storage_pool`: Proxmox storage pool for the VM disk (default: "local-lvm")
- `format`: Format of the virtual disk (default: "raw")

### Network Settings
- `model`: Virtual network adapter model (default: "virtio")
- `bridge`: Proxmox bridge to attach the adapter to (default: "vmbr0")
- `firewall`: Whether the interface should be protected by the firewall (default: false)

## Variables Configuration

The following variables need to be configured in `variables.pkr.hcl`:

- `proxmox_api_url`: Proxmox API URL (e.g., "https://<PROXMOX IP>:8006/api2/json")
- `proxmox_api_token_id`: API token ID in format "user@realm!tokenname" (e.g., "root@pve!packer")
- `proxmox_api_token_secret`: API token secret key
- `ssh_private_key_file`: Path to SSH private key file for connection to the VM during build
- `proxmox_node`: Node in the Proxmox cluster to run the build on (default: "pve")
- `proxmox_storage_pool`: Storage pool for the VM disk (default: "local-lvm")
- `proxmox_storage_format`: Format for the VM disk (default: "raw")
- `clone_vm`: Name of the VM to clone from (default: "ubuntu-server-noble")
- `ssh_username`: SSH username used during the build process (default: "ubuntu")

## Building Templates

To build a Clone-based template:

1. Ensure you have an existing VM or template to clone from (e.g., "ubuntu-server-noble")
2. Copy `variables.pkr.hcl.example` to `variables.pkr.hcl`
3. Update the variables in `variables.pkr.hcl` with your Proxmox configuration
4. Set the `clone_vm` variable to the name of the VM or template you want to clone
5. Download the Packer Proxmox Integration
   ```bash
   packer init ubuntu-server.pkr.hcl
   ```
6. Validate the Packer config
   ```bash
   packer validate -var-file=variables.pkr.hcl ubuntu-server.pkr.hcl
   ```
7. Run packer build:
   ```bash
   packer build -var-file=variables.pkr.hcl ubuntu-server.pkr.hcl
   ```

## How Clone-based Templates Work

1. Packer connects to your Proxmox instance using API credentials
2. It clones the specified source VM with the name provided in `clone_vm`
3. The cloned VM is started to apply cloud-init configurations
4. Packer connects via SSH using the provided key to verify the build
5. Any provisioners defined in the template are executed to customize the image
6. The final VM is converted to a template ready for deployment

## Security Considerations

- API tokens should never be committed to the repository
- SSH keys should be properly secured with appropriate file permissions
- The source VM should be in a clean state before cloning
- Production environments should use stronger SSH key algorithms
- Consider security implications of cloning an existing VM that may contain sensitive information

## What's Omitted in Default Configurations and Why

### Additional Network Interfaces
- The template only configures a single network interface - additional interfaces would require template modifications
- Static IP configuration is not included by default - uses DHCP for simplicity

### Advanced Storage Options
- Uses default storage pool and format - more complex storage configurations would need template adjustments
- No advanced storage configurations like LVM or RAID are included by default

### Firewall Configuration
- Firewall is disabled in the template - should be enabled with proper rules for production

### VM Resource Configuration
- CPU and memory settings are inherited from the source VM - additional configuration would require template modifications

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

### Packer Proxmox Integration
- [Packer Proxmox Builder](https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox)
- [Packer Proxmox Clone Builder](https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox/latest/components/builder/clone)

### Related Resources
- [Packer Proxmox GitHub Repository by Dustin Rue](https://github.com/dustinrue/proxmox-packer)
- [Christian Lempa's Boilerplates](https://github.com/ChristianLempa/boilerplates/tree/main/library)
- [Automating Proxmox VM Provisioning with Packer](https://justtothepoint.com/software/homeserverpacker/)
- [Create Cloud-Init VM Templates with Packer on Proxmox by Uncommon Engineer](https://ronamosa.io/docs/engineer/LAB/proxmox-packer-vm/)

## Customization Examples

### Changing the Source VM
Modify the `clone_vm` variable to clone from a different source:
```hcl
variable "proxmox_clone_vm" {
  type    = string
  default = "my-custom-ubuntu-template"
}
```

### Adding Additional Network Interfaces
Update the network adapter section in the template:
```hcl
  network_adapters {
    model = "virtio"
    bridge = "vmbr1"
    firewall = false
  }
```

### Adjusting VM Resources
To change the resources, you would need to modify the source VM template or use post-provisioning scripts to adjust settings.

## Differences from ISO-based Templates

| Feature | ISO-based | Clone-based |
|---------|-----------|-------------|
| Build Time | Longer (downloads and installs OS) | Shorter (clones existing VM) |
| Source | ISO file | Existing VM or template |
| Use Case | Creating from scratch | Customizing existing images |
| Storage | Fresh install | Copy of existing image |
| Flexibility | Can install any OS from scratch | Limited to modifications of source VM |
