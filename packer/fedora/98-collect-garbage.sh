#!/usr/bin/env bash

# Clean DNF caches, remove temporary/unneeded files/logs/packages.

exec 1>&2
set -eux -o pipefail

# Remove old kernels.
dnf remove -y $(dnf repoquery --installonly --latest-limit=-1 -q)

dnf remove -y fwupd linux-firmware

dnf clean -y all

rm -rf /context/

sync
