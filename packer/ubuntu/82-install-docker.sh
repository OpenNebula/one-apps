#!/bin/bash
set -e

echo "Installing Docker and Docker Compose v2..."
apt-get update
apt-get install -y docker-compose-v2

echo "Configuring Docker daemon..."
mkdir -p /etc/docker
cat <<EOF > /etc/docker/daemon.json
{
  "iptables": false,
  "bip": "192.168.99.1/24",
  "default-address-pools": [
    {
      "base": "192.168.99.0/25",
      "size": 27
    }
  ],
  "log-driver": "local",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3",
    "compress": "true"
  }
}
EOF

echo "Disabling Docker service by default..."
systemctl disable docker
