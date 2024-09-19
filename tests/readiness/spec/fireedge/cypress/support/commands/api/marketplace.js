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

import { ENV } from '@commands/api'
import { jsonToXml } from '@commands/helpers'

const XML_ROOT = 'MARKETPLACE'
const XML_POOL_ROOT = 'MARKETPLACE_POOL'
const REG_ID_FROM_ERROR = new RegExp(`${XML_ROOT} (\\d+)`)

/**
 * Retrieves information for all or part of the markets in the pool.
 *
 * @returns {Cypress.Chainable} - A promise that resolves to the images information
 */
const getMarketplaces = () => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/marketpool/info/`

  return cy
    .request({ url, auth: { bearer: jwt } })
    .its(`body.data.${XML_POOL_ROOT}`)
    .then((pool) => pool?.[XML_ROOT] || [])
    .then((pool) => (Array.isArray(pool) ? pool : [pool]))
}

/**
 * Retrieves information for market.
 *
 * @param {string} id - market id
 * @param {object} qs - Query parameters
 * @param {boolean} [qs.decrypt] - True to decrypt contained secrets (only admin)
 * @returns {Cypress.Chainable} - A promise that resolves to the template information
 */
const getMarketplace = (id, qs) => {
  if (typeof id === 'string' && isNaN(+id)) {
    return getMarketplaces().then((pool) => {
      const arrayPool = !Array.isArray(pool) ? [pool] : pool

      return arrayPool.find((template) => template.NAME === id)
    })
  }

  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/market/info/${id}`

  return cy
    .request({ url, auth: { bearer: jwt }, qs })
    .its(`body.data.${XML_ROOT}`)
}

/**
 * Allocates a new marketplace in OpenNebula.
 *
 * @param {object} template - An object containing the template
 * @returns {Cypress.Chainable} - A promise that resolves to the market id
 */
const allocateMarket = (template) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/market/allocate/`

  return cy
    .request({
      method: 'POST',
      url,
      auth: { bearer: jwt },
      body: { template: jsonToXml({ ...template }) },
      failOnStatusCode: false,
    })
    .then(({ isOkStatusCode, body: { data } }) =>
      isOkStatusCode ? data : data.match(REG_ID_FROM_ERROR)?.[1]
    )
}

/**
 * Deletes the given marketplace from the pool.
 *
 * @param {string} id - marketplace id
 * @returns {Cypress.Chainable<Cypress.Response>}
 * A promise that resolves to marketplace id
 */
const deleteMarkeplace = (id) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/market/delete/${id}`

  return cy.request({
    method: 'DELETE',
    url,
    auth: { bearer: jwt },
    failOnStatusCode: false,
  })
}

Cypress.Commands.add('apiGetMarketplace', getMarketplace)
Cypress.Commands.add('apiGetMarketplaces', getMarketplaces)
Cypress.Commands.add('apiAllocateMarketplace', allocateMarket)
Cypress.Commands.add('apiDeleteMarketplace', deleteMarkeplace)
