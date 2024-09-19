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
 * @param {object} vrouter - VRouter.
 */
const vrouterDelete = (vrouter) => {
  if (vrouter.id === undefined) return
  cy.navigateMenu('instances', 'Virtual Routers')
  cy.deleteVRouter(vrouter).then(() => {
    cy.getVRouterTable({ search: vrouter.name }).within(() => {
      cy.getBySel('refresh')
        .click()
        .then(() => {
          cy.get(`[role='row'][data-cy$='${vrouter.id}']`).should('not.exist')
        })
    })
  })
}

/**
 * Change vrouter template permissions.
 *
 * @param {object} resource - VRouter template.
 */
const vrouterinstancePermissions = (resource) => {
  cy.navigateMenu('instances', 'Virtual Routers')
  cy.changePermissionsVRouter(resource)
}

/**
 * Renames the given vrouter template.
 *
 * @param {object} vrouter -  VRouter.
 * @param {string} newName - New name.
 */
const vrouterRename = (vrouter, newName) => {
  cy.navigateMenu('instances', 'Virtual Routers')
  cy.renameVRouter(vrouter, newName)
}

/**
 * @param {object} vroutertemplate - VRouter template.
 * @param {string} newOwner - New owner.
 */
const vroutertemplateChown = (vroutertemplate, newOwner) => {
  cy.navigateMenu('templates', 'VRouter Template')
  cy.changeownerVRouterTemplate(vroutertemplate, newOwner)
}

/**
 * @param {object} vrouter - Running vrouter
 */
const vrouterinstanceValidate = (vrouter) => {
  cy.navigateMenu('instances', 'Virtual Routers')
  cy.validateVRouterInstance(vrouter)
}

module.exports = {
  vrouterinstancePermissions,
  vrouterRename,
  vroutertemplateChown,
  vrouterinstanceValidate,
  vrouterDelete,
}
