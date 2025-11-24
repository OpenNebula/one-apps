#!/bin/bash
# ---------------------------------------------------------------------------- #
# Copyright 2024, OpenNebula Project, OpenNebula Systems                       #
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

#
# Script that manages the startup and state restoration of nvidia-fabricmanager
#

set -o errexit -o pipefail

FM_STATE_FILE="/var/lib/nvidia-fabricmanager/fabricmanager.state"
ONE_STATE_FILE="/var/lib/nvidia-fabricmanager/active_partitions.state"
PARTITIONER_TOOL="/usr/local/sbin/nv-partitioner"
LOG_TAG="one-fm-boot-manager"

log() {
    echo "$@" >&2
    logger -t "${LOG_TAG}" -- "$@"
}

log "Starting NVIDIA Fabric Manager boot manager..."

# Handle the case where one state file exists, but NVIDIA's does not.
# This is an inconsistent state. We back up our file and start fresh.
if [ -s "${ONE_STATE_FILE}" ] && [ ! -f "${FM_STATE_FILE}" ]; then
    BACKUP_FILE="${ONE_STATE_FILE}.failed-$(date +%Y%m%d-%H%M%S)"
    log "WARNING: Inconsistent state detected. NVIDIA's state file is missing, but OpenNebula's partition state file exists."
    log "WARNING: Backing up current partition state to ${BACKUP_FILE}"
    mv "${ONE_STATE_FILE}" "${BACKUP_FILE}"
    log "WARNING: Proceeding with a fresh start. No partitions will be restored."
fi

# 1. Decide which mode to start the Fabric Manager
if [ -f "${FM_STATE_FILE}" ]; then
    log "State file found. Starting Fabric Manager in --restart mode."
    /usr/bin/nv-fabricmanager --restart &
else
    log "No state file found. Starting Fabric Manager in normal mode."
    /usr/bin/nv-fabricmanager &
fi

# Capture the PID of the last background process
FM_PID=$!
log "Fabric Manager daemon started with PID ${FM_PID}."

# 2. Wait for the daemon to be ready
log "Waiting for 5 seconds for the daemon to initialize..."
sleep 5

# 3. Perform the partition state restoration.
# ONLY attempt restore if we started in restart mode (i.e., FM_STATE_FILE existed)
if [ -f "${FM_STATE_FILE}" ]; then
    if [ -x "${PARTITIONER_TOOL}" ]; then
        log "Executing partition restore operation..."
        if ! "${PARTITIONER_TOOL}" -o 3; then
            log "WARNING: Partition restore command failed. Check fabricmanager logs."
        else
            log "Partition restore operation completed."
        fi
    else
        log "WARNING: Partitioner tool not found at ${PARTITIONER_TOOL}. Skipping restore."
    fi
else
    log "INFO: Started in normal mode (FM state file missing), skipping partition restore operation."
fi

# 4. Wait for the Fabric Manager daemon to exit.
log "Boot manager script is now waiting for the daemon to exit."
wait "${FM_PID}"

exit $?
