#!/usr/bin/env bash

# Download and install the latest one-context package.

: "${CTXEXT:=deb}"

policy_rc_d_disable() (echo "exit 101" >/usr/sbin/policy-rc.d && chmod a+x /usr/sbin/policy-rc.d)
policy_rc_d_enable()  (echo "exit 0"   >/usr/sbin/policy-rc.d && chmod a+x /usr/sbin/policy-rc.d)

exec 1>&2
set -eux -o pipefail

export DEBIAN_FRONTEND=noninteractive

ls -lha /context/

LATEST=$(find /context/ -type f -name "one-context*.$CTXEXT" | sort -V | tail -n1)

policy_rc_d_disable

dpkg -i --auto-deconfigure "$LATEST" || apt-get install -y -f
dpkg -i --auto-deconfigure "$LATEST"

apt-get install -y haveged

systemctl enable haveged

# >>> Apply only on one-context >= 6.1 >>>
if ! dpkg-query -W --showformat '${Version}' one-context | grep -E '^([1-5]\.|6\.0\.)'; then
    apt-get install -y --no-install-recommends --no-install-suggests netplan.io network-manager
fi
# <<< Apply only on one-context >= 6.1 <<<

policy_rc_d_enable

sync
