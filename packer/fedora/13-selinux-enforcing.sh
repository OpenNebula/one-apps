#!/usr/bin/env bash

exec 1>&2
set -eux -o pipefail

sed -i -e 's:^SELINUX=.*:SELINUX=enforcing:' /etc/selinux/config
