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

import { checkForm, hasRestrictedAttributes } from '@support/utils'

/**
 * Check if the restricted attributes of a template are disabled or not depending on the user.
 *
 * @param {object} restrictedAttributes - Map of restricted attributes
 * @param {string} check - Condition to check
 * @param {object} template - Template to check
 */
const checkTemplateGUI = (restrictedAttributes, check, template) => {
  // Check the General step and click next
  checkGeneralStep(restrictedAttributes, check)
  cy.getBySel('stepper-next-button').click()

  // Check the Storage tab
  checkStorageTab(restrictedAttributes, check, template)

  // Check the Network tab
  checkNetworkTab(restrictedAttributes, check, template)

  // Check the OS&CPU tab
  checkOSAndCPUTab(restrictedAttributes, check)

  // Check the IO tab
  checkIOTab(restrictedAttributes, check)

  // Check Context tab
  checkContextTab(restrictedAttributes, check)

  // Check Schedule Action tab
  checkScheduleActionTab(restrictedAttributes, check)

  // Check Placement tab
  checkPlacementTab(restrictedAttributes, check)

  // Check Numa tab
  checkNumaTab(restrictedAttributes, check)

  // Check Backup tab
  checkBackupTab(restrictedAttributes, check)
}

/**
 * Check the General step.
 *
 * @param {object} restrictedAttributes - Map of restricted attributes
 * @param {string} check - Condition to check
 */
const checkGeneralStep = (restrictedAttributes, check) => {
  // Ensure that the General step is loaded before checking the fields
  cy.getBySel('legend-general-information').then(() => {
    // Check form of the general step
    checkForm(restrictedAttributes.PARENT, check)
  })
}

/**
 * Check the Storage tab.
 *
 * @param {object} restrictedAttributes - Map of restricted attributes
 * @param {string} check - Condition to check
 * @param {object} template - Template to check
 */
const checkStorageTab = (restrictedAttributes, check, template) => {
  // Go to Storage tab
  cy.navigateTab('storage')

  // If exists a DISK attribute and it's not admin, delete button has to be disabled
  hasRestrictedAttributes(template.disks[0], 'DISK', restrictedAttributes) &&
    cy.getBySelLike('disk-detach-0').should(check)

  // Click on update button
  cy.getBySel('edit-0').click()

  // Update a disk has two different steps

  // Check first step
  cy.get('[role="dialog"]').then(() =>
    checkForm(restrictedAttributes.DISK, check)
  )

  // Click next button
  cy.get('[role="dialog"]').within(() =>
    cy.getBySel('stepper-next-button').click()
  )

  // Check second step
  cy.get('[role="dialog"]').then(() =>
    checkForm(restrictedAttributes.DISK, check)
  )

  // Click next button
  cy.get('[role="dialog"]').within(() =>
    cy.getBySel('stepper-next-button').click()
  )
}

/**
 * Check the Network tab.
 *
 * @param {object} restrictedAttributes - Map of restricted attributes
 * @param {string} check - Condition to check
 * @param {object} template - Template to check
 */
const checkNetworkTab = (restrictedAttributes, check, template) => {
  // Go to Network tab
  cy.navigateTab('network')

  // If exists a Vnet attribute and it's not admin, delete button has to be disabled - not alias
  hasRestrictedAttributes(template.vnets[0], 'NIC', restrictedAttributes) &&
    cy.getBySelLike('detach-nic-1').should(check)

  // Click on update button
  cy.getBySel('edit-0').click()

  // Update a network has three different steps

  // Check first step
  cy.get('[role="dialog"]').then(() =>
    checkForm(restrictedAttributes.NIC, check)
  )

  // Click next button
  cy.get('[role="dialog"]').within(() =>
    cy.getBySel('stepper-next-button').click()
  )

  // Check second step
  cy.get('[role="dialog"]').then(() =>
    checkForm(restrictedAttributes.NIC, check)
  )

  // Click next button
  cy.get('[role="dialog"]').within(() =>
    cy.getBySel('stepper-next-button').click()
  )

  // Check third step
  cy.get('[role="dialog"]').then(() =>
    checkForm(restrictedAttributes.NIC, check)
  )

  // Click next button
  cy.get('[role="dialog"]').within(() =>
    cy.getBySel('stepper-next-button').click()
  )
}

/**
 * Check the OS&CPU tab.
 *
 * @param {object} restrictedAttributes - Map of restricted attributes
 * @param {string} check - Condition to check
 */
const checkOSAndCPUTab = (restrictedAttributes, check) => {
  // Go to Storage tab
  cy.navigateTab('booting')

  // Check form
  checkForm(restrictedAttributes.OS, check)
}

/**
 * Check the IO tab.
 *
 * @param {object} restrictedAttributes - Map of restricted attributes
 * @param {string} check - Condition to check
 */
const checkIOTab = (restrictedAttributes, check) => {
  // Go to IO tab
  cy.navigateTab('input_output')

  // Check form
  checkForm(restrictedAttributes.GRAPHICS, check)

  // Check form
  checkForm(restrictedAttributes.INPUT, check)

  // Check form
  checkForm(restrictedAttributes.PCI, check)

  // Check form
  checkForm(restrictedAttributes.VIDEO, check)
}

/**
 * Check the Context tab.
 *
 * @param {object} restrictedAttributes - Map of restricted attributes
 * @param {string} check - Condition to check
 */
const checkContextTab = (restrictedAttributes, check) => {
  // Go to IO tab
  cy.navigateTab('context')

  // Check form
  checkForm(restrictedAttributes.CONTEXT, check)

  // Check form
  checkForm(restrictedAttributes.USER_INPUTS, check)
}

/**
 * Check the Schedule Action tab.
 *
 * @param {object} restrictedAttributes - Map of restricted attributes
 * @param {string} check - Condition to check
 */
const checkScheduleActionTab = (restrictedAttributes, check) => {
  // Go to Schedule Action tab
  cy.navigateTab('sched_action')

  // It's exist a SCHED_ACTION attribute and it's not admin, delete button has to be disabled
  restrictedAttributes.SCHED_ACTION &&
    cy.getBySelLike('sched-delete-0').should(check)

  // Click on update button
  cy.getBySel('sched-update-0').click()

  // Check form
  cy.get('[role="dialog"]').then(() =>
    checkForm(restrictedAttributes.SCHED_ACTION, check)
  )

  // Click next button
  cy.get('[role="dialog"]').within(() =>
    cy.getBySel('dg-accept-button').click()
  )
}

/**
 * Check the Placement tab.
 *
 * @param {object} restrictedAttributes - Map of restricted attributes
 * @param {string} check - Condition to check
 */
const checkPlacementTab = (restrictedAttributes, check) => {
  // Go to IO tab
  cy.navigateTab('placement')

  // Check form
  checkForm(restrictedAttributes.PARENT, check)
}

/**
 * Check the Numa tab.
 *
 * @param {object} restrictedAttributes - Map of restricted attributes
 * @param {string} check - Condition to check
 */
const checkNumaTab = (restrictedAttributes, check) => {
  // Go to IO tab
  cy.navigateTab('numa')

  // Check form
  checkForm(restrictedAttributes.TOPOLOGY, check)
}

/**
 * Check the Backup tab.
 *
 * @param {object} restrictedAttributes - Map of restricted attributes
 * @param {string} check - Condition to check
 */
const checkBackupTab = (restrictedAttributes, check) => {
  // Go to IO tab
  cy.navigateTab('backup')

  // Check form
  checkForm(restrictedAttributes.BACKUP_CONFIG, check)
}

export { checkTemplateGUI }
