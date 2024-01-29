#!/usr/bin/env bash

# Install required packages and upgrade the distro.

exec 1>&2
set -eux -o pipefail

xfs_growfs /

echo 'hostonly="no"' >/etc/dracut.conf.d/02-generic-image.conf

zypper --non-interactive --gpg-auto-import-keys update -y

# Ensure packages needed for post-processing scripts do exist.
zypper --non-interactive install -y curl gawk grep jq sed

sync
