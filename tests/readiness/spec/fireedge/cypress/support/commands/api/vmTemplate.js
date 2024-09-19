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

const XML_ROOT = 'VMTEMPLATE'
const XML_POOL_ROOT = 'VMTEMPLATE_POOL'
const REG_ID_FROM_ERROR = /TEMPLATE (\d+)/

/**
 * Retrieves information for all or part of the Resources in the pool.
 *
 * @param {object} qs - Query parameters
 * @param {number} [qs.filter] - Filter flag
 * @param {number} [qs.start] - Range start ID
 * @param {number} [qs.end] - Range end ID
 * @returns {Cypress.Chainable<object[]>}
 * A promise that resolves to the templates information
 */
const getTemplates = (qs) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = addZoneRequestQuery(`${baseUrl}/api/templatepool/info/`)

  return cy
    .request({ url, auth: { bearer: jwt }, qs })
    .its(`body.data.${XML_POOL_ROOT}`)
    .then((pool) => pool?.[XML_ROOT] || [])
    .then((pool) => (Array.isArray(pool) ? pool : [pool]))
}

/**
 * Retrieves information for the vm template.
 *
 * @param {string} id - Template id
 * @param {object} qs - Query parameters
 * @param {boolean} [qs.extended] - True to include extended information
 * @param {boolean} [qs.decrypt] - True to decrypt contained secrets (only admin)
 * @returns {Cypress.Chainable<object>}
 * A promise that resolves to the template information
 */
const getTemplate = (id, qs) => {
  if (typeof id === 'string' && isNaN(+id)) {
    // find template by name from pool if id is a string and not a number

    return getTemplates().then((pool) => pool.find((t) => t.NAME === id))
  }

  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = addZoneRequestQuery(`${baseUrl}/api/template/info/${id}`)

  return cy
    .request({ url, auth: { bearer: jwt }, qs })
    .its(`body.data.${XML_ROOT}`)
}

/**
 * Allocates a new VM Template in OpenNebula.
 *
 * @param {object} template - An object containing the template
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to the template id
 */
const allocateVmTemplate = (template) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = addZoneRequestQuery(`${baseUrl}/api/template/allocate`)

  return cy
    .request({
      method: 'PUT',
      url,
      auth: { bearer: jwt },
      body: { template: jsonToXml({ ...template }) },
      failOnStatusCode: false,
    })
    .then(({ isOkStatusCode, body: { data } }) =>
      isOkStatusCode ? data : data.match(REG_ID_FROM_ERROR)?.[1]
    )
}

/**
 * Replaces the template contents.
 *
 * @param {number|string} id - Template id
 * @param {object} body - Request body for the POST request
 * @param {string} body.template - The new template contents
 * @param {0|1} body.replace
 * - Update type:
 * `0`: Replace the whole template.
 * `1`: Merge new template with the existing one.
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to the template id
 */
const updateVmTemplate = (id, body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = addZoneRequestQuery(`${baseUrl}/api/template/update/${id}`)

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
 * Instantiates a new virtual machine from a template.
 *
 * @param {string} id - Template id
 * @param {object} body - Request body for the POST request
 * @param {string} body.name - Name for the new VM instance
 * @param {boolean} body.hold - True to create it on hold state. By default it is `false`
 * @param {boolean} body.persistent - True to create a private persistent copy. By default it is `false`
 * @param {object} body.template - Extra template to be merged with the one being instantiated
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to the instantiated VM id
 */
const instantiateVmTemplate = (id, body = {}) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = addZoneRequestQuery(`${baseUrl}/api/template/instantiate/${id}`)

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
 * Deletes the given VM template from the pool.
 *
 * @param {string} id - VM template id
 * @param {boolean} image - `true` to delete the template plus any image defined in DISK
 * @returns {Cypress.Chainable<Cypress.Response>}
 * A promise that resolves to template id
 */
const deleteVmTemplate = (id, image = false) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = addZoneRequestQuery(`${baseUrl}/api/template/delete/${id}`)

  return cy.request({
    method: 'DELETE',
    url,
    auth: { bearer: jwt },
    qs: { image },
    failOnStatusCode: false,
  })
}

const chmodVmTemplate = (id, permissions = {}) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = addZoneRequestQuery(`${baseUrl}/api/template/chmod/${id}`)

  return cy
    .request({
      method: 'PUT',
      url,
      auth: { bearer: jwt },
      body: permissions,
      failOnStatusCode: false,
    })
    .then(({ isOkStatusCode, body: { data } }) =>
      isOkStatusCode ? data : data.match(REG_ID_FROM_ERROR)?.[1]
    )
}

const chownVmTemplate = (id, userId) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = addZoneRequestQuery(`${baseUrl}/api/template/chown/${id}`)

  return cy
    .request({
      method: 'PUT',
      url,
      auth: { bearer: jwt },
      body: {
        user: userId,
      },
      failOnStatusCode: false,
    })
    .then(({ isOkStatusCode, body: { data } }) =>
      isOkStatusCode ? data : data.match(REG_ID_FROM_ERROR)?.[1]
    )
}

const chgrpVmTemplate = (id, groupId) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = addZoneRequestQuery(`${baseUrl}/api/template/chown/${id}`)

  return cy
    .request({
      method: 'PUT',
      url,
      auth: { bearer: jwt },
      body: {
        group: groupId,
      },
      failOnStatusCode: false,
    })
    .then(({ isOkStatusCode, body: { data } }) =>
      isOkStatusCode ? data : data.match(REG_ID_FROM_ERROR)?.[1]
    )
}

Cypress.Commands.add('apiGetVmTemplates', getTemplates)
Cypress.Commands.add('apiGetVmTemplate', getTemplate)
Cypress.Commands.add('apiAllocateVmTemplate', allocateVmTemplate)
Cypress.Commands.add('apiUpdateVmTemplate', updateVmTemplate)
Cypress.Commands.add('apiInstantiateVmTemplate', instantiateVmTemplate)
Cypress.Commands.add('apiDeleteVmTemplate', deleteVmTemplate)
Cypress.Commands.add('apiChmodVmtemplate', chmodVmTemplate)
Cypress.Commands.add('apiChownVmtemplate', chownVmTemplate)
Cypress.Commands.add('apiChgrpVmtemplate', chgrpVmTemplate)
