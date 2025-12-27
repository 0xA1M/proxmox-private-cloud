# Data source to find VM templates on Proxmox node
data "proxmox_virtual_environment_vms" "templates" {
  node_name = var.proxmox_node_name  # Specifies which Proxmox node to search on (from variables)
  tags = ["template"]                # Filter VMs by the "template" tag to find template VMs created by Packer
}

# Optional TLS private key resource (commented out)
# In case you want to create a unique pair of SSH keys for this particular VM
# resource "tls_private_key" "ubuntu_vm_key" {
#   algorithm = "RSA"      # Specifies RSA algorithm for the key
#   rsa_bits = 4096        # Key size in bits (4096 is more secure than default)
# }

# Optional local file data source for SSH key (commented out)
# In case you want to use your own public SSH key
# data "local_file" "ssh_public_key" {
#   filename = "~/.ssh/id.pub"  # Path to the SSH public key file
# }

# Data source to read the cloud-init configuration from a local file
data "local_file" "user_data_cloud_config" {
  filename = "${path.module}/config/user-data.yaml"  # Path to the user-data.yaml file using path.module variable
}

# Resource to upload the cloud-init configuration as a file to Proxmox storage
resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"  # Specifies "snippets" content type - requires snippets to be enabled in Proxmox storage
  datastore_id = "local"     # Storage pool to upload the file to (local storage)
  node_name = var.proxmox_node_name  # Proxmox node where the file will be stored

  source_raw {
    data = data.local_file.user_data_cloud_config.content  # Content of the file from the local_file data source
    file_name = "user-data.yaml"  # Name of the file in Proxmox storage
  }
}

# Resource to create a VM by cloning from a template
resource "proxmox_virtual_environment_vm" "minecraft_vm" {
  name = "mc-server-01"                    # Name of the VM
  node_name = var.proxmox_node_name        # Node where the VM will be created (from variables)

  clone {
    vm_id = data.proxmox_virtual_environment_vms.templates.vms[0].vm_id  # ID of the source VM to clone (first VM found with "template" tag)
    full = true  # Whether to perform a full clone (creates independent copy) or linked clone
  }

  # count = 3 # Specify that we want 3 instances of said resource (minecraft_vm)

  # Optional CPU configuration (commented out, using template defaults)
  # cpu {
  #   cores = 4              # Number of CPU cores (4 cores)
  #   architecture = "x86_64"  # CPU architecture (x86_64)
  # }

  # Optional disk configuration (commented out, using template defaults)
  # disk {
  #   aio = "io_uring"       # Asynchronous I/O mode (io_uring for better performance)
  #   file_format = "qcow2"  # Disk format (qcow2)
  #   interface = "virtio"   # Interface type (virtio for better performance)
  #   size = 16              # Disk size in GB (16)
  # }

  # Optional memory configuration (commented out, using template defaults)
  # memory {
  #   dedicated = 4096       # Amount of RAM in MB (4096 = 4GB)
  # }

  # Network configuration for the VM
  network_device {
    bridge   = "vmbr0"      # Network bridge to connect to (vmbr0)
    firewall = false         # Whether to enable the Proxmox firewall for this interface (disabled)
  }

  # Optional migration setting (commented out, using defaults)
  # migrate = true           # Would allow the VM to be migrated to other nodes in the cluster

  # QEMU Guest Agent configuration
  agent {
    enabled = true           # Enables the QEMU Guest Agent for better integration with Proxmox
                             # Make sure it is installed and runs on startup
  }

  # Initialization configuration for cloud-init
  initialization {
    # Optional datastore settings for cloud-init (commented out, using template defaults)
    # datastore_id = "local-lvm"  # Storage pool for the cloud-init drive
    # interface = "ide2"          # Interface type for cloud-init drive
    # file_format = "raw"         # Format of the cloud-init drive

    # DNS configuration
    dns {
      servers = ["8.8.8.8", "1.1.1.1"]  # List of DNS servers to configure in the VM (Google and Cloudflare)
    }

    # IP configuration for the VM
    ip_config {
      ipv4 {
        address = "dhcp"      # IP address assignment method (using DHCP)
      }
    }

    # Reference to the uploaded cloud-config file ID for initialization
    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id

    # Optional user account configuration (commented out, since we want more granular control)
    # user_account {
    #   username = "ubuntu"    # Name of the user to create
    #   password = ""          # openssl passwd -6, Password of the user
    #   # SSH keys to add to the user account (using generated key or local file)
    #   keys = [trimspace(data.local_file.ssh_public_key.content)]
    # }
  }
}

# Output to return the IP address of the deployed VM
output "ubuntu_vm_ip" {
  value = proxmox_virtual_environment_vm.minecraft_vm.ipv4_addresses[1][0]  # Gets the first IPv4 address from the second network interface (index 1)
}

# Optional output for SSH private key (commented out)
# output "ubuntu_vm_private_key" {
#   value = tls_private_key.ubuntu_vm_key.private_key_openssh  # Returns the generated private key
# }

# Optional output for SSH public key (commented out)
# output "ubuntu_vm_public_key" {
#   value = tls_private_key.ubuntu_vm_key.public_key_openssh   # Returns the generated public key
# }
