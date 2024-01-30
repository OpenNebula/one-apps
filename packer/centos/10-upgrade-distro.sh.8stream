#!/usr/bin/env bash

# Install required packages and upgrade the distro.

exec 1>&2
set -eux -o pipefail

dnf install -y epel-release

dnf update -y --skip-broken

# Ensure packages needed for post-processing scripts do exist.
dnf install -y curl gawk grep jq sed

sync
