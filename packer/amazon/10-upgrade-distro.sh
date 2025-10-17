#!/usr/bin/env bash

# Install required packages and upgrade the distro.

exec 1>&2
set -eux -o pipefail

# NOTE: in this old version of OL, dnf is not available.
pgrep yum && pkill yum ||:

yum update -y --skip-broken

yum upgrade -y util-linux

if [ "$DIST_VER" = 2 ]; then
    # Install ruby 3.0 as is also required for context cloud-init parsing
    amazon-linux-extras enable ruby3.0
    yum install -y curl gawk grep jq sed ruby
else
    yum install -y curl-minimal gawk grep jq sed
fi

sync
