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

import { FORCE } from '@support/commands/constants'
import { fillVmGroupGUI } from '@support/commands/vmgroup/create'
import { VmGroup as VmGroupDocs } from '@support/commands/vmgroup/jsdocs'
import { Intercepts, createIntercept } from '@support/utils'
const { VmGroup } = require('@models')

/**
 * Deletes a vmgroup.
 *
 */
const deleteVmGroup = () => {
  const interceptDelete = createIntercept(Intercepts.SUNSTONE.VMGROUP_DELETE)

  cy.getBySel('action-vmgroup_delete').click(FORCE)

  cy.getBySel(`modal-delete`)
    .should('exist')
    .then(($dialog) => {
      cy.wrap($dialog).find(`[data-cy=dg-accept-button]`).click(FORCE)

      return cy
        .wait(interceptDelete)
        .its('response.statusCode')
        .should('eq', 200)
    })
}

/**
 * Locks/Disables a vmgroup.
 *
 * @param {VmGroupDocs} [vmgroup={}] - The vmgroup to lock
 * @returns {void} - No return value
 */
const lockVmGroup = (vmgroup = {}) => {
  const interceptLock = createIntercept(Intercepts.SUNSTONE.VMGROUP_LOCK)

  cy.getBySel('action-vmgroup_disable')
    .click(FORCE)
    .then(() => {
      validateVmGroupInfo({
        id: vmgroup.json.ID,
        name: vmgroup.json.NAME,
        state: 'Yes',
      })
    })

  return cy.wait(interceptLock).its('response.statusCode').should('eq', 200)
}

/**
 * Unlocks/Enables a vmgroup.
 *
 * @param {VmGroupDocs} [vmgroup={}] - The vmgroup to unlock
 * @returns {void} - No return value
 */
const unlockVmGroup = (vmgroup = {}) => {
  const interceptUnlock = createIntercept(Intercepts.SUNSTONE.VMGROUP_UNLOCK)

  cy.getBySel('action-vmgroup_enable')
    .click(FORCE)
    .then(() => {
      validateVmGroupInfo({
        id: vmgroup.json.ID,
        name: vmgroup.json.NAME,
        state: 'No',
      })
    })

  return cy.wait(interceptUnlock).its('response.statusCode').should('eq', 200)
}

/**
 * Creates a new vmgroup via GUI.
 *
 * @param {VmGroup} vmgroup - The vmgroup to create
 * @returns {void} - No return value
 */
const vmgroupGUI = (vmgroup) => {
  const interceptVmGroupAllocate = createIntercept(
    Intercepts.SUNSTONE.VMGROUP_CREATE
  )

  cy.getBySel('action-create_dialog').click()
  fillVmGroupGUI(vmgroup)
  cy.getBySel('stepper-next-button').click(FORCE)

  return cy
    .wait(interceptVmGroupAllocate)
    .its('response.statusCode')
    .should('eq', 200)
}

/**
 * Updates a vmgroup via GUI.
 *
 * @param {VmGroup} vmgroup - The vmgroup to update
 * @returns {void} - No return value
 */
const vmgroupUpdate = (vmgroup) => {
  const { DISABLED_NAME, START_INDEX } = vmgroup
  const { VmGrp, TEMPLATE } = vmgroup
  const interceptVmGroupUpdate = createIntercept(
    Intercepts.SUNSTONE.VMGROUP_UPDATE
  )

  cy.clickVmGroupRow({ id: VmGrp.id })
  cy.getBySel('action-update_dialog').click()
  fillVmGroupGUI(TEMPLATE, { DISABLED_NAME, START_INDEX })
  cy.getBySel('stepper-next-button').click(FORCE)

  return cy
    .wait(interceptVmGroupUpdate)
    .its('response.statusCode')
    .should('eq', 200)
}
/**
 * Validates the information tab of a vmgroup.
 *
 * @param {object} params - Parameters
 * @param {number} params.id - VmGroup ID
 * @param {string} params.name - Name
 * @param {string} params.state - VmGroup state
 */
const validateVmGroupInfo = ({ id, name, state }) => {
  cy.navigateTab('info').within(() => {
    cy.getBySel('id').should('have.text', id)
    cy.getBySel('name').should('have.text', name)
    cy.getBySel('locked').should('have.text', state)
  })
}

/**
 * @param {object} resource - OpenNebula resource to be updated
 */
const changePermissionsVmGroup = (resource) => {
  const { VmGrp, NEW_PERMISSIONS } = resource

  cy.navigateMenu('templates', 'VM Groups')
  cy.clickVmGroupRow({ id: VmGrp.id })
    .then(() =>
      cy.changePermissions(NEW_PERMISSIONS, Intercepts.SUNSTONE.VMGROUP_CHMOD)
    )
    .then(() => VmGrp.info())
    .then(() => cy.validatePermissions(NEW_PERMISSIONS))
}

/**
 * Validates the VMs tab for a VM group.
 *
 * @param {string|number} vmname - VM id
 */
const validateVmGroupMonitoring = (vmname) => {
  cy.navigateTab('vms').within(() => {
    cy.contains('.MuiDataGrid-cell[data-field="NAME"]', vmname).should('exist')
  })
}

Cypress.Commands.add('vmgroupGUI', vmgroupGUI)
Cypress.Commands.add('vmgroupUpdate', vmgroupUpdate)
Cypress.Commands.add('deleteVmGroup', deleteVmGroup)
Cypress.Commands.add('validateVmGroupInfo', validateVmGroupInfo)
Cypress.Commands.add('validateVmGroupMonitoring', validateVmGroupMonitoring)
Cypress.Commands.add('changePermissionsVmGroup', changePermissionsVmGroup)
Cypress.Commands.add('lockVmGroup', lockVmGroup)
Cypress.Commands.add('unlockVmGroup', unlockVmGroup)
