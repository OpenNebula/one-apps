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

const XML_ROOT = 'ACL'
const XML_POOL_ROOT = 'ACL_POOL'
const REG_ID_FROM_ERROR = new RegExp(`${XML_ROOT} (\\d+)`)

/**
 * Retrieves information for all or part of the acls in the pool.
 *
 * @returns {Cypress.Chainable} - A promise that resolves to the acls information
 */
const getAcls = () => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/acl/info/`

  return cy
    .request({ url, auth: { bearer: jwt } })
    .its(`body.data.${XML_POOL_ROOT}.${XML_ROOT}`)
    .then((pool) => (Array.isArray(pool) ? pool : [pool]))
}

/**
 * Retrieves information for one acl.
 *
 * @param {string} id - Group id or name
 * @returns {Cypress.Chainable} - A promise that resolves to the acl information
 */
const getAcl = (id) =>
  // ACL info returns all the rules so we can only filter by id
  getAcls().then((pool) => pool.find((acl) => acl.ID === id))

/**
 * Allocates a new acl in OpenNebula.
 *
 * @param {object} body - Body to send in the request
 * @returns {Cypress.Chainable}
 * A promise that resolves to the acl id
 */
const allocateAcl = (body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/acl/addrule`

  return cy
    .request({
      method: 'POST',
      url,
      auth: { bearer: jwt },
      body: body,
      failOnStatusCode: false,
    })
    .then(({ isOkStatusCode, body: { data } }) =>
      isOkStatusCode ? data : data.match(REG_ID_FROM_ERROR)?.[1]
    )
}

/**
 * Deletes the given acl from the pool.
 *
 * @param {string} id - Acl id
 * @returns {Cypress.Chainable<Cypress.Response>}
 * A promise that resolves to acl id
 */
const deleteAcl = (id) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/acl/delrule/${id}`

  return cy.request({
    method: 'DELETE',
    url,
    auth: { bearer: jwt },
    failOnStatusCode: false,
  })
}

Cypress.Commands.add('apiGetAcls', getAcls)
Cypress.Commands.add('apiGetAcl', getAcl)
Cypress.Commands.add('apiAllocateAcl', allocateAcl)
Cypress.Commands.add('apiDeleteAcl', deleteAcl)
