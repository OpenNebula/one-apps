#!/usr/bin/env bash

# Configures and enables service context.

exec 1>&2
set -o errexit -o nounset -o pipefail
set -x

mv /etc/one-appliance/net-90 /etc/one-context.d/net-90-service-appliance
mv /etc/one-appliance/net-99 /etc/one-context.d/net-99-report-ready

chown root:root /etc/one-context.d/*
chmod u=rwx,go=rx /etc/one-context.d/*

sync
