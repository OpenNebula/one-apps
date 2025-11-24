#!/bin/bash
# ---------------------------------------------------------------------------- #
# Copyright 2024, OpenNebula Project, OpenNebula Systems                       #
#                                                                              #
# Licensed under the Apache License, Version 2.0 (the "License"); you may      #
# not use this file except in compliance with the License. You may obtain      #
# a copy of the License at                                                     #
#                                                                              #
# http://www.apache.org/licenses/LICENSE-2.0                                   #
#                                                                              #
# Unless required by applicable law or agreed to in writing, software          #
# distributed under the License is distributed on an "AS IS" BASIS,            #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.     #
# See the License for the specific language governing permissions and          #
# limitations under the License.                                               #
# ---------------------------------------------------------------------------- #
set -o errexit -o pipefail

### Important notes ##################################################
#
# 1. This appliance requires a base OS image with cloud-init and wget.
# 2. This appliance MUST be instantiated with a VM Template that
#    includes UEFI boot and Q35 machine settings .
#
### Important notes ##################################################


# List of contextualization parameters
ONE_SERVICE_PARAMS=(
    :
)


### Appliance metadata ###############################################

# Appliance metadata
ONE_SERVICE_NAME='Service NVIDIA Fabric Manager - KVM'
ONE_SERVICE_VERSION='RELEASE.2025-10-22T13-00-00Z'
ONE_SERVICE_BUILD=$(date +%s)
ONE_SERVICE_SHORT_DESCRIPTION='Appliance with NVIDIA Fabric Manager for Shared NVSwitch Virtualization'
ONE_SERVICE_DESCRIPTION=$(cat <<EOF
Appliance with pre-installed NVIDIA Fabric Manager service.

This appliance is designed to be the "Shared NVSwitch Virtualization Model" service VM, as described in the IAAS-NVIDIA-GPUs-Passthrough documentation .

It comes with:
- The required NVIDIA datacenter driver.
- The 'nvidia-fabricmanager' service, pre-configured for 'FABRIC_MODE=1' (Shared NVSwitch multitenancy mode).
- The 'nvidia-fabricmanager-dev' SDK.
- A pre-compiled C++ tool ('nv-partitioner') for managing NVLink partitions.

**CRITICAL DEPLOYMENT INSTRUCTIONS:**

1.  **VM TEMPLATE:** This appliance **MUST** be instantiated with a VM Template that:
* Passes through **ALL NVSwitch PCIe devices** on the host using multiple 'PCI' attributes. **Do NOT pass any GPU devices to this VM.**
    * Enables **UEFI boot** ('FIRMWARE = "/usr/share/OVMF/OVMF_CODE_4M.fd"').
    * Uses a **Q35 machine type** (e.g. 'MACHINE = "pc-q35-noble"').
    * Includes the **RAW QEMU arguments** for PCI passthrough.
    * Passes through **ALL NVSwitch PCIe devices** on the host. (This VM must *not* have any GPUs passed to it) .

2.  **PCIe to Module ID MAP:** This VM **CANNOT** discover the mapping between your hypervisor's GPU PCIe addresses and the 'Module IDs' used by the partitioner. You **MUST** create this map manually *before* partitioning .

3.  **NEXT STEPS:**
    * Once this VM is running, SSH into it.
    * Run 'nvswitch-audit' to check the current partition state.
    * Run '/usr/local/sbin/nv-partitioner' to apply new partitions.
EOF
)
ONE_SERVICE_RECONFIGURABLE=false

# ------------------------------------------------------------------------------
# Contextualization defaults
# ------------------------------------------------------------------------------

# (No user-configurable parameters for this appliance)

### Globals ##########################################################

# --- EDIT THESE VALUES ---
# Define the NVIDIA driver branch to install
# This version MUST match the dev package
DRIVER_BRANCH="570"

# Name of the final executable produced by 'make'
PARTITION_TOOL_EXE_NAME="partitioner" # Assumed name, change if needed
# --- END EDIT ---

PARTITION_TOOL_NAME="nv-partitioner" # The final name we want on the system
PARTITION_TOOL_PATH="/usr/local/sbin/${PARTITION_TOOL_NAME}"
PARTITION_TOOL_BUILD_DIR="/root/build-partition-tool" # Temporary build dir

# NVIDIA repo key for Ubuntu 22.04
CUDA_REPO_DEB="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb"

###############################################################################
###############################################################################
###############################################################################

#
# service implementation
#

service_cleanup()
{
    :
}

service_install()
{
    export DEBIAN_FRONTEND=noninteractive

    # ensuring that the setup directory exists
    mkdir -p "$ONE_SERVICE_SETUP_DIR"

    # Add NVIDIA repository
    install_nvidia_repo

    # Install drivers, FM service, and build tools (make are in build-essential)
    install_packages

    # Install the boot manager script that adds resiliency
    install_boot_manager

    # Configure the FM service
    configure_fm_service

    # Build and install the partitioning tool
    build_partition_tool

    # service metadata
    create_one_service_metadata

    # cleanup
    postinstall_cleanup

    msg info "INSTALLATION FINISHED"

    return 0
}

service_configure()
{
    msg info "Starting NVIDIA Fabric Manager service (managed by one-fm-boot-manager.sh)"
    if ! systemctl start nvidia-fabricmanager; then
        msg error "Failed to start nvidia-fabricmanager service. Check VM logs and /var/log/syslog for 'one-fm-boot-manager' entries."
        exit 1
    fi

    msg info "FABRIC MANAGER VM CONFIGURATION FINISHED"
    msg info "This VM is READY."
    msg info "Next steps: SSH in and run '${PARTITION_TOOL_PATH}' to set partitions."
    return 0
}

service_bootstrap()
{
    # No bootstrap actions required
    return 0
}

###############################################################################
###############################################################################
###############################################################################

#
# functions
#

install_boot_manager()
{
    local SCRIPT_DIR
    SCRIPT_DIR="$(dirname "$0")"
    local BOOT_MANAGER_SRC="${SCRIPT_DIR}/one-fm-boot-manager.sh"
    local BOOT_MANAGER_DST="/usr/local/sbin/one-fm-boot-manager.sh"

    msg info "Installing Fabric Manager boot manager script"

    if [ ! -f "${BOOT_MANAGER_SRC}" ]; then
        msg error "Boot manager script not found at: ${BOOT_MANAGER_SRC}"
        exit 1
    fi

    cp "${BOOT_MANAGER_SRC}" "${BOOT_MANAGER_DST}"
    chmod +x "${BOOT_MANAGER_DST}"
}

install_nvidia_repo()
{
    msg info "Installing NVIDIA CUDA Repository Key"
    # Need wget to download the key
    if ! apt-get update || ! apt-get install -y wget; then
       msg error "Failed to install wget"
       exit 1
    fi
    wget ${CUDA_REPO_DEB} -O /tmp/cuda-keyring.deb
    if ! dpkg -i /tmp/cuda-keyring.deb; then
        msg error "Failed to install NVIDIA repo keyring"
        exit 1
    fi
    rm /tmp/cuda-keyring.deb
    apt-get update
}

install_packages()
{
    msg info "Installing NVIDIA and build packages (Branch ${DRIVER_BRANCH})"

    # Install drivers, fabric manager, the dev SDK, and build-essential (for make/g++)
    if ! apt-get install -y \
        "nvidia-driver-${DRIVER_BRANCH}" \
        "nvidia-fabricmanager-${DRIVER_BRANCH}" \
        "nvidia-fabricmanager-dev-${DRIVER_BRANCH}" \
        build-essential; then
        msg error "Failed to install required packages"
        exit 1
    fi

    return 0
}

configure_fm_service()
{
    local FM_CONFIG_FILE="/usr/share/nvidia/nvswitch/fabricmanager.cfg"
    
    msg info "Configuring Fabric Manager for Shared NVSwitch Mode"

    # Fabric Manager Operating Mode
    # (1) Start FM in Shared NVSwitch multi-tenancy mode.
    sed -i 's/^\(FABRIC_MODE\)=.*/\1=1/' ${FM_CONFIG_FILE}

    # Set persistent state files
    mkdir -p /var/lib/nvidia-fabricmanager
    touch /var/lib/nvidia-fabricmanager/active_partitions.state
    
    # STATE_FILE_NAME is used by nvidia-fabricmanager itself (metadata)
    sed -i 's|^\(STATE_FILE_NAME\)=.*|\1=/var/lib/nvidia-fabricmanager/fabricmanager.state|' ${FM_CONFIG_FILE}

    # Override the systemd to use boot manager script for resiliency
    msg info "Overriding systemd service to use boot manager"
    local OVERRIDE_DIR="/etc/systemd/system/nvidia-fabricmanager.service.d"
    mkdir -p "${OVERRIDE_DIR}"
    cat <<EOF > "${OVERRIDE_DIR}/override.conf"
[Service]
ExecStart=
ExecStart=/usr/local/sbin/one-fm-boot-manager.sh
EOF

    systemctl daemon-reload

    msg info "Enabling nvidia-fabricmanager systemd service"
    systemctl enable nvidia-fabricmanager.service
}

build_partition_tool()
{
    local SCRIPT_DIR
    SCRIPT_DIR="$(dirname "$0")"
    local TOOL_SRC_DIR="${SCRIPT_DIR}/fabricManager-partition-tool"

    msg info "Building NVLink partition tool from local source: ${TOOL_SRC_DIR}"

    if [ ! -d "${TOOL_SRC_DIR}" ]; then
        msg error "Partition tool source directory not found at: ${TOOL_SRC_DIR}"
        exit 1
    fi

    # Create build directory and copy source
    mkdir -p "${PARTITION_TOOL_BUILD_DIR}"
    cp -r "${TOOL_SRC_DIR}"/* "${PARTITION_TOOL_BUILD_DIR}/"

    msg info "Compiling tool in ${PARTITION_TOOL_BUILD_DIR}"
    cd "${PARTITION_TOOL_BUILD_DIR}"

    # Assuming the directory has a standard Makefile that uses g++ and links against libnvfm
    if ! make; then
        msg error "Failed to compile partition tool using 'make'."
        msg error "Check the Makefile and build dependencies (build-essential, nvidia-fabricmanager-dev-${DRIVER_BRANCH})."
        cd /root
        rm -rf "${PARTITION_TOOL_BUILD_DIR}"
        exit 1
    fi

    # Check if the expected executable exists after make
    if [ ! -f "${PARTITION_TOOL_EXE_NAME}" ]; then
         msg error "Makefile did not produce the expected executable: ${PARTITION_TOOL_EXE_NAME}"
         msg error "Please update 'PARTITION_TOOL_EXE_NAME' in the appliance script."
         cd /root
         rm -rf "${PARTITION_TOOL_BUILD_DIR}"
         exit 1
    fi

    msg info "Installing compiled tool to ${PARTITION_TOOL_PATH}"
    # Copy the compiled binary to the final destination
    cp "${PARTITION_TOOL_EXE_NAME}" "${PARTITION_TOOL_PATH}"
    chmod +x "${PARTITION_TOOL_PATH}"

    # Cleanup build directory
    cd /root
    rm -rf "${PARTITION_TOOL_BUILD_DIR}"

    msg info "Partition tool build successful."
}


postinstall_cleanup()
{
    export DEBIAN_FRONTEND=noninteractive

    msg info "Delete cache and stored packages"
    apt-get autoclean -y
    apt-get autoremove -y
    find /var/lib/apt/lists/ -type f ! -name '*nvidia*' -delete
}