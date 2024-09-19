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

const XML_ROOT = 'SECURITY_GROUP'
const XML_POOL_ROOT = 'SECURITY_GROUP_POOL'
const REG_ID_FROM_ERROR = new RegExp(`${XML_ROOT} (\\d+)`)

/**
 * Retrieves information for all or part of the Security Groups in the pool.
 *
 * @param {object} qs - Query parameters
 * @param {number} [qs.filter] - Filter flag
 * @param {number} [qs.start] - Range start ID
 * @param {number} [qs.end] - Range end ID
 * @returns {Cypress.Chainable} - A promise that resolves to the Security Groups information
 */
const getSecGroups = (qs) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/secgrouppool/info/`

  return cy
    .request({ url, auth: { bearer: jwt }, qs })
    .its(`body.data.${XML_POOL_ROOT}`)
    .then((pool) => pool?.[XML_ROOT] || [])
    .then((pool) => (Array.isArray(pool) ? pool : [pool]))
}

/**
 * Retrieves information for the Security Group.
 *
 * @param {string|number} id - Security Group id or name
 * @param {object} qs - Query parameters
 * @param {boolean} [qs.decrypt] - Optional flag to decrypt contained secrets, valid only for admin
 * @returns {Cypress.Chainable} - A promise that resolves to the Security Group information
 */
const getSecGroup = (id, qs) => {
  if (typeof id === 'string' && isNaN(+id)) {
    // find Security Group by name from pool if id is a string and not a number
    return getSecGroups().then((pool) => pool.find((sg) => sg.NAME === id))
  }

  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/secgroup/info/${id}`

  return cy
    .request({ url, auth: { bearer: jwt }, qs })
    .its(`body.data.${XML_ROOT}`)
}

/**
 * Allocates a new Security Group in OpenNebula.
 *
 * @param {object} body - Request body for the POST request
 * @param {object} body.template - An object containing the template of the Security Group
 * @returns {Cypress.Chainable} - A promise that resolves to the Security Group id
 */
const allocateSecGroup = (body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/secgroup/allocate/`

  return cy
    .request({
      method: 'POST',
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
 * Deletes the given Security Group from the pool.
 *
 * @param {string} id - Security Group id
 * @returns {Cypress.Chainable<Cypress.Response>}
 * A promise that resolves to Security Group id
 */
const deleteSecGroup = (id) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/secgroup/delete/${id}`

  return cy.request({
    method: 'DELETE',
    url,
    auth: { bearer: jwt },
    failOnStatusCode: false,
  })
}

Cypress.Commands.add('apiGetSecGroups', getSecGroups)
Cypress.Commands.add('apiGetSecGroup', getSecGroup)
Cypress.Commands.add('apiAllocateSecGroup', allocateSecGroup)
Cypress.Commands.add('apiDeleteSecGroup', deleteSecGroup)
