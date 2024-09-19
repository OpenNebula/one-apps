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

const XML_ROOT = 'USER'
const XML_POOL_ROOT = 'USER_POOL'
const REG_ID_FROM_ERROR = new RegExp(`${XML_ROOT} (\\d+)`)

/**
 * Retrieves information for all or part of the users in the pool.
 *
 * @returns {Cypress.Chainable} - A promise that resolves to the user information
 */
const getUsers = () => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/userpool/info/`

  return cy
    .request({ url, auth: { bearer: jwt } })
    .its(`body.data.${XML_POOL_ROOT}.${XML_ROOT}`)
    .then((pool) => (Array.isArray(pool) ? pool : [pool]))
}

/**
 * Retrieves information for the User.
 *
 * @param {string} id - User id or name
 * @param {object} qs - Query parameters
 * @param {boolean} [qs.decrypt] - True to decrypt contained secrets (only admin)
 * @returns {Cypress.Chainable} - A promise that resolves to the user information
 */
const getUser = (id, qs) => {
  if (typeof id === 'string' && isNaN(+id)) {
    return getUsers().then((pool) => pool.find((user) => user.NAME === id))
  }

  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/user/info/${id}`

  return cy
    .request({ url, auth: { bearer: jwt }, qs })
    .its(`body.data.${XML_ROOT}`)
}

/**
 * Allocates a new user in OpenNebula.
 *
 * @param {object} body - Request body for the POST request
 * @param {string} body.username - Username for the new user
 * @param {string} body.password - Password for the new user
 * @param {string} [body.driver] - Authentication driver for the new user
 * @param {string[]} [body.group] - Array of Group IDs
 * @returns {Cypress.Chainable} - A promise that resolves to the user id
 */
const allocateUser = (body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/user/allocate`

  return cy
    .request({
      method: 'POST',
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
 * Replaces the User template contents.
 *
 * @param {number|string} id - User id
 * @param {object} body - Request body for the POST request
 * @param {string} body.template - The new template contents
 * @param {0|1} body.replace
 * - Update type:
 * `0`: Replace the whole template.
 * `1`: Merge new template with the existing one.
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to the user id
 */
const updateUser = (id, body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/user/update/${id}`

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
 * Deletes the given user from the pool.
 *
 * @param {string} id - User id
 * @returns {Cypress.Chainable<Cypress.Response>}
 * A promise that resolves to user id
 */
const deleteUser = (id) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/user/delete/${id}`

  return cy.request({
    method: 'DELETE',
    url,
    auth: { bearer: jwt },
    failOnStatusCode: false,
  })
}

/**
 * Retrieves QR 2fa information.
 *
 * @returns {Cypress.Chainable} - A promise that resolves to the user information
 */
const getQr = () => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/tfa`

  return cy.request({ url, auth: { bearer: jwt } }).its('body.data.img')
}

/**
 * Set 2FA to user.
 *
 * @param {string} token - authentication six-digit code
 * @returns {Cypress.Chainable} - A promise that resolves to the user information
 */
const set2fa = (token) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/tfa`

  return cy
    .request({
      method: 'POST',
      url,
      auth: { bearer: jwt },
      body: { token },
      failOnStatusCode: false,
    })
    .then(({ body: requestBody }) => requestBody)
}

/**
 * Delete 2FA to user.
 *
 * @returns {Cypress.Chainable} - A promise that resolves to the user information
 */
const del2fa = () => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/tfa`

  return cy
    .request({
      method: 'DELETE',
      url,
      auth: { bearer: jwt },
      failOnStatusCode: false,
    })
    .then(({ body: requestBody }) => requestBody)
}

Cypress.Commands.add('apiGetUser', getUser)
Cypress.Commands.add('apiGetUsers', getUsers)
Cypress.Commands.add('apiAllocateUser', allocateUser)
Cypress.Commands.add('apiUpdateUser', updateUser)
Cypress.Commands.add('apiDeleteUser', deleteUser)

Cypress.Commands.add('apiUserGet2faQr', getQr)
Cypress.Commands.add('apiSetTfa', set2fa)
Cypress.Commands.add('apiDeleteTfa', del2fa)
