#!/usr/bin/env bash

# Install required packages and upgrade the distro.

[[ -e /usr/sbin/policy-rc.d ]] && cp /usr/sbin/policy-rc.d /tmp/
policy_rc_d_disable() (echo "exit 101" >/usr/sbin/policy-rc.d && chmod a+x /usr/sbin/policy-rc.d)
policy_rc_d_enable()  (echo "exit 0"   >/usr/sbin/policy-rc.d && chmod a+x /usr/sbin/policy-rc.d)

exec 1>&2
set -eux -o pipefail

export DEBIAN_FRONTEND=noninteractive

case "${DIST_VER}" in
    4) CODENAME=chimaera  ;;
    5) CODENAME=daedalus  ;;
    6) CODENAME=excalibur ;;
    *) echo "Unsupported DIST_VER=${DIST_VER}" >&2; exit 1 ;;
esac

sed -i '/^deb cdrom/d' /etc/apt/sources.list
echo "deb http://deb.devuan.org/merged ${CODENAME}          main" >> /etc/apt/sources.list
echo "deb http://deb.devuan.org/merged ${CODENAME}-updates  main" >> /etc/apt/sources.list
echo "deb http://deb.devuan.org/merged ${CODENAME}-security main" >> /etc/apt/sources.list

apt-get update -y

policy_rc_d_disable

debconf-set-selections <<< 'grub-pc grub-pc/install_devices multiselect /dev/sda'

apt-get install -y --fix-broken

apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# Ensure packages needed for post-processing scripts do exist.
apt-get install -y curl gawk grep jq

# hwclock is required for KVM guest time sync (`virsh domtime --sync`)
if apt-cache show util-linux-extra >/dev/null 2>&1; then
    apt-get install -y util-linux-extra
fi

policy_rc_d_enable

ln -sf /usr/share/zoneinfo/UTC /etc/localtime

sync
