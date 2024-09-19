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

import { Host } from '@models'
import { FORCE } from '@support/commands/constants'
import { Intercepts, createIntercept } from '@support/utils'
import { configCreateHost } from '@support/commands/host/jsdocs'

/**
 * Create Host.
 *
 * @param {configCreateHost} host - host config
 * @returns {Cypress.Chainable<Cypress.Response>} create host
 */
const create = (host = {}) => {
  const hostAllocate = createIntercept(Intercepts.SUNSTONE.HOST_ALLOCATE)
  const { name, hypervisor, cluster } = host

  cy.getBySel('action-host_create_dialog').click(FORCE)

  hypervisor &&
    cy
      .get(`[data-cy=general-hypervisor-vmmMad] > button[value=${hypervisor}]`)
      .click(FORCE)

  name && cy.getBySel('general-information-hostname').type(name)

  cy.getBySel('stepper-next-button').click()

  cluster && cy.getClusterRow(cluster).click(FORCE)

  // SUBMIT
  cy.getBySel('stepper-next-button').click()

  return cy.wait(hostAllocate)
}

/**
 * Delete host.
 *
 * @param {Host} host - host
 * @returns {Cypress.Chainable<Cypress.Response>} delete host response
 */
const deleteHost = (host) => {
  const hostChangeState = createIntercept(Intercepts.SUNSTONE.HOST_DELETE)
  cy.clickHostRow(host)
  cy.getBySel('action-host-delete').click(FORCE)

  cy.getBySel(`modal-host-delete`).within(() => {
    cy.getBySel('dg-accept-button').click(FORCE)
  })

  return cy.wait(hostChangeState)
}

/**
 * Set state on host.
 *
 * @param {string} action - action
 * @returns {function(Host):Cypress.Chainable<Cypress.Response>} change host state response
 */
const setState = (action) => (host) => {
  const hostChangeState = createIntercept(
    Intercepts.SUNSTONE.HOST_CHANGE_STATUS
  )
  cy.clickHostRow(host)
  cy.getBySel(`action-host_${action}`).click(FORCE)

  return cy.wait(hostChangeState)
}

Cypress.Commands.add('createHost', create)
Cypress.Commands.add('disableHost', setState('disable'))
Cypress.Commands.add('enableHost', setState('enable'))
Cypress.Commands.add('offlineHost', setState('offline'))
Cypress.Commands.add('deleteHost', deleteHost)
