#!/usr/bin/env bash

# Cleans YUM caches, removes temporary files / logs,
# removes leftover / temporary unneeded packages.

exec 1>&2
set -o errexit -o nounset -o pipefail
set -x

systemctl mask gssproxy.service

package-cleanup --oldkernels --count=1 -y

yum remove -y NetworkManager
yum remove -y fwupd linux-firmware

yum clean -y all

rm -rf /context/

sync
