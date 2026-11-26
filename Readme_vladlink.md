# Custom Ubuntu Image Build (vladlink)

This document describes the customizations made to the Ubuntu image building process for OpenNebula. These changes are specific to this fork and are not intended to be merged into the main stream branch.

## 🎯 Goal
Build a customized, fresh Ubuntu image (24.04/26.04) using Packer within a Dockerized environment, optimized for OpenNebula and capable of automatic application deployment.

## 🛠 Infrastructure & Build Process

### Builder Image
A specialized `Dockerfile` was created to provide a consistent build environment:
- **Packer 1.16.2**: Installed via Yandex mirror.
- **Tooling**: QEMU, FPM, and `libguestfs-tools` are included.
- **Runtime Requirements**: To allow `virt-sysprep` and KVM to function inside Docker, the builder must be run with:
  - `--privileged`
  - Mounting `/dev/kvm`
  - Mounting `/boot` and `/lib/modules` from the host in read-only mode.

### Makefile Enhancements
- **Cyclic Dependency Fix**: Resolved a bug in the `Makefile` regarding the generation of `generate-all.sh`.
- **Selective Packaging**: Implemented `CONTEXT_TARGETS='deb iso'` to allow building only required package formats, bypassing the need for `rpmbuild`.

## 🌐 Networking & Security

### Netplan /32 Gateway Fix
Discovered that Ubuntu's Netplan ignores default gateways for `/32` interfaces unless a specific route to the gateway with `scope: link` is defined.
- **Fix**: Patched `one-context` (`netcfg-netplan`) to automatically add `scope: link` to the Netplan configuration when applicable.

### SSH Access
To ensure seamless access to the newly created VM:
- Modified `cloud-init.yml` and `runcmd` to force:
  - `PermitRootLogin yes`
  - `PasswordAuthentication yes`
This allows root access via password immediately after deployment.

### Firewall & Boot-up
- **Firewall**: Rules are predefined in `/etc/iptables.rules` (blocking all by default, allowing loopback, Docker networks, and specific trusted IPs).
- **rc.local**: The `rc-local.service` is activated to apply firewall rules via `iptables-restore < /etc/iptables.rules` on every boot.
- **Dynamic Override**: If the `IPTABLES_BASE64` variable is passed via OpenNebula context, the agent will overwrite `/etc/iptables.rules` and immediately apply the new rules.

## 🐳 Docker & Compose Automation

### Pre-installation
The image now comes with `docker-compose-v2` pre-installed via `packer/ubuntu/82-install-docker.sh`.

### Default State
- **Service State**: Docker service is **disabled by default** (`systemctl disable docker`) to save resources.
- **Configuration**: A custom `/etc/docker/daemon.json` is applied:
  - `"iptables": false`: Docker does not manipulate iptables.
  - `"bip": "192.168.99.1/24"`: Fixed bridge IP.
  - `"default-address-pools"`: Defined as `192.168.99.0/25` (size 27).
  - `"log-driver": "local"`: Configured with rotation (max 3 files, 10MB each, compressed).

### Automatic Deployment via Context
A new agent module `loc-30-docker-compose` was added. If the `START_DOCKER_COMPOSE_BASE64` variable is passed via OpenNebula context:
1. The Docker service is started.
2. The base64 string is decoded into `/opt/docker-compose.yaml`.
3. `docker compose -f /opt/docker-compose.yaml up -d` is executed.

## ⚙️ Context Engine Enhancements (Underscore Overrides)

Implemented a "forced override" mechanism in `/usr/sbin/one-contextd` to handle variables that are otherwise ignored or overwritten by the system.

- **Mechanism**: Any variable in the context starting with an underscore (e.g., `_ETH0_MASK`) will be treated as a priority override for the variable without the underscore (`ETH0_MASK`).
- **Priority**: Underscore variables are processed **after** the standard import, ensuring they always take precedence.

## 🛠 Customization Guide (How it works)

### Image Build-time Customization
If you need to add new software or system settings to the base image:
1. Create a new shell script in `packer/ubuntu/` following the naming convention `XX-description.sh` (e.g., `84-install-custom-tool.sh`).
2. Packer automatically collects and executes all `*.sh` scripts in the directory in alphabetical order during the provisioning phase.

### Boot-time Customization (one-context)
If you need to add dynamic configuration logic that runs when a VM starts:
1. Add a script to `context-linux/src/etc/one-context.d/`.
2. Scripts are executed in alphabetical order:
   - `loc-10-*`: Basic system and network setup.
   - `loc-20-*`: User and password configuration.
   - `loc-30-*`: High-level application setup (e.g., our Docker Compose logic).
3. These scripts have access to all OpenNebula context variables passed during VM instantiation.
4. **Important**: Ensure your scripts have execution permissions (`chmod +x`). Otherwise, `one-contextd` will fail to execute them with a 'Permission denied' error.

## 🚀 Usage Guide

### Building the Image
1. Build the builder:
   ```bash
   docker build -t packer-builder . --network=host
   ```
2. Run the build for Ubuntu 26.04:
   ```bash
   docker run --rm --privileged \
       --network=host \
       -v /dev/kvm:/dev/kvm \
       -v /boot:/boot:ro \
       -v /lib/modules:/lib/modules:ro \
       -v $(pwd):/workspace \
       -e CONTEXT_TARGETS='deb iso' \
       packer-builder \
       make ubuntu2604
   ```

### Terraform / OpenNebula Variables
- `USERNAME` / `PASSWORD`: Standard credentials.
- `_VARIABLE_NAME`: Use to force a value for `VARIABLE_NAME` (e.g., `_ETH0_MASK=255.255.0.0`).
- `IPTABLES_BASE64`: Pass a base64 encoded `iptables-save` output to override firewall rules.
- `START_DOCKER_COMPOSE_BASE64`: Pass a base64 encoded `docker-compose.yaml` to auto-deploy an application stack.
