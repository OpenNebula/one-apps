#!/usr/bin/env bash

# Deregister from SUSE Customer Center.

exec 1>&2
set -eux -o pipefail

SUSEConnect -d
SUSEConnect --cleanup

sync
