#!/bin/bash
set -e

echo "Installing Docker and Docker Compose v2..."
apt-get update
apt-get install -y docker-compose-v2

echo "Disabling Docker service by default..."
systemctl disable docker
