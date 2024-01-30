#!/usr/bin/env bash

# Clean APT caches, remove temporary/unneeded files/logs/packages.

exec 1>&2
set -eux -o pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get remove --purge -y cloud-init fwupd

apt-get autoremove -y

apt-get clean -y && rm -rf /var/lib/apt/lists/*

install -d /var/lib/apt/lists/partial/

rm -rf /context/

# virt-sysprep fails to do that
rm -rf /etc/openssh/ssh_host*

sync
