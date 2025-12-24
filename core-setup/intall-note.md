# Phase 1: Core Setup – Production-Ready Proxmox Post-Installation

This document focuses on turning a fresh Proxmox VE 9.1 install into a **secure, stable, and production-ready** single-node foundation. The actual ISO installation is straightforward and well-covered in the official docs and blog Part I.

> **Goal**: Harden the system, optimize performance, enable key security features, and prepare for automation in later phases.

## Quick Installation Summary (Do This First)

1. Download Proxmox VE 9.1 ISO from https://www.proxmox.com/en/downloads
2. Create bootable USB (Rufus DD mode on Windows, `dd` or Etcher on Linux/macOS)
3. Boot → **Install Proxmox VE (Graphical)**
4. Key choices:
   - Target disk: Select your drive (data will be erased)
   - Filesystem: **ext4** (simple/reliable) or **ZFS** (recommended for snapshots/compression if you have sufficient RAM)
   - Strong root password + valid email
   - Static IP (highly recommended for production)
5. Install → Reboot

Access the web UI at `https://<your-ip>:8006` (accept self-signed cert warning for now).

## Production-Ready Post-Installation Steps

Run these via SSH (`ssh root@<proxmox-ip>`) or the web UI Shell. All commands are idempotent where possible.

### 1. System Update & Repository Configuration

```bash
# Full update
apt update && apt full-upgrade -y

# Disable enterprise repository (unless you have a subscription)
sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/pve-enterprise.list

# Add no-subscription community repository
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list

# Add community Ceph repo if planning Ceph later (optional)
echo "deb http://download.proxmox.com/debian/ceph-reef bookworm no-subscription" > /etc/apt/sources.list.d/ceph.list

# Update package lists again
apt update
```

### 2. Security Hardening

```bash
# Disable root login over SSH.
# Disable password login. Use only ssh keys.
# Create a administrator user with sudo privileges rather than using root.

# Enable Proxmox firewall at all levels
# Via UI:
#   Datacenter → Firewall → Options → Enable Firewall
#   Node → Firewall → Options → Enable Firewall

# Enable 2FA for root and any admin users
# UI: Datacenter → Permissions → Two Factor Authentication → Add → TOTP
# Scan QR with Authy/Google Authenticator
```

### 3. Community Post-Install Optimization (Highly Recommended)

```bash
wget https://raw.githubusercontent.com/extremeshok/xshok-proxmox/master/install-post.sh -c -O install-post.sh && bash install-post.sh && rm install-post.sh
```

**What it does (safe defaults):**
- Disable the enterprise repo, enable the public repo, Add non-free sources
- Installs common utilities
- Enables no-subscription repos properly
- Minor performance tweaks
- Set pigz to replace gzip, 2x faster gzip compression
- Protect the web interface with fail2ban

> **Important**: Always review the script source first. It’s widely trusted, but verify it matches your needs.

Reboot after running:

```bash
reboot
```

### 4. Additional Production Recommendations


| Task                          | Command / Action                                                                 | Why |
|-------------------------------|----------------------------------------------------------------------------------|-----|
| Set correct timezone          | `dpkg-reconfigure tzdata`                                                        | Logs & scheduling |
| Enable automatic updates      | Install `unattended-upgrades` and configure (or use UI Updates)                  | Security patches |
| Configure email notifications | UI: Node → System → Mail → Edit (use Gmail relay or local postfix)                | Critical alerts |
| Add local DNS entry           | On your workstation: edit hosts file → `<ip> pve.local proxmox                  | Easy access |
| Upload common ISOs            | UI: Datacenter → Storage → local → Content → Upload (Ubuntu, Debian, etc.)       | Ready for Phase 2 |
| Install qemu-guest-agent on future VMs | Include in cloud-init or templates (later phases)                                 | Better metrics & shutdown |

For DNS use bind9 and setup a name server, check Christian Lempa amazing [video](https://youtu.be/syzwLwE3Xq4?si=0IHukeEImLDQrHa6).

### 5. Verify Everything

After reboot:
- Log in to web UI – no subscription banner
- Check Updates tab – packages from community repo
- Shell: `pveversion -v` – confirm latest
- Firewall rules active (green shield icons)
