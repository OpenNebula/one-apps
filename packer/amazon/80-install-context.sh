#!/usr/bin/env bash

# Downloads and installs the latest one-context package.

: "${CTXEXT:=el7.noarch.rpm}"

exec 1>&2
set -eux -o pipefail

LATEST=$(find /context/ -type f -name "one-context*.$CTXEXT" | sort -V | tail -n1)

yum install -y "$LATEST" open-vm-tools

sync
