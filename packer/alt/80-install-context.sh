#!/usr/bin/env bash

# Downloads and installs the latest one-context package.

: "${CTXEXT:=alt1.noarch.rpm}"

exec 1>&2
set -eux -o pipefail

export DEBIAN_FRONTEND=noninteractive

LATEST=$(find /context/ -type f -name "one-context*-$CTXEXT" | sort -V | tail -n1)

apt-get remove --purge -y cloud-init
apt-get install -y "$LATEST" haveged open-vm-tools

systemctl enable haveged

# >>> Apply only on one-context >= 6.1 >>>
# - Fix Alt favour of NM by removing etcnet plugin and pointing to correct sysctl.conf
# - Disable Alt custom resolv.conf generation
if ! rpm -q --queryformat '%{VERSION}' one-context | grep -E '^([1-5]\.|6\.0\.)'; then
    apt-get install -y NetworkManager
    systemctl enable NetworkManager.service
    sed -i -e 's/^\(\s*plugins\s*\)=.*/\1=keyfile/' /etc/NetworkManager/NetworkManager.conf
    sed -i -e 's#^\(\s*NM_SYSCTL_CONF\)=.*#\1=/etc/sysctl.conf#' /etc/sysconfig/NetworkManager
    systemctl mask altlinux-libresolv
    systemctl mask altlinux-libresolv.path
    systemctl mask altlinux-openresolv
    systemctl mask altlinux-openresolv.path
    systemctl mask altlinux-simpleresolv
    systemctl mask altlinux-simpleresolv.path
fi
# <<< Apply only on one-context >= 6.1 <<<

sync
