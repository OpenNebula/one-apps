#!/usr/bin/env ash

# Install required packages and upgrade the distro.

exec 1>&2
set -eux -o pipefail

service haveged stop ||:

apk update

apk add bash curl ethtool gawk grep iproute2 jq ruby sed tcpdump go iptables

sync
