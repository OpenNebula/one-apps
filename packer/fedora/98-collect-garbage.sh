#!/usr/bin/env bash

# Cleans DNF caches, removes temporary files / logs,
# removes leftover / temporary unneeded packages.

exec 1>&2
set -o errexit -o nounset -o pipefail
set -x

# Remove old kernels.
dnf remove -y $(dnf repoquery --installonly --latest-limit=-1 -q)

dnf remove -y fwupd linux-firmware

dnf clean -y all

rm -rf /context/

sync
