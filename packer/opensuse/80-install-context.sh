#!/usr/bin/env bash

# Download and install the latest one-context package.

: "${CTXEXT:=suse.noarch.rpm}"

exec 1>&2
set -eux -o pipefail

LATEST=$(find /context/ -type f -name "one-context*.$CTXEXT" | sort -V | tail -n1)

zypper --non-interactive --no-gpg-checks install -y "$LATEST" haveged

systemctl enable haveged

sync
