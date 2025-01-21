#!/usr/bin/env bash

# Clean APK caches, remove temporary/unneeded files/logs/packages.

exec 1>&2
set -eux -o pipefail

apk del cloud-init
find /etc/runlevels/ -name 'cloud-init*' -delete

# chrony sometimes takes too long to start also delaying sshd
service chronyd stop
apk del chrony
userdel chrony

rm -f /etc/motd

rm -rf /var/cache/apk/*

rm -rf /context/

sync
