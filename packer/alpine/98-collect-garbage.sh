#!/usr/bin/env bash

# Cleans APK caches, removes temporary files / logs,
# removes leftover / temporary unneeded packages.

exec 1>&2
set -o errexit -o nounset -o pipefail
set -x

rm -f /etc/motd

rm -rf /var/cache/apk/*
rm -rf /context/

sync
