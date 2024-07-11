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
#
### Important notes ##################################################


# List of contextualization parameters
ONE_SERVICE_PARAMS=(
    'ONEAPP_MINIO_ROOT_USER'           'configure'  'MinIO root user for MinIO server'                              'O|text'
    'ONEAPP_MINIO_ROOT_PASSWORD'       'configure'  'MinIO root user password for MinIO server'                     'O|password'
    'ONEAPP_MINIO_OPTS'                'configure'  'Additional commandline options for MinIO server'               'O|text'
    'ONEAPP_MINIO_HOSTNAME'            'configure'  'MinIO hostname for TLS certificate'                            'O|text'
    'ONEAPP_MINIO_TLS_CERT'            'configure'  'MinIO TLS certificate (.crt)'                                  'O|text64'
    'ONEAPP_MINIO_TLS_KEY'             'configure'  'MinIO TLS key (.key)'                                          'O|text64'
)


### Appliance metadata ###############################################

# Appliance metadata
ONE_SERVICE_NAME='Service MinIO - KVM'
ONE_SERVICE_VERSION=''   #latest
ONE_SERVICE_BUILD=$(date +%s)
ONE_SERVICE_SHORT_DESCRIPTION='Appliance with preinstalled MinIO for KVM hosts'
ONE_SERVICE_DESCRIPTION=$(cat <<EOF
Appliance with preinstalled MinIO.

This appliance installs the latest version of MinIO DEB from the official download mirror. If no parameters are defined
in the template contextualization, the MinIO Environment Variable File will use the defaults defined [here]
(https://min.io/docs/minio/linux/operations/install-deploy-manage/deploy-minio-single-node-single-drive.html#create-the-environment-variable-file).

This appliance can deploy a Single-Node Single-Drive or a Single-Node Multi-Drive installation of MinIO. The configuration script
will automatically detect how many drives are present on the VM and partition, format and mount all detected disks.
If just one disk is detected, the appliance will configure MinIO as Single-Node Multi-Drive. If more than one additional disk are detected,
the appliance will configure as Single-Node Multi-Drive.

Notes for "Single-Node Multi-Drive":
  - At least 4 drives have to be configured on the VM template, as that it is the minimum number of drives indicated in the [documentation]
  (https://min.io/docs/minio/linux/operations/checklists/hardware.html#id2).
  - All drives have to be the same size since MinIO limits the size used per drive to the smallest drive in the deployment.
  Refer to MinIO documentation for additional information.
  - The appliance will use /dev/vdb as the first disk for MinIO storage, and continue with vdc, vdd, etc. If any disk has a XFS partition already created,
it asumes the configuration was already made in previous configuration steps. It will skip the partition and formatting of the drive.

WARNING: After initial configuration do not add / remove disks to the VM since the configuration scripts will not
manage storage configuration changes.
EOF
)
ONE_SERVICE_RECONFIGURABLE=true

# ------------------------------------------------------------------------------
# Contextualization defaults
# ------------------------------------------------------------------------------

ONEAPP_MINIO_ROOT_USER="${ONEAPP_MINIO_ROOT_USER:-myminioadmin}"
ONEAPP_MINIO_ROOT_PASSWORD="${ONEAPP_MINIO_ROOT_PASSWORD:-minio-secret-key-change-me}"
ONEAPP_MINIO_OPTS="${ONEAPP_MINIO_OPTS:---console-address :9001}"
ONEAPP_MINIO_HOSTNAME="${ONEAPP_MINIO_HOSTNAME:-localhost,minio-*.example.net}"

### Globals ##########################################################

MINIO_VERSION="https://dl.min.io/server/minio/release/linux-amd64/archive/minio_20240704142545.0.0_amd64.deb"
CERTGEN_VERSION="https://github.com/minio/certgen/releases/download/v1.3.0/certgen_1.3.0_linux_amd64.deb"

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
    # ensuring that the setup directory exists
    #TODO: move to service
    mkdir -p "$ONE_SERVICE_SETUP_DIR"

    # minio install
    install_minio_server
    # certgen install
    install_minio_certgen
    # create user and group for MinIO
    create_user_group
    # create MinIO environment variable file
    create_default_environment_variable_file
    # create MinIO systemd service file
    create_enable_systemd_service
    # add MinIO section to fstab
    msg info "Add MinIO section to fstab"
    cat >> /etc/fstab <<EOF
# Start MinIO-volumes
# End MinIO-volumes
EOF

    # service metadata
    create_one_service_metadata

    # cleanup
    postinstall_cleanup

    msg info "INSTALLATION FINISHED"

    return 0
}

service_configure()
{
    # For each drive other than /dev/vda, check if they're already formatted.
    # If there's no format, create partitions and filesystem
    msg info "Checking drives partition and format"
    local_minio_drives=$(lsblk -d -o NAME | grep vd | grep -v 'vda')
    local_drives_count=1
    local_minio_volumes=""
    for device in $local_minio_drives; do
        # Partition and format dev
        partition_format_drive $device
        # Create folder in /mnt for drive mount
        folder="/mnt/disk-${local_drives_count}"
        local_minio_volumes+=" ${folder}"

        if [[ ! -d "${folder}" ]]; then
            msg info "Create folder ${folder}"
            mkdir "${folder}"
            msg info "Add /dev/${device}1 entry to fstab"
            sed -i "/# End MinIO-volumes/i /dev/${device}1    ${folder}    xfs    defaults    0    0" /etc/fstab
        else
            msg info "Folder ${folder} exists, skipping"
        fi

        local_drives_count=$((local_drives_count+1))
    done
    local_drives_count=$((local_drives_count-1))

    msg info "Mount fstab"
    if ! mount -a -t xfs; then
        msg error "Error mounting MinIO drives"
        exit 1
    fi

    msg info "Give ownership to minio-user on ${local_minio_volumes}"
    chown -R minio-user:minio-user ${local_minio_volumes}

    ## TLS Certificates
    #  If TLS certificate and key are provided from contextualization, use those. Otherwise, if
    #  defaults are detected, generate new certificate and key using MinIO certgen tool.
    #  Place the certificates in /opt/minio/certs. Ownership must be given to minio-user.
    local_minio_certs="/opt/minio/certs"

    if [[ -f "${local_minio_certs}/public.crt" ]] || [[ -f "${local_minio_certs}/private.key" ]]; then
        msg info "Certificates already exist. Skipping."
    else
        if [[ ! -d "${local_minio_certs}" ]]; then
            msg info "Create folder for TLS certificates: ${local_minio_certs}"
            mkdir -p ${local_minio_certs}
        else
            msg info "Folder for TLS certificates exists. Skipping."
        fi

        if [[ -z "${ONEAPP_MINIO_TLS_CERT}" ]] || [[ -z "${ONEAPP_MINIO_TLS_KEY}" ]]; then
            msg info "Autogenerating TLS certificates..."
            generate_tls_certs
        else
            msg info "Configuring provided TLS certificates..."
            echo ${ONEAPP_MINIO_TLS_CERT} | base64 --decode >> /opt/minio/certs/public.crt
            echo ${ONEAPP_MINIO_TLS_KEY} | base64 --decode >> /opt/minio/certs/private.key
            add_trusted_ca
        fi

        msg info "Give ownership of /opt/minio to minio-user"
        chown -R minio-user:minio-user /opt/minio
    fi

    # Edit MinIO environment variable file
    if (( local_drives_count > 1 )); then
        update_environment_variable_file "/mnt/disk-{1...$((local_drives_count))}"
    else
        update_environment_variable_file "${folder}"
    fi

    msg info "MINIO SERVER CONFIGURATION FINISHED"
    return 0
}

service_bootstrap()
{
    # TODO add bootstrap
    return 0
}

###############################################################################
###############################################################################
###############################################################################

#
# functions
#

partition_format_drive()
{
    # Check if device has been partitioned before
    if [[ -z "$(lsblk -nd -o PTTYPE /dev/${1})" ]]; then
        msg info "Create partition on /dev/${1}"
        echo ';' | sfdisk /dev/${1}
        msg info "Create XFS filesystem on /dev/${1}1"
        mkfs.xfs /dev/${1}1
    else
        msg info "/dev/${1}1 partition already exists, skipping partition and format"
    fi
}

install_minio_server()
{
    msg info "Install MinIO"
    wget ${MINIO_VERSION} -O minio.deb

    if ! dpkg -i minio.deb ; then
        msg error "Error installing MinIO server"
        exit 1
    fi

    return 0
}

install_minio_certgen()
{
    msg info "Install MinIO certgen"
    wget ${CERTGEN_VERSION} -O certgen.deb

    if ! dpkg -i certgen.deb ; then
        msg error "Error installing MinIO certgen"
        exit 1
    fi

    return 0
}

create_user_group()
{
    msg info "Create group minio-user"
    groupadd -r minio-user
    msg info "Create user minio-user"
    useradd -M -r -g minio-user minio-user
}

create_enable_systemd_service()
{
    msg info "Create systemd Service File"
    cat > /usr/lib/systemd/system/minio.service <<'EOF'
[Unit]
Description=MinIO
Documentation=https://min.io/docs/minio/linux/index.html
Wants=network-online.target
After=network-online.target
AssertFileIsExecutable=/usr/local/bin/minio

[Service]
WorkingDirectory=/usr/local

User=minio-user
Group=minio-user
ProtectProc=invisible

EnvironmentFile=-/etc/default/minio
ExecStartPre=/bin/bash -c "if [ -z \"${MINIO_VOLUMES}\" ]; then echo \"Variable MINIO_VOLUMES not set in /etc/default/minio\"; exit 1; fi"
ExecStart=/usr/local/bin/minio server $MINIO_OPTS $MINIO_VOLUMES

# MinIO RELEASE.2023-05-04T21-44-30Z adds support for Type=notify (https://www.freedesktop.org/software/systemd/man/systemd.service.html#Type=)
# This may improve systemctl setups where other services use `After=minio.server`
# Uncomment the line to enable the functionality
# Type=notify

# Let systemd restart this service always
Restart=always

# Specifies the maximum file descriptor number that can be opened by this process
LimitNOFILE=65536

# Specifies the maximum number of threads this process can create
TasksMax=infinity

# Disable timeout logic and wait until process is stopped
TimeoutStopSec=infinity
SendSIGKILL=no

[Install]
WantedBy=multi-user.target

# Built for ${project.name}-${project.version} (${project.name})

EOF

    msg info "Enable systemd service for MinIO"
    systemctl enable minio.service
}

create_default_environment_variable_file()
{
    msg info "Create default Environment Variable File for MinIO"
    cat > /etc/default/minio <<'EOF'
#
# ATTENTION: This file is managed by MinIO Service Contextualization. DO NOT manually edit this file, instead
# use contextualization parameters to update MinIO attributes.
#
# Begin Environment Variable File
#
# MINIO_ROOT_USER and MINIO_ROOT_PASSWORD sets the root account for the MinIO server.
# This user has unrestricted permissions to perform S3 and administrative API operations on any resource in the deployment.
# Omit to use the default values 'minioadmin:minioadmin'.
# MinIO recommends setting non-default values as a best practice, regardless of environment

MINIO_ROOT_USER=myminioadmin
MINIO_ROOT_PASSWORD=minio-secret-key-change-me

# MINIO_VOLUMES sets the storage volume or path to use for the MinIO server.

MINIO_VOLUMES="/mnt/data"

# MINIO_OPTS sets any additional commandline options to pass to the MinIO server.
# For example, `--console-address :9001` sets the MinIO Console listen port
MINIO_OPTS="--console-address :9001"

# MINIO_SERVER_URL sets the hostname of the local machine for use with the MinIO Server
# MinIO assumes your network control plane can correctly resolve this hostname to the local machine

# Uncomment the following line and replace the value with the correct hostname for the local machine and port for the MinIO server (9000 by default).

#MINIO_SERVER_URL="http://minio.example.net:9000"
EOF
}

generate_tls_certs()
{
    if [[ -z "${ONEAPP_MINIO_HOSTNAME}" ]]; then
        msg info "ONEAPP_MINIO_HOSTNAME is not set or empty. Generating certs with default name minio.example.net"
        ONEAPP_MINIO_HOSTNAME="localhost,minio-*.example.net"
    fi
    cd /opt/minio/certs

    msg info "Generate TLS certificates using certgen"
    if certgen -host "${ONEAPP_MINIO_HOSTNAME}"; then
        msg info "Certificate generated successfully"
    else
        msg info "Error generating TLS certificate. Resuming..."
    fi

    msg info "Give ownership of certificates to minio-user"
    chown minio-user:minio-user private.key public.crt

    cd /root
}

add_trusted_ca()
{
    local_ca_folder="/usr/local/share/ca-certificates/minio"

    msg info "Adding trust CA for MinIO endpoint"
    if [[ ! -d "${local_ca_folder}" ]]; then
        msg info "Create folder ${local_ca_folder}"
        mkdir "${local_ca_folder}"
    fi

    msg info "Create CA file and update certificates"
    cp /opt/minio/certs/public.crt ${local_ca_folder}/ca.crt
    update-ca-certificates
}

update_environment_variable_file()
{
    msg info "Update MinIO root user"
    sed -i "s/^MINIO_ROOT_USER\\s*=.*/MINIO_ROOT_USER=${ONEAPP_MINIO_ROOT_USER}/" /etc/default/minio
    msg info "Update MinIO root user password"
    sed -i "s/^MINIO_ROOT_PASSWORD\\s*=.*/MINIO_ROOT_PASSWORD=${ONEAPP_MINIO_ROOT_PASSWORD}/" /etc/default/minio
    msg info "Update MinIO volumes"
    sed -i "s|^MINIO_VOLUMES\\s*=.*|MINIO_VOLUMES=\"${1}\"|" /etc/default/minio
    msg info "Update MinIO opts"
    sed -i "s|^MINIO_OPTS\\s*=.*|MINIO_OPTS=\"${ONEAPP_MINIO_OPTS} --certs-dir /opt/minio/certs\"|" /etc/default/minio

    msg info "Restart minio service"
    systemctl restart minio
}

postinstall_cleanup()
{
    export DEBIAN_FRONTEND=noninteractive

    msg info "Delete cache and stored packages"
    apt-get autoclean
    apt-get autoremove
    rm -rf /var/lib/apt/lists/*
    rm /root/*.deb
}