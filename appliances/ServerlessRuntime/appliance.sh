#!/usr/bin/env bash

# ---------------------------------------------------------------------------- #
# Serverless Runtime Appliance for OpenNebula Marketplace
# ---------------------------------------------------------------------------- #

### Utility Functions

# ------------------------------------------------------------------------------
# List of contextualization parameters
# ------------------------------------------------------------------------------
ONE_SERVICE_PARAMS=(
    'ONEAPP_SR_BROKER'   'configure' 'RabbitMQ broker URL (optional, auto-discovered via OneGate)' ''
    'ONEAPP_SR_FLAVOUR'  'configure' 'Service flavour/queue name (required)'                        'O|text'
    'ONEAPP_SR_PORT'     'configure' 'API port (default: 8000)'                                    ''
    'ONEAPP_SR_PROM_PORT' 'configure' 'Prometheus metrics port (default: 9100)'                    ''
)

# ------------------------------------------------------------------------------
# Appliance metadata
# ------------------------------------------------------------------------------

ONE_SERVICE_NAME='Serverless Runtime - KVM'
ONE_SERVICE_VERSION='1.0.0'
ONE_SERVICE_BUILD=$(date +%s)
ONE_SERVICE_SHORT_DESCRIPTION='Appliance running Serverless Runtime service'
ONE_SERVICE_DESCRIPTION=$(cat <<EOF
Appliance with preinstalled Serverless Runtime. The Serverless Runtime is a
FastAPI-based service that executes offloaded tasks and exposes FaaS/DaaS APIs.

The service exposes:
- FaaS/DaaS APIs on port 8000 (configurable via ONEAPP_SR_PORT)
- Prometheus metrics on port 9100 (configurable via ONEAPP_SR_PROM_PORT)

Contextualization variables:
- ONEAPP_SR_FLAVOUR: Required. Service flavour/queue name for RabbitMQ
- ONEAPP_SR_BROKER: Optional. RabbitMQ broker URL. If not provided, will be
  auto-discovered via OneGate from the Frontend service.
- ONEAPP_SR_PORT: Optional. API port (default: 8000)
- ONEAPP_SR_PROM_PORT: Optional. Prometheus port (default: 9100)

After deploying the appliance, check the status of the deployment in
/etc/one-appliance/status. You can check the appliance logs in
/var/log/one-appliance/ and the service logs via systemctl status cognit-sr.
EOF
)

# ------------------------------------------------------------------------------
# Contextualization defaults
# ------------------------------------------------------------------------------
SR_BROKER="${ONEAPP_SR_BROKER:-}"
SR_FLAVOUR="${ONEAPP_SR_FLAVOUR:-}"
SR_PORT="${ONEAPP_SR_PORT:-8000}"
SR_PROM_PORT="${ONEAPP_SR_PROM_PORT:-9100}"

# ------------------------------------------------------------------------------
# Installation Stage => Install Python, dependencies, and serverless-runtime
# ------------------------------------------------------------------------------
service_install() {
    msg info "Checking internet access..."
    check_internet_access

    msg info "Installing system dependencies..."
    install_requirements

    msg info "Setting up Python virtual environment..."
    setup_python_environment

    msg info "Installing Python dependencies..."
    install_python_dependencies

    create_one_service_metadata
    msg info "Installation phase finished"
}

# ------------------------------------------------------------------------------
# Configuration Stage => Create systemd service file
# ------------------------------------------------------------------------------
service_configure() {
    msg info "Starting configuration..."

    if [ -z "$SR_FLAVOUR" ]; then
        msg error "ONEAPP_SR_FLAVOUR is required but not set"
        exit 1
    fi

    msg info "Creating systemd service file..."
    create_systemd_service

    msg info "Configuration phase finished"
}

# ------------------------------------------------------------------------------
# Bootstrap Stage => Enable and start the service
# ------------------------------------------------------------------------------
service_bootstrap() {
    msg info "Starting bootstrap..."

    msg info "Enabling cognit-sr service..."
    systemctl daemon-reload
    systemctl enable cognit-sr.service

    msg info "Starting cognit-sr service..."
    systemctl start cognit-sr.service

    # Wait a bit for the service to start
    sleep 5

    # Check if service is running
    if systemctl is-active --quiet cognit-sr.service; then
        msg info "Serverless Runtime service is running"
    else
        msg warning "Serverless Runtime service may not be running properly"
        systemctl status cognit-sr.service || true
    fi

    msg info "Bootstrap phase finished"
}

# ------------------------------------------------------------------------------
# Function Definitions
# ------------------------------------------------------------------------------

check_internet_access() {
    # Try multiple methods to check internet access
    # QEMU user-mode networking doesn't support ICMP, so use TCP/HTTP instead
    if curl -s --connect-timeout 10 http://archive.ubuntu.com > /dev/null 2>&1; then
        msg info "Internet access OK (via curl)"
        return 0
    elif nc -z -w 5 archive.ubuntu.com 80 2>/dev/null; then
        msg info "Internet access OK (via nc)"
        return 0
    elif ping -c 1 -W 5 8.8.8.8 &> /dev/null; then
        msg info "Internet access OK (via ping)"
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
        python3.10 \
        python3.10-venv \
        python3-pip \
        jq \
        curl \
        git \
        build-essential \
        python3-dev

    if [ $? -eq 0 ]; then
        msg info "System dependencies installed successfully"
    else
        msg error "System dependencies installation failed. Aborting..."
        exit 1
    fi
}

setup_python_environment() {
    SR_DIR="/root/serverless-runtime"

    if [ ! -d "$SR_DIR" ]; then
        msg error "Serverless Runtime directory not found at $SR_DIR"
        exit 1
    fi

    msg info "Creating Python virtual environment..."
    cd "$SR_DIR"
    python3.10 -m venv serverless-env

    msg info "Activating virtual environment and upgrading pip..."
    source serverless-env/bin/activate
    pip install --upgrade pip setuptools wheel

    msg info "Python environment setup complete"
}

install_python_dependencies() {
    SR_DIR="/root/serverless-runtime"

    cd "$SR_DIR"
    source serverless-env/bin/activate

    msg info "Installing Python dependencies from requirements.txt..."
    pip install -r requirements.txt

    if [ $? -eq 0 ]; then
        msg info "Python dependencies installed successfully"
    else
        msg error "Python dependencies installation failed. Aborting..."
        exit 1
    fi

    # Clean up pip cache
    pip cache purge || true
}

create_systemd_service() {
    SR_DIR="/root/serverless-runtime"
    SERVICE_FILE="/etc/systemd/system/cognit-sr.service"

    # Determine broker URL
    if [ -n "$SR_BROKER" ]; then
        BROKER_URL="$SR_BROKER"
        msg info "Using provided broker URL: $BROKER_URL"
    else
        # Auto-discover via OneGate (will be set in start script)
        BROKER_URL=""
        msg info "Broker will be auto-discovered via OneGate"
    fi

    # Create start script that handles broker discovery
    START_SCRIPT="/root/serverless-runtime/start-service.sh"
    cat > "$START_SCRIPT" <<'EOFSCRIPT'
#!/bin/bash
set -e

SR_DIR="/root/serverless-runtime"
cd "$SR_DIR"
source serverless-env/bin/activate
cd app/

# Source OpenNebula context
if [ -f /var/run/one-context/one_env ]; then
    source /var/run/one-context/one_env
fi

# Determine broker URL
if [ -n "$ONEAPP_SR_BROKER" ]; then
    BROKER="$ONEAPP_SR_BROKER"
elif [ -n "$COGNIT_BROKER" ]; then
    BROKER="$COGNIT_BROKER"
else
    # Try to discover via OneGate
    if command -v onegate >/dev/null 2>&1; then
        FRONTEND_VM_ID=$(onegate service show --json 2>/dev/null | jq -r '.SERVICE.roles[] | select(.name == "Frontend").nodes[0].vm_info.VM.ID' 2>/dev/null || echo "")
        if [ -n "$FRONTEND_VM_ID" ] && [ "$FRONTEND_VM_ID" != "null" ]; then
            FRONTEND_VM_IP=$(onegate vm show "$FRONTEND_VM_ID" --json 2>/dev/null | jq -r '.VM.TEMPLATE.NIC[0].IP' 2>/dev/null || echo "")
            if [ -n "$FRONTEND_VM_IP" ] && [ "$FRONTEND_VM_IP" != "null" ]; then
                BROKER="amqp://rabbitadmin:rabbitadmin@${FRONTEND_VM_IP}:5672"
            fi
        fi
    fi
fi

# Use flavour from context or environment
FLAVOUR="${ONEAPP_SR_FLAVOUR:-${COGNIT_FLAVOUR}}"
PORT="${ONEAPP_SR_PORT:-8000}"

if [ -z "$BROKER" ] || [ -z "$FLAVOUR" ]; then
    echo "Error: BROKER or FLAVOUR not set. BROKER=$BROKER FLAVOUR=$FLAVOUR" >&2
    exit 1
fi

exec python3 main.py --host "0.0.0.0" --port "$PORT" --broker "$BROKER" --flavour "$FLAVOUR"
EOFSCRIPT

    chmod +x "$START_SCRIPT"

    # Create systemd service file
    cat > "$SERVICE_FILE" <<EOFSERVICE
[Unit]
Description=Serverless Runtime Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$SR_DIR/app
Environment="ONEAPP_SR_BROKER=$SR_BROKER"
Environment="ONEAPP_SR_FLAVOUR=$SR_FLAVOUR"
Environment="ONEAPP_SR_PORT=$SR_PORT"
Environment="ONEAPP_SR_PROM_PORT=$SR_PROM_PORT"
ExecStart=$START_SCRIPT
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOFSERVICE

    msg info "Systemd service file created at $SERVICE_FILE"
}


