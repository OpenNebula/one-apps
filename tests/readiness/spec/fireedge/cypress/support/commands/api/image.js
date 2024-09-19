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

const XML_ROOT = 'IMAGE'
const XML_POOL_ROOT = 'IMAGE_POOL'
const REG_ID_FROM_ERROR = new RegExp(`${XML_ROOT} (\\d+)`)

/**
 * Retrieves information for all or part of the images in the pool.
 *
 * @param {object} qs - Query parameters
 * @param {number} [qs.filter] - Filter flag
 * @param {number} [qs.start] - Range start ID
 * @param {number} [qs.end] - Range end ID
 * @returns {Cypress.Chainable<object[]>} - A promise that resolves to the images information
 */
const getImages = (qs) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = addZoneRequestQuery(`${baseUrl}/api/imagepool/info`)

  return cy
    .request({ url, auth: { bearer: jwt }, qs })
    .its(`body.data.${XML_POOL_ROOT}`)
    .then((pool) => pool?.[XML_ROOT] || [])
    .then((pool) => (Array.isArray(pool) ? pool : [pool]))
}

/**
 * Retrieves information for the image.
 *
 * @param {string} id - Image id or name
 * @param {object} qs - Query parameters
 * @param {boolean} [qs.decrypt] - True to decrypt contained secrets (only admin)
 * @returns {Cypress.Chainable<object>}
 * A promise that resolves to the image information
 */
const getImage = (id, qs) => {
  if (typeof id === 'string' && isNaN(+id)) {
    // find vnet by name from pool if id is a string and not a number
    return getImages().then((pool) => pool.find((img) => img.NAME === id))
  }

  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = addZoneRequestQuery(`${baseUrl}/api/image/info/${id}`)

  return cy
    .request({ url, auth: { bearer: jwt }, qs })
    .its(`body.data.${XML_ROOT}`)
}

/**
 * Allocates a new image in OpenNebula.
 *
 * @param {object} body - Request body for the POST request
 * @param {object} body.template - An object  containing the template of the image
 * @param {string} body.datastore - The datastore ID
 * @param {boolean} [body.capacity] - `true` to avoid checking datastore capacity. Default: `false`
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to the image id
 */
const allocateImage = (body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = addZoneRequestQuery(`${baseUrl}/api/image/allocate`)

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
 * Deletes the given image from the pool.
 *
 * @param {string} id - Image id
 * @param {boolean} force - Force delete
 * @returns {Cypress.Chainable<Cypress.Response>}
 * A promise that resolves to image id
 */
const deleteImage = (id, force = false) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = addZoneRequestQuery(`${baseUrl}/api/image/delete/${id}`)

  return cy.request({
    method: 'DELETE',
    url,
    auth: { bearer: jwt },
    body: { force: force },
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
const changePermissionImage = (id, body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = addZoneRequestQuery(`${baseUrl}/api/image/chmod/${id}`)

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

Cypress.Commands.add('apiGetImages', getImages)
Cypress.Commands.add('apiGetImage', getImage)
Cypress.Commands.add('apiAllocateImage', allocateImage)
Cypress.Commands.add('apiDeleteImage', deleteImage)
Cypress.Commands.add('apiChmodImage', changePermissionImage)
