# The Proxmox API URL variable with a default value
variable "proxmox_api_url" {
  type    = string
  default = "https://10.0.0.2:8006/api2/json"  # Default Proxmox API endpoint (can be overridden)
}

# The Proxmox API token for authentication
variable "proxmox_api_token" {
  type      = string
  sensitive = true        # Marks this as sensitive to avoid showing in logs
}

# The SSH username for connecting to Proxmox
variable "proxmox_ssh_username" {
  type      = string
  sensitive = true
}

# The Proxmox node name variable with a default value
variable "proxmox_node_name" {
  type    = string
  default = "pve"
}

# The Proxmox node IP address variable with a default value
variable "proxmox_node_address" {
  type    = string
  default = "10.0.0.2"
}
