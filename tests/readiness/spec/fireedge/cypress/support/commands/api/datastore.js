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

const XML_ROOT = 'DATASTORE'
const XML_POOL_ROOT = 'DATASTORE_POOL'
const REG_ID_FROM_ERROR = new RegExp(`${XML_ROOT} (\\d+)`)

/**
 * Retrieves information for all or part of the datastores in the pool.
 *
 * @returns {Cypress.Chainable} - A promise that resolves to the datastores information
 */
const getDatastores = () => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = addZoneRequestQuery(`${baseUrl}/api/datastorepool/info/`)

  return cy
    .request({ url, auth: { bearer: jwt } })
    .its(`body.data.${XML_POOL_ROOT}`)
    .then((pool) => pool?.[XML_ROOT] || [])
    .then((pool) => (Array.isArray(pool) ? pool : [pool]))
}

/**
 * Retrieves information for the datastore.
 *
 * @param {string|number} id - Datastore id or name
 * @param {object} qs - Query parameters
 * @param {boolean} [qs.decrypt] - Optional flag to decrypt contained secrets, valid only for admin
 * @returns {Cypress.Chainable} - A promise that resolves to the datastore information
 */
const getDatastore = (id, qs) => {
  if (typeof id === 'string' && isNaN(+id)) {
    // find datastore by name from pool if id is a string and not a number
    return getDatastores().then((pool) => pool.find((ds) => ds.NAME === id))
  }

  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = addZoneRequestQuery(`${baseUrl}/api/datastore/info/${id}`)

  return cy
    .request({ url, auth: { bearer: jwt }, qs })
    .its(`body.data.${XML_ROOT}`)
}

/**
 * Allocates a new datastore in OpenNebula.
 *
 * @param {object} body - Request body for the POST request
 * @param {object} body.template - An object containing the template of the image
 * @param {string} body.cluster - The cluster ID. If it's -1, the default one will be used
 * @returns {Cypress.Chainable} - A promise that resolves to the datastore id
 */
const allocateDatastore = (body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = addZoneRequestQuery(`${baseUrl}/api/datastore/allocate/`)

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
 * Deletes the given datastore from the pool.
 *
 * @param {string} id - Datastore id
 * @returns {Cypress.Chainable<Cypress.Response>}
 * A promise that resolves to datastore id
 */
const deleteDatastore = (id) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = addZoneRequestQuery(`${baseUrl}/api/datastore/delete/${id}`)

  return cy.request({
    method: 'DELETE',
    url,
    auth: { bearer: jwt },
    failOnStatusCode: false,
  })
}

Cypress.Commands.add('apiGetDatastores', getDatastores)
Cypress.Commands.add('apiGetDatastore', getDatastore)
Cypress.Commands.add('apiAllocateDatastore', allocateDatastore)
Cypress.Commands.add('apiDeleteDatastore', deleteDatastore)
