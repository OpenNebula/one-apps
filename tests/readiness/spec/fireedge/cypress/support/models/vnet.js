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

const VNET_STATES = [
  'INIT',
  'READY',
  'LOCK_CREATE',
  'LOCK_DELETE',
  'DONE',
  'ERROR',
]

class VNet extends OpenNebulaResource {
  /** @returns {string} The vnet state */
  get state() {
    return VNET_STATES[this.json.STATE]
  }

  /** @returns {boolean} Whether the vnet is done */
  get isDone() {
    return this.state === 'DONE'
  }

  /** @returns {boolean} Whether the vnet is ready */
  get isReady() {
    return this.state === 'READY'
  }

  /** @returns {boolean} Whether the vnet is error */
  get isError() {
    return this.state === 'ERROR'
  }

  /** @returns {object[]} Address ranges */
  get addresses() {
    return [this.json?.AR_POOL?.AR ?? []].flat()
  }

  /**
   * Retrieves information for the vnet.
   *
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves to the vnet information
   */
  info() {
    const id = this.id ?? this.name

    return cy.apiGetVNet(id).then((vnet) => {
      this.json = vnet

      return vnet
    })
  }

  /**
   * Allocates a new virtual network in OpenNebula.
   *
   * @param {object} body - Request body for the POST request
   * @param {object} body.template - An object containing the template of the vnet
   * @param {string} [body.cluster] - The cluster ID. If it's -1, the default one will be used
   * @returns {Cypress.Chainable<object>} A promise that resolves to the vnet information
   */
  allocate(body) {
    return cy.apiAllocateVNet(body).then((vnId) => {
      this.id = vnId

      return this.info()
    })
  }

  /**
   * @returns {Cypress.Chainable<Cypress.Response>}
   * A promise that resolves to the vnet id
   */
  delete() {
    return cy.apiDeleteVNet(this.id).then((response) => {
      response?.isOkStatusCode && (this.json.STATE = 4) // DONE

      return response
    })
  }

  /**
   * @param {string} state - The state to wait for
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves when the vnet reaches the state
   */
  waitState(state) {
    return cy.waitUntil(() => this.info().then(() => this.state === state))
  }

  /**
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves when the vnet is done
   */
  waitDone() {
    return cy.waitUntil(() =>
      cy.apiGetVNets().then((pool) => !pool.some((vn) => vn.ID === this.id))
    )
  }

  /**
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves when the vnet is ready
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
    return cy.apiChmodVNet(this.id, body).then(() => this.info())
  }
}

export default VNet
