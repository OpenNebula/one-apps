#!/usr/bin/env bash

# Clean ZYPPER caches, remove temporary/unneeded files/logs/packages.

exec 1>&2
set -eux -o pipefail

# Keep only the latest kernel, temporarily override multiversion.kernels
if [[ -e /etc/zypp/zypp.conf ]]; then
    cp -f /etc/zypp/zypp.conf /etc/zypp/zypp.conf.bak
    sed -i 's/^\(multiversion.kernels\s*=\).*$/\1latest/' /etc/zypp/zypp.conf
    zypper -n purge-kernels
    mv -f /etc/zypp/zypp.conf.bak /etc/zypp/zypp.conf
else
    # libzypp 17.38+ (Leap 16.1) no longer ships /etc/zypp/zypp.conf, defaults
    # are in /usr/etc/zypp/zypp.conf and overrides in /etc/zypp/zypp.conf.d/
    mkdir -p /etc/zypp/zypp.conf.d
    printf '[main]\nmultiversion.kernels = latest\n' >/etc/zypp/zypp.conf.d/one-purge-kernels.conf
    zypper -n purge-kernels
    rm -f /etc/zypp/zypp.conf.d/one-purge-kernels.conf
fi

zypper remove --clean-deps -y salt salt-minion ||:

zypper clean --all

rm -f /etc/hostname
rm -rf /context/

# Remove jeos-firstboot file
# https://github.com/openSUSE/jeos-firstboot
rm -f /var/lib/YaST2/reconfig_system

sync
