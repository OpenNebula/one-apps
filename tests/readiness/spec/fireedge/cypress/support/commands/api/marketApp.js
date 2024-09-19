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

const XML_ROOT = 'MARKETPLACEAPP'
const XML_POOL_ROOT = 'MARKETPLACEAPP_POOL'
const REG_ID_FROM_ERROR = new RegExp(`${XML_ROOT} (\\d+)`)
const REG_ID_MARKETAPP = /VMTEMPLATE\s.*ID: (?<vmtemplate>\d+)/
const REG_ID_MARKETAPP_IMAGE = /IMAGE\s.*ID: (?<image>\d+)/
const REG_DELETE_LINE_BREAK = /\s+/g

/**
 * Retrieves information for all or part of the apps in the pool.
 *
 * @param {object} qs - Query parameters
 * @param {number} [qs.filter] - Filter flag
 * @param {number} [qs.start] - Range start ID
 * @param {number} [qs.end] - Range end ID
 * @returns {Cypress.Chainable<object[]>}
 * A promise that resolves to the apps information
 */
const getMarketplaceApps = (qs) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = addZoneRequestQuery(`${baseUrl}/api/marketapppool/info/`)

  return cy
    .request({ url, auth: { bearer: jwt }, qs })
    .its(`body.data.${XML_POOL_ROOT}`)
    .then((pool) => pool?.[XML_ROOT] || [])
    .then((pool) => (Array.isArray(pool) ? pool : [pool]))
}

/**
 * Retrieves information for the marketplace app.
 *
 * @param {string} id - App id or name
 * @returns {Cypress.Chainable<object>}
 * A promise that resolves to the app information
 */
const getMarketplaceApp = (id) => {
  if (typeof id === 'string' && isNaN(+id)) {
    // find vnet by name from pool if id is a string and not a number
    return getMarketplaceApps().then((pool) =>
      pool.find((app) => app.NAME === id)
    )
  }

  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = addZoneRequestQuery(`${baseUrl}/api/marketapp/info/${id}`)

  return cy.request({ url, auth: { bearer: jwt } }).its(`body.data.${XML_ROOT}`)
}

/**
 * Replaces the App template contents.
 *
 * @param {number|string} id - Marketplace app id
 * @param {object} body - Request body for the POST request
 * @param {string} body.template - The new template contents
 * @param {0|1} body.replace
 * - Update type:
 * `0`: Replace the whole template.
 * `1`: Merge new template with the existing one.
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to the marketplace app id
 */
const updateMarketplaceApp = (id, body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = addZoneRequestQuery(`${baseUrl}/api/marketapp/update/${id}`)

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
 * Allocates a new marketapp in OpenNebula.
 *
 * @param {number|string} id - Marketplace app id
 * @param {object} body - Request body for the POST request
 * @param {object} body.ORIGIN_ID - image id
 * @param {string} body.NAME - marketapp name
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to the marketapp
 */
const allocateMarketplaceApp = (id, body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = addZoneRequestQuery(`${baseUrl}/api/marketapp/allocate/${id}`)

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
 * Export a marketapp in OpenNebula.
 *
 * @param {number|string} id - Marketplace app id
 * @param {object} body - Request body for the POST request
 * @param {object} body.associated - associated
 * @param {string} body.datastore - datastore id
 * @param {string} body.name - app name
 * @param {string} body.vmname - vm name
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to the marketapp
 */
const exportMarketplaceApp = (id, body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = addZoneRequestQuery(`${baseUrl}/api/marketapp/export/${id}`)

  return cy
    .request({
      method: 'POST',
      url,
      auth: { bearer: jwt },
      body: { ...body },
      failOnStatusCode: false,
    })
    .then(({ body: { data } }) => {
      const dataWithoutLineBreaks = data
        .replace(REG_DELETE_LINE_BREAK, ' ')
        .trim()

      return {
        image: REG_ID_MARKETAPP_IMAGE.exec(dataWithoutLineBreaks)?.groups
          ?.image,
        template: REG_ID_MARKETAPP.exec(dataWithoutLineBreaks)?.groups
          ?.vmtemplate,
      }
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
const changePermissionMarketApp = (id, body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = addZoneRequestQuery(`${baseUrl}/api/marketapp/chmod/${id}`)

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

Cypress.Commands.add('apiGetMarketplaceApps', getMarketplaceApps)
Cypress.Commands.add('apiGetMarketplaceApp', getMarketplaceApp)
Cypress.Commands.add('apiUpdateMarketplaceApp', updateMarketplaceApp)
Cypress.Commands.add('apiAllocateMarketplaceApp', allocateMarketplaceApp)
Cypress.Commands.add('apiExportMarketplaceApp', exportMarketplaceApp)
Cypress.Commands.add('apiChmodMarketplaceApp', changePermissionMarketApp)
