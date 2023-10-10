#!/usr/bin/env bash

timeout 5m virt-sysprep \
    --add ${OUTPUT_DIR}/${APPLIANCE_NAME} \
    --selinux-relabel \
    --root-password disabled \
    --hostname localhost.localdomain \
    --run-command 'truncate -s0 -c /etc/machine-id' \
    --delete /etc/resolv.conf

# virt-sparsify was haning sometimes
for I in 1 2 3; do
    timeout 5m virt-sparsify \
        --in-place ${OUTPUT_DIR}/${APPLIANCE_NAME} && break
done
