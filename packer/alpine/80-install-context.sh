#!/usr/bin/env ash

# Download and install the latest *official* one-context package.

: "${CTXEXT:=apk}"

exec 1>&2
set -eux -o pipefail

apk add tzdata haveged

# Alpine 3.22+ needs ruby-base64 (separate package), use alpine322 variant
if [ "${DIST_VER}" -ge 322 ] 2>/dev/null; then
    LATEST=$(find /context/ -type f -name "one-context*.alpine322.$CTXEXT" | sort -V | tail -n1)
else
    LATEST=$(find /context/ -type f -name "one-context*.$CTXEXT" ! -name "*.alpine322.*" | sort -V | tail -n1)
fi

apk add --allow-untrusted "$LATEST"

rc-update add qemu-guest-agent default
rc-update add haveged boot

sync
