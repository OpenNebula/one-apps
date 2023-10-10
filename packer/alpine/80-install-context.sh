#!/usr/bin/env bash

# Downloads and installs the latest one-context package.

exec 1>&2
set -o errexit -o nounset -o pipefail
set -x

: "${CTX_SUFFIX:=.apk}"

set -o errexit -o nounset -o pipefail
set -x

if ! stat /context/one-context*$CTX_SUFFIX; then (
    install -d /context/ && cd /context/
    curl -fsSL https://api.github.com/repos/OpenNebula/addon-context-linux/releases \
    | jq -r ".[0].assets[].browser_download_url | select(endswith(\"$CTX_SUFFIX\"))" \
    | xargs -r -n1 curl -fsSLO
) fi

apk --no-cache add tzdata haveged open-vm-tools-plugins-all
apk --no-cache add --allow-untrusted /context/one-context*$CTX_SUFFIX

rc-update add qemu-guest-agent default
rc-update add open-vm-tools default
rc-update add haveged boot

sync
