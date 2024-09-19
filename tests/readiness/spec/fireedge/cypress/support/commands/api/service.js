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
 * Retrieves information for all or part of the Service in the pool.
 *
 * @param {object} qs - Query parameters
 * @param {number} [qs.filter] - Filter flag
 * @param {number} [qs.start] - Range start ID
 * @param {number} [qs.end] - Range end ID
 * @returns {Cypress.Chainable<object[]>} - A promise that resolves to the service information
 */
const getServices = (qs) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/service/`

  return cy
    .request({ url, auth: { bearer: jwt }, qs })
    .its(`body.data.${DOCUMENT_ROOT_POOL}`)
    .then((pool) => pool?.[DOCUMENT_ROOT] || [])
    .then((pool) => (Array.isArray(pool) ? pool : [pool]))
}

/**
 * Retrieves information for the Service.
 *
 * @param {string} id - Service id or name
 * @param {object} qs - Query parameters
 * @param {boolean} [qs.decrypt] - True to decrypt contained secrets (only admin)
 * @returns {Cypress.Chainable<object>}
 * A promise that resolves to the service information
 */
const getService = (id, qs) => {
  if (typeof id === 'string' && isNaN(+id)) {
    return getServices().then((pool) => pool.find((st) => st.NAME === id))
  }

  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/service/${id}`

  return cy
    .request({ url, auth: { bearer: jwt }, qs })
    .its(`body.data.${DOCUMENT_ROOT}`)
}

/**
 * Deletes the given service from the pool.
 *
 * @param {string} id - service id
 * @returns {Cypress.Chainable<Cypress.Response>}
 * A promise that resolves to service id
 */
const deleteService = (id) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/service/action/${id}`

  return cy.request({
    method: 'POST',
    url,
    auth: { bearer: jwt },
    body: {
      action: {
        params: {
          delete: true,
        },
        perform: 'recover',
      },
    },
    failOnStatusCode: false,
  })
}

/**
 * Updates the permissions for a service in OpenNebula.
 *
 * @param {object} id - service id to update
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
 * @returns {Cypress.Chainable} - A promise that resolves to the service id
 */
const changePermissionService = (id, body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/service/action/${id}`

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

Cypress.Commands.add('apiGetServices', getServices)
Cypress.Commands.add('apiGetService', getService)
Cypress.Commands.add('apiDeleteService', deleteService)
Cypress.Commands.add('apiChmodService', changePermissionService)
