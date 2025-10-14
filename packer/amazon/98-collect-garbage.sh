#!/usr/bin/env bash

# Clean APT caches, remove temporary/unneeded files/logs/packages.

exec 1>&2
set -eux -o pipefail

systemctl mask gssproxy.service

if [ "$DIST_VER" = "2" ]; then
    package-cleanup --oldkernels --count=1 -y
else
    package-cleanup --dupes -y
fi

yum remove -y NetworkManager
yum remove -y linux-firmware

yum clean -y all

rm -rf /context/

sync
