#!/usr/bin/env bash

# Install the UEK kernel modules package which provides virtiofs
exec 1>&2
set -eux -o pipefail

dnf install -y kernel-uek-modules

sync
