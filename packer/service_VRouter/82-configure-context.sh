#!/usr/bin/env bash

# Configure and enable service context.

exec 1>&2
set -eux -o pipefail

printf '#!/bin/sh\n\ntrue\n' > /etc/one-context.d/loc-12-firewall
printf '#!/bin/sh\n\ntrue\n' > /etc/one-context.d/loc-15-ip_forward
printf '#!/bin/sh\n\ntrue\n' > /etc/one-context.d/loc-15-keepalived

mv /etc/one-appliance/net-90 /etc/one-context.d/net-90-service-appliance
mv /etc/one-appliance/net-99 /etc/one-context.d/net-99-report-ready

chown root:root /etc/one-context.d/*
chmod u=rwx,go=rx /etc/one-context.d/*

sync
