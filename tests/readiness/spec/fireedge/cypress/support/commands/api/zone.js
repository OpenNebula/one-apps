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
import { addZoneRequestQuery, jsonToXml } from '@commands/helpers'

const XML_ROOT = 'ZONE'
const XML_POOL_ROOT = 'ZONE_POOL'
const REG_ID_FROM_ERROR = new RegExp(`${XML_ROOT} (\\d+)`)

/**
 * Retrieves information for all or part of the zone in the pool.
 *
 * @returns {Cypress.Chainable<object>}
 * A promise that resolves to the zones information
 */
const getZones = () => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = addZoneRequestQuery(`${baseUrl}/api/zonepool/info/`)

  return cy
    .request({ url, auth: { bearer: jwt }, failOnStatusCode: false })
    .its(`body.data.${XML_POOL_ROOT}`)
    .then((pool) => pool?.[XML_ROOT] || [])
    .then((pool) => (Array.isArray(pool) ? pool : [pool]))
}

/**
 * Retrieves information for the zones.
 *
 * @param {string} id - Zone id or name
 * @returns {Cypress.Chainable<object>}
 * A promise that resolves to the zones information
 */
const getZone = (id) => {
  if (typeof id === 'string' && isNaN(+id)) {
    // find zones by name from pool if id is a string and not a number
    return getZones().then((pool) => pool.find((zones) => zones.NAME === id))
  }

  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = addZoneRequestQuery(`${baseUrl}/api/zone/info/${id}`)

  return cy
    .request({ url, auth: { bearer: jwt }, failOnStatusCode: false })
    .its(`body.data.${XML_ROOT}`)
}

/**
 * Allocates a new zone in OpenNebula.
 *
 * @param {object} body - Request body for the POST request
 * @param {string} [body.cluster] - The cluster ID
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to zone id
 */
const allocateZone = (body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/zone/allocate/`

  return cy
    .request({
      method: 'PUT',
      url,
      auth: { bearer: jwt },
      body,
      failOnStatusCode: false,
    })
    .then(({ isOkStatusCode, body: { data } }) =>
      isOkStatusCode ? data : data.match(REG_ID_FROM_ERROR)?.[1]
    )
}

/**
 * Replaces the zone contents.
 *
 * @param {number|string} id - Zone id
 * @param {object} body - Request body for the POST request
 * @param {string} body.template - The new template contents
 * @param {0|1} body.replace
 * - Update type:
 * `0`: Replace the whole template.
 * `1`: Merge new template with the existing one.
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to the template id
 */
const updateZone = (id, body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/zone/update/${id}`

  return cy
    .request({
      method: 'PUT',
      url,
      auth: { bearer: jwt },
      body: { ...body, template: jsonToXml({ ...body.template }) },
      failOnStatusCode: false,
    })
    .then(({ isOkStatusCode, body: { data } }) =>
      isOkStatusCode ? data : data.match(REG_ID_FROM_ERROR)?.[1]
    )
}

/**
 * Deletes the given zone from the pool.
 *
 * @param {string} id - Zone id
 * @returns {Cypress.Chainable<Cypress.Response>}
 * A promise that resolves to Zone id
 */
const deleteZone = (id) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/zone/delete/${id}`

  return cy.request({
    method: 'DELETE',
    url,
    auth: { bearer: jwt },
    failOnStatusCode: false,
  })
}

Cypress.Commands.add('apiGetZones', getZones)
Cypress.Commands.add('apiGetZone', getZone)
Cypress.Commands.add('apiAllocateZone', allocateZone)
Cypress.Commands.add('apiUpdateZone', updateZone)
Cypress.Commands.add('apiDeleteZone', deleteZone)
