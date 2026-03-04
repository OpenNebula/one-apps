#!/usr/bin/env bash

# Configure critical settings for OpenSSH server.

exec 1>&2
set -eux -o pipefail

rm -f /etc/ssh/sshd_config.d/*-cloud-init.conf

sync
