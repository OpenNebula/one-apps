#!/usr/bin/env bash

# Install required packages and upgrade the distro.

exec 1>&2
set -eux -o pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update -y

apt-get install -y --fix-broken

# Ensure packages needed for post-processing scripts do exist.
apt-get install -y curl gawk grep jq sed

sync
