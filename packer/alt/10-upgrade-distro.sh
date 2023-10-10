#!/usr/bin/env bash

# (Auto)Removes unneeded packages and upgrades
# the distro.

exec 1>&2
set -o errexit -o nounset -o pipefail
set -x

export DEBIAN_FRONTEND=noninteractive

apt-get update -y

apt-get install -y --fix-broken

# Ensure packages needed for post-processing scripts do exist.
apt-get install -y curl gawk grep jq sed

sync
