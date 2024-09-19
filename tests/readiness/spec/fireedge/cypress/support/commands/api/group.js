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

const XML_ROOT = 'GROUP'
const XML_POOL_ROOT = 'GROUP_POOL'
const REG_ID_FROM_ERROR = new RegExp(`${XML_ROOT} (\\d+)`)

/**
 * Retrieves information for all or part of the images in the pool.
 *
 * @returns {Cypress.Chainable} - A promise that resolves to the groups information
 */
const getGroups = () => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/grouppool/info/`

  return cy
    .request({ url, auth: { bearer: jwt } })
    .its(`body.data.${XML_POOL_ROOT}.${XML_ROOT}`)
    .then((pool) => (Array.isArray(pool) ? pool : [pool]))
}

/**
 * Retrieves information for the group.
 *
 * @param {string} id - Group id or name
 * @param {object} qs - Query parameters
 * @param {boolean} [qs.decrypt] - True to decrypt contained secrets (only admin)
 * @returns {Cypress.Chainable} - A promise that resolves to the group information
 */
const getGroup = (id, qs) => {
  if (typeof id === 'string' && isNaN(+id)) {
    return getGroups().then((pool) => pool.find((group) => group.NAME === id))
  }

  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/group/info/${id}`

  return cy
    .request({ url, auth: { bearer: jwt }, qs })
    .its(`body.data.${XML_ROOT}`)
}

/**
 * Allocates a new group in OpenNebula.
 *
 * @param {object} name - The name of the new group
 * @returns {Cypress.Chainable}
 * A promise that resolves to the group id
 */
const allocateGroup = (name) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/group/allocate`

  return cy
    .request({
      method: 'POST',
      url,
      auth: { bearer: jwt },
      body: { name },
      failOnStatusCode: false,
    })
    .then(({ isOkStatusCode, body: { data } }) =>
      isOkStatusCode ? data : data.match(REG_ID_FROM_ERROR)?.[1]
    )
}

/**
 * Deletes the given group from the pool.
 *
 * @param {string} id - Group id
 * @returns {Cypress.Chainable<Cypress.Response>}
 * A promise that resolves to group id
 */
const deleteGroup = (id) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/group/delete/${id}`

  return cy.request({
    method: 'DELETE',
    url,
    auth: { bearer: jwt },
    failOnStatusCode: false,
  })
}

Cypress.Commands.add('apiGetGroup', getGroup)
Cypress.Commands.add('apiGetGroups', getGroups)
Cypress.Commands.add('apiAllocateGroup', allocateGroup)
Cypress.Commands.add('apiDeleteGroup', deleteGroup)
