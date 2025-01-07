#!/usr/bin/env bash

# Clean APK caches, remove temporary/unneeded files/logs/packages.

exec 1>&2
set -eux -o pipefail

apk --no-cache del --rdepends go gcc musl-dev
rm -rf ~/go/

rm -rf /var/cache/apk/*

sync
