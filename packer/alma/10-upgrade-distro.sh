#!/usr/bin/env bash

# (Auto)Removes unneeded packages and upgrades
# the distro.

exec 1>&2
set -o errexit -o nounset -o pipefail
set -x

dnf install -y epel-release

dnf update -y --skip-broken

# Ensure packages needed for post-processing scripts do exist.
dnf install -y curl gawk grep jq sed

sync
