#!/usr/bin/env ash

# Install required packages and upgrade the distro.

exec 1>&2
set -eux -o pipefail

service haveged stop ||:

apk --no-cache add bash curl ethtool gawk go grep iproute2 iptables iptables-openrc jq ruby sed tcpdump

rc-update add iptables default

touch /etc/iptables/rules-save

sync
