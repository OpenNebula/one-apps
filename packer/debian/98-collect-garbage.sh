#!/usr/bin/env bash

# Clean APT caches, remove temporary/unneeded files/logs/packages.

exec 1>&2
set -eux -o pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get purge -y cloud-init fwupd snapd

apt-get autoremove -y

apt-get clean -y && rm -rf /var/lib/apt/lists/*

if [[ -e /tmp/policy-rc.d ]]; then
    # restore vanilla policy if it has been backed up
    cp /tmp/policy-rc.d /usr/sbin/
else
    # remove temporary policy if no policy was present initially
    rm /usr/sbin/policy-rc.d
fi

rm -f /etc/hostname
rm -f /etc/network/cloud-ifupdown-helper
rm -f /etc/network/cloud-interfaces-template
rm -f /etc/network/if-post-down.d/cloud_inet6
rm -f /etc/network/if-pre-up.d/cloud_inet6
rm -f /etc/udev/rules.d/75-cloud-ifupdown.rules

rm -rf /context/

sync
