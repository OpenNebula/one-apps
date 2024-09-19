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

import { OpenNebulaResource } from '@models'

class Marketplace extends OpenNebulaResource {
  /** @returns {string[]} - List of Marketplaces Apps */
  get apps() {
    return [this.json?.MARKETPLACEAPPS?.ID ?? []].flat()
  }

  /**
   * Retrieves information for the marketplace.
   *
   * @returns {Cypress.Chainable<object>}
   * - A promise that resolves to the market information
   */
  info() {
    const id = this.id ?? this.name

    return cy.apiGetMarketplace(id).then((market) => {
      this.json = market

      return market
    })
  }

  /**
   * Allocates a new marketplace in OpenNebula.
   *
   * @param {object} [template] - An object containing the template
   * @returns {Cypress.Chainable<object>} A promise that resolves to the market information
   */
  allocate(template) {
    return cy.apiAllocateMarketplace(template).then((marketId) => {
      this.id = marketId

      return this.info()
    })
  }
}

export default Marketplace
