#!/usr/bin/env bash

# Clean DNF caches, remove temporary/unneeded files/logs/packages.

exec 1>&2
set -eux -o pipefail

systemctl disable kdump.service

# Remove old kernels.
dnf remove -y $(dnf repoquery --installonly --latest-limit=-1 -q)

dnf remove -y linux-firmware insights-client

dnf clean -y all

rm -rf /boot/*-rescue-*
rm -rf /context/

sync
