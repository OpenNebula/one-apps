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
import { fillTemplateGUI } from '@commands/template/create'
import { fillVrTemplateInstantiateGUI } from './create'

/**
 * Deletes a vr template.
 *
 */
const deleteVrTemplate = () => {
  const interceptDelete = createIntercept(
    Intercepts.SUNSTONE.VROUTERTEMPLATE_DELETE
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
 * Creates a new vr template via GUI.
 *
 * @param {object} vrtemplate - The vrtemplate to create
 * @returns {void} - No return value
 */
const vrtemplateGUI = (vrtemplate) => {
  const interceptVrTemplateAllocate = createIntercept(
    Intercepts.SUNSTONE.VROUTERTEMPLATE_CREATE
  )

  cy.getBySel('action-create_dialog').click()
  fillTemplateGUI(vrtemplate)
  cy.getBySel('stepper-next-button').click(FORCE)

  return cy
    .wait(interceptVrTemplateAllocate)
    .its('response.statusCode')
    .should('eq', 200)
}

/**
 * Updates a Vr Template via GUI.
 *
 * @param {object} vrtemplate - The vr template to update
 * @returns {void} - No return value
 */
const vrtemplateUpdate = (vrtemplate) => {
  const interceptVrTemplateUpdate = createIntercept(
    Intercepts.SUNSTONE.VROUTERTEMPLATE_UPDATE
  )

  const { existingId, template } = vrtemplate

  cy.clickVrTemplateRow({ id: existingId })
  cy.getBySel('action-update_dialog').click()
  fillTemplateGUI(template, true)
  cy.getBySel('stepper-next-button').click(FORCE)

  return cy
    .wait(interceptVrTemplateUpdate)
    .its('response.statusCode')
    .should('eq', 200)
}

/**
 * @param {object} resource - OpenNebula resource to be updated
 */
const changePermissionsVrTemplate = (resource) => {
  const { VrTemplate, NEW_PERMISSIONS } = resource

  cy.clickVrTemplateRow({ id: VrTemplate.id })
    .then(() =>
      cy.changePermissions(
        NEW_PERMISSIONS,
        Intercepts.SUNSTONE.VROUTERTEMPLATE_CHMOD,
        { delay: true }
      )
    )
    .then(() => VrTemplate.info())
    .then(() => cy.validatePermissions(NEW_PERMISSIONS))
}

/**
 * @param {object} vrtemplate - OpenNebula resource to be updated
 * @param {string} newName - New name
 */
const renameVrTemplate = (vrtemplate, newName) => {
  cy.clickVrTemplateRow({ id: vrtemplate.id }).then(() => {
    cy.renameResource(newName, Intercepts.SUNSTONE.VROUTER_TEMPLATE)
      .then(() => (vrtemplate.name = newName))
      .then(() => cy.getVrTemplateRow(vrtemplate).contains(newName))
  })
}

/**
 * @param {object} vrtemplate - OpenNebula resource to be updated
 * @param {string} newOwner - New owner
 * @returns {void} - No return value
 */
const changeownerVrTemplate = (vrtemplate, newOwner) => {
  const interceptVrTemplateChown = createIntercept(
    Intercepts.SUNSTONE.VROUTERTEMPLATE_CHANGE_OWN
  )

  const interceptLoadUserPool = createIntercept(Intercepts.SUNSTONE.USERS)
  cy.clickVrTemplateRow({ id: vrtemplate.id }).then(() => {
    cy.wait(interceptLoadUserPool)
      .its('response.statusCode')
      .should(
        'satisfy',
        (statusCode) => statusCode === 200 || statusCode === 304
      )
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
    .wait(interceptVrTemplateChown)
    .its('response.statusCode')
    .should('eq', 200)
}

const instantiateVrTemplate = ({ existingId, template }) => {
  const interceptVrTemplateInstantiate = createIntercept(
    Intercepts.SUNSTONE.VROUTERTEMPLATE_INSTANTIATE
  )

  cy.clickVrTemplateRow({ id: existingId })
  cy.getBySel('action-instantiate_dialog').click()
  fillVrTemplateInstantiateGUI(template)
  cy.getBySel('stepper-next-button').click(FORCE)

  return cy.wait(interceptVrTemplateInstantiate).then((interception) => {
    expect(interception.response.statusCode).to.eq(200)

    const id = interception.response.body.ID

    return id
  })
}

Cypress.Commands.add('vrtemplateGUI', vrtemplateGUI)
Cypress.Commands.add('vrtemplateUpdate', vrtemplateUpdate)
Cypress.Commands.add('deletevrtemplate', deleteVrTemplate)
Cypress.Commands.add('changePermissionsvrtemplate', changePermissionsVrTemplate)
Cypress.Commands.add('renamevrtemplate', renameVrTemplate)
Cypress.Commands.add('changeownervrtemplate', changeownerVrTemplate)
Cypress.Commands.add('instantiatevrtemplate', instantiateVrTemplate)
