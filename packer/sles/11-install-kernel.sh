#!/usr/bin/env bash

# Install the full default kernel which provides virtiofs, openvswitch and kvm modules.

exec 1>&2
set -eux -o pipefail

zypper --non-interactive install --force-resolution -y kernel-default

sync
