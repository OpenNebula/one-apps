#!/usr/bin/env bash

# Download and install the latest one-context package.

: "${CTXEXT:=deb}"

policy_rc_d_disable() (echo "exit 101" >/usr/sbin/policy-rc.d && chmod a+x /usr/sbin/policy-rc.d)
policy_rc_d_enable()  (echo "exit 0"   >/usr/sbin/policy-rc.d && chmod a+x /usr/sbin/policy-rc.d)

exec 1>&2
set -eux -o pipefail

export DEBIAN_FRONTEND=noninteractive

LATEST=$(find /context/ -type f -name "one-context*.$CTXEXT" | sort -V | tail -n1)

policy_rc_d_disable

dpkg -i "$LATEST" || apt-get install -y -f
dpkg -i "$LATEST"

policy_rc_d_enable

sync
