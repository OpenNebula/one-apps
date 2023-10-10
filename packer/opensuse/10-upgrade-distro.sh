#!/usr/bin/env bash

# (Auto)Removes unneeded packages and upgrades
# the distro.

exec 1>&2
set -o errexit -o nounset -o pipefail
set -x

xfs_growfs /

echo 'hostonly="no"' >/etc/dracut.conf.d/02-generic-image.conf

zypper --non-interactive --gpg-auto-import-keys update -y

# Ensure packages needed for post-processing scripts do exist.
zypper --non-interactive install -y curl gawk grep jq sed

sync
