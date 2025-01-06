#!/usr/bin/env bash

# Clean APK caches, remove temporary/unneeded files/logs/packages.

exec 1>&2
set -eux -o pipefail

apk del cloud-init

rm -f /etc/motd

rm -rf /var/cache/apk/*

rm -rf /context/

sync
