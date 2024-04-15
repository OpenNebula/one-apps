#!/bin/bash

# Harbor Docker Registry Appliance for OpenNebula Marketplace

### Utility Functions
gen_password() {
    # Placeholder for password generation logic
    tr -dc A-Za-z0-9 </dev/urandom | head -c 20; echo
}

get_local_ip() {
    # Placeholder for local IP retrieval logic
    hostname -I | awk '{print $1}'
}


### Constants and Defaults
HARBOR_ADMIN_PASSWORD="${HARBOR_ADMIN_PASSWORD:-Harbor12345}"
HARBOR_DB_PASSWORD="${HARBOR_DB_PASSWORD:-$(gen_password)}"
HARBOR_CLAIR_DB_PASSWORD="${HARBOR_CLAIR_DB_PASSWORD:-$(gen_password)}"
HARBOR_HOSTNAME="${HARBOR_HOSTNAME:-$(get_local_ip)}"
HARBOR_SSL_CERT="${HARBOR_SSL_CERT:-}"
HARBOR_SSL_KEY="${HARBOR_SSL_KEY:-}"
HARBOR_SSL_CHAIN="${HARBOR_SSL_CHAIN:-}"

### Logging Function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

### Installation Stage
service_install() {
    log "Starting installation..."
    check_docker
}


service_configuration() {
    log "Starting configuration..."
    generate_ssl_certs
    log "SSL certificate generation completed."
}

service_bootstrap() {
    log "Starting bootstrap..."
    download_install_harbor
    log "Harbor installation completed."
    cleanup_installation
    log "Cleanup completed."

}

### Function Definitions
check_docker() {
    log "Checking if Docker is installed and running..."
    if ! command -v docker &> /dev/null; then
        log "Docker could not be found, installing..."
        install_docker
    else
        log "Docker is installed, ensuring it is running..."
        if ! sudo systemctl is-active --quiet docker; then
            log "Docker is not running, attempting to start Docker..."
            sudo systemctl start docker
            sudo systemctl enable docker
        fi
        if ! sudo systemctl is-active --quiet docker; then
            log "Failed to start Docker, please check the Docker service and try again."
            exit 1
        else
            log "Docker is running."
        fi
    fi
}

install_docker() {
    log "Installing Docker..."
    sudo apt update
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io

    log "Installing the latest version of Docker Compose..."
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    log "Docker Compose version $(docker-compose --version) installed successfully."
}


generate_ssl_certs() {
    log "Generating SSL certificates..."
    if [ -z "${HARBOR_HOSTNAME}" ]; then
        log "HARBOR_HOSTNAME is not set or is empty. Cannot generate SSL certificates."
        exit 1
    fi
    mkdir -p certs
    openssl req -x509 -nodes -days 730 -newkey rsa:4096 -sha256 \
        -keyout certs/"${HARBOR_HOSTNAME}".key -addext "subjectAltName = DNS:${HARBOR_HOSTNAME}" \
        -out certs/"${HARBOR_HOSTNAME}".crt -subj "/CN=${HARBOR_HOSTNAME}"
    if [ $? -eq 0 ]; then
        sudo mv certs/"${HARBOR_HOSTNAME}".crt /etc/ssl/certs/
        sudo mv certs/"${HARBOR_HOSTNAME}".key /etc/ssl/private/
        sudo chown root:root /etc/ssl/certs/"${HARBOR_HOSTNAME}".crt
        sudo chown root:root /etc/ssl/private/"${HARBOR_HOSTNAME}".key
    else
        log "Failed to generate SSL certificates."
        exit 1
    fi
}


download_install_harbor() {
    log "Downloading and installing Harbor..."
    curl -s https://api.github.com/repos/goharbor/harbor/releases/latest | grep browser_download_url | cut -d '"' -f 4 | grep '\.tgz$' | grep -v offline | wget -qi -
    LATEST_HARBOR=$(ls -t harbor-online-installer-v*.tgz | head -n 1)
    tar -xvzf $LATEST_HARBOR
    cp harbor/harbor.yml.tmpl harbor/harbor.yml
    sed -i "s/reg.mydomain.com/${HARBOR_HOSTNAME}/" harbor/harbor.yml
    sed -i "s|/your/certificate/path|/etc/ssl/certs/${HARBOR_HOSTNAME}.crt|" harbor/harbor.yml
    sed -i "s|/your/private/key/path|/etc/ssl/private/${HARBOR_HOSTNAME}.key|" harbor/harbor.yml
    sed -i "s/harbor_admin_password: Harbor12345/harbor_admin_password: ${HARBOR_ADMIN_PASSWORD}/" harbor/harbor.yml
    cd harbor && sudo ./install.sh
}

cleanup_installation() {
    log "Cleaning up installation residues..."
    sudo apt-get clean
    sudo rm -rf /var/lib/apt/lists/* /opt/harbor.tgz harbor
}

### Main Execution Flow
log "Starting Harbor installation..."
check_docker
generate_ssl_certs
download_install_harbor
cleanup_installation
log "Harbor installation completed successfully."
