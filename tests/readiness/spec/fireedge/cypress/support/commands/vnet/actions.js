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
import { createIntercept, Intercepts } from '@support/utils'
import {
  VirtualNetworkTest,
  ReserveLeaseTest,
} from '@support/commands/vnet/jsdoc'
import {
  fillVirtualNetwork,
  fillReservationForm,
} from '@support/commands/vnet/create'
import { VNet } from '@models'
import { FORCE } from '@support/commands/constants'
import { checkVnetGUI } from '@support/commands/vnet/attributes'

/**
 * Create Virtual Network via interface.
 *
 * @param {VirtualNetworkTest} data - Virtual network data to fill the form
 * @returns {Cypress.Chainable<Cypress.Response>} Create response
 */
const createVirtualNetwork = (data) => {
  const allocateIntercept = createIntercept(
    Intercepts.SUNSTONE.NETWORK_ALLOCATE
  )

  cy.getBySel('action-vnet-create_dialog').click()

  fillVirtualNetwork(data)

  cy.getBySel('stepper-next-button').click(FORCE)

  return cy.wait(allocateIntercept)
}

/**
 * Update Virtual Network via interface.
 *
 * @param {VNet} vnet - Virtual network to update
 * @param {VirtualNetworkTest} data - Virtual network data to fill the form
 * @returns {Cypress.Chainable<Cypress.Response>} Update response
 */
const updateVirtualNetwork = (vnet, data) => {
  const updateIntercept = createIntercept(Intercepts.SUNSTONE.NETWORK_UPDATE)

  cy.clickVNetRow(vnet)
  cy.getBySel('action-vnet-update_dialog').click()

  fillVirtualNetwork(data, true)
  cy.getBySel('stepper-next-button').click(FORCE)

  return cy.wait(updateIntercept)
}

/**
 * Delete Virtual Network.
 *
 * @param {VNet} vnet - Virtual network to delete
 * @returns {Cypress.Chainable<Cypress.Response>[]} Delete & info responses
 */
const deleteVirtualNetwork = (vnet = {}) => {
  const deleteIntercept = createIntercept(Intercepts.SUNSTONE.NETWORK_DELETE)

  cy.clickVNetRow(vnet)
  cy.getBySel('action-vnet-delete').click(FORCE)

  cy.getBySel('modal-vnet-delete').within(() => {
    cy.getBySel('dg-accept-button').click(FORCE)
  })

  return cy.wait(deleteIntercept)
}

/**
 * Reserve Virtual Network.
 *
 * @param {VNet} vnet - Virtual network to reserve
 * @param {ReserveLeaseTest} data - Reservation data
 * @returns {Cypress.Chainable<Cypress.Response>} Reserve response
 */
const reserveVirtualNetwork = (vnet = {}, data = []) => {
  const intercept = createIntercept(Intercepts.SUNSTONE.NETWORK_RESERVE)
  cy.clickVNetRow(vnet)

  cy.getBySel('action-vnet-reserve_dialog').click(FORCE)

  cy.getBySel('modal-reserve').then(() => {
    fillReservationForm(data)
    cy.getBySel('dg-accept-button').click(FORCE)
  })

  return cy.wait(intercept)
}

/**
 * Change lock Virtual Network.
 *
 * @param {boolean} lock - lock
 * @returns {function(VirtualNetworkTest):Cypress.Chainable<Cypress.Response>} (un)lock response
 */
const lockVirtualNetwork =
  (lock) =>
  (vnet = {}) => {
    const lockIntercept = createIntercept(
      lock
        ? Intercepts.SUNSTONE.NETWORK_LOCK
        : Intercepts.SUNSTONE.NETWORK_UNLOCK
    )

    const infoIntercept = createIntercept(Intercepts.SUNSTONE.NETWORK)

    const action = lock ? 'lock' : 'unlock'
    cy.clickVNetRow(vnet)

    cy.getBySel('action-vnet-lock').click(FORCE)
    cy.getBySel(`action-${action}`).click(FORCE)

    cy.getBySel(`modal-${action}`).within(() => {
      cy.getBySel('dg-accept-button').click(FORCE)
    })

    return cy.wait([lockIntercept, infoIntercept])
  }

/**
 * Check the vnet restricted attributes on a template.
 *
 * @param {object} restrictedAttributes - Map of restricted attributes
 * @param {object} vnetInfo - VNet to check
 * @param {boolean} admin - If the user belongs to oneadmin group.
 */
const checkVnetRestricteAttributes = (
  restrictedAttributes,
  vnetInfo,
  admin
) => {
  // Check disabled or not depending if the user is an admin
  const check = admin ? 'not.be.disabled' : 'be.disabled'

  // Get info template
  vnetInfo.info().then(() => {
    // Check the vnet
    checkVnetGUI(restrictedAttributes, check, vnetInfo)
  })
}

Cypress.Commands.add('createVirtualNetwork', createVirtualNetwork)
Cypress.Commands.add('updateVirtualNetwork', updateVirtualNetwork)
Cypress.Commands.add('deleteVirtualNetwork', deleteVirtualNetwork)
Cypress.Commands.add('reserveVirtualNetwork', reserveVirtualNetwork)
Cypress.Commands.add('lockVirtualNetwork', lockVirtualNetwork(true))
Cypress.Commands.add('unlockVirtualNetwork', lockVirtualNetwork(false))
Cypress.Commands.add(
  'checkVnetRestricteAttributes',
  checkVnetRestricteAttributes
)
