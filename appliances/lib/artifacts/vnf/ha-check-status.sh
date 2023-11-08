#!/bin/sh

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

set -e

WAITOUT=5 # seconds for status file to emerge

if [ -f /run/keepalived.pid ] ; then
    # delete old file if exists
    rm -f /tmp/keepalived.data

    # prompt keepalived to create status file
    pid=$(cat /run/keepalived.pid)
    if [ -n "$pid" ] && kill -0 "$pid" ; then
        kill -USR1 "$pid"
    else
        echo "KEEPALIVED: NOT RUNNING"
        exit 1
    fi

    while [ "$WAITOUT" -gt 0 ] ; do
        if [ -f /tmp/keepalived.data ] ; then
            break
        fi

        WAITOUT=$(( WAITOUT - 1 ))
        sleep 1s
    done

    if [ -f /tmp/keepalived.data ] ; then
        instances=$(awk '
        {
            if ($0 ~ /^[[:space:]]*VRRP Instance/) {
                instance = $(NF);
                state = "instance";
            } else if ($0 ~ /^[[:space:]]*VRRP Sync Group/) {
                group_name = $(NF-1);
                group_state = $(NF);
                gsub(/,/, "", group_name);
                gsub(/,/, "", state_state);
                vgroup[group_name] = group_state;
            } else if (state == "instance") {
                if ($1 == "State") {
                    if ($(NF) == "MASTER")
                        vrrp[instance] = "MASTER";
                    else
                        vrrp[instance] = "BACKUP";
                    state = "";
                }
            }
        }
        END {
            for (i in vrrp)
                printf("VRRP-INSTANCE(%s): %s\n", i, vrrp[i]);
            for (i in vgroup)
                printf("SYNC-GROUP(%s): %s\n", i, vgroup[i]);

            # workaround for changed behavior of Keepalived regarding the sync
            # groups which are ignored and removed if they contain only one
            # interface...
            if ((length(vrrp) == 1) && (length(vgroup) == 0)) {
                for (i in vrrp)
                    printf("SYNC-GROUP(vrouter): %s\n", vrrp[i]);
            }
        }
        ' < /tmp/keepalived.data)

        if [ -n "$instances" ] ; then
            # this means there is some vrrp instance
            echo "KEEPALIVED: RUNNING"
            echo "$instances"
        else
            # no vrrp instance - keepalived does nothing
            echo "KEEPALIVED: RUNNING IDLE (NO INSTANCE)"
        fi

        exit 0
    else
        # no data - timeouted...
        echo "KEEPALIVED: UNKNOWN (NO DATA)"
        exit 1
    fi
fi

exit 1
