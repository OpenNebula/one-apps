#!/usr/bin/env bash
set -ex

# avoid libvirt seclabel incompatibility (libguestfs 1.58 / libvirt >= 11)
export LIBGUESTFS_BACKEND=direct

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
