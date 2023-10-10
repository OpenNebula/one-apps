#!/usr/bin/env bash

# Downloads and installs the latest one-context package.

: "${CTX_SUFFIX:=.el8.noarch.rpm}"

exec 1>&2
set -o errexit -o nounset -o pipefail
set -x

if ! stat /context/one-context*$CTX_SUFFIX; then (
    install -d /context/ && cd /context/
    curl -fsSL https://api.github.com/repos/OpenNebula/addon-context-linux/releases \
    | jq -r ".[0].assets[].browser_download_url | select(endswith(\"$CTX_SUFFIX\"))" \
    | xargs -r -n1 curl -fsSLO
) fi

dnf install -y /context/one-context*$CTX_SUFFIX haveged open-vm-tools

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
