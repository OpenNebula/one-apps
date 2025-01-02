#!/usr/bin/env bash

# Clean DNF caches, remove temporary/unneeded files/logs/packages.

exec 1>&2
set -eux -o pipefail

KDUMP="kdump.service"
systemctl list-units --full -all | grep -Fq "$KDUMP" && systemctl disable "$KDUMP"

# Remove old kernels.
dnf remove -y $(dnf repoquery --installonly --latest-limit=-1 -q)

dnf remove -y linux-firmware

dnf clean -y all

rm -rf /boot/*-rescue-*
rm -rf /context/

sync
