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

const XML_ROOT = 'BACKUPJOB'
const XML_POOL_ROOT = 'BACKUPJOB_POOL'
const REG_ID_FROM_ERROR = /^\[one\.backupjob\.(?:\w+)?\] .* (\d+)/

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
const getBackupJobs = (qs) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/backupjobpool/info/`

  return cy
    .request({ url, auth: { bearer: jwt }, qs })
    .its(`body.data.${XML_POOL_ROOT}`)
    .then((pool) => pool?.[XML_ROOT] || [])
    .then((pool) => (Array.isArray(pool) ? pool : [pool]))
}

/**
 * Retrieves information for the Backup Job.
 *
 * @param {string} id - Template id
 * @param {object} qs - Query parameters
 * @returns {Cypress.Chainable<object>}
 * A promise that resolves to the template information
 */
const getBackupJob = (id, qs) => {
  if (typeof id === 'string' && isNaN(+id)) {
    // find Backup Job by name from pool if id is a string and not a number
    return getBackupJobs().then((pool) => pool.find((t) => t.NAME === id))
  }

  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/backupjob/info/${id}`

  return cy
    .request({ url, auth: { bearer: jwt }, qs })
    .its(`body.data.${XML_ROOT}`)
}

/**
 * Allocates a new Backup Job in OpenNebula.
 *
 * @param {object} template - An object containing the template
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to the template id
 */
const allocateBackupJob = (template) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/backupjob/allocate`

  return cy
    .request({
      method: 'POST',
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
 * Replaces the backupjob contents.
 *
 * @param {number|string} id - backupjob id
 * @param {object} body - Request body for the POST request
 * @param {string} body.template - The new template contents
 * @param {0|1} body.replace
 * - Update type:
 * `0`: Replace the whole template.
 * `1`: Merge new template with the existing one.
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to the template id
 */
const updateBackupJob = (id, body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/backupjob/update/${id}`

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
 * @param {string} id - BackupJob id
 * @returns {Cypress.Chainable<Cypress.Response>}
 * A promise that resolves to template id
 */
const deleteBackupJob = (id) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/backupjob/delete/${id}`

  return cy.request({
    method: 'DELETE',
    url,
    auth: { bearer: jwt },
    failOnStatusCode: false,
  })
}

const chmodBackupJob = (id, permissions = {}) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/backupjob/chmod/${id}`

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

const chownBackupJob = (id, user) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/backupjob/chown/${id}`

  return cy
    .request({
      method: 'PUT',
      url,
      auth: { bearer: jwt },
      body: { user },
      failOnStatusCode: false,
    })
    .then(({ body: { data } }) => data)
}

Cypress.Commands.add('apiGetBackupJobs', getBackupJobs)
Cypress.Commands.add('apiGetBackupJob', getBackupJob)
Cypress.Commands.add('apiAllocateBackupJob', allocateBackupJob)
Cypress.Commands.add('apiUpdateBackupJob', updateBackupJob)
Cypress.Commands.add('apiDeleteBackupJob', deleteBackupJob)
Cypress.Commands.add('apiChmodBackupJob', chmodBackupJob)
Cypress.Commands.add('apiChownBackupJob', chownBackupJob)
