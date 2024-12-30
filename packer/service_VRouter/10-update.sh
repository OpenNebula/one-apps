#!/usr/bin/env ash

# Install required packages and upgrade the distro.

exec 1>&2
set -eux -o pipefail

service haveged stop ||:

apk --no-cache add bash curl ethtool gawk go grep iproute2 jq ruby sed tcpdump iptables

sync
