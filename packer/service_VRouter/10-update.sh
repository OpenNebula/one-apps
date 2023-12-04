#!/usr/bin/env sh

# (Auto)Removes unneeded packages and upgrades
# the distro.

exec 1>&2
set -ex

service haveged stop ||:

apk update

apk --no-cache add \
    bash curl ethtool gawk grep iproute2 jq ruby sed tcpdump

sync
