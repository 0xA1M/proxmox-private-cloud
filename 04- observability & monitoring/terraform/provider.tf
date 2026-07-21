terraform {
  # Defines the required providers for this Terraform configuration
  required_providers {
    # Specifies the Proxmox provider with source and version constraints
    proxmox = {
      source = "bpg/proxmox"  # Provider source from the bpg organization
      version = "0.90.0"     # Exact version to use for consistency
    }
  }
}

# Configures the Proxmox provider with connection details
provider "proxmox" {
  # URL of the Proxmox API endpoint, sourced from variables
  endpoint = var.proxmox_api_url

  # API token for authenticating with Proxmox, sourced from variables
  api_token = var.proxmox_api_token

  # Allows insecure HTTPS connections (needed for self-signed certificates)
  insecure = true

  # SSH configuration for executing commands on the Proxmox host
  ssh {
    # Enable SSH agent for key management (optional, but recommended)
    agent       = true
    # SSH username for connecting to Proxmox, sourced from variables
    username    = var.proxmox_ssh_username
    # SSH private key for connecting to Proxmox, read from local file
    private_key = file("~/.ssh/id")

    # Node-specific SSH configuration
    node {
      # Name of the Proxmox node, sourced from variables
      name     = var.proxmox_node_name
      # IP address of the Proxmox node, sourced from variables
      address  = var.proxmox_node_address
    }
  }
}
