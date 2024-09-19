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

const DOCUMENT_ROOT = 'DOCUMENT'
const DOCUMENT_ROOT_POOL = 'DOCUMENT_POOL'
const REG_ID_FROM_ERROR = new RegExp(`${DOCUMENT_ROOT} (\\d+)`)

/**
 * Retrieves information for all or part of the ServiceTemplate in the pool.
 *
 * @param {object} qs - Query parameters
 * @param {number} [qs.filter] - Filter flag
 * @param {number} [qs.start] - Range start ID
 * @param {number} [qs.end] - Range end ID
 * @returns {Cypress.Chainable<object[]>} - A promise that resolves to the service templates information
 */
const getServiceTemplates = (qs) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/service_template/`

  return cy
    .request({ url, auth: { bearer: jwt }, qs })
    .its(`body.data.${DOCUMENT_ROOT_POOL}`)
    .then((pool) => pool?.[DOCUMENT_ROOT] || [])
    .then((pool) => (Array.isArray(pool) ? pool : [pool]))
}

/**
 * Retrieves information for the ServiceTemplate.
 *
 * @param {string} id - ServiceTemplate id or name
 * @param {object} qs - Query parameters
 * @param {boolean} [qs.decrypt] - True to decrypt contained secrets (only admin)
 * @returns {Cypress.Chainable<object>}
 * A promise that resolves to the service template information
 */
const getServiceTemplate = (id, qs) => {
  if (typeof id === 'string' && isNaN(+id)) {
    return getServiceTemplates().then((pool) =>
      pool.find((st) => st.NAME === id)
    )
  }

  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/service_template/${id}`

  return cy
    .request({ url, auth: { bearer: jwt }, qs })
    .its(`body.data.${DOCUMENT_ROOT}`)
}

/**
 * Instantiates a new service in OpenNebula.
 *
 * @param {string} id - ServiceTemplate id or name
 * @param {object} body - Instantiate template body
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to the service template id
 */
const instantiateServiceTemplate = (id, body) => {
  if (typeof id === 'string' && isNaN(+id)) {
    return getServiceTemplates().then((pool) =>
      pool.find((st) => st.NAME === id)
    )
  }

  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/service_template/action/${id}`

  return cy
    .request({
      method: 'POST',
      url,
      auth: { bearer: jwt },
      body: { template: { ...body } },
      failOnStatusCode: false,
    })
    .then(({ isOkStatusCode, body: { data } }) =>
      isOkStatusCode ? data : data.match(REG_ID_FROM_ERROR)?.[1]
    )
}

/**
 * Allocates a new service template in OpenNebula.
 *
 * @param {object} body - Request body for the POST request
 * @param {object} body.template - An object  containing the template of the service template
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to the service template id
 */
const allocateServiceTemplate = (body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/service_template`

  return cy
    .request({
      method: 'POST',
      url,
      auth: { bearer: jwt },
      body: { template: { ...body } },
      failOnStatusCode: false,
    })
    .then(({ isOkStatusCode, body: { data } }) =>
      isOkStatusCode ? data : data.match(REG_ID_FROM_ERROR)?.[1]
    )
}

/**
 * Deletes the given service template from the pool.
 *
 * @param {string} id - service template id
 * @returns {Cypress.Chainable<Cypress.Response>}
 * A promise that resolves to service template id
 */
const deleteServiceTemplate = (id) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/service_template/${id}`

  return cy.request({
    method: 'DELETE',
    url,
    auth: { bearer: jwt },
    failOnStatusCode: false,
  })
}

/**
 * Updates the permissions for a service template in OpenNebula.
 *
 * @param {object} id - service template id to update
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
 * @returns {Cypress.Chainable} - A promise that resolves to the service template id
 */
const changePermissionServiceTemplate = (id, body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/service_template/action/${id}`

  return cy
    .request({
      method: 'POST',
      url,
      auth: { bearer: jwt },
      body: { ...body },
      failOnStatusCode: false,
    })
    .then(({ isOkStatusCode, body: { data } }) =>
      isOkStatusCode ? data : data.match(REG_ID_FROM_ERROR)?.[1]
    )
}

Cypress.Commands.add('apiGetServiceTemplates', getServiceTemplates)
Cypress.Commands.add('apiGetServiceTemplate', getServiceTemplate)
Cypress.Commands.add(
  'apiInstantiateServiceTemplate',
  instantiateServiceTemplate
)
Cypress.Commands.add('apiAllocateServiceTemplate', allocateServiceTemplate)
Cypress.Commands.add('apiDeleteServiceTemplate', deleteServiceTemplate)
Cypress.Commands.add('apiChmodServiceTemplate', changePermissionServiceTemplate)
