#!/usr/bin/env bash

# Clean APT caches, remove temporary/unneeded files/logs/packages.

exec 1>&2
set -eux -o pipefail

export DEBIAN_FRONTEND=noninteractive

# cloud-init was split into cloud-init + cloud-init-base (Ubuntu 26.04+);
# purge whichever are installed, otherwise cloud-init still runs at boot
# and clobbers root's authorized_keys with a disable_root forced command.
cloud_init_pkgs=$(dpkg-query -W -f='${Package}\n' 'cloud-init*' 2>/dev/null \
    | grep -xE 'cloud-init(-base)?' || true)

apt-get purge -y $cloud_init_pkgs snapd fwupd

apt-get autoremove -y --purge

apt-get clean -y && rm -rf /var/lib/apt/lists/*

if [[ -e /tmp/policy-rc.d ]]; then
    # restore vanilla policy if it has been backed up
    cp /tmp/policy-rc.d /usr/sbin/
else
    # remove temporary policy if no policy was present initially
    rm /usr/sbin/policy-rc.d
fi

rm -f /etc/sysctl.d/99-cloudimg-ipv6.conf

rm -rf /context/

sync
