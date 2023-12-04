#!/usr/bin/env bash

# ---------------------------------------------------------------------------- #
# Copyright 2018-2020, OpenNebula Project, OpenNebula Systems                  #
#                                                                              #
# Licensed under the Apache License, Version 2.0 (the "License"); you may      #
# not use this file except in compliance with the License. You may obtain      #
# a copy of the License at                                                     #
#                                                                              #
# http://www.apache.org/licenses/LICENSE-2.0                                   #
#                                                                              #
# Unless required by applicable law or agreed to in writing, software          #
# distributed under the License is distributed on an "AS IS" BASIS,            #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.     #
# See the License for the specific language governing permissions and          #
# limitations under the License.                                               #
# ---------------------------------------------------------------------------- #


# shellcheck disable=SC1090
# shellcheck disable=SC2034
true

#
# keepalived transition
#

TYPE="$1"
NAME="$2"
TARGET_STATE="$3"
PRIORITY="$4"

#
# globals
#

# wait max two minutes for previous instance of this script to finish or abort
WAIT_ON_LOCK=120

# wait max five minutes for the service appliance script to finish  or abort
WAIT_ON_SERVICE_SCRIPT=300

# this is our status file where we signal our state
HA_FAILOVER_STATUSFILE='/run/keepalived/ha-failover.status'

# this is our extra logfile (along the syslog) to log our messages
HA_FAILOVER_LOGFILE='/var/log/ha-failover.log'


#
# functions
#

# TODO: change service script so it can be sourced and we don't duplicate stuff
# here...

ONE_SERVICE_DIR=/etc/one-appliance
ONE_SERVICE_SETUP_DIR="/opt/one-appliance"
ONE_SERVICE_CONTEXTFILE="${ONE_SERVICE_DIR}/context.json"
ONE_SERVICE_COMMON="${ONE_SERVICE_DIR}/service.d/common.sh"
ONE_SERVICE_APPLIANCE="${ONE_SERVICE_DIR}/service.d/appliance.sh"

# source service appliance scripts
. "$ONE_SERVICE_COMMON"
. "$ONE_SERVICE_APPLIANCE"

# args: <type> <message>
logmsg()
{
    _type="$1"
    shift

    msg "$_type" "${CMD}[$$]:" "$@" 2>&1 | \
        logger --stderr -t HA_KEEPALIVED 2>> "$HA_FAILOVER_LOGFILE"
}

started_transition_text()
{
    echo "${TARGET_STATE}: IN PROGRESS"
}

completed_transition_text()
{
    echo "${TARGET_STATE}: DONE"
}

aborted_transition_text()
{
    echo "${TARGET_STATE}: ABORTED"
}

failed_transition_text()
{
    echo "${TARGET_STATE}: FAILED"
}

on_exit()
{
    _status=$(cat "$HA_FAILOVER_STATUSFILE")

    if [ "$_status" != "$(completed_transition_text)" ] \
        && [ "$_status" != "$(aborted_transition_text)" ] \
        ;
    then
        failed_transition_text > "$HA_FAILOVER_STATUSFILE"
    fi
}


#
# locking
#

CMD=$(realpath "$0")

if [ "${_KEEPALIVED_HA_NOTIFY_SCRIPT}" != "$CMD" ] ; then
    logmsg info "Lock (args: $*) or wait (max ${WAIT_ON_LOCK} sec.)..."
    exec env _KEEPALIVED_HA_NOTIFY_SCRIPT="$CMD" \
        flock -x -w "$WAIT_ON_LOCK" "$CMD" "$CMD" "$@"
fi


#
# main
#

trap on_exit INT QUIT TERM EXIT

# TODO: find a better solution to avoid the dead-lock with the appliance script
logmsg info "Firstly wait for the service appliance to finish (max ${WAIT_ON_SERVICE_SCRIPT} sec.)..."

# check status file
_timeout="$WAIT_ON_SERVICE_SCRIPT"
while [ "$_timeout" -gt 0 ] ; do
    _status=$(cat '/etc/one-appliance/status' 2>/dev/null)

    case "$_status" in
        bootstrap_success)
            # we can continue
            break
            ;;
        *_failure)
            logmsg error "Service appliance failed - ABORT"
            exit 1
            ;;
        *)
            # we wait
            sleep 1
            _timeout=$((_timeout - 1))
            ;;
    esac
done

if [ "$_timeout" -eq 0 ] ; then
    logmsg error "Reached timeout waiting for service appliance - ABORT"
    exit 1
fi

# save the current keepalived status
CURRENT_KEEPALIVED_STATUS=$("${VNF_KEEPALIVED_HA_STATUS_SCRIPT}" | \
    awk '/^SYNC-GROUP[(]vrouter[)]/ {print $NF}')


# TODO:
# verify that our transition is not stale otherwise abort...
#
# sometimes keepalived triggers notify script with a stale state and we need to
# abort the processing in such a case due to this strange and undesirable
# situation - so the result in the status file of this script won't be DONE but
# FAILED...FYI
#
# Example:
#   Keepalived is in MASTER state but for some reason this script is started
#   with argument set as BACKUP...
#
#   This script is not a proper transition script - it is a notify script. That
#   means it will be started as a notification that keepalived's state has
#   changed and to signal which state it has now.
#
#   So it has no effect on the keepalived cluster per se - in contrast with
#   a proper transition script (not provided by keepalived AFAIK) which would
#   be responsible for transfer of the cluster from one state to another (e.g.:
#   BACKUP -> MASTER).
#
#   From this we can see that if keepalived is MASTER but this script receive
#   argument BACKUP then something shady is happenning...
#
# the reason for this is unknown as of this moment (to me) - it can be that
# keepalived does not guarantee the proper event queue - for that reason maybe
# the keepalived configuration should use 'notify_fifo' instead of 'notify'?
#
# Or simply...keepalived has a bug...
#
case "$CURRENT_KEEPALIVED_STATUS" in
    MASTER|BACKUP|FAULT|STOP)
        if [ "$TARGET_STATE" != "$CURRENT_KEEPALIVED_STATUS" ] ; then
            logmsg warning "Keepalived cluster is ahead (${CURRENT_KEEPALIVED_STATUS}) - this transition is stale (${TARGET_STATE}) - ABORT"
            aborted_transition_text > "$HA_FAILOVER_STATUSFILE"
            exit 0
        fi
        ;;
esac

logmsg info "Started VNF transition to the state: ${TARGET_STATE}"

started_transition_text > "$HA_FAILOVER_STATUSFILE"

# we build ENABLED/DISABLED lists of VNFs
load_context "$ONE_SERVICE_CONTEXTFILE"
sortout_vnfs

case "$TARGET_STATE" in
    MASTER)
        # (re)start requested VNFs/services except keepalived itself...
        _vnfs=$(for _vnf in $ENABLED_VNF_LIST ; do echo "$_vnf" ; done \
            | sed '/^KEEPALIVED$/d' | tr '\n' ' ')

        # what if keepalived was reconfigured and stopped?
        if is_running 'KEEPALIVED' ; then
            # everything seems to be ok - we continue as intended
            logmsg info "Restarting: ${_vnfs}"

            # reload/start services where it makes sense
            for _vnf in ${_vnfs} ; do
                if is_running "${_vnf}" ; then
                    reload_vnfs "$_vnf"
                else
                    start_vnfs "$_vnf"
                fi
            done
        else
            # keepalived is not running...
            _vnfs=$(for _vnf in $ALL_SUPPORTED_VNF_NAMES ; do echo "$_vnf" ; done \
                | sed '/^KEEPALIVED$/d' | tr '\n' ' ')

            logmsg warning "Keepalived process is not running anymore - ABORT"
            logmsg info " No keepalived process - stop and disable all VNFs: ${_vnfs}"
            stop_and_disable_vnfs "$_vnfs"
            exit 1
        fi
        ;;
    BACKUP|FAULT|STOP)
        # stop and disable all VNFs except keepalived itself...
        _vnfs=$(for _vnf in $ALL_SUPPORTED_VNF_NAMES ; do echo "$_vnf" ; done \
            | sed '/^KEEPALIVED$/d' | tr '\n' ' ')

        logmsg info "Requested BACKUP state - stop and disable all VNFs: ${_vnfs}"
        stop_and_disable_vnfs "$_vnfs"
        ;;
    *)
        logmsg error "Unknown keepalived state: ${TARGET_STATE}"
        exit 1
        ;;
esac

# signal the end of the transition
logmsg info "VNF transition completed: ${TARGET_STATE}"

completed_transition_text > "$HA_FAILOVER_STATUSFILE"

exit 0
