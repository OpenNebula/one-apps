/* ------------------------------------------------------------------------- *
 * Copyright 2002-2023, OpenNebula Project, OpenNebula Systems               *
 *                                                                           *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may   *
 * not use this file except in compliance with the License. You may obtain   *
 * a copy of the License at                                                  *
 *                                                                           *
 * http://www.apache.org/licenses/LICENSE-2.0                                *
 *                                                                           *
 * Unless required by applicable law or agreed to in writing, software       *
 * distributed under the License is distributed on an "AS IS" BASIS,         *
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  *
 * See the License for the specific language governing permissions and       *
 * limitations under the License.                                            *
 * ------------------------------------------------------------------------- */

import { VirtualMachine } from '@models'

const HISTORY_ACTIONS = [
  'none',
  'migrate',
  'live-migrate',
  'shutdown',
  'shutdown-hard',
  'undeploy',
  'undeploy-hard',
  'hold',
  'release',
  'stop',
  'suspend',
  'resume',
  'boot',
  'delete',
  'delete-recreate',
  'reboot',
  'reboot-hard',
  'resched',
  'unresched',
  'poweroff',
  'poweroff-hard',
  'disk-attach',
  'disk-detach',
  'nic-attach',
  'nic-detach',
  'disk-snapshot-create',
  'disk-snapshot-delete',
  'terminate',
  'terminate-hard',
  'disk-resize',
  'deploy',
  'chown',
  'chmod',
  'updateconf',
  'rename',
  'resize',
  'update',
  'snapshot-resize',
  'snapshot-delete',
  'snapshot-revert',
  'disk-saveas',
  'disk-snapshot-revert',
  'recover',
  'retry',
  'monitor',
  'disk-snapshot-rename',
  'alias-attach',
  'alias-detach',
  'poweroff-migrate',
  'poweroff-hard-migrate',
]

const getActionName = (action) => HISTORY_ACTIONS[parseInt(action, 10)]

/**
 * Validate history action.
 *
 * @param {VirtualMachine} vm - VM
 */
const validateVmHistory = (vm) => {
  const { HISTORY } = vm.json.HISTORY_RECORDS || {}
  const ensuredHistory = Array.isArray(HISTORY) ? HISTORY : [HISTORY]

  if (ensuredHistory.length === 0) return

  cy.clickVmRow(vm)

  cy.navigateTab('history').within(() => {
    ensuredHistory.forEach(({ SEQ, HOSTNAME, ACTION } = {}) => {
      cy.getBySel(`record-${SEQ}`).within(() => {
        cy.getBySel('record-data').contains(`#${SEQ}`)
        cy.getBySel('record-data').contains(HOSTNAME)
        cy.getBySel('record-data').contains(getActionName(ACTION))
      })
    })
  })
}

Cypress.Commands.add('validateVmHistory', validateVmHistory)
