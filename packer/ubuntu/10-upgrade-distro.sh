#!/usr/bin/env bash

# Install required packages and upgrade the distro.

[[ -e /usr/sbin/policy-rc.d ]] && cp /usr/sbin/policy-rc.d /tmp/
policy_rc_d_disable() (echo "exit 101" >/usr/sbin/policy-rc.d && chmod a+x /usr/sbin/policy-rc.d)
policy_rc_d_enable()  (echo "exit 0"   >/usr/sbin/policy-rc.d && chmod a+x /usr/sbin/policy-rc.d)

exec 1>&2
set -eux -o pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update -y

policy_rc_d_disable

apt-get install -y --fix-broken

apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# Ensure packages needed for post-processing scripts do exist.
apt-get install -y curl gawk grep jq initramfs-tools

policy_rc_d_enable

sync
