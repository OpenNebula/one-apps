#!/usr/bin/env bash

# Downloads and installs the latest one-context package.

: "${CTXEXT:=amzn${DIST_VER}.noarch.rpm}"

exec 1>&2
set -eux -o pipefail

LATEST=$(find /context/ -type f -name "one-context*.$CTXEXT" | sort -V | tail -n1)

yum install -y "$LATEST"


if [ "$DIST_VER" = "2023" ]; then
    # WARN: As Amazon2 only supports ifcfg scripts and we don't want to keep 2 different
    # netcfg types for Amazon 2 and 2023, up until we discontinue Amazon2 we will also
    # keep ifcfg script for Amazon2023.
    # TODO: Once Amazon2 is discontinued/eol switch to networkd
    systemctl disable systemd-networkd
    systemctl enable network
fi

sync
