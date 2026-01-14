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

# Check for inconsistent state before starting Fabric Manager
if [ -s "${ONE_STATE_FILE}" ] && [ ! -f "${FM_STATE_FILE}" ]; then
    # --- Hard Recovery ---
    log "WARNING: Inconsistent state detected. Starting hard recovery process."

    # 1. Create backup
    BACKUP_FILE="${ONE_STATE_FILE}.failed-$(date +%Y%m%d-%H%M%S)"
    log "INFO: Backing up current partition state to ${BACKUP_FILE}"
    mv "${ONE_STATE_FILE}" "${BACKUP_FILE}"

    # 2. Start FM in normal mode
    log "INFO: Starting Fabric Manager in normal mode for recovery."
    /usr/bin/nv-fabricmanager &
    FM_PID=$!
    log "INFO: Fabric Manager daemon started with PID ${FM_PID}."
    log "INFO: Waiting for 5 seconds for the daemon to initialize..."
    sleep 5

    # 3. Read partitions from backup and activate one-by-one
    log "INFO: Attempting to reactivate partitions from ${BACKUP_FILE}"
    while read -r PARTITION_ID; do
        # Skip empty
        if [ -z "$PARTITION_ID" ]; then continue; fi

        log "INFO: Attempting to activate partition ID: ${PARTITION_ID}"
        if "${PARTITIONER_TOOL}" -o 1 -p "${PARTITION_ID}"; then
            log "SUCCESS: Partition ${PARTITION_ID} activated."
        else
            log "ERROR: Failed to activate partition ${PARTITION_ID}. Check logs for details."
        fi
    done < "${BACKUP_FILE}"

    # 4. Final Summary
    log "INFO: Hard recovery process finished. Validating final state..."

    # Ensure the new state file exists
    if [ ! -f "${ONE_STATE_FILE}" ]; then
        touch "${ONE_STATE_FILE}"
    fi

    # compare files
    SORTED_BACKUP=$(mktemp)
    SORTED_CURRENT=$(mktemp)
    sort "${BACKUP_FILE}" > "${SORTED_BACKUP}"
    sort "${ONE_STATE_FILE}" > "${SORTED_CURRENT}"
    if diff -q "${SORTED_BACKUP}" "${SORTED_CURRENT}" >/dev/null; then
        log "SUCCESS: Hard recovery complete. All partitions were successfully restored."
    else
        log "CRITICAL: Hard recovery was PARTIAL. Not all partitions could be restored."
        log "CRITICAL: The following differences were found between the desired state (left) and the recovered state (right):"
        diff "${SORTED_BACKUP}" "${SORTED_CURRENT}" | logger -t "${LOG_TAG}" --
    fi

    rm -f "${SORTED_BACKUP}" "${SORTED_CURRENT}"

else
    # --- Normal/Resilient Boot ---
    log "INFO: Consistent state detected. Proceeding with normal or restart boot."

    RESTART_MODE=false

    # 1. Decide which mode to start the Fabric Manager based on the saved decision
    if [ -f "${FM_STATE_FILE}" ] && [ -s "${ONE_STATE_FILE}" ]; then
        log "State file found. Starting Fabric Manager in --restart mode."
        RESTART_MODE=true
        /usr/bin/nv-fabricmanager --restart &
    else
        log "No state file found. Starting Fabric Manager in normal mode."
        /usr/bin/nv-fabricmanager &
    fi

    FM_PID=$!
    log "Fabric Manager daemon started with PID ${FM_PID}."

    # 2. Wait for the daemon to be ready
    log "Waiting for 5 seconds for the daemon to initialize..."
    sleep 5

    # 3. Perform partition restoration based on the SAVED start-up decision
    if [ "${RESTART_MODE}" = true ]; then
        if [ -x "${PARTITIONER_TOOL}" ]; then
            log "Executing atomic partition restore operation..."
            if ! "${PARTITIONER_TOOL}" -o 3; then
                log "WARNING: Partition restore command failed. Check fabricmanager logs."
            else
                log "Partition restore operation completed."
            fi
        else
            log "WARNING: Partitioner tool not found at ${PARTITIONER_TOOL}. Skipping restore."
        fi
    else
        log "INFO: Started in normal mode, skipping partition restore operation."
    fi
fi

# 4. Wait for the Fabric Manager daemon to exit.
log "Boot manager script is now waiting for the daemon to exit."
wait "${FM_PID}"

exit $?
