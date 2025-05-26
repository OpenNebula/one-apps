#!/usr/bin/env bash

exec 1>&2
set -eux -o pipefail

sed -i -e 's:^SELINUX=.*:SELINUX=permissive:' /etc/selinux/config

fixfiles -F onboot

# Avoid  reboot vs. packer-ssh-reconnect race
systemctl stop sshd

reboot
