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

/**
 * Deletes a vrouter template.
 *
 * @param {object} vrtemplate - VR template.
 */
const vrtemplateDelete = (vrtemplate) => {
  if (vrtemplate.id === undefined) return
  cy.navigateMenu('templates', 'Virtual Routers')
  cy.clickVrTemplateRow({ id: vrtemplate.id }).then(() => {
    cy.deletevrtemplate().then(() => {
      cy.getVrTemplateTable({ search: vrtemplate.name }).within(() => {
        cy.get(`[role='row'][data-cy$='${vrtemplate.id}']`).should('not.exist')
      })
    })
  })
}

/**
 * Creates a new vrouter template via GUI.
 *
 * @param {object} vrtemplate -  VR template.
 */
const vrtemplateGUI = (vrtemplate) => {
  cy.navigateMenu('templates', 'Virtual Routers')
  cy.vrtemplateGUI(vrtemplate)
}

/**
 * @param {object} vrtemplate - VR template.
 */
const vrtemplateUpdate = (vrtemplate) => {
  cy.navigateMenu('templates', 'Virtual Routers')
  cy.vrtemplateUpdate(vrtemplate)
}

/**
 * Change vrouter template permissions.
 *
 * @param {object} resource - VR template.
 */
const vrtemplatePermissions = (resource) => {
  cy.navigateMenu('templates', 'Virtual Routers')
  cy.changePermissionsvrtemplate(resource)
}

/**
 * Renames the given vrouter template.
 *
 * @param {object} vrtemplate -  VR template.
 * @param {string} newName - New name.
 */
const vrtemplateRename = (vrtemplate, newName) => {
  cy.navigateMenu('templates', 'Virtual Routers')
  cy.renamevrtemplate(vrtemplate, newName)
}

/**
 * @param {object} vrtemplate - VR template.
 * @param {string} newOwner - New owner.
 */
const vrtemplateChown = (vrtemplate, newOwner) => {
  cy.navigateMenu('templates', 'Virtual Routers')
  cy.changeownervrtemplate(vrtemplate, newOwner)
}

/**
 * @param {object} vrtemplate - VR template.
 * @returns {number} - Inntantiated vrouter ID
 */
const vrtemplateInstantiate = (vrtemplate) => {
  cy.navigateMenu('templates', 'Virtual Routers')

  return cy.instantiatevrtemplate(vrtemplate)
}

module.exports = {
  vrtemplateGUI,
  vrtemplateUpdate,
  vrtemplateDelete,
  vrtemplatePermissions,
  vrtemplateRename,
  vrtemplateChown,
  vrtemplateInstantiate,
}
