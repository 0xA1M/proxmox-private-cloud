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

variable "proxmox_iso_pool" {
  type    = string
  default = "local:iso"
}

variable "proxmox_storage_pool" {
  type    = string
  default = "local-lvm"
}

variable "proxmox_storage_format" {
  type    = string
  default = "raw"
}

variable "ubuntu_image" {
  type    = string
  default = "ubuntu-24.04.3-live-server-amd64.iso"
}

variable "http_directory" {
  type    = string
  default = "http"
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "ssh_private_key_file" {
  type      = string
  sensitive = true
}

# Resource definition for the VM template
source "proxmox-iso" "ubuntu-server" {
  ### - Proxmox Authentication Parameters
  # URL to the Proxmox API
  proxmox_url = "${var.proxmox_api_url}"

  # Username when authenticating to Proxmox, including the realm.
  username = "${var.proxmox_api_token_id}"

  # Token for authenticating API calls.
  token = "${var.proxmox_api_token_secret}"

  # Skip validating the certificate.
  insecure_skip_tls_verify = true

  ### - Cluster settings
  # Which node in the Proxmox cluster to start the virtual machine on during creation.
  node = "${var.proxmox_node}"

  ### - VM settings
  # The ID used to reference the virtual machine. If not given, the next free ID on the cluster will be used.
  vm_id = 100

  # Name of the virtual machine during creation. If not given, a random uuid will be used.
  vm_name = "ubuntu-server-noble"

  # How many CPU cores to give the virtual machine.
  cores = 2

  # How much memory (in megabytes) to give the virtual machine.
  memory = 2048

  # Enables QEMU Agent option for this VM. (we must install qemu-guest-agent on the VM)
  qemu_agent = true

  # Add an empty Cloud-Init CDROM drive after the virtual machine has been converted to a template.
  cloud_init = true

  # Specifies the storage pool for cloud-init data.
  cloud_init_storage_pool = "${var.proxmox_storage_pool}"

  # VM Disk settings
  disks {
    # The type of disk.
    type = "virtio"
    # The size of the disk, including a unit suffix.
    disk_size = "16G"
    # Name of the Proxmox storage pool to store the virtual machine disk on.
    storage_pool = "${var.proxmox_storage_pool}"
    # The format of the file backing the disk.
    format = "${var.proxmox_storage_format}"
  }

  # VM Network adapter settings
  network_adapters {
    # Model of the virtual network adapter.
    model = "virtio"
    # Which Proxmox bridge to attach the adapter to.
    bridge = "vmbr0"
    # If the interface should be protected by the firewall. (recommended in production)
    firewall = false
  }

  ### - Packer Boot settings
  # Override default boot order.
  # virtio0: is the VM disk
  # scsi0: since we mounted the iso to this interface we must specify it
  # ide2: for CD/DVD
  # net0: network
  # NOTE: you may add as much devices as long as you order them correctly
  boot = "order=virtio0;scsi0;ide2;net0"

  # The time to wait after booting the initial virtual machine before typing the boot_command.
  boot_wait = "10s"

  # Specifies the keys to type when the virtual machine is first booted in order to start the OS installer (Thanks to dustinrue's proxmox-packer repo)
  boot_command = [
    "c",
    "linux /casper/vmlinuz -- autoinstall ds='nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/'",
    "<enter><wait><wait>",
    "initrd /casper/initrd",
    "<enter><wait><wait>",
    "boot<enter>"
  ]

  # Specify the boot config
  boot_iso {
    # Bus type that the ISO will be mounted on.
    type = "scsi"
    # Path to the ISO file to boot from, expressed as a proxmox datastore path
    iso_file = "${var.proxmox_iso_pool}/${var.ubuntu_image}"
    # If true, remove the mounted ISO from the template after finishing.
    unmount = true
    # The checksum for the ISO file or virtual hard drive file.
    iso_checksum = "sha256:c3514bf0056180d09376462a7a1b4f213c1d6e8ea67fae5c25099c6fd3d8274b"
  }

  ### - Packer autoinstall settings
  # Path to a directory to serve using an HTTP server.
  http_directory = "${var.http_directory}"

  ssh_username = "${var.ssh_username}"
  ssh_private_key_file = "${var.ssh_private_key_file}"
  ssh_timeout = "30m"     # The OS install can take a while. If 30 minutes pass and it’s still not installed or no networking, it’ll fail eventually. This options increases timeout for OS installation.
}

build {
  name = "ubuntu-server"
  sources = ["source.proxmox-iso.ubuntu-server"]

  # Shell provisioner for image finalization and base tooling
  # - Waits for cloud-init to fully complete
  # - Removes machine- and host-specific state (SSH keys, machine-id, netplan)
  # - Cleans package manager and cloud-init data for safe template reuse
  # - Installs base utilities and Docker
  # - Prepares the VM to be converted into a reusable Proxmox template
  provisioner "shell" {
    script = "scripts/provision.sh"
  }

  # Provisioning the VM Template for Cloud-Init Integration in Proxmox
  # This provisioner transfers a custom configuration file (99-pve.cfg) to the VM, which is used for cloud-init configuration.
  provisioner "file" {
    source      = "files/99-pve.cfg"
    destination = "/tmp/99-pve.cfg"
  }

  # Provisioning the VM Template for Cloud-Init Integration in Proxmox
  # This provisioner copies the configuration file to the appropriate location in the VM.
  provisioner "shell" {
    inline = [ "sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg" ]
  }
}
