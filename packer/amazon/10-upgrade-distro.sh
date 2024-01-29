#!/usr/bin/env bash

# Install required packages and upgrade the distro.

exec 1>&2
set -eux -o pipefail

# NOTE: in this old version of OL, dnf is not available.

yum update -y --skip-broken

yum upgrade -y util-linux

# Ensure packages needed for post-processing scripts do exist.
yum install -y curl gawk grep jq sed

sync
