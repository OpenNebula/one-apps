#!/usr/bin/env sh

exec 1>&2
set -o errexit -o nounset -o pipefail
set -x

service haveged stop ||:

apk update
apk --no-cache add bash

sync
