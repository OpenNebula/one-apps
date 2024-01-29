#!/usr/bin/env bash

# Clean APT caches, remove temporary/unneeded files/logs/packages.

exec 1>&2
set -eux -o pipefail

systemctl mask gssproxy.service

package-cleanup --oldkernels --count=1 -y

yum remove -y NetworkManager
yum remove -y fwupd linux-firmware

yum clean -y all

rm -rf /context/

sync
