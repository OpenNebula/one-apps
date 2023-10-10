#!/bin/sh

set -ex

# upgrade system
env PAGER=cat freebsd-update fetch --not-running-from-cron || :
freebsd-update install --not-running-from-cron || :

# contextualize
export ASSUME_ALWAYS_YES=yes
pkg install -y curl bash sudo base64 ruby open-vm-tools-nox11 gawk virt-what isc-dhcp44-client
pkg install -y /tmp/context/one-context-[0-9]*.txz
pkg clean -ay

# reconfigure SSH server
sed -i '' -e '/^[[:space:]]*PasswordAuthentication[[:space:]]/d' /etc/ssh/sshd_config
sed -i '' -e '/^[[:space:]]*ChallengeResponseAuthentication[[:space:]]/d' /etc/ssh/sshd_config
sed -i '' -e '/^[[:space:]]*PermitRootLogin[[:space:]]/d' /etc/ssh/sshd_config
sed -i '' -e '/^[[:space:]]*UseDNS[[:space:]]/d' /etc/ssh/sshd_config

echo 'PasswordAuthentication no' >>/etc/ssh/sshd_config
echo 'ChallengeResponseAuthentication no' >>/etc/ssh/sshd_config
echo 'PermitRootLogin without-password' >>/etc/ssh/sshd_config
echo 'UseDNS no' >>/etc/ssh/sshd_config

sysrc -f /boot/loader.conf autoboot_delay=3 beastie_disable=YES
sysrc sendmail_enable="NONE"
sysrc syslogd_flags="-ss"

# Reconfigure for custom DHCP wrapper script
if [ -x /usr/sbin/one-dual-dhclient ]; then
    sysrc dhclient_program="/usr/sbin/one-dual-dhclient"
fi

# VMware
sysrc vmware_guest_kmod_enable=="YES"
sysrc vmware_guestd_enable="YES"

pw user mod root -w no

# cleanups
rm -rf /var/db/freebsd-update/*
rm -rf /var/db/pkg/repo-FreeBSD.sqlite
rm -rf /etc/ssh/ssh_host_*
rm -rf /tmp/context
[ -s /etc/machine-id ] && rm -f /etc/machine-id || true

# zero free space
# dd if=/dev/zero of=/.zero bs=1m || :
# rm -rf /.zero
