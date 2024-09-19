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

/**
 * Validate address ranges tab.
 *
 * @param {VNet} vnet - Virtual Network
 */
const validateVNetAddresses = (vnet) => {
  if (vnet.addresses.length === 0) return

  cy.clickVNetRow(vnet)

  cy.navigateTab('address').within(() => {
    vnet.addresses.forEach(
      ({
        AR_ID,
        TYPE,
        IPAM_MAD,
        IP,
        IP_END = '-',
        MAC,
        MAC_END = '-',
        IP6,
        IP6_END = '-',
      }) => {
        cy.contains('[data-cy=id]', AR_ID)
          .closest('[data-cy=ar]')
          .within(() => {
            cy.getBySel('type').contains(TYPE, { noMatchCase: false })

            IPAM_MAD &&
              cy.getBySel('ipam-mad').contains(IPAM_MAD, { noMatchCase: false })

            MAC && cy.getBySel('range-mac').contains(`MAC: ${MAC} | ${MAC_END}`)
            IP && cy.getBySel('range-ip').contains(`IP: ${IP} | ${IP_END}`)
            IP6 && cy.getBySel('range-ip6').contains(`IP6: ${IP6} | ${IP6_END}`)
          })
      }
    )
  })
}

Cypress.Commands.add('validateVNetAddresses', validateVNetAddresses)
