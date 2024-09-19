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

const XML_ROOT = 'VM_GROUP'
const XML_POOL_ROOT = 'VM_GROUP_POOL'
const REG_ID_FROM_ERROR = new RegExp(`${XML_ROOT} (\\d+)`)

/**
 * Retrieves information for all or part of the vmgroups in the pool.
 *
 * @param {object} qs - Query parameters
 * @param {number} [qs.filter] - Filter flag
 * @param {number} [qs.start] - Range start ID
 * @param {number} [qs.end] - Range end ID
 * @returns {Cypress.Chainable<object[]>} - A promise that resolves to the vmgroups information
 */
const getVmGroups = (qs) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/vmgrouppool/info/`

  return cy
    .request({ url, auth: { bearer: jwt }, qs })
    .its(`body.data.${XML_POOL_ROOT}`)
    .then((pool) => pool?.[XML_ROOT] || [])
    .then((pool) => (Array.isArray(pool) ? pool : [pool]))
}

/**
 * Retrieves information for the VmGroup.
 *
 * @param {string} id - VmGroup id or name
 * @param {object} qs - Query parameters
 * @param {boolean} [qs.decrypt] - True to decrypt contained secrets (only admin)
 * @returns {Cypress.Chainable<object>}
 * A promise that resolves to the vmgroup information
 */
const getVmGroup = (id, qs) => {
  if (typeof id === 'string' && isNaN(+id)) {
    return getVmGroups().then((pool) => pool.find((vmg) => vmg.NAME === id))
  }

  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/vmgroup/info/${id}`

  return cy
    .request({ url, auth: { bearer: jwt }, qs })
    .its(`body.data.${XML_ROOT}`)
}

/**
 * Allocates a new vmgroup in OpenNebula.
 *
 * @param {object} body - Request body for the POST request
 * @param {object} body.template - An object  containing the template of the vmgroup
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to the vmgroup id
 */
const allocateVmGroup = (body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/vmgroup/allocate/`

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
 * Deletes the given vmgroup from the pool.
 *
 * @param {string} id - Vmgroup id
 * @returns {Cypress.Chainable<Cypress.Response>}
 * A promise that resolves to vmgroup id
 */
const deleteVmgroup = (id) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/vmgroup/delete/${id}`

  return cy.request({
    method: 'DELETE',
    url,
    auth: { bearer: jwt },
    failOnStatusCode: false,
  })
}

/**
 * Updates the permissions for a vmgroup in OpenNebula.
 *
 * @param {object} id - VMGroup id to update
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
 * @returns {Cypress.Chainable} - A promise that resolves to the vmgroup id
 */
const changePermissionVmGroup = (id, body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/vmgroup/chmod/${id}`

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

Cypress.Commands.add('apiGetVmGroups', getVmGroups)
Cypress.Commands.add('apiGetVmGroup', getVmGroup)
Cypress.Commands.add('apiAllocateVmGroup', allocateVmGroup)
Cypress.Commands.add('apiDeleteVmGroup', deleteVmgroup)
Cypress.Commands.add('apiChmodVmGroup', changePermissionVmGroup)
