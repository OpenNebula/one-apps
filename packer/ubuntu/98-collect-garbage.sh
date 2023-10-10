#!/usr/bin/env bash

# Cleans APT caches, removes temporary files / logs,
# removes leftover / temporary unneeded packages.

exec 1>&2
set -o errexit -o nounset -o pipefail
set -x

export DEBIAN_FRONTEND=noninteractive

apt-get purge -y cloud-init snapd fwupd

apt-get autoremove -y --purge

apt-get clean -y && rm -rf /var/lib/apt/lists/*

rm -f /etc/sysctl.d/99-cloudimg-ipv6.conf

rm -rf /context/

sync
