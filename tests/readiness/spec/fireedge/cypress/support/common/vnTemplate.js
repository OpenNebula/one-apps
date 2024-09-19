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

const { Intercepts } = require('@support/utils/index')

/**
 * Function to be executed before each Virtual Network Template test.
 */
const beforeEachVNTemplateTest = () => {
  cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
    qs: { externalToken: Cypress.env('TOKEN') },
  })
}

/**
 * Renames the given virtual network template.
 *
 * @param {object} vntemplate - Virtual Network template.
 * @param {string} newName - New name.
 */
const renameVNTemplate = (vntemplate, newName) => {
  cy.navigateMenu('networks', 'Network Templates')

  cy.clickVNTemplateRow(vntemplate)
    .then(() =>
      cy.renameResource(newName, Intercepts.SUNSTONE.NETWORK_TEMPLATE)
    )
    .then(() => (vntemplate.name = newName))
    .then(() => cy.getVNTemplateRow(vntemplate).contains(newName))
}

/**
 * Locks the given virtual network template.
 *
 * @param {object} vntemplate - Virtual Network template.
 */
const lockVNTemplate = (vntemplate) => {
  cy.navigateMenu('networks', 'Network Templates')

  cy.lockVNTemplate(vntemplate)
    .then(() => vntemplate.info())
    .then(() => cy.validateLock(vntemplate))
}

/**
 * Unlocks the given virtual network template.
 *
 * @param {object} vntemplate - Virtual Network template.
 */
const unlockVNTemplate = (vntemplate) => {
  cy.navigateMenu('networks', 'Network Templates')

  cy.unlockVNTemplate(vntemplate)
    .then(() => vntemplate.info())
    .then(() => cy.validateLock(vntemplate))
}

/**
 * Reserves a range on the virtual network template.
 *
 * @param {object} vntemplate - Virtual Network template.
 * @returns {any} response of deletion
 */
const deleteVNTemplate = (vntemplate) => {
  cy.navigateMenu('networks', 'Network Templates')

  return cy.then(() => cy.deleteVNTemplate(vntemplate))
}

/**
 * Deletes the given virtual network template.
 *
 * @param {object} vntemplate - Virtual Network template.
 */
const deleteVNTemplateAndValidate = (vntemplate) => {
  deleteVNTemplate(vntemplate).its('response.body.id').should('eq', 200)
}

/**
 * Deletes all the resources given.
 *
 * @param {object} vntemplate - Virtual Network templates to be deleted.
 */
const deleteResources = (vntemplate) => {
  Object.entries(vntemplate).forEach(([, vnTemplate]) => {
    vnTemplate.delete()
  })
}

/**
 * Change permissions a virtual network template GUI.
 *
 * @param {object} resources - resources
 */
const changePermissionsVnTemplateGUI = (resources = {}) => {
  const { VN_TEMPLATE, NEW_PERMISSIONS } = resources

  if (VN_TEMPLATE.id === undefined) return
  cy.navigateMenu('networks', 'Network Templates')

  cy.clickVNTemplateRow(VN_TEMPLATE)
    .then(() =>
      cy.changePermissions(
        NEW_PERMISSIONS,
        Intercepts.SUNSTONE.NETWORK_TEMPLATE_CHANGE_MOD
      )
    )
    .then(() => cy.validatePermissions(NEW_PERMISSIONS))
}

/**
 * @param {object} vntemplate - Virtual Network template.
 */
const updateVNTemplate = (vntemplate) => {
  cy.navigateMenu('networks', 'Network Templates')
  cy.updateVNTemplate(vntemplate)
}

/**
 * @param {object} vntemplate - Virtual Network template.
 */
const createVNTemplate = (vntemplate) => {
  cy.navigateMenu('networks', 'Network Templates')
  cy.createVNTemplate(vntemplate)
}

export {
  beforeEachVNTemplateTest,
  changePermissionsVnTemplateGUI,
  createVNTemplate,
  deleteResources,
  deleteVNTemplateAndValidate,
  lockVNTemplate,
  renameVNTemplate,
  unlockVNTemplate,
  updateVNTemplate,
}
