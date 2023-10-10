#!/usr/bin/env bash

# Downloads and installs the latest one-context package.

: "${CTX_SUFFIX:=.el7.noarch.rpm}"

exec 1>&2
set -o errexit -o nounset -o pipefail
set -x

if ! stat /context/one-context*$CTX_SUFFIX; then (
    install -d /context/ && cd /context/
    curl -fsSL https://api.github.com/repos/OpenNebula/addon-context-linux/releases \
    | jq -r ".[0].assets[].browser_download_url | select(endswith(\"$CTX_SUFFIX\"))" \
    | xargs -r -n1 curl -fsSLO
) fi

yum install -y /context/one-context*$CTX_SUFFIX open-vm-tools

sync
