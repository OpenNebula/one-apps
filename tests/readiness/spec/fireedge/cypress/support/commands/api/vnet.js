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

const XML_ROOT = 'VNET'
const XML_POOL_ROOT = 'VNET_POOL'
const REG_ID_FROM_ERROR = /NET (\d+)/

/**
 * Retrieves information for all or part of the vnets in the pool.
 *
 * @param {object} qs - Query parameters
 * @param {number} [qs.filter] - Filter flag
 * @param {number} [qs.start] - Range start ID
 * @param {number} [qs.end] - Range end ID
 * @returns {Cypress.Chainable} - A promise that resolves to the vnets information
 */
const getVNets = (qs) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/vnpool/info/`

  return cy
    .request({ url, auth: { bearer: jwt }, qs, failOnStatusCode: false })
    .its(`body.data.${XML_POOL_ROOT}`)
    .then((pool) => pool?.[XML_ROOT] || [])
    .then((pool) => (Array.isArray(pool) ? pool : [pool]))
}

/**
 * Retrieves information for the virtual network.
 *
 * @param {string} id - Virtual network id or name
 * @param {object} qs - Query parameters
 * @param {boolean} [qs.decrypt] - True to decrypt contained secrets (only admin)
 * @returns {Cypress.Chainable} - A promise that resolves to the vnet information
 */
const getVNet = (id, qs) => {
  if (typeof id === 'string' && isNaN(+id)) {
    // find vnet by name from pool if id is a string and not a number
    return getVNets().then((pool) => pool.find((vn) => vn.NAME === id))
  }

  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/vn/info/${id}`

  return cy
    .request({ url, auth: { bearer: jwt }, qs, failOnStatusCode: false })
    .its(`body.data.${XML_ROOT}`)
}

/**
 * Allocates a new virtual network in OpenNebula.
 *
 * @param {object} body - Request body for the POST request
 * @param {object} body.template - An object containing the template of the vnet
 * @param {string} body.cluster - The cluster ID. If it's -1, the default one will be used
 * @returns {Cypress.Chainable} - A promise that resolves to the vnet id
 */
const allocateVNet = (body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/vn/allocate/`

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
 * Deletes the given vnet from the pool.
 *
 * @param {string} id - Virtual network id
 * @returns {Cypress.Chainable<Cypress.Response>}
 * A promise that resolves to vnet id
 */
const deleteVNet = (id) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/vn/delete/${id}`

  return cy.request({
    method: 'DELETE',
    url,
    auth: { bearer: jwt },
    failOnStatusCode: false,
  })
}

/**
 * Updates the permissions for a virtual network in OpenNebula.
 *
 * @param {object} id - VNet id to update
 * @param {object} body - Request body for the PUT request
 * @param {object} body.ownerUse - Owner use permission
 * @param {string} body.ownerManage - Owner manage permission
 * @param {string} body.ownerAdmin - Owner admin permission
 * @param {string} body.groupUse - Group use permission
 * @param {string} body.groupManage - Group manage permission
 * @param {string} body.groupAdmin - Group admin permission
 * @param {string} body.otherUse - Other use permission
 * @param {string} body.otherManage - Other manage permission
 * @param {string} body.otherAdmin - OtherAdmin permission
 * @returns {Cypress.Chainable} - A promise that resolves to the vnet id
 */
const changePermissionVnet = (id, body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/vn/chmod/${id}`

  return cy
    .request({
      method: 'PUT',
      url,
      auth: { bearer: jwt },
      body: { ...body },
      failOnStatusCode: false,
    })
    .then(({ isOkStatusCode, body: { data } }) =>
      isOkStatusCode ? data : data.match(REG_ID_FROM_ERROR)?.[1]
    )
}

Cypress.Commands.add('apiGetVNets', getVNets)
Cypress.Commands.add('apiGetVNet', getVNet)
Cypress.Commands.add('apiAllocateVNet', allocateVNet)
Cypress.Commands.add('apiDeleteVNet', deleteVNet)
Cypress.Commands.add('apiChmodVNet', changePermissionVnet)
