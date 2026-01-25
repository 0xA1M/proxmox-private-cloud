# Ansible Configuration Management

This directory contains Ansible playbooks for configuring VMs after they've been provisioned with Terraform/OpenTofu. The playbooks implement idempotent configuration management to ensure consistent system states across all deployed VMs.

## Overview

The Ansible configuration system implements a layered approach to system configuration, with each playbook responsible for a specific aspect of system setup. This modular approach allows for targeted execution of specific configuration tasks while maintaining consistency across all nodes.

### Playbooks Structure

The configuration is divided into five main playbooks:

- **`init.yaml`**: Initial system setup and package management
- **`users.yaml`**: User and sudo configuration management
- **`security.yaml`**: Security hardening and firewall configuration
- **`minecraft.yaml`**: Minecraft server Docker deployment

Each playbook targets specific host groups and can be run independently or as part of the complete configuration sequence.

## Playbook Descriptions

### 1. init.yaml - Initial System Setup
This playbook handles basic system configuration tasks for all hosts:

- Updates and performs full system upgrade of APT packages
- Installs essential base packages (ufw, htop, vim, curl, wget, git, etc.)
- Sets system timezone to UTC
- Configures system locale to en_US.UTF-8
- Includes automatic system restart if kernel updates require it

**Target hosts**: `all`

### 2. users.yaml - User and Sudo Configuration
This playbook manages user accounts and SSH access:

- Creates an admin group with sudo and docker privileges
- Creates a deploy user with sudo privileges
- Configures .ssh directory for the admin user
- Adds SSH public keys to the admin user account for secure authentication

**Target hosts**: `all`

### 3. security.yaml - Enhanced Security Hardening
This playbook implements comprehensive security measures:

- Configures SSH settings (disables root login, disables password authentication)
- Sets up fail2ban for SSH protection with configurable parameters
- Configures UFW firewall with default deny policy
  - Allows SSH access
  - Allows Minecraft server port (25565) on Minecraft hosts
  - Allows HTTP/HTTPS traffic on web servers (ports 80/443)
- Includes automatic service restarts when configuration changes

**Target hosts**: `all`

### 4. minecraft.yaml - Minecraft Server Docker Deployment
This playbook deploys a Minecraft server using Docker:

- Creates a directory for Minecraft data persistence at `/opt/minecraft`
- Creates and starts a Minecraft server container using `itzg/minecraft-server:latest`
- Configures the server with specific settings (2GB memory, Paper type, specific difficulty, etc.)
- Maps port 25565 for Minecraft access
- Includes health checks to verify server startup

**Target hosts**: `minecraft`

## Ansible Configuration File (ansible.cfg)

The `ansible.cfg` file controls various aspects of Ansible's behavior, including default settings for inventory, connection types, timeouts, and output formatting. This file is located in the root of your Ansible project directory.

## Inventory Configuration

The `inventory.ini` file defines the target hosts for configuration:

```
[role]
ip	ansible_user=ssh_user	ansible_ssh_private_key_file=/path/to/private/key
```

Host groups are determined by the target host's role:
- `minecraft` group: For Minecraft server deployment
- `all` group: For tasks that apply to all hosts (init, users, security)

### Group Assignment

Group membership is determined by how you structure your inventory or by dynamic assignment using Ansible tags or extra variables. The playbooks check group membership using conditional logic.

### Advanced Inventory Features

You can enhance your inventory configuration using group variables and host variables:

```
# Group variables in [group:vars] sections
[minecraft:vars]
ansible_python_interpreter=/usr/bin/python3
mc_eula=true
mc_server_name="Private Minecraft Server"

# Host variables can be set individually
vm-minecraft ansible_host=192.168.1.100 mc_seed=-8456743215432556789
```

Inventory files also support YAML format:

```yaml
all:
  children:
    minecraft:
      hosts:
        vm-minecraft:
          ansible_host: 192.168.1.100
          ansible_user: deploy
          ansible_ssh_private_key_file: /path/to/private/key
      vars:
        mc_eula: true
        mc_server_name: "Private Minecraft Server"
  vars:
    ansible_python_interpreter: /usr/bin/python3
```

## Ansible Vault - Managing Sensitive Data

Ansible Vault is a feature that allows you to keep sensitive data such as passwords or keys in encrypted files, rather than as plaintext in your playbooks or inventory files. This keeps your sensitive data secure.

### Using Ansible Vault

#### 1. Creating and Editing Encrypted Files

To create a new encrypted file:
```bash
ansible-vault create secrets.yml
```

To edit an existing encrypted file:
```bash
ansible-vault edit secrets.yml
```

To view an encrypted file without editing:
```bash
ansible-vault view secrets.yml
```

To rekey (change the password) of an encrypted file:
```bash
ansible-vault rekey secrets.yml
```

#### 2. Encrypting Existing Files

To encrypt an existing file:
```bash
ansible-vault encrypt existing_file.yml
```

#### 3. Integrating Vault with Playbooks

You can reference variables from encrypted files in your playbooks:

Example vault file (`vault/secrets.yml`):
```yaml
---
database_password: "supersecret_password_here"
api_key: "sk-1234567890abcdef"
ssl_certificate_password: "cert_password_here"
```

Include vault variables in your playbook:
```yaml
---
- name: Example Playbook Using Vault Variables
  hosts: all
  vars_files:
    - vault/secrets.yml
  tasks:
    - name: Use secret variable in task
      debug:
        msg: "Database password is {{ database_password }}"
```

#### 4. Running Playbooks with Vault

When running playbooks that use encrypted variables, you'll need to provide the vault password:

Using a password file (recommended for automation):
```bash
ansible-playbook main.yaml --vault-password-file ~/.vault_pass
```

Alternatively, you can use environment variables:
```bash
export ANSIBLE_VAULT_PASSWORD_FILE=~/.vault_pass
ansible-playbook main.yaml
```

Or you can enter the password interactively:
```bash
ansible-playbook main.yaml --ask-vault-pass
```

#### 5. Vault Password Management in CI/CD

For automated environments like CI/CD pipelines, you can store the vault password securely:

1. Set the `ANSIBLE_VAULT_PASSWORD_FILE` environment variable pointing to a file containing the password
2. Or set the `ANSIBLE_VAULT_IDENTITY_LIST` variable with appropriate identifiers
3. Many CI/CD platforms provide secure ways to store vault passwords as environment variables or secrets
4. For GitHub Actions, you can use repository secrets and reference them in your workflow

## How to Execute

### 1. Running Individual Playbooks

To run a specific playbook:

```bash
# Run initial system setup only
ansible-playbook playbooks/init.yaml
```

### 2. Running Complete Configuration Sequence

The `main.yaml` file orchestrates all playbooks in the correct order:

```bash
# Run all playbooks in sequence
ansible-playbook main.yaml
```

The execution order in `main.yaml` is:
1. `playbooks/init.yaml` - Basic system setup
2. `playbooks/users.yaml` - User management
3. `playbooks/security.yaml` - Security hardening
4. `playbooks/minecraft.yaml` - Minecraft server deployment

### 3. Running for Specific Groups

You can target specific groups by using the `--limit` flag:

```bash
# Run only on web servers
ansible-playbook main.yaml --limit web

# Run only on minecraft servers
ansible-playbook main.yaml --limit minecraft
```

### 4. Running with Vault Secrets

When using vault-protected variables:

```bash
# Run with password file
ansible-playbook main.yaml --vault-password-file ~/.my_vault_pass

# Run and be prompted for vault password
ansible-playbook main.yaml --ask-vault-pass
```

## Detailed Playbook Documentation

For detailed information about each playbook's implementation, see the documentation comments within each file:

- [init.yaml](playbooks/init.yaml) - Initial system setup and package management
- [users.yaml](playbooks/users.yaml) - User and sudo configuration management
- [security.yaml](playbooks/security.yaml) - Security hardening and firewall configuration
- [minecraft.yaml](playbooks/minecraft.yaml) - Minecraft server Docker deployment
- [main.yaml](main.yaml) - Playbook orchestrator for complete setup

## Best Practices

### Security Considerations
- Use SSH key-based authentication exclusively (password authentication disabled)
- Implement the principle of least privilege for user accounts
- Regular updates with automated patching via the init playbook
- Proper firewall configuration through UFW with default deny policy
- Use Ansible Vault to protect sensitive data like passwords, API keys, and certificates

### Configuration Management
- Idempotent operations: Playbooks can be run multiple times without side effects
- Use of variables to maintain consistency and enable customization
- Modularity allows for targeted configuration changes
- Error handling and retry mechanisms for robust deployments
- Encrypt sensitive data with Ansible Vault

### Maintenance
- Regular review of security configurations and system updates
- Monitor log files for security events using configured log rotation
- Backup and version control of Ansible playbooks
- Testing changes in a development environment before production deployment
- Secure storage of vault password files and proper rotation procedures
