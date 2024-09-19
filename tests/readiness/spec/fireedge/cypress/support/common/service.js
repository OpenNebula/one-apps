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
 * @param {object} service - Service.
 */
const serviceDelete = (service) => {
  if (service.id === undefined) return
  cy.navigateMenu('instances', 'Services')
  cy.deleteService(service).then(() => {
    cy.getServiceTable({ search: service.name }).within(() => {
      cy.getBySel('refresh')
        .click()
        .then(() => {
          cy.get(`[role='row'][data-cy$='${service.id}']`).should('not.exist')
        })
    })
  })
}

/**
 * Change service template permissions.
 *
 * @param {object} resource - Service template.
 */
const serviceinstancePermissions = (resource) => {
  cy.navigateMenu('instances', 'Services')
  cy.changePermissionsService(resource)
}

/**
 * Renames the given service template.
 *
 * @param {object} service -  Service.
 * @param {string} newName - New name.
 */
const serviceRename = (service, newName) => {
  cy.navigateMenu('instances', 'Services')
  cy.renameService(service, newName)
}

/**
 * Adds a role to the given service.
 *
 * @param {object} service -  Service.
 * @param {object} role - New role.
 */
const serviceAddRole = (service, role) => {
  cy.navigateMenu('instances', 'Services')
  cy.serviceAddRole(service, role)
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
 * @param {object} service - Running service
 */
const serviceinstanceValidate = (service) => {
  cy.navigateMenu('instances', 'Services')
  cy.validateServiceInstance(service)
}

/**
 * Perform an action on a role to the given service.
 *
 * @param {object} service -  Service.
 * @param {string} action - Action to perform
 * @param {string} role - Name of the role
 */
const servicePerformActionRole = (service, action, role) => {
  cy.navigateMenu('instances', 'Services')
  cy.servicePerformActionRole(service, action, role)
}

module.exports = {
  serviceinstancePermissions,
  serviceRename,
  serviceAddRole,
  servicetemplateChown,
  serviceinstanceValidate,
  serviceDelete,
  servicePerformActionRole,
}
