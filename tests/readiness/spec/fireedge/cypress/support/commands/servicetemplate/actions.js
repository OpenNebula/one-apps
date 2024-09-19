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
import { Intercepts, createIntercept } from '@support/utils'
import {
  fillServiceTemplateGUI,
  fillServiceTemplateInstantiateGUI,
} from './create'

/**
 * Deletes a service template.
 *
 */
const deleteServiceTemplate = () => {
  const interceptDelete = createIntercept(
    Intercepts.SUNSTONE.SERVICETEMPLATE_DELETE
  )

  cy.getBySel('action-delete').click(FORCE)

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
 * Creates a new service template via GUI.
 *
 * @param {object} servicetemplate - The servicetemplate to create
 * @returns {void} - No return value
 */
const servicetemplateGUI = (servicetemplate) => {
  const interceptServiceTemplateAllocate = createIntercept(
    Intercepts.SUNSTONE.SERVICETEMPLATE_CREATE
  )

  cy.getBySel('action-create_dialog').click()
  fillServiceTemplateGUI(servicetemplate)
  cy.getBySel('stepper-next-button').click(FORCE)

  return cy
    .wait(interceptServiceTemplateAllocate)
    .its('response.statusCode')
    .should('eq', 200)
}

/**
 * Updates a Service Template via GUI.
 *
 * @param {object} servicetemplate - The service template to update
 * @returns {void} - No return value
 */
const servicetemplateUpdate = (servicetemplate) => {
  const interceptServiceTemplateUpdate = createIntercept(
    Intercepts.SUNSTONE.SERVICETEMPLATE_UPDATE
  )

  const { existingId, template } = servicetemplate

  cy.clickServiceTemplateRow({ id: existingId })
  cy.getBySel('action-update_dialog').click()
  fillServiceTemplateGUI(template)
  cy.getBySel('stepper-next-button').click(FORCE)

  return cy
    .wait(interceptServiceTemplateUpdate)
    .its('response.statusCode')
    .should('eq', 200)
}

/**
 * @param {object} resource - OpenNebula resource to be updated
 */
const changePermissionsServiceTemplate = (resource) => {
  const { ServiceTemplate, NEW_PERMISSIONS } = resource

  cy.clickServiceTemplateRow({ id: ServiceTemplate.id })
    .then(() =>
      cy.changePermissions(
        NEW_PERMISSIONS,
        Intercepts.SUNSTONE.SERVICETEMPLATE_CHMOD,
        { delay: true }
      )
    )
    .then(() => ServiceTemplate.info())
    .then(() => cy.validatePermissions(NEW_PERMISSIONS))
}

/**
 * @param {object} servicetemplate - OpenNebula resource to be updated
 * @param {string} newName - New name
 */
const renameServiceTemplate = (servicetemplate, newName) => {
  cy.clickServiceTemplateRow({ id: servicetemplate.id }).then(() => {
    cy.renameResource(newName, Intercepts.SUNSTONE.SERVICE_TEMPLATE)
      .then(() => (servicetemplate.name = newName))
      .then(() => cy.getServiceTemplateRow(servicetemplate).contains(newName))
  })
}

/**
 * @param {object} servicetemplate - OpenNebula resource to be updated
 * @param {string} newOwner - New owner
 * @returns {void} - No return value
 */
const changeownerServiceTemplate = (servicetemplate, newOwner) => {
  const interceptServiceTemplateChown = createIntercept(
    Intercepts.SUNSTONE.SERVICETEMPLATE_CHOWN
  )

  const interceptLoadUserPool = createIntercept(Intercepts.SUNSTONE.USERS)

  cy.clickServiceTemplateRow({ id: servicetemplate.id }).then(() => {
    cy.wait(interceptLoadUserPool)
      .its('response.statusCode')
      .should('eq', 200)
      .then(() => {
        cy.getBySel('edit-owner')
          .click()
          .then(() => {
            cy.getBySel('select-owner')
              .select(newOwner.name)
              .then(() => {
                cy.getBySel('accept-owner').click()
              })
          })
      })
  })

  return cy
    .wait(interceptServiceTemplateChown)
    .its('response.statusCode')
    .should('eq', 200)
}

const instantiateServiceTemplate = ({ existingId, template }) => {
  const interceptServiceTemplateInstantiate = createIntercept(
    Intercepts.SUNSTONE.SERVICETEMPLATE_INSTANTIATE
  )

  cy.clickServiceTemplateRow({ id: existingId })
  cy.getBySel('action-instantiate_dialog').click()
  fillServiceTemplateInstantiateGUI(template)
  cy.getBySel('stepper-next-button').click(FORCE)

  return cy.wait(interceptServiceTemplateInstantiate).then((interception) => {
    expect(interception.response.statusCode).to.eq(200)

    const id = interception.response.body.data.DOCUMENT.ID

    return id
  })
}

Cypress.Commands.add('servicetemplateGUI', servicetemplateGUI)
Cypress.Commands.add('servicetemplateUpdate', servicetemplateUpdate)
Cypress.Commands.add('deleteServiceTemplate', deleteServiceTemplate)
Cypress.Commands.add(
  'changePermissionsServiceTemplate',
  changePermissionsServiceTemplate
)
Cypress.Commands.add('renameServiceTemplate', renameServiceTemplate)
Cypress.Commands.add('changeownerServiceTemplate', changeownerServiceTemplate)
Cypress.Commands.add('instantiateServiceTemplate', instantiateServiceTemplate)
