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
import { VNet } from '@models'
import { FORCE } from '@support/commands/constants'
import { VirtualNetworkTest } from '@support/commands/vnet/jsdoc'
import { fillVirtualNetworkTemplate } from '@support/commands/vnetTemplate/create'
import { createIntercept, Intercepts } from '@support/utils'

/**
 * Create Virtual Network via interface.
 *
 * @param {VirtualNetworkTest} data - Virtual network data to fill the form
 * @returns {Cypress.Chainable<Cypress.Response>} Create response
 */
const createVNTemplate = (data) => {
  const allocateIntercept = createIntercept(
    Intercepts.SUNSTONE.NETWORK_TEMPLATE_ALLOCATE
  )

  cy.getBySel('action-vnettemplate-create_dialog').click()

  fillVirtualNetworkTemplate(data)

  cy.getBySel('stepper-next-button').click(FORCE)

  return cy.wait(allocateIntercept)
}

/**
 * Update Virtual Network via interface.
 *
 * @param {object} params - data
 * @param {VNet} params.VN_TEMPLATE - Virtual network to update
 * @param {VNet} params.TEMPLATE - new template
 * @returns {Cypress.Chainable<Cypress.Response>} Update response
 */
const updateVNTemplate = ({ VN_TEMPLATE, TEMPLATE } = {}) => {
  const updateIntercept = createIntercept(
    Intercepts.SUNSTONE.NETWORK_TEMPLATE_UPDATE
  )

  cy.clickVNTemplateRow(VN_TEMPLATE)
  cy.getBySel('action-vnettemplate-update_dialog').click()

  fillVirtualNetworkTemplate(TEMPLATE, true)
  cy.getBySel('stepper-next-button').click(FORCE)

  return cy.wait(updateIntercept)
}

/**
 * Delete Virtual Network.
 *
 * @param {VNet} vnet - Virtual network to delete
 * @returns {Cypress.Chainable<Cypress.Response>[]} Delete & info responses
 */
const deleteVNTemplate = (vnet = {}) => {
  const deleteIntercept = createIntercept(
    Intercepts.SUNSTONE.NETWORK_TEMPLATE_DELETE
  )

  cy.clickVNTemplateRow(vnet)
  cy.getBySel('action-vnettemplate-delete').click(FORCE)

  cy.getBySel('modal-vnettemplate-delete').within(() => {
    cy.getBySel('dg-accept-button').click(FORCE)
  })

  return cy.wait(deleteIntercept)
}

/**
 * Change lock Virtual Network.
 *
 * @param {boolean} lock - lock
 * @returns {function(VirtualNetworkTest):Cypress.Chainable<Cypress.Response>} (un)lock response
 */
const lockVNTemplate =
  (lock) =>
  (vnet = {}) => {
    const lockIntercept = createIntercept(
      lock
        ? Intercepts.SUNSTONE.NETWORK_TEMPLATE_LOCK
        : Intercepts.SUNSTONE.NETWORK_TEMPLATE_UNLOCK
    )

    const infoIntercept = createIntercept(Intercepts.SUNSTONE.NETWORK_TEMPLATE)

    const action = lock ? 'lock' : 'unlock'
    cy.clickVNTemplateRow(vnet)

    cy.getBySel('action-vnettemplate-lock').click(FORCE)
    cy.getBySel(`action-${action}`).click(FORCE)

    cy.getBySel(`modal-${action}`).within(() => {
      cy.getBySel('dg-accept-button').click(FORCE)
    })

    return cy.wait([lockIntercept, infoIntercept])
  }

Cypress.Commands.add('createVNTemplate', createVNTemplate)
Cypress.Commands.add('updateVNTemplate', updateVNTemplate)
Cypress.Commands.add('deleteVNTemplate', deleteVNTemplate)
Cypress.Commands.add('lockVNTemplate', lockVNTemplate(true))
Cypress.Commands.add('unlockVNTemplate', lockVNTemplate(false))
