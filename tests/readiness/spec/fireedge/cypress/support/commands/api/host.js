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

const XML_ROOT = 'HOST'
const XML_POOL_ROOT = 'HOST_POOL'
const REG_ID_FROM_ERROR = new RegExp(`${XML_ROOT} (\\d+)`)

/**
 * Retrieves information for all or part of the hosts in the pool.
 *
 * @returns {Cypress.Chainable<object>}
 * A promise that resolves to the hosts information
 */
const getHosts = () => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/hostpool/info/`

  return cy
    .request({ url, auth: { bearer: jwt }, failOnStatusCode: false })
    .its(`body.data.${XML_POOL_ROOT}`)
    .then((pool) => pool?.[XML_ROOT] || [])
    .then((pool) => (Array.isArray(pool) ? pool : [pool]))
}

/**
 * Retrieves information for the host.
 *
 * @param {string} id - Host id or name
 * @returns {Cypress.Chainable<object>}
 * A promise that resolves to the host information
 */
const getHost = (id) => {
  if (typeof id === 'string' && isNaN(+id)) {
    // find host by name from pool if id is a string and not a number
    return getHosts().then((pool) => pool.find((host) => host.NAME === id))
  }

  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/host/info/${id}`

  return cy
    .request({ url, auth: { bearer: jwt }, failOnStatusCode: false })
    .its(`body.data.${XML_ROOT}`)
}

/**
 * Allocates a new host in OpenNebula.
 *
 * @param {object} body - Request body for the POST request
 * @param {string} body.hostname - Hostname of the machine we want to add
 * @param {string} body.imMad - The name of the information manager (im_mad_name)
 * @param {string} body.vmmMad - The name of the  manager mad name (vmm_mad_name)
 * @param {string} [body.cluster] - The cluster ID
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to host id
 */
const allocateHost = (body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/host/allocate/`

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
 * Deletes the given host from the pool.
 *
 * @param {string} id - Host id
 * @returns {Cypress.Chainable<Cypress.Response>}
 * A promise that resolves to host id
 */
const deleteHost = (id) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/host/delete/${id}`

  return cy.request({
    method: 'DELETE',
    url,
    auth: { bearer: jwt },
    failOnStatusCode: false,
  })
}

/**
 * Sets the status of the host.
 *
 * @param {string} id - Host id
 * @param {0|1} status - Host status (0 = enabled, 1 = disabled, 2 = offline)
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to host id
 */
const changeStatusHost = (id, status) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/host/status/${id}`

  return cy
    .request({
      method: 'PUT',
      url,
      auth: { bearer: jwt },
      body: { status },
      failOnStatusCode: false,
    })
    .then(({ isOkStatusCode, body: { data } }) =>
      isOkStatusCode ? data : data.match(REG_ID_FROM_ERROR)?.[1]
    )
}

/**
 * Sets the status of the host to enabled.
 *
 * @param {string} id - Host id
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to enabled host id
 */
const enableHost = (id) => changeStatusHost(id, 0)

/**
 * Sets the status of the host to disabled.
 *
 * @param {string} id - Host id
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to disabled host id
 */
const disableHost = (id) => changeStatusHost(id, 1)

/**
 * Sets the status of the host to disabled.
 *
 * @param {string} id - Host id
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to offline host id
 */
const offlineHost = (id) => changeStatusHost(id, 2)

Cypress.Commands.add('apiGetHosts', getHosts)
Cypress.Commands.add('apiGetHost', getHost)
Cypress.Commands.add('apiAllocateHost', allocateHost)
Cypress.Commands.add('apiDeleteHost', deleteHost)
Cypress.Commands.add('apiEnableHost', enableHost)
Cypress.Commands.add('apiDisableHost', disableHost)
Cypress.Commands.add('apiOfflineHost', offlineHost)
