#!/usr/bin/env bash

# Install required packages and upgrade the distro.

exec 1>&2
set -eux -o pipefail

service haveged stop ||:

apk --no-cache add bash podman

rc-update add podman boot
rc-service podman start

sync