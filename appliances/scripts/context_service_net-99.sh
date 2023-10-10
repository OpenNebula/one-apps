#!/usr/bin/env bash

ENV_FILE=${ENV_FILE:-/var/run/one-context/one_env}

if [ "$REPORT_READY" != "YES" ]; then
    exit 0
fi

# $TOKENTXT is available only through the env. file
if [ -f "${ENV_FILE}" ]; then
    . "${ENV_FILE}"
fi

# Reports only if ONE service appliance bootstrapped successfully
if [ -x '/etc/one-appliance/service' ]; then
    _status=$(cat '/etc/one-appliance/status' 2>/dev/null)
    if [ "${_status}" != 'bootstrap_success' ]; then
        exit 0
    fi
fi

###

if which onegate >/dev/null 2>&1; then
    onegate vm update --data "READY=YES"

    if [ "$?" = "0" ]; then
        exit 0
    fi
fi

if which curl >/dev/null 2>&1; then
    curl -X "PUT" "${ONEGATE_ENDPOINT}/vm" \
        --header "X-ONEGATE-TOKEN: $TOKENTXT" \
        --header "X-ONEGATE-VMID: $VMID" \
        -d "READY=YES"

    if [ "$?" = "0" ]; then
        exit 0
    fi
fi

if which wget >/dev/null 2>&1; then
    wget --method=PUT "${ONEGATE_ENDPOINT}/vm" \
        --body-data="READY=YES" \
        --header "X-ONEGATE-TOKEN: $TOKENTXT" \
        --header "X-ONEGATE-VMID: $VMID"

    if [ "$?" = "0" ]; then
        exit 0
    fi
fi
