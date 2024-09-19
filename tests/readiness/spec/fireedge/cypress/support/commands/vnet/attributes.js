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
 * Check if the restricted attributes of a vnet are disabled or not depending on the user.
 *
 * @param {object} restrictedAttributes - Map of restricted attributes
 * @param {string} check - Condition to check
 * @param {object} vnetInfo - Virtual network to check
 */
const checkVnetGUI = (restrictedAttributes, check, vnetInfo) => {
  // Click on the vnet
  cy.clickVNetRow(vnetInfo)

  // Click on update button
  cy.getBySel('action-vnet-update_dialog').click()

  // Check the General step and click next
  checkGeneralStep(restrictedAttributes, check)
  cy.getBySel('stepper-next-button').click()

  // Check the Security tab
  checkSecurityTab(restrictedAttributes, check)

  // Check the QoS tab
  checkQoSTab(restrictedAttributes, check)

  // Check the Context tab
  checkContextTab(restrictedAttributes, check)

  // Close the update form
  cy.getBySel('stepper-next-button').click()

  // Click on the vnet
  cy.clickVNetRow(vnetInfo)

  // Check the Address tab
  checkAddressTab(restrictedAttributes, check, vnetInfo)
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
 * Check the Security tab.
 *
 * @param {object} restrictedAttributes - Map of restricted attributes
 * @param {string} check - Condition to check
 */
const checkSecurityTab = (restrictedAttributes, check) => {
  // Go to Storage tab
  cy.navigateTab('security')

  // Check form
  checkForm(restrictedAttributes.PARENT, check)
}

/**
 * Check the QoS tab.
 *
 * @param {object} restrictedAttributes - Map of restricted attributes
 * @param {string} check - Condition to check
 */
const checkQoSTab = (restrictedAttributes, check) => {
  // Go to Storage tab
  cy.navigateTab('qos')

  // Check form
  checkForm(restrictedAttributes.PARENT, check)
}

/**
 * Check the Context tab.
 *
 * @param {object} restrictedAttributes - Map of restricted attributes
 * @param {string} check - Condition to check
 */
const checkContextTab = (restrictedAttributes, check) => {
  // Go to Context tab
  cy.navigateTab('context')

  // Check form
  checkForm(restrictedAttributes.PARENT, check)
}

/**
 * Check the Address tab.
 *
 * @param {object} restrictedAttributes - Map of restricted attributes
 * @param {string} check - Condition to check
 * @param {object} vnet - Virtual network to check
 */
const checkAddressTab = (restrictedAttributes, check, vnet) => {
  // Go to Address tab
  cy.navigateTab('address')

  // It's exist a AR attribute and it's not admin, delete button has to be disabled - not alias
  hasRestrictedAttributes(vnet.addresses[0], 'AR', restrictedAttributes) &&
    cy.getBySelLike('delete_ar-0').should(check)

  // Click on update button
  cy.getBySel('update_ar-0').click()

  // Check form
  checkForm(restrictedAttributes.AR, check)
}

export { checkVnetGUI }
