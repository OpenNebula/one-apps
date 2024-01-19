#!/usr/bin/env bash

# Clean APK caches, remove temporary/unneeded files/logs/packages.

exec 1>&2
set -eux -o pipefail

rm -f /etc/motd

rm -rf /var/cache/apk/*

rm -rf /context/

sync
