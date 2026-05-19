#!/usr/bin/env bash

# Install required packages and upgrade the distro.

# backup policy file if it exists
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
apt-get install -y curl gawk grep jq

# hwclock is required for KVM guest time sync (`virsh domtime --sync`)
# Since Debian 12 hwclock ships in util-linux-extra; on older releases it is part of util-linux
if apt-cache show util-linux-extra >/dev/null 2>&1; then
    apt-get install -y util-linux-extra
fi

policy_rc_d_enable

sync
