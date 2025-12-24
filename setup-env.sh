#!/bin/bash

### Works only on debian/ubuntu

# Exit immediately if a command exits with a non-zero status
set -e

# Function to print status messages
print_status() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if running as root or with sudo privileges
if [[ $EUID -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
fi

print_status "Starting setup environment script..."

# Install Packer
if command_exists packer; then
    print_status "Packer is already installed. Skipping installation."
else
    print_status "Installing Packer..."

    # Ensure prerequisites are installed
    $SUDO apt update
    $SUDO apt install -y wget gpg apt-transport-https

    # Add HashiCorp GPG key
    wget -O - https://apt.releases.hashicorp.com/gpg | $SUDO gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

    # Add HashiCorp repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | $SUDO tee /etc/apt/sources.list.d/hashicorp.list

    # Update apt and install packer
    $SUDO apt update && $SUDO apt install -y packer

    print_status "Packer installation completed."
fi

# Install OpenTofu
if command_exists tofu; then
    print_status "OpenTofu is already installed. Skipping installation."
else
    print_status "Installing OpenTofu..."

    # Install OpenTofu via snap
    $SUDO snap install --classic opentofu

    print_status "OpenTofu installation completed."
fi

# Install Ansible
if command_exists ansible; then
    print_status "Ansible is already installed. Skipping installation."
else
    print_status "Installing Ansible..."

    # Update apt and install prerequisites
    $SUDO apt update
    $SUDO apt install -y software-properties-common

    # Add Ansible PPA
    $SUDO add-apt-repository --yes --update ppa:ansible/ansible

    # Install Ansible
    $SUDO apt install -y ansible

    print_status "Ansible installation completed."
fi

# Verify installations
print_status "Verifying installations..."
if command_exists packer; then
    print_status "Packer version: $(packer version)"
else
    print_status "ERROR: Packer installation failed!"
    exit 1
fi

if command_exists tofu; then
    print_status "OpenTofu version: $(tofu version)"
else
    print_status "ERROR: OpenTofu installation failed!"
    exit 1
fi

if command_exists ansible; then
    print_status "Ansible version: $(ansible --version | head -n1)"
else
    print_status "ERROR: Ansible installation failed!"
    exit 1
fi

print_status "All tools have been installed or were already present."
print_status "Setup environment completed successfully!"
