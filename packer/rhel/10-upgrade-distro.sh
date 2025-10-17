#!/usr/bin/env bash

# Install required packages and upgrade the distro.

exec 1>&2
set -eux -o pipefail

# Make sure /etc/machine-id exists otherwise this can happen:
# https://bugzilla.redhat.com/show_bug.cgi?id=1737355
systemd-machine-id-setup

ln -sf ../usr/share/zoneinfo/UTC /etc/localtime

if [ "${DIST_VER}" -lt 10 ]; then
    subscription-manager register \
        --username "${RHEL_USER}" \
        --password "${RHEL_PASSWORD}" \
        --auto-attach \
        --force
fi

subscription-manager repos --enable codeready-builder-for-rhel-${DIST_VER}-${DIST_ARCH}-rpms

dnf install -y "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${DIST_VER}.noarch.rpm"

dnf repolist enabled

dnf update -y

# Ensure packages needed for post-processing scripts do exist.
dnf install -y curl gawk grep jq sed

sync
