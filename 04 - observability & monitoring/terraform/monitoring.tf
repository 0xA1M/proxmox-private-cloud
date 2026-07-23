# Data source to read the cloud-init configuration for the monitoring VM from a local file
data "local_file" "monitoring_user_data" {
  filename = "${path.module}/config/monitoring-user-data.yaml"  # Path to the monitoring user-data.yaml file
}

# Resource to upload the monitoring VM's cloud-init configuration as a file to Proxmox storage
resource "proxmox_virtual_environment_file" "monitoring_cloud_config" {
  content_type = "snippets"  # Specifies "snippets" content type - requires snippets to be enabled in Proxmox storage
  datastore_id = "local"     # Storage pool to upload the file to (local storage)
  node_name = var.proxmox_node_name  # Proxmox node where the file will be stored

  source_raw {
    data = data.local_file.monitoring_user_data.content  # Content of the file from the local_file data source
    file_name = "monitoring-user-data.yaml"  # Name of the file in Proxmox storage
  }
}

# Resource to create a monitoring VM by cloning from a template
resource "proxmox_virtual_environment_vm" "monitoring_vm" {
  name = "monitoring-01"                    # Name of the monitoring VM
  node_name = var.proxmox_node_name        # Node where the VM will be created (from variables)

  clone {
    vm_id = data.proxmox_virtual_environment_vms.templates.vms[0].vm_id  # ID of the source VM to clone (first VM found with "template" tag)
    full = true  # Whether to perform a full clone (creates independent copy) or linked clone
  }

  # CPU configuration
  cpu {
    cores = 2              # Number of CPU cores (2 cores for monitoring stack)
  }

  # Memory configuration
  memory {
    dedicated = 4096       # Amount of RAM in MB (4096 = 4GB for monitoring stack)
  }

  # Disk configuration (interface must match the disk device name: virtio0, scsi0, etc.)
  disk {
    aio = "io_uring"       # Asynchronous I/O mode (io_uring for better performance)
    file_format = "qcow2"  # Disk format (qcow2)
    interface = "virtio0"  # Disk device name — NOT just the bus type "virtio"
    size = 16              # Disk size in GB (16)
  }

  # Network configuration for the VM
  network_device {
    bridge   = "vmbr0"      # Network bridge to connect to (vmbr0)
    firewall = false         # Whether to enable the Proxmox firewall for this interface (disabled)
  }

  # QEMU Guest Agent configuration
  agent {
    enabled = true           # Enables the QEMU Guest Agent for better integration with Proxmox
  }

  # Initialization configuration for cloud-init
  initialization {
    dns {
      servers = ["8.8.8.8", "1.1.1.1"]  # List of DNS servers to configure in the VM (Google and Cloudflare)
    }

    ip_config {
      ipv4 {
        address = "dhcp"      # IP address assignment method (using DHCP)
      }
    }

    # Reference to the uploaded cloud-config file for initialization
    user_data_file_id = proxmox_virtual_environment_file.monitoring_cloud_config.id
  }
}

# Output to return the IP address of the deployed monitoring VM
output "monitoring_vm_ip" {
  value = proxmox_virtual_environment_vm.monitoring_vm.ipv4_addresses[1][0]
}
