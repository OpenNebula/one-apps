#!/usr/bin/env bash

exec 1>&2
set -eux -o pipefail

subscription-manager remove --all
subscription-manager unregister
subscription-manager clean

sync
