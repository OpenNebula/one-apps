#!/usr/bin/env bash

# Download and install the latest one-context package.

: "${CTXEXT:=el${DIST_VER}.noarch.rpm}"

exec 1>&2
set -eux -o pipefail

LATEST=$(find /context/ -type f -name "one-context*.$CTXEXT" | sort -V | tail -n1)

if [ "${DIST_VER}" -lt "10" ]; then
    dnf install -y "$LATEST" haveged
    systemctl enable haveged
    dnf install -y --setopt=install_weak_deps=False NetworkManager systemd-networkd
else
    dnf install -y "$LATEST"
    dnf install -y --setopt=install_weak_deps=False NetworkManager
fi

sync
