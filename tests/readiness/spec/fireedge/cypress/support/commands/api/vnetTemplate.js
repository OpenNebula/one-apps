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

const XML_ROOT = 'VNTEMPLATE'
const XML_POOL_ROOT = 'VNTEMPLATE_POOL'
const REG_ID_FROM_ERROR = new RegExp(`${XML_ROOT} (\\d+)`)

/**
 * Retrieves information for all or part of the virtual network template in the pool.
 *
 * @param {object} qs - Query parameters
 * @param {number} [qs.filter] - Filter flag
 * @param {number} [qs.start] - Range start ID
 * @param {number} [qs.end] - Range end ID
 * @returns {Cypress.Chainable} - A promise that resolves to the virtual network information
 */
const getVNetTemplates = (qs) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/vntemplatepool/info/`

  return cy
    .request({ url, auth: { bearer: jwt }, qs, failOnStatusCode: false })
    .its(`body.data.${XML_POOL_ROOT}`)
    .then((pool) => pool?.[XML_ROOT] || [])
    .then((pool) => (Array.isArray(pool) ? pool : [pool]))
}

/**
 * Retrieves information for the virtual network template.
 *
 * @param {string} id - Virtual network template id or name
 * @param {object} qs - Query parameters
 * @param {boolean} [qs.decrypt] - True to decrypt contained secrets (only admin)
 * @returns {Cypress.Chainable} - A promise that resolves to the virtual network template information
 */
const getVNetTemplate = (id, qs) => {
  if (typeof id === 'string' && isNaN(+id)) {
    // find virtual network template by name from pool if id is a string and not a number
    return getVNetTemplates().then((pool) => pool.find((vn) => vn.NAME === id))
  }

  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/vntemplate/info/${id}`

  return cy
    .request({ url, auth: { bearer: jwt }, qs, failOnStatusCode: false })
    .its(`body.data.${XML_ROOT}`)
}

/**
 * Allocates a new virtual network template in OpenNebula.
 *
 * @param {object} body - Request body for the POST request
 * @param {object} body.template - An object containing the template of the virtual network template
 * @returns {Cypress.Chainable} - A promise that resolves to the virtual network template id
 */
const allocateVNetTemplate = (body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/vntemplate/allocate/`

  return cy
    .request({
      method: 'POST',
      url,
      auth: { bearer: jwt },
      body: { template: jsonToXml({ ...body }) },
      failOnStatusCode: false,
    })
    .then(({ isOkStatusCode, body: { data } }) =>
      isOkStatusCode ? data : data.match(REG_ID_FROM_ERROR)?.[1]
    )
}

/**
 * Replaces the virtual network template contents.
 *
 * @param {number|string} id - Virtual network template id
 * @param {object} body - Request body for the POST request
 * @param {string} body.template - The new Virtual network template contents
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to the Virtual network template id
 */
const updateVNetTemplate = (id, body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/vntemplate/update/${id}`

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
 * Deletes the given virtual network template from the pool.
 *
 * @param {string} id - Virtual network id
 * @returns {Cypress.Chainable<Cypress.Response>}
 * A promise that resolves to vnet id
 */
const deleteVNetTemplate = (id) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/vntemplate/delete/${id}`

  return cy.request({
    method: 'DELETE',
    url,
    auth: { bearer: jwt },
    failOnStatusCode: false,
  })
}

/**
 * Updates the permissions for a virtual network template in OpenNebula.
 *
 * @param {object} id - virtual network template id to update
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
const changePermissionVnetTemplate = (id, body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/vntemplate/chmod/${id}`

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

Cypress.Commands.add('apiGetVNetTemplates', getVNetTemplates)
Cypress.Commands.add('apiGetVNetTemplate', getVNetTemplate)
Cypress.Commands.add('apiAllocateVNetTemplate', allocateVNetTemplate)
Cypress.Commands.add('apiUpdateVNetTemplate', updateVNetTemplate)
Cypress.Commands.add('apiDeleteVNetTemplate', deleteVNetTemplate)
Cypress.Commands.add('apiChmodVNetTemplate', changePermissionVnetTemplate)
