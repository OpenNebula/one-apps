#!/usr/bin/env bash

# Install required packages and upgrade the distro.

exec 1>&2
set -eux -o pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update -y

sync
