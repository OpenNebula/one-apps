#!/usr/bin/env bash
# Runs OpenNebula service appliances configuration & bootstrap script

#TODO: just single run based on "status"
_oneapp_service='/etc/one-appliance/service'

# one-context 6.2.0+ shifts the command argument
if [ $# -eq 2 ]; then
    _reconfigure="$2"
else
    _reconfigure="$1"
fi

if [ -x "${_oneapp_service}" ]; then
    "${_oneapp_service}" configure "$_reconfigure" && \
        "${_oneapp_service}" bootstrap
fi
