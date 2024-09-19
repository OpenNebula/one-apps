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

import { OpenNebulaResource } from '@models'

const IMAGE_STATES = [
  'INIT',
  'READY',
  'USED',
  'DISABLED',
  'LOCKED',
  'ERROR',
  'CLONE',
  'DELETE',
  'USED_PERS',
  'LOCKED_USED',
  'LOCKED_USED_PERS',
]

const IMAGE_TYPES = ['OS', 'CDROM', 'DATABLOCK', 'KERNEL', 'RAMDISK', 'CONTEXT']

class Image extends OpenNebulaResource {
  /** @returns {string} - The image state */
  get state() {
    return IMAGE_STATES[this.json.STATE]
  }

  /** @returns {boolean} - Whether the image is disabled */
  get isDisabled() {
    return this.state === 'DISABLED'
  }

  /** @returns {boolean} - Whether the image is ready */
  get isReady() {
    return this.state === 'READY'
  }

  /** @returns {boolean} - Whether the image is locked */
  get isLock() {
    return this.state === 'LOCKED'
  }

  /** @returns {boolean} - Whether the image is public */
  get isPublic() {
    return (
      this.json?.PERMISSIONS?.GROUP_U === '1' ||
      this.json?.PERMISSIONS?.OTHER_U === '1'
    )
  }

  /** @returns {string} - The image type */
  get type() {
    return IMAGE_TYPES[this.json.TYPE]
  }

  /**
   * Retrieves information for the image.
   *
   * @returns {Cypress.Chainable<object>}
   * - A promise that resolves to the image information
   */
  info() {
    const id = this.id ?? this.name

    return cy.apiGetImage(id).then((image) => {
      this.json = image

      return image
    })
  }

  /**
   * Allocates a new image in OpenNebula.
   *
   * @param {object} body - Request body for the POST request
   * @param {object} body.template - An object containing the template of the image
   * @param {string} body.datastore - The datastore ID
   * @param {boolean} [body.capacity] - `true` to avoid checking datastore capacity. Default: `false`
   * @returns {Cypress.Chainable<object>} A promise that resolves to the image information
   */
  allocate(body) {
    return cy
      .apiAllocateImage(body)
      .then((imageId) => {
        this.id = imageId
      })
      .then(
        () => cy.wait(20) // eslint-disable-line cypress/no-unnecessary-waiting
      )
      .then(() => this.info())
  }

  /**
   * @param {boolean} force - Force delete
   * @returns {Cypress.Chainable<Cypress.Response>}
   * A promise that resolves to the image id
   */
  delete(force = false) {
    return cy.apiDeleteImage(this.id, force)
  }

  /**
   * @param {string} state - The state to wait for
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves when the image reaches the state
   */
  waitState(state) {
    return cy.waitUntil(() => this.info().then(() => this.state === state))
  }

  /**
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves when the image is disabled
   */
  waitDisabled() {
    return this.waitState('DISABLED')
  }

  /**
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves when the image is ready
   */
  waitReady() {
    return this.waitState('READY')
  }

  /**
   * Updates the permissions for a virtual network in OpenNebula.
   *
   * @param {object} body - Request body for the PUT request
   * @param {object} body.id - Owner use permission
   * @param {object} body.ownerUse - Owner use permission
   * @param {string} body.ownerManage - Owner manage permission
   * @param {string} body.ownerAdmin - Owner admin permission
   * @param {string} body.groupUse - Group use permission
   * @param {string} body.groupManage - Group manage permission
   * @param {string} body.groupAdmin - Group admin permission
   * @param {string} body.otherUse - Other use permission
   * @param {string} body.otherManage - Other manage permission
   * @param {string} body.otherAdmin - OtherAdmin permission
   * @returns {Cypress.Chainable<object>} A promise that resolves to the vnet information
   */
  chmod(body) {
    return cy.apiChmodImage(this.id, body).then(() => this.info())
  }
}

export default Image
