#!/usr/bin/env bash

# Configures and enables service context.

policy_rc_d_disable() (echo "exit 101" >/usr/sbin/policy-rc.d && chmod a+x /usr/sbin/policy-rc.d)
policy_rc_d_enable()  (echo "exit 0"   >/usr/sbin/policy-rc.d && chmod a+x /usr/sbin/policy-rc.d)

exec 1>&2
set -o errexit -o nounset -o pipefail
set -x

policy_rc_d_disable

apt-get install -y apparmor tzdata

mv /etc/one-appliance/net-90 /etc/one-context.d/net-90-service-appliance
mv /etc/one-appliance/net-99 /etc/one-context.d/net-99-report-ready

chown root:root /etc/one-context.d/*
chmod u=rwx,go=rx /etc/one-context.d/*

policy_rc_d_enable

sync
