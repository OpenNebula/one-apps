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

const XML_ROOT = 'VMTEMPLATE'
const XML_ROOT_POOL = 'VMTEMPLATE_POOL'
const REG_ID_FROM_ERROR = new RegExp(`${XML_ROOT} (\\d+)`)

/**
 * Retrieves information for all or part of the VRouterTemplate in the pool.
 *
 * @param {object} qs - Query parameters
 * @param {number} [qs.filter] - Filter flag
 * @param {number} [qs.start] - Range start ID
 * @param {number} [qs.end] - Range end ID
 * @returns {Cypress.Chainable<object[]>} - A promise that resolves to the vrouter templates information
 */
const getVRouterTemplates = (qs) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/templatepool/info/`

  return cy
    .request({ url, auth: { bearer: jwt }, qs })
    .its(`body.data.${XML_ROOT_POOL}`)
    .then((pool) => pool?.[XML_ROOT] || [])
    .then((pool) => (Array.isArray(pool) ? pool : [pool]))
}

/**
 * Retrieves information for the VRouterTemplate.
 *
 * @param {string} id - VRouterTemplate id or name
 * @param {object} qs - Query parameters
 * @param {boolean} [qs.decrypt] - True to decrypt contained secrets (only admin)
 * @returns {Cypress.Chainable<object>}
 * A promise that resolves to the vrouter template information
 */
const getVRouterTemplate = (id, qs) => {
  if (typeof id === 'string' && isNaN(+id)) {
    return getVRouterTemplates().then((pool) =>
      pool.find((st) => st.NAME === id)
    )
  }

  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/template/info/${id}`

  return cy
    .request({ url, auth: { bearer: jwt }, qs })
    .its(`body.data.${XML_ROOT}`)
}

/**
 * Allocates a new vrouter template in OpenNebula.
 *
 * @param {object} body - Request body for the POST request
 * @param {object} body.template - An object  containing the template of the vrouter template
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to the vrouter template id
 */
const allocateVRouterTemplate = (body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/template/allocate/`

  return cy
    .request({
      method: 'PUT',
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
 * Deletes the given vrouter template from the pool.
 *
 * @param {string} id - vrouter template id
 * @returns {Cypress.Chainable<Cypress.Response>}
 * A promise that resolves to vrouter template id
 */
const deleteVRouterTemplate = (id) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/template/delete/${id}`

  return cy.request({
    method: 'DELETE',
    url,
    auth: { bearer: jwt },
    failOnStatusCode: false,
  })
}

/**
 * Updates the permissions for a vrouter template in OpenNebula.
 *
 * @param {object} id - vrouter template id to update
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
 * @returns {Cypress.Chainable} - A promise that resolves to the vrouter template id
 */
const changePermissionVRouterTemplate = (id, body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/template/chmod/${id}`

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

Cypress.Commands.add('apiGetVRouterTemplates', getVRouterTemplates)
Cypress.Commands.add('apiGetVRouterTemplate', getVRouterTemplate)
Cypress.Commands.add('apiAllocateVRouterTemplate', allocateVRouterTemplate)
Cypress.Commands.add('apiDeleteVRouterTemplate', deleteVRouterTemplate)
Cypress.Commands.add('apiChmodVRouterTemplate', changePermissionVRouterTemplate)
