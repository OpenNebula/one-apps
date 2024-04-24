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

# Harbor Docker Registry Appliance for OpenNebula Marketplace

### Utility Functions

gen_db_password() {
    # In case of password losing, it can be retrieved from the harbor-db container root environment variables 
    tr -dc A-Za-z0-9 </dev/urandom | head -c 20; echo
}


# List of contextualization parameters #######################################
ONE_SERVICE_PARAMS=(
    'HARBOR_ADMIN_PASSWORD'     'configure' 'Harbor admin password'                             'O|password'
    'HARBOR_DB_PASSWORD'        'configure' 'Harbor database password'                          'O|password'
    'HARBOR_HOSTNAME'           'configure' 'Harbor hostname/IP'                                'O|text'
    'HARBOR_SSL_CERT'           'configure' 'SSL certificate (.crt)'                            'O|text64'
    'HARBOR_SSL_KEY'            'configure' 'SSL key (.key)'                                    'O|text64'
)

### Contextualization defaults #######################################
HARBOR_ADMIN_PASSWORD="${HARBOR_ADMIN_PASSWORD:-Harbor12345}"  # Default Harbor admin password
HARBOR_DB_PASSWORD="${HARBOR_DB_PASSWORD:-$(gen_db_password)}" # Defaults to autogenerated password
HARBOR_HOSTNAME="${HARBOR_HOSTNAME:-0.0.0.0}" # Listens in all interfaces by default
HARBOR_SSL_CERT="${HARBOR_SSL_CERT:-AG}" # Defaults to "AG", indicating "AutoGenerated"
HARBOR_SSL_KEY="${HARBOR_SSL_KEY:-AG}" # Defaults to "AG", indicating "AutoGenerated"


### Installation Stage => Installs requirements, downloads and unpacks Harbor 
service_install() {
    msg info "Checking internet access..."
    check_internet_access
    install_requirements
    download_unpack_harbor
    msg info "Installation phase finished"
}

### Configuration Stage => Configures Harbor YAML and SSL certificates
service_configure() { 
    msg info "Starting configuration..."
    mount_persistent
    ## SSL CERTS

    mkdir /root/certs
    if [ "$HARBOR_SSL_CERT" = "AG" ] || [ "$HARBOR_SSL_KEY" = "AG" ]; then
        msg info "Autogenerating SSL certificates..."
        generate_ssl_certs
    else
        msg info "Configuring provided SSL certificates..."
        echo $HARBOR_SSL_CERT >> mkdir /root/certs/server.crt
        echo $HARBOR_SSL_KEY >> mkdir /root/certs/server.key
    fi

    msg info "Configuring Harbor YAML file..."

    gawk -i inplace -v cert="/root/certs/server.crt" -v key="/root/certs/server.key" -v hostname="$HARBOR_HOSTNAME" '
    {
        if ($1 == "certificate:") {
            print "  certificate:", cert
        } else if ($1 == "private_key:") {
            print "  private_key:", key
        } else if ($1 == "hostname:") {
            print "hostname:", hostname
        } else {
            print
        }
    }' /root/harbor/harbor.yml

    gawk -i inplace -v admin_pwd="$HARBOR_ADMIN_PASSWORD" -v db_pwd="$HARBOR_DB_PASSWORD" '
    {
        if ($1 == "harbor_admin_password:") {
            print "harbor_admin_password:", admin_pwd
        } else if ($1 == "password:") {
            print "  password:", db_pwd
        } else {
            print
        }
    }' /root/harbor/harbor.yml
    msg info "Configuration phase finished"
}

service_bootstrap() { # Running Harbor installer => will generate and run docker-compose
    msg info "Starting bootstrap..."
    /root/harbor/install.sh
    if [ $? -ne 0 ]; then
	    msg error "Harbor installation script failed, aborting..."
        exit 1
    else
        msg info "Harbor installation script finished successfully. Waiting 60s before final health checks..."
    fi
    sleep 60
    msg info "Running final health checks..."
    wait_for_docker_containers
    cleanup_installation
    msg info "Bootstrap phase finished"

}

### Function Definitions

check_internet_access() {
    # Ping Google's public DNS server
    if ping -c 1 8.8.8.8 &> /dev/null; then
        msg info "Internet access OK"
        return 0
    else
        msg error "The VM does not have internet access. Aborting Harbor deployment..."
        exit 1
    fi
}

install_requirements(){
    apt update && apt install openssl ca-certificates curl gnupg docker.io docker-compose -y
    if [ $? -eq 0 ]; then
	    msg info "Dependencies installation finished successfully. Running extra checks..."
    else
        msg error "Dependencies installation failed. Resuming..."
    fi
    check_docker
    check_docker_compose
}

check_docker() {
    msg info "Checking if Docker is installed and running..."
    if ! command -v docker &> /dev/null; then
        msg error "Docker could not be found, Docker installation failed..."
    else
        msg info "Docker is installed, ensuring it is running..."
        if ! systemctl is-active --quiet docker; then
            msg warning "Docker is not running, attempting to start Docker..."
            systemctl start docker
            systemctl enable docker
            sleep 5
        fi
        if ! systemctl is-active --quiet docker; then
            msg error "Failed to start Docker, please check the Docker service and try again."
            exit 1
        else
            msg info "Docker is running"
            return 0
        fi
    fi
}

check_docker_compose() {
    msg info "Checking if docker-compose is installed..."
    if ! command -v docker-compose &> /dev/null; then
        msg error "docker-compose could not be found, aborting..."
        exit 1
    else
        msg info "docker-compose is installed"
        return 0
    fi
}



generate_ssl_certs() {
    if [ -z "${HARBOR_HOSTNAME}" ]; then
        msg info "HARBOR_HOSTNAME is not set or is empty. Generating certs with 'example.com'"
        HARBOR_HOSTNAME=example.com
    fi
    openssl req -new -newkey rsa:2048 -sha256 -days 365 -nodes -x509 \
    -keyout /root/certs/server.key -out /root/certs/server.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=$HARBOR_HOSTNAME"
    if [ $? -eq 0 ]; then
        msg info "Certificate generated successfully"
    else
        msg info "Error generating SSL certificate. Resuming..."
    fi
}


download_unpack_harbor() {
    msg info "Downloading Harbor..."
    url=$(curl -s https://api.github.com/repos/goharbor/harbor/releases/latest | grep browser_download_url | cut -d '"' -f 4 | grep '\.tgz$' | grep online)
    if [ $? -ne 0 ]; then
        msg error "Unable to obtain Harbor download URL, aborting..."
        exit 1
    fi
    wget -P /root/ $url
    if [ $? -ne 0 ]; then
	    msg info "Harbor download failed. Download URL: $url"
        exit 1
    else
        msg info "Harbor downloaded successfully"
    fi
    tar -xvzf /root/harbor-online-installer-v*.tgz
    if [ $? -ne 0 ]; then
	    msg info "Harbor unpacking failed. Aborting..."
        exit 1
    else
        msg info "Harbor unpacked successfully"
    fi
    cp /root/harbor/harbor.yml.tmpl /root/harbor/harbor.yml
}


mount_persistent() {
    # Check if /data directory exists, if not create it
    if [ ! -d "/data" ]; then
        mkdir -p /data
    fi

    # Check if /dev/vda exists
    if [ -e "/dev/vda" ]; then
        # Check if already mounted
        msg info "Persistent disk (/dev/vda) detected"
        if grep -qs '/dev/vda' /proc/mounts; then
            msg info "/dev/vda is already mounted."
        else
            # Add entry to /etc/fstab for persistence
            echo "/dev/vda   /data   ext4   defaults   0   2" | sudo tee -a /etc/fstab > /dev/null
            # Mount the drive
            mount -a
            msg info "Mounted /dev/vda to /data successfully."
        fi
    else
        msg error "Device /dev/vda does not exist, persistency can not be ensured"
        exit 1
    fi
}


wait_for_docker_containers() {
    local start_time=$(date +%s)
    local end_time=$((start_time + 300))  # 5 minutes in seconds
    local all_healthy=1

    while [ $(date +%s) -lt $end_time ]; do
        # Get the IDs of all running containers
        local container_ids=$(docker ps --format "{{.ID}}")

        # Iterate through each container ID to check its health
        for container_id in $container_ids; do
            local health=$(docker inspect --format "{{.State.Health.Status}}" "$container_id")
            
            # Check if the container is healthy
            if [ "$health" != "healthy" ]; then
                all_healthy=0
                break  # Break out of the loop if any container is not healthy
            fi
        done

        if [ $all_healthy -eq 1 ]; then
            msg info "All Docker containers are healthy."
            return 0  # All containers are healthy, exit successfully
        fi

        # Sleep for 5 seconds before checking again
        sleep 5
    done

    # If execution reaches here, some containers are still unhealthy after 5 minutes
    msg warning "Some Docker containers are not healthy after 5 minutes."
    return 1
}



cleanup_installation() {
    msg info "Cleaning up installation residues..."
    apt-get clean
    rm /root/harbor-online-installer-v*.tgz
}