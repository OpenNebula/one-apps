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

const XML_ROOT = 'CLUSTER'
const XML_POOL_ROOT = 'CLUSTER_POOL'
const REG_ID_FROM_ERROR = new RegExp(`${XML_ROOT} (\\d+)`)

/**
 * Retrieves information for all or part of the cluster in the pool.
 *
 * @returns {Cypress.Chainable<object>}
 * A promise that resolves to the cluster information
 */
const getClusters = () => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/clusterpool/info/`

  return cy
    .request({ url, auth: { bearer: jwt }, failOnStatusCode: false })
    .its(`body.data.${XML_POOL_ROOT}`)
    .then((pool) => pool?.[XML_ROOT] || [])
    .then((pool) => (Array.isArray(pool) ? pool : [pool]))
}

/**
 * Retrieves information for the cluster.
 *
 * @param {string} id - Cluster id or name
 * @returns {Cypress.Chainable<object>}
 * A promise that resolves to the cluster information
 */
const getCluster = (id) => {
  if (typeof id === 'string' && isNaN(+id)) {
    // find host by name from pool if id is a string and not a number
    return getClusters().then((pool) => pool.find((host) => host.NAME === id))
  }

  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/cluster/info/${id}`

  return cy
    .request({ url, auth: { bearer: jwt }, failOnStatusCode: false })
    .its(`body.data.${XML_ROOT}`)
}

/**
 * Allocates a new cluster in OpenNebula.
 *
 * @param {object} body - Request body for the POST request
 * @param {string} body.name - Hostname of the machine we want to add
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to host id
 */
const allocateCluster = (body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/cluster/allocate/`

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
 * Deletes the given cluster from the pool.
 *
 * @param {string} id - cluster id
 * @returns {Cypress.Chainable<Cypress.Response>}
 * A promise that resolves to host id
 */
const deleteCluster = (id) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/cluster/delete/${id}`

  return cy.request({
    method: 'DELETE',
    url,
    auth: { bearer: jwt },
    failOnStatusCode: false,
  })
}

/**
 * Add a host to a cluster.
 *
 * @param {string} id - Cluster id
 * @param {object} body - Host
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to cluster information
 */
const apiAddHostCluster = (id, body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/cluster/addhost/${id}`

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
 * Add a vnet to a cluster.
 *
 * @param {string} id - Cluster id
 * @param {object} body - VNet
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to cluster information
 */
const apiAddVNetCluster = (id, body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/cluster/addvnet/${id}`

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
 * Add a datastore to a cluster.
 *
 * @param {string} id - Cluster id
 * @param {object} body - Datastore
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to cluster information
 */
const apiAddDatastoreCluster = (id, body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/cluster/adddatastore/${id}`

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

Cypress.Commands.add('apiGetClusters', getClusters)
Cypress.Commands.add('apiGetCluster', getCluster)
Cypress.Commands.add('apiAllocateCluster', allocateCluster)
Cypress.Commands.add('apiDeleteCluster', deleteCluster)
Cypress.Commands.add('apiAddHostCluster', apiAddHostCluster)
Cypress.Commands.add('apiAddVNetCluster', apiAddVNetCluster)
Cypress.Commands.add('apiAddDatastoreCluster', apiAddDatastoreCluster)
