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
import { booleanToString } from '@commands/helpers'

/**
 * Validates Virtual Network state.
 *
 * @param {string|RegExp} state - Virtual Network state in readable format
 */
const validateState = (state) => {
  cy.navigateTab('info').within(() => {
    state instanceof RegExp
      ? cy.getBySel('state').invoke('text').should('match', state)
      : cy.getBySel('state').should('have.text', state)
  })
}

/**
 * Validates Virtual Network QoS.
 *
 * @param {VNet} vnet - Virtual Network
 */
const validateQoS = (vnet) => {
  cy.navigateTab('info').within(() => {
    const {
      INBOUND_AVG_BW = '-',
      INBOUND_PEAK_BW = '-',
      INBOUND_PEAK_KB = '-',
      OUTBOUND_AVG_BW = '-',
      OUTBOUND_PEAK_BW = '-',
      OUTBOUND_PEAK_KB = '-',
    } = vnet.json.TEMPLATE

    cy.getBySel('inbound-avg').should('include.text', INBOUND_AVG_BW)
    cy.getBySel('inbound-peak-bandwidth').should(
      'include.text',
      INBOUND_PEAK_BW
    )
    cy.getBySel('inbound-peak').should('include.text', INBOUND_PEAK_KB)
    cy.getBySel('outbound-avg').should('include.text', OUTBOUND_AVG_BW)
    cy.getBySel('outbound-peak-bandwidth').should(
      'include.text',
      OUTBOUND_PEAK_BW
    )
    cy.getBySel('outbound-peak').should('include.text', OUTBOUND_PEAK_KB)
  })
}

/**
 * Validate info tab.
 *
 * @param {VNet} vnet - Virtual Network
 */
const validateVNetInfo = (vnet) => {
  const {
    ID,
    NAME,
    VLAN_ID,
    VLAN_ID_AUTOMATIC,
    OUTER_VLAN_ID,
    OUTER_VLAN_ID_AUTOMATIC,
  } = vnet.json

  cy.clickVNetRow(vnet, undefined, { clearSelectedRows: true })

  cy.navigateTab('info').within(() => {
    cy.getBySel('id').should('have.text', ID)
    cy.getBySel('name').should('have.text', NAME)

    cy.getBySel('vlan-id').should('have.text', VLAN_ID || '-')
    cy.getBySel('vlan-id-automatic').should(
      'have.text',
      booleanToString(VLAN_ID_AUTOMATIC)
    )

    cy.getBySel('outer-vlan-id').should('have.text', OUTER_VLAN_ID || '-')
    cy.getBySel('outer-vlan-id-automatic').should(
      'have.text',
      booleanToString(OUTER_VLAN_ID_AUTOMATIC)
    )

    cy.validateOwnership(vnet)
    cy.validatePermissions(vnet)
  })

  cy.validateVNetState(vnet.state)
  cy.validateLock(vnet)
  cy.validateVNetQoS(vnet)
}

Cypress.Commands.add('validateVNetState', validateState)
Cypress.Commands.add('validateVNetQoS', validateQoS)
Cypress.Commands.add('validateVNetInfo', validateVNetInfo)
