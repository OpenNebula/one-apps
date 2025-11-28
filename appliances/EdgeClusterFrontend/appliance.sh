#!/usr/bin/env bash

# ---------------------------------------------------------------------------- #
# Edge Cluster Frontend Appliance for OpenNebula Marketplace
# Combines: Edge Cluster Frontend + Prometheus RabbitMQ Exporter
# ---------------------------------------------------------------------------- #

### Utility Functions

# ------------------------------------------------------------------------------
# List of contextualization parameters
# ------------------------------------------------------------------------------
ONE_SERVICE_PARAMS=(
    'ONEAPP_ECF_FLAVOUR'         'configure' 'Queue/flavour name (COGNIT_FLAVOUR)'              'O|text'
)

# ------------------------------------------------------------------------------
# Appliance metadata
# ------------------------------------------------------------------------------

ONE_SERVICE_NAME='Edge Cluster Frontend - KVM'
ONE_SERVICE_VERSION='1.0.0'
ONE_SERVICE_BUILD=$(date +%s)
ONE_SERVICE_SHORT_DESCRIPTION='Appliance running Edge Cluster Frontend with Prometheus Exporter'
ONE_SERVICE_DESCRIPTION=$(cat <<EOF
Appliance with preinstalled Edge Cluster Frontend and Prometheus RabbitMQ Exporter.

The Edge Cluster Frontend is a FastAPI-based service that manages function execution
and service scaling for edge clusters.

Services exposed:
- Edge Cluster Frontend API on port 1339
- Prometheus metrics on port 9100
- RabbitMQ on port 5672 (management on 15672)

Contextualization variables:
- COGNIT_FLAVOUR: Queue/flavour name (required)

After deploying, the start_services.sh script will configure RabbitMQ and start services.
EOF
)

# ------------------------------------------------------------------------------
# Installation directories
# ------------------------------------------------------------------------------
ECF_DIR="/root/edgecluster-frontend"
PROM_EXPORTER_DIR="/root/prometheus-rabbitmq-exporter"
CONFIG_FILE="/etc/cognit-edge_cluster_frontend.conf"

# ------------------------------------------------------------------------------
# Installation Stage
# ------------------------------------------------------------------------------
service_install() {
    msg info "Checking internet access..."
    check_internet_access

    msg info "Installing system dependencies..."
    install_requirements

    msg info "Installing RabbitMQ..."
    install_rabbitmq

    msg info "Setting up Edge Cluster Frontend..."
    setup_edge_cluster_frontend

    msg info "Setting up Prometheus RabbitMQ Exporter..."
    setup_prometheus_exporter

    msg info "Creating configuration file..."
    create_config_file

    msg info "Creating start_services.sh script..."
    create_start_script

    create_one_service_metadata
    msg info "Installation phase finished"
}

# ------------------------------------------------------------------------------
# Configuration Stage
# ------------------------------------------------------------------------------
service_configure() {
    msg info "Configuration phase - nothing to do (configured at boot)"
}

# ------------------------------------------------------------------------------
# Bootstrap Stage
# ------------------------------------------------------------------------------
service_bootstrap() {
    msg info "Bootstrap phase - services started by start_services.sh via context"
}

# ------------------------------------------------------------------------------
# Function Definitions
# ------------------------------------------------------------------------------

check_internet_access() {
    if curl -s --connect-timeout 10 http://archive.ubuntu.com > /dev/null 2>&1; then
        msg info "Internet access OK (via curl)"
        return 0
    elif nc -z -w 5 archive.ubuntu.com 80 2>/dev/null; then
        msg info "Internet access OK (via nc)"
        return 0
    else
        msg error "The VM does not have internet access. Aborting..."
        exit 1
    fi
}

install_requirements() {
    export DEBIAN_FRONTEND=noninteractive

    msg info "Updating package lists..."
    apt-get update -y

    msg info "Installing system packages..."
    apt-get install -y \
        python3 \
        python3-venv \
        python3-pip \
        jq \
        curl \
        git \
        build-essential \
        python3-dev \
        libxml2-dev \
        libxslt1-dev

    if [ $? -eq 0 ]; then
        msg info "System dependencies installed successfully"
    else
        msg error "System dependencies installation failed. Aborting..."
        exit 1
    fi
}

install_rabbitmq() {
    msg info "Installing RabbitMQ server..."
    apt-get install -y rabbitmq-server

    msg info "Enabling RabbitMQ management plugin..."
    # Create enabled_plugins file with correct permissions
    mkdir -p /etc/rabbitmq
    echo '[rabbitmq_management].' > /etc/rabbitmq/enabled_plugins
    chown -R rabbitmq:rabbitmq /etc/rabbitmq

    msg info "Enabling RabbitMQ service..."
    systemctl enable rabbitmq-server

    # Start RabbitMQ to get rabbitmqadmin
    msg info "Starting RabbitMQ temporarily to download rabbitmqadmin..."
    systemctl start rabbitmq-server
    
    # Wait for management API to be ready
    msg info "Waiting for RabbitMQ management API..."
    for i in {1..30}; do
        if curl -s http://localhost:15672/cli/rabbitmqadmin -o /dev/null 2>&1; then
            break
        fi
        sleep 2
    done

    # Install rabbitmqadmin tool
    msg info "Installing rabbitmqadmin..."
    if curl -s http://localhost:15672/cli/rabbitmqadmin -o /usr/local/bin/rabbitmqadmin; then
        chmod +x /usr/local/bin/rabbitmqadmin
        msg info "rabbitmqadmin installed successfully"
    else
        msg warning "Could not download rabbitmqadmin, will download at first boot"
        # Create a placeholder script that downloads on first run
        cat > /usr/local/bin/rabbitmqadmin << 'EOFADMIN'
#!/bin/bash
if [ ! -f /usr/local/bin/.rabbitmqadmin_real ]; then
    curl -s http://localhost:15672/cli/rabbitmqadmin -o /usr/local/bin/.rabbitmqadmin_real
    chmod +x /usr/local/bin/.rabbitmqadmin_real
fi
exec /usr/local/bin/.rabbitmqadmin_real "$@"
EOFADMIN
        chmod +x /usr/local/bin/rabbitmqadmin
    fi

    # Stop RabbitMQ (will be started at boot)
    systemctl stop rabbitmq-server

    msg info "RabbitMQ installed successfully"
}

setup_edge_cluster_frontend() {
    local SRC_DIR="/root/edgecluster-frontend"

    if [ ! -d "$SRC_DIR" ]; then
        msg error "Edge Cluster Frontend source not found at $SRC_DIR"
        exit 1
    fi

    msg info "Creating Python virtual environment for Edge Cluster Frontend..."
    cd "$SRC_DIR"
    python3 -m venv .venv

    msg info "Installing Python dependencies..."
    source .venv/bin/activate
    pip install --upgrade pip setuptools wheel
    pip install -r requirements.txt

    if [ $? -eq 0 ]; then
        msg info "Edge Cluster Frontend dependencies installed successfully"
    else
        msg error "Edge Cluster Frontend dependencies installation failed. Aborting..."
        exit 1
    fi

    # Clean up pip cache
    pip cache purge || true
    deactivate
}

setup_prometheus_exporter() {
    local SRC_DIR="/root/prometheus-rabbitmq-exporter"

    if [ ! -d "$SRC_DIR" ]; then
        msg error "Prometheus RabbitMQ Exporter source not found at $SRC_DIR"
        exit 1
    fi

    msg info "Installing Prometheus exporter dependencies globally..."
    pip3 install prometheus-client requests

    msg info "Prometheus Exporter setup complete"
}

create_config_file() {
    msg info "Creating Edge Cluster Frontend configuration at $CONFIG_FILE"

    cat > "$CONFIG_FILE" << 'EOF'
host: 0.0.0.0
port: 1339
one_xmlrpc: https://cognit-lab.sovereignedge.eu/RPC2
oneflow: https://cognit-lab-oneflow.sovereignedge.eu/
cognit_frontend: https://cognit-lab-frontend.sovereignedge.eu/
broker: http://localhost:5672
cluster_id: 0
workers: 1
log_level: info
EOF

    msg info "Configuration file created"
}

create_start_script() {
    local SCRIPT_PATH="/root/start_services.sh"

    msg info "Creating start_services.sh at $SCRIPT_PATH"

    cat > "$SCRIPT_PATH" << 'EOFSCRIPT'
#!/bin/bash

echo "Sourcing OpenNebula environment..."
source /var/run/one-context/one_env

# Safety check: Exit if the COGNIT_FLAVOUR variable was not set.
if [ -z "$COGNIT_FLAVOUR" ]; then
    echo "ERROR: COGNIT_FLAVOUR environment variable not set. Exiting." >&2
    exit 1
fi
echo "Service flavour detected: $COGNIT_FLAVOUR"

# --- 1. Wait for RabbitMQ to be ready ---
echo "Waiting for RabbitMQ to start..."
while ! rabbitmqctl status > /dev/null 2>&1; do
    sleep 1
done
echo "RabbitMQ is ready."

# --- 2. Configure RabbitMQ Resources ---
# Exchanges
rabbitmqadmin delete exchange name=jobs_fanout > /dev/null 2>&1 || true
rabbitmqadmin delete exchange name=results > /dev/null 2>&1 || true
rabbitmqadmin declare exchange name=jobs_fanout type=fanout durable=false
rabbitmqadmin declare exchange name=results type=direct durable=false

# Queues (using the variable for the main queue)
rabbitmqadmin delete queue name=scaler_metrics_queue > /dev/null 2>&1 || true
rabbitmqadmin delete queue name="$COGNIT_FLAVOUR" > /dev/null 2>&1 || true
rabbitmqadmin declare queue name=scaler_metrics_queue durable=true
rabbitmqadmin declare queue name="$COGNIT_FLAVOUR" durable=false

# Bindings (using the variable for the main binding)
rabbitmqadmin declare binding source=jobs_fanout destination="$COGNIT_FLAVOUR"
rabbitmqadmin declare binding source=jobs_fanout destination=scaler_metrics_queue

echo "RabbitMQ configured."

# --- Start Edge Cluster Frontend ---
cd /root/edgecluster-frontend
source .venv/bin/activate
nohup python src/main.py >> /var/log/edge_cluster_frontend.log 2>&1 &
deactivate

# --- RabbitMQ Prometheus exporter ---
cd /root/prometheus-rabbitmq-exporter
nohup python3 exporter.py &
EOFSCRIPT

    chmod +x "$SCRIPT_PATH"
    msg info "start_services.sh created and made executable"
}
