#!/usr/bin/env bash

# Clean APT caches, remove temporary/unneeded files/logs/packages.

exec 1>&2
set -eux -o pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get purge -y cloud-init snapd fwupd

apt-get autoremove -y --purge

apt-get clean -y && rm -rf /var/lib/apt/lists/*

rm -f /etc/sysctl.d/99-cloudimg-ipv6.conf

rm -rf /context/

sync
