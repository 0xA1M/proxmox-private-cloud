# Proxmox API URL — replace the default with your Proxmox host's address
variable "proxmox_api_url" {
  type    = string
  default = "https://CHANGEME_PROXMOX_HOST_IP:8006/api2/json"
}

# Proxmox API token for authentication (sensitive — use terraform.tfvars or secrets.tfvars)
variable "proxmox_api_token" {
  type      = string
  sensitive = true
}

# SSH username for connecting to Proxmox (sensitive)
variable "proxmox_ssh_username" {
  type      = string
  sensitive = true
}

# Proxmox node name
variable "proxmox_node_name" {
  type    = string
  default = "pve"
}

# Proxmox node IP address
variable "proxmox_node_address" {
  type    = string
  default = "CHANGEME_PROXMOX_HOST_IP"
}
