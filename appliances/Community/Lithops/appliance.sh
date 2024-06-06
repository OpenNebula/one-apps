# ---------------------------------------------------------------------------- #
# Copyright 2024, OpenNebula Project, OpenNebula Systems                  #
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


# List of contextualization parameters
ONE_SERVICE_PARAMS=(
    'ONEAPP_LITHOPS_BACKEND'            'configure'  'Lithops compute backend'                                          'O|text'
    'ONEAPP_LITHOPS_STORAGE'            'configure'  'Lithops storage backend'                                          'O|text'
    'ONEAPP_MINIO_ENDPOINT'             'configure'  'Lithops storage backend MinIO endpoint URL'                       'O|text'
    'ONEAPP_MINIO_ACCESS_KEY_ID'        'configure'  'Lithops storage backend MinIO account user access key'            'O|text'
    'ONEAPP_MINIO_SECRET_ACCESS_KEY'    'configure'  'Lithops storage backend MinIO account user secret access key'     'O|text'
    'ONEAPP_MINIO_BUCKETT'              'configure'  'Lithops storage backend MinIO existing bucket'                    'O|text'
    'ONEAPP_MINIO_ENDPOINT_CERT'        'configure'  'Lithops storage backend MinIO endpoint certificate'               'O|text64'
)


### Appliance metadata ###############################################

# Appliance metadata
ONE_SERVICE_NAME='Service Lithops - KVM'
ONE_SERVICE_VERSION='3.4.0'   #latest
ONE_SERVICE_BUILD=$(date +%s)
ONE_SERVICE_SHORT_DESCRIPTION='Appliance with preinstalled Lithops for KVM hosts'
ONE_SERVICE_DESCRIPTION=$(cat <<EOF
Appliance with preinstalled Lithops v3.4.0.

By default, it uses localhost both for Compute and Storage Backend.

To configure MinIO as Storage Backend use the parameter ONEAPP_LITHOPS_STORAGE=minio
with ONEAPP_MINIO_ENDPOINT, ONEAPP_MINIO_ACCESS_KEY_ID and ONEAPP_MINIO_SECRET_ACCESS_KEY.
These parameters values have to point to a valid and reachable MinIO server endpoint.

The parameter ONEAPP_MINIO_BUCKETT and ONEAPP_MINIO_ENDPOINT_CERT are optional.
- ONEAPP_MINIO_BUCKET points to an existing bucket in the MinIO server. If the bucket does not exist or if the
parameter is empty, the MinIO server will generate a bucket automatically.
- ONEAPP_MINIO_ENDPOINT_CERT is necessary when using self-signed certificates on the MinIO server. This is the
certificate for the CA on the MinIO server. If the CA certificate exists, script will skip it,
if one would want to update the CA certificate from context, first delete previous ca.crt file.
EOF
)
ONE_SERVICE_RECONFIGURABLE=true

### Contextualization defaults #######################################

ONEAPP_LITHOPS_BACKEND="${ONEAPP_LITHOPS_BACKEND:-localhost}"
ONEAPP_LITHOPS_STORAGE="${ONEAPP_LITHOPS_STORAGE:-localhost}"

### Globals ##########################################################

DEP_PKGS="python3-pip"
DEP_PIP="boto3"
LITHOPS_VERSION="3.4.0"
DOCKER_VERSION="5:26.1.3-1~ubuntu.22.04~jammy"

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
    export DEBIAN_FRONTEND=noninteractive

    # packages
    install_deps ${DEP_PKGS} ${DEP_PIP}

    # docker
    install_docker

    # Lithops
    install_lithops

    # create Lithops config file in /etc/lithops
    create_lithops_config

    # service metadata
    create_one_service_metadata

    # cleanup
    postinstall_cleanup

    msg info "INSTALLATION FINISHED"

    return 0
}

service_configure()
{
    # update Lithops config file if non-default options are set
    update_lithops_config

    local_ca_folder="/usr/local/share/ca-certificates/minio"
    if [[ ! -z "${ONEAPP_MINIO_ENDPOINT_CERT}" ]] && [[ ! -f "${local_ca_folder}/ca.crt" ]]; then
        msg info "Adding trust CA for MinIO endpoint"

        if [[ ! -d "${local_ca_folder}" ]]; then
            msg info "Create folder ${local_ca_folder}"
            mkdir "${local_ca_folder}"
        fi

        msg info "Create CA file and update certificates"
        echo ${ONEAPP_MINIO_ENDPOINT_CERT} | base64 --decode >> ${local_ca_folder}/ca.crt
        update-ca-certificates
    fi

    return 0
}

service_bootstrap()
{
    update_lithops_config
    return 0
}

###############################################################################
###############################################################################
###############################################################################

#
# functions
#

install_deps()
{
    msg info "Run apt-get update"
    apt-get update

    msg info "Install required packages for Lithops"
    if ! apt-get install -y "${1}" ; then
        msg error "Package(s) installation failed: ${1}"
        exit 1
    fi

    msg info "Install pip dependencies"
    if ! pip install "${2}" ; then
        msg error "Python pip dependencies installation failed"
        exit 1
    fi
}

install_docker()
{
    msg info "Add Docker official GPG key"
    install -m 0755 -d /etc/apt/keyrings

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc

    chmod a+r /etc/apt/keyrings/docker.asc

    msg info "Add Docker repository to apt sources"
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update

    msg info "Install Docker Engine"
    if ! apt-get install -y docker-ce=$DOCKER_VERSION docker-ce-cli=$DOCKER_VERSION containerd.io docker-buildx-plugin docker-compose-plugin ; then
        msg error "Docker installation failed"
        exit 1
    fi
}

install_lithops()
{
    msg info "Install Lithops from pip"
    if ! pip install lithops==${LITHOPS_VERSION} ; then
        msg error "Error installing Lithops"
        exit 1
    fi

    msg info "Create /etc/lithops folder"
    mkdir /etc/lithops
}

create_lithops_config()
{
    msg info "Create default config file"
    cat > /etc/lithops/config <<EOF
lithops:
  backend: localhost
  storage: localhost

# Start Compute Backend configuration
# End Compute Backend configuration

# Start Storage Backend configuration
# End Storage Backend configuration
EOF
}

update_lithops_config(){
    msg info "Update compute and storage backend modes"
    sed -i "s/backend: .*/backend: ${ONEAPP_LITHOPS_BACKEND}/g" /etc/lithops/config
    sed -i "s/storage: .*/storage: ${ONEAPP_LITHOPS_STORAGE}/g" /etc/lithops/config

    if [[ ${ONEAPP_LITHOPS_STORAGE} = "localhost" ]]; then
        msg info "Edit config file for localhost Storage Backend"
        sed -i -ne "/# Start Storage/ {p;" -e ":a; n; /# End Storage/ {p; b}; ba}; p" /etc/lithops/config
    elif [[ ${ONEAPP_LITHOPS_STORAGE} = "minio" ]]; then
        msg info "Edit config file for MinIO Storage Backend"
        if ! check_minio_attrs; then
            echo
            msg error "MinIO configuration failed"
            msg info "You have to provide endpoint, access key id and secrec access key to configure MinIO storage backend"
            exit 1
        else
            msg info "Adding MinIO configuration to /etc/lithops/config"
            sed -i -ne "/# Start Storage/ {p; iminio:\n  endpoint: ${ONEAPP_MINIO_ENDPOINT}\n  access_key_id: ${ONEAPP_MINIO_ACCESS_KEY_ID}\n  secret_access_key: ${ONEAPP_MINIO_SECRET_ACCESS_KEY}\n  storage_bucket: ${ONEAPP_MINIO_BUCKETT}" -e ":a; n; /# End Storage/ {p; b}; ba}; p" /etc/lithops/config
        fi
    fi
}

check_minio_attrs()
{
    [[ -z "$ONEAPP_MINIO_ENDPOINT" ]] && return 1
    [[ -z "$ONEAPP_MINIO_ACCESS_KEY_ID" ]] && return 1
    [[ -z "$ONEAPP_MINIO_SECRET_ACCESS_KEY" ]] && return 1

    return 0
}

postinstall_cleanup()
{
    msg info "Delete cache and stored packages"
    apt-get autoclean
    apt-get autoremove
    rm -rf /var/lib/apt/lists/*
}
