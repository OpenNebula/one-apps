# OpenNebula Appliance Creation Guide

## Prerequisites

```bash
sudo apt-get install -y rpm qemu-system-x86 cloud-image-utils libguestfs-tools packer
sudo chmod +r /boot/vmlinuz-*
sudo usermod -aG kvm $USER && newgrp kvm
```

## Directory Structure

```
one-apps/
├── appliances/YourService/appliance.sh    # Install/configure logic
├── packer/service_YourService/
│   ├── YourService.pkr.hcl                # Packer config
│   ├── gen_context                        # Context generator
│   └── 8x-configure-*.sh                  # Setup scripts
├── Makefile
└── Makefile.config
```

## Step 1: Create Appliance Script

`appliances/YourService/appliance.sh`:

```bash
#!/usr/bin/env bash

ONE_SERVICE_PARAMS=(
    'ONEAPP_PARAM1' 'configure' 'Description' 'O|text'
)

ONE_SERVICE_NAME='Your Service'
ONE_SERVICE_VERSION='1.0.0'

service_install() {
    apt-get update && apt-get install -y your-packages
}

service_configure() {
    # Create config using $ONEAPP_PARAM1
}

service_bootstrap() {
    systemctl enable --now your-service
}
```

## Step 2: Create Packer Config

`packer/service_YourService/YourService.pkr.hcl` - Key sections:

```hcl
source "qemu" "YourService" {
  iso_url      = "export/ubuntu2204.qcow2"
  accelerator  = "kvm"
  # ... standard QEMU config
}

build {
  sources = ["source.qemu.YourService"]
  
  provisioner "file" {
    source      = "/path/to/your/app"
    destination = "/root/"
  }
  
  provisioner "shell" {
    inline = ["/etc/one-appliance/service install && sync"]
  }
}
```

## Step 3: Add to Makefile

```makefile
# In Makefile
packer-service_YourService: packer-ubuntu2204 $(DIR_EXPORT)/service_YourService.qcow2

# In Makefile.config
SERVICES_AMD64 := ... service_YourService
```

## Step 4: Build

```bash
cd one-apps
export PACKER_HEADLESS=true
make ubuntu2204           # Base image (first time only)
make service_YourService  # Your appliance
```

## Step 5: Register in OpenNebula

```bash
# Image
sudo cp export/service_YourService.qcow2 /var/tmp/ && sudo chmod 644 /var/tmp/service_YourService.qcow2
oneimage create -d default --name "YourService" --path /var/tmp/service_YourService.qcow2 --type OS --format qcow2

# Template
cat > /tmp/template.txt << 'EOF'
NAME = "YourService-VM"
MEMORY = 2048
CPU = 2
DISK = [ IMAGE = "YourService" ]
NIC = [ NETWORK_ID = "0" ]
CONTEXT = [
  NETWORK = "YES",
  SSH_PUBLIC_KEY = "$USER[SSH_PUBLIC_KEY]",
  START_SCRIPT_BASE64 = "YOUR_BASE64_SCRIPT"
]
EOF
onetemplate create /tmp/template.txt
```

## Step 6: Publish to Marketplace

```bash
TMPL64=$(onetemplate show <id> -x | base64 -w0)
cat > /tmp/app.txt << EOF
NAME = "YourService"
ORIGIN_ID = "<image_id>"
TYPE = "IMAGE"
VERSION = "1.0.0"
VMTEMPLATE64 = "$TMPL64"
EOF
onemarketapp create /tmp/app.txt -m <marketplace_id>
```

## Step 7: Download & Instantiate

```bash
onemarketapp export <app_id> "AppName" -d default
onetemplate instantiate <template_id> --name "my-vm"
```

## Quick Commands

```bash
oneimage list                              # List images
onetemplate list                           # List templates
onetemplate instantiate <id> --name "vm"   # Create VM
onevm show <id>                            # VM details
sudo su oneadmin -c "ssh root@<ip>"        # SSH into VM
onevm terminate --hard <id>                # Delete VM
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| KVM permission denied | `newgrp kvm` or re-login |
| libguestfs error | `sudo chmod +r /boot/vmlinuz-*` |
| No internet in build VM | Use curl not ping (QEMU SLIRP) |
| Image permission denied | Copy to `/var/tmp/` with `chmod 644` |


# Visual Flow

Your Computer
    │
    ├─ ServerlessRuntime.pkr.hcl  (instructions)
    ├─ appliance.sh               (what to install)
    └─ serverless-runtime/        (files to copy)
         │
         ▼
    Packer reads .pkr.hcl
         │
         ▼
    Starts QEMU VM (Ubuntu)
         │
         ├─ Copies files → /root/serverless-runtime
         ├─ Runs: service install
         │   └─ Calls appliance.sh functions
         │       ├─ install_requirements()
         │       ├─ setup_python_environment()
         │       └─ install_python_dependencies()
         │
         ▼
    Shuts down VM
         │
         ▼
    Saves as: service_ServerlessRuntime.qcow2