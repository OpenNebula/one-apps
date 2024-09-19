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
import { createIntercept, Intercepts } from '@support/utils'

const FORCE = { force: true }

/**
 * Validate snapshot action.
 *
 * @param {VirtualMachine} vm - VM
 */
const validateVmSnapshots = (vm) => {
  const { SNAPSHOT } = vm.json.TEMPLATE || {}
  const ensuredSnapshots = Array.isArray(SNAPSHOT) ? SNAPSHOT : [SNAPSHOT]
  if (ensuredSnapshots.filter(Boolean).length === 0) return

  cy.clickVmRow(vm)

  cy.navigateTab('snapshot').within(() => {
    ensuredSnapshots.forEach((snapshot) => {
      cy.getBySel('snapshot-id').contains(snapshot.SNAPSHOT_ID)
      cy.getBySel('snapshot-name').contains(snapshot.NAME)
    })
  })
}

/**
 * Reverts a VM snapshot.
 *
 * @param {VirtualMachine} vm - VM
 * @param {string} snapshotName - Snapshot name
 * @returns {Cypress.Chainable<Cypress.Response>} Revert snapshot response
 */
const revertVmSnapshot = (vm, snapshotName) => {
  const revertSnapshot = createIntercept(Intercepts.SUNSTONE.VM_SNAPSHOT_REVERT)

  cy.clickVmRow(vm)

  cy.navigateTab('snapshot').within(() => {
    cy.getBySel('snapshot-name')
      .contains(snapshotName)
      // `snapshot-<id>` is the selector for the container of the snapshot
      .closest('[data-cy*=snapshots] > [data-cy*=snapshot-]')
      .find('button[data-cy*=snapshot-revert]')
      .click()
  })

  cy.getBySel('modal-revert-snapshot').within(() => {
    cy.getBySel('dg-accept-button').click(FORCE)
  })

  return cy.wait(revertSnapshot)
}

/**
 * Deletes a VM snapshot.
 *
 * @param {VirtualMachine} vm - VM
 * @param {string} snapshotName - Snapshot name
 * @returns {Cypress.Chainable<Cypress.Response>} Delete snapshot response
 */
const deleteVmSnapshot = (vm, snapshotName) => {
  const deleteSnapshot = createIntercept(Intercepts.SUNSTONE.VM_SNAPSHOT_DELETE)

  cy.clickVmRow(vm)

  cy.navigateTab('snapshot').within(() => {
    cy.getBySel('snapshot-name')
      .contains(snapshotName)
      // `snapshot-<id>` is the selector for the container of the snapshot
      .closest('[data-cy*=snapshots] > [data-cy*=snapshot-]')
      .find('button[data-cy*=snapshot_delete]')
      .click()
  })

  cy.getBySel('modal-delete-snapshot').within(() => {
    cy.getBySel('dg-accept-button').click(FORCE)
  })

  return cy.wait(deleteSnapshot)
}

/**
 * Takes VM snapshot.
 *
 * @param {VirtualMachine} vm - VM
 * @param {string} snapshotName - Snapshot name
 * @returns {Cypress.Chainable<Cypress.Response>} New snapshot response
 */
const takeVmSnapshot = (vm, snapshotName) => {
  const getVmSnapshot = createIntercept(Intercepts.SUNSTONE.VM_SNAPSHOT_CREATE)

  cy.clickVmRow(vm)

  cy.navigateTab('snapshot').within(() => {
    cy.getBySel('snapshot-create').click(FORCE)
  })

  cy.getBySel('modal-create-snapshot').within(() => {
    cy.getBySel('form-dg-name').clear(FORCE).type(snapshotName)
    cy.getBySel('dg-accept-button').click(FORCE)
  })

  return cy.wait(getVmSnapshot)
}

Cypress.Commands.add('validateVmSnapshots', validateVmSnapshots)
Cypress.Commands.add('deleteVmSnapshot', deleteVmSnapshot)
Cypress.Commands.add('revertVmSnapshot', revertVmSnapshot)
Cypress.Commands.add('takeVmSnapshot', takeVmSnapshot)
