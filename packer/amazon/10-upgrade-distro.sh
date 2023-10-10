#!/usr/bin/env bash

# (Auto)Removes unneeded packages and upgrades
# the distro.

exec 1>&2
set -o errexit -o nounset -o pipefail
set -x

# NOTE: in this old version of OL, dnf is not available.

yum update -y --skip-broken

yum upgrade -y util-linux

# Ensure packages needed for post-processing scripts do exist.
yum install -y curl gawk grep jq sed

sync
