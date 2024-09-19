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
 * Deletes a service template.
 *
 * @param {object} servicetemplate - Service template.
 */
const servicetemplateDelete = (servicetemplate) => {
  if (servicetemplate.id === undefined) return
  cy.navigateMenu('templates', 'Service Templates')
  cy.clickServiceTemplateRow({ id: servicetemplate.id }).then(() => {
    cy.deleteServiceTemplate().then(() => {
      cy.getServiceTemplateTable({ search: servicetemplate.name }).within(
        () => {
          cy.get(`[role='row'][data-cy$='${servicetemplate.id}']`).should(
            'not.exist'
          )
        }
      )
    })
  })
}

/**
 * Creates a new service template via GUI.
 *
 * @param {object} servicetemplate -  Service template.
 */
const servicetemplateGUI = (servicetemplate) => {
  cy.navigateMenu('templates', 'Service Templates')
  cy.servicetemplateGUI(servicetemplate)
}

/**
 * @param {object} servicetemplate - Service template.
 */
const servicetemplateUpdate = (servicetemplate) => {
  cy.navigateMenu('templates', 'Service Templates')
  cy.servicetemplateUpdate(servicetemplate)
}

/**
 * Change service template permissions.
 *
 * @param {object} resource - Service template.
 */
const servicetemplatePermissions = (resource) => {
  cy.navigateMenu('templates', 'Service Template')
  cy.changePermissionsServiceTemplate(resource)
}

/**
 * Renames the given service template.
 *
 * @param {object} servicetemplate -  Service template.
 * @param {string} newName - New name.
 */
const servicetemplateRename = (servicetemplate, newName) => {
  cy.navigateMenu('templates', 'Service Template')
  cy.renameServiceTemplate(servicetemplate, newName)
}

/**
 * @param {object} servicetemplate - Service template.
 * @param {string} newOwner - New owner.
 */
const servicetemplateChown = (servicetemplate, newOwner) => {
  cy.navigateMenu('templates', 'Service Template')
  cy.changeownerServiceTemplate(servicetemplate, newOwner)
}

/**
 * @param {object} servicetemplate - Service template.
 * @returns {number} - Inntantiated service ID
 */
const servicetemplateInstantiate = (servicetemplate) => {
  cy.navigateMenu('templates', 'Service Template')

  return cy.instantiateServiceTemplate(servicetemplate)
}

module.exports = {
  servicetemplateGUI,
  servicetemplateUpdate,
  servicetemplateDelete,
  servicetemplatePermissions,
  servicetemplateRename,
  servicetemplateChown,
  servicetemplateInstantiate,
}
