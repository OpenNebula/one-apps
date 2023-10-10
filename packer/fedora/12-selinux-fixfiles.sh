#!/usr/bin/env bash

sed -i -e 's:^SELINUX=.*:SELINUX=permissive:' /etc/selinux/config
fixfiles -F onboot
reboot
