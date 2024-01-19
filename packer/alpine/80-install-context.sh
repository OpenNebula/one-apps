#!/usr/bin/env ash

# Download and install the latest *official* one-context package.

: "${CTXEXT:=apk}"

exec 1>&2
set -eux -o pipefail

apk add tzdata haveged open-vm-tools-plugins-all

LATEST=$(find /context/ -type f -name "one-context*.$CTXEXT" | sort -V | tail -n1)

apk add --allow-untrusted "$LATEST"

rc-update add qemu-guest-agent default
rc-update add open-vm-tools default
rc-update add haveged boot

sync
