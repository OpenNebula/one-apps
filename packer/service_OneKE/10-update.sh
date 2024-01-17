#!/usr/bin/env sh

# (Auto)Removes unneeded packages and upgrades the distro.

exec 1>&2
set -ex

export DEBIAN_FRONTEND=noninteractive

apt-get update -y

sync
