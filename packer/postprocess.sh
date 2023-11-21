#!/usr/bin/env bash
set -ex

timeout 5m virt-sysprep \
    --add ${OUTPUT_DIR}/${APPLIANCE_NAME} \
    --selinux-relabel \
    --root-password disabled \
    --hostname localhost.localdomain \
    --run-command 'truncate -s0 -c /etc/machine-id' \
    --delete /etc/resolv.conf

# virt-sparsify hang badly sometimes, when this happends
# kill + start again
timeout -s9 5m virt-sparsify --in-place ${OUTPUT_DIR}/${APPLIANCE_NAME}
