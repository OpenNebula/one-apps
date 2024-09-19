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

import { createIntercept, Intercepts } from '@support/utils/index'
import { Host } from '@models'
import { FORCE } from '@support/commands/constants'

/**
 * Validate host state.
 *
 * @param {string|RegExp} state - Host state in readable format
 */
const validateHostState = (state) => {
  cy.navigateTab('info').within(() => {
    state instanceof RegExp
      ? cy.getBySel('state').invoke('text').should('match', state)
      : cy.getBySel('state').should('have.text', state)
  })
}

/**
 * Set overcommitment in host.
 *
 * @param {object} config - overcommitment config.
 * @param {number} config.CPU - CPU
 * @param {string} config.MEMORY - MEMORY
 */
const overcommitmentHost = ({ CPU, MEMORY }) => {
  const interceptUpdate = createIntercept(Intercepts.HOST_UPDATE)
  cy.navigateTab('info').within(() => {
    if (CPU) {
      cy.getBySel('edit-allocatedCpu').click(FORCE)
      cy.getBySel('text-allocatedCpu').clear(FORCE).type(`${CPU}{del}`) // this is because when the clear is done, the input remains at '0' and when writing the new value it is concatenated.
      cy.getBySel('accept-allocatedCpu').click(FORCE)
      cy.wait(interceptUpdate).its('response.statusCode').should('eq', 200)
    }
    if (MEMORY) {
      cy.getBySel('edit-allocatedMemory').click(FORCE)
      cy.getBySel('text-allocatedMemory').clear(FORCE).type(`${MEMORY}{del}`)
      cy.getBySel('accept-allocatedMemory').click(FORCE)
      cy.wait(interceptUpdate).its('response.statusCode').should('eq', 200)
    }
  })
}

/**
 * Set overcommitment in host.
 *
 * @param {object} host - host.
 * @param {object} host.json - host json.
 * @param {object} config - config
 * @param {number} config.CPU - CPU
 * @param {number} config.MEMORY - MEMORY
 */
const validateOvercommitmentHost = ({ json }, { CPU, MEMORY }) => {
  if (CPU) {
    expect(json?.TEMPLATE?.RESERVED_CPU).to.equal(
      `${+(json?.HOST_SHARE?.TOTAL_CPU || 0) - +CPU}`
    )
  }
  if (MEMORY) {
    expect(json?.TEMPLATE?.RESERVED_MEM).to.equal(
      `${+(json?.HOST_SHARE?.TOTAL_MEM || 0) - +MEMORY}`
    )
  }
}

/**
 * Validate Info tab.
 *
 * @param {Host} host - Host
 */
const validateHostInfo = (host) => {
  const { IM_MAD, VM_MAD, CLUSTER_ID, CLUSTER } = host.json

  cy.navigateTab('info').within(() => {
    cy.getBySel('id').should('have.text', host.id)
    cy.getBySel('name').should('have.text', host.name)
    cy.getBySel('immad').should('have.text', IM_MAD)
    cy.getBySel('vmmad').should('have.text', VM_MAD)
    cy.getBySel('clusterid').contains(CLUSTER_ID)
    cy.getBySel('clusterid').contains(CLUSTER)
  })

  cy.validateHostState(host.state)
}

Cypress.Commands.add('validateHostState', validateHostState)
Cypress.Commands.add('validateHostInfo', validateHostInfo)
Cypress.Commands.add('overcommitmentHost', overcommitmentHost)
Cypress.Commands.add('validateOvercommitmentHost', validateOvercommitmentHost)
