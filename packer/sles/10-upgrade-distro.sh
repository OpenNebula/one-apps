#!/usr/bin/env bash

# Register with SUSE Customer Center, install required packages and upgrade the distro.

exec 1>&2
set -eux -o pipefail

xfs_growfs /

echo 'hostonly="no"' >/etc/dracut.conf.d/02-generic-image.conf

SUSEConnect -r "${SLE_REGCODE}" -e "${SLE_EMAIL}"

zypper --non-interactive --gpg-auto-import-keys update -y

# Ensure packages needed for post-processing scripts do exist.
zypper --non-interactive install -y curl gawk grep jq sed

sync
