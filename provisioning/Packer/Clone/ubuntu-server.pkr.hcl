### Packer Template to create an Ubuntu Server (Noble 24.04.x) on Proxmox

# Packer Template to create an Ubuntu Server (plucky) VM template on Proxmox.
# This template is designed for unattended installation using cloud-init.
packer {
  required_plugins {
    proxmox = {
      version = "~> 1"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# Variable Definitions
variable "proxmox_api_url" {
    type = string
}

variable "proxmox_api_token_id" {
    type = string
}

variable "proxmox_api_token_secret" {
    type      = string
    sensitive = true
}

variable "proxmox_node" {
  type    = string
  default = "pve"
}

variable "proxmox_clone_vm" {
  type    = string
  default = "ubuntu-server-noble"
}

# Resource definition for the VM template
source "proxmox-clone" "ubuntu-server" {
  ### - Proxmox Authentication Parameters
  # URL to the Proxmox API
  proxmox_url = "${var.proxmox_api_url}"

  # Username when authenticating to Proxmox, including the realm.
  username = "${var.proxmox_api_token_id}"

  # Token for authenticating API calls.
  token = "${var.proxmox_api_token_secret}"

  # Skip validating the certificate.
  insecure_skip_tls_verify = true

  ### - General settings
  # Which node in the Proxmox cluster to start the virtual machine on during creation.
  node = "${var.proxmox_node}"

  # The name of the VM Packer should clone and build from.
  clone_vm = "${var.proxmox_clone_vm}"

  # The timeout for Promox API operations (to avoid timeout errors we set it to 30 minutes)
  task_timeout = "30m"

  ### - VM settings
  # Name of the virtual machine during creation. If not given, a random uuid will be used.
  vm_name = "ubuntu-server"

  # Whether to run a full or shallow clone from the base clone_vm.
  full_clone = true

  # VM Network adapter settings
  network_adapters {
    # Model of the virtual network adapter.
    model = "virtio"
    # Which Proxmox bridge to attach the adapter to.
    bridge = "vmbr0"
    # If the interface should be protected by the firewall. (recommended in production)
    firewall = false
  }

  # Set IP address and gateway via Cloud-Init.
  ipconfig {
    ip = "dhcp"
  }

  ### - Packer autoinstall settings
  ssh_username = "${var.ssh_username}"
  ssh_private_key_file = "${var.ssh_private_key_file}"
  ssh_timeout = "30m"     # The OS install can take a while. If 30 minutes pass and it’s still not installed or no networking, it’ll fail eventually. This options increases timeout for OS installation.
}

build {
  name = "ubuntu-server"
  sources = ["source.proxmox-clone.ubuntu-server"]
}
