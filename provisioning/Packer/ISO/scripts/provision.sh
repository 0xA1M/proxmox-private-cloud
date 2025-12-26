#!/usr/bin/env bash
set -euxo pipefail

echo "Autoinstall presumably done. Checking QEMU Guest Agent..."
systemctl status qemu-guest-agent || true

echo "Waiting for cloud-init to finish..."
while [ ! -f /var/lib/cloud/instance/boot-finished ]; do
  sleep 1
done

# Cleanup for template safety
sudo rm -f /etc/ssh/ssh_host_*
sudo truncate -s 0 /etc/machine-id

# Clean package cache
sudo apt -y autoremove --purge
sudo apt -y clean
sudo apt -y autoclean

# Clean cloud-init
sudo cloud-init clean
sudo rm -f /etc/netplan/50-cloud-init.yaml
sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg

# ---------------- OPTIONAL ----------------
# Update system
sudo apt update
sudo apt upgrade -y
sudo apt install -y vim ca-certificates curl

# Docker installation
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Get Ubuntu codename
. /etc/os-release
CODENAME="${UBUNTU_CODENAME:-$VERSION_CODENAME}"

# Add Docker repository
cat <<EOF | sudo tee /etc/apt/sources.list.d/docker.sources
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${CODENAME}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF


sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Verify Docker installation
sudo docker --version
# ---------------- END OPTIONAL ----------------

# Final sync
sudo sync
echo "Provisioning complete!"
