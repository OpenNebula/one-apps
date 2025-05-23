#!/usr/bin/env bash

# Configure and enable service context.

[[ -e /usr/sbin/policy-rc.d ]] && cp /usr/sbin/policy-rc.d /tmp/
policy_rc_d_disable() (echo "exit 101" >/usr/sbin/policy-rc.d && chmod a+x /usr/sbin/policy-rc.d)
policy_rc_d_enable()  (echo "exit 0"   >/usr/sbin/policy-rc.d && chmod a+x /usr/sbin/policy-rc.d)

exec 1>&2
set -eux -o pipefail

export DEBIAN_FRONTEND=noninteractive

policy_rc_d_disable

apt-get install -y apparmor tzdata

mv /etc/one-appliance/net-90-service-appliance /etc/one-context.d/
mv /etc/one-appliance/net-99-report-ready      /etc/one-context.d/

chown root:root /etc/one-context.d/*
chmod u=rwx,go=rx /etc/one-context.d/*

policy_rc_d_enable

if [[ -e /tmp/policy-rc.d ]]; then
    # restore vanilla policy if it has been backed up
    cp /tmp/policy-rc.d /usr/sbin/
else
    # remove temporary policy if no policy was present initially
    rm /usr/sbin/policy-rc.d
fi

sync
