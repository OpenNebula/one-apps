#!/usr/bin/env bash

# Download and install the latest one-context package.

: "${CTXEXT:=fc.noarch.rpm}"

exec 1>&2
set -eux -o pipefail

LATEST=$(find /context/ -type f -name "one-context*.$CTXEXT" | sort -V | tail -n1)

dnf install -y "$LATEST" haveged open-vm-tools

systemctl enable haveged

if ! rpm -q --queryformat '%{VERSION}' one-context | grep -E '^([1-5]\.|6\.0\.)'; then
# >>> Apply only on one-context >= 6.1 >>>
    dnf install -y --setopt=install_weak_deps=False NetworkManager systemd-networkd

    systemctl enable systemd-networkd

    # This is a workaround for systemd-networkd-wait-online timeout when networkd not used.
    # Although this effectively breaks reaching network.target correctly, it is still better
    # not to slowdown the boot by (120s) timeout as networkd is rather marginal in RHEL.
    systemctl disable systemd-networkd-wait-online

# <<< Apply only on one-context >= 6.1 <<<
else
    systemctl enable network
fi

sync
