#!/usr/bin/env bash

# Clean ZYPPER caches, remove temporary/unneeded files/logs/packages.

exec 1>&2
set -eux -o pipefail

cp -f /etc/zypp/zypp.conf /etc/zypp/zypp.conf.bak
sed -i 's/^\(multiversion.kernels\s*=\).*$/\1latest/' /etc/zypp/zypp.conf
zypper -n purge-kernels
mv -f /etc/zypp/zypp.conf.bak /etc/zypp/zypp.conf

zypper remove --clean-deps -y salt salt-minion ||:

zypper clean --all

rm -f /etc/hostname
rm -rf /context/

# Remove jeos-firstboot file
# https://github.com/openSUSE/jeos-firstboot
rm -f /var/lib/YaST2/reconfig_system

sync
