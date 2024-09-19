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

const DS_STATES = ['READY', 'DISABLED']
const DS_TYPES = ['IMAGE', 'SYSTEM', 'FILE']

class Datastore extends OpenNebulaResource {
  /** @returns {string} - The datastore state */
  get state() {
    return DS_STATES[this.json.STATE]
  }

  /** @returns {boolean} - Whether the datastore is disabled */
  get isDisabled() {
    return this.state === 'DISABLED'
  }

  /** @returns {boolean} - Whether the datastore is ready */
  get isReady() {
    return this.state === 'READY'
  }

  /** @returns {string} - The datastore type */
  get type() {
    return DS_TYPES[this.json.TYPE]
  }

  /**
   * Retrieves information for the datastore.
   *
   * @returns {Cypress.Chainable<object>}
   * - A promise that resolves to the datastore information
   */
  info() {
    const id = this.id ?? this.name

    return cy.apiGetDatastore(id).then((ds) => {
      this.json = ds

      return ds
    })
  }

  /**
   * Allocates a new datastore in OpenNebula.
   *
   * @param {object} body - Request body for the POST request
   * @param {object} body.template - An object containing the template of the datastore
   * @param {string} [body.cluster] - The cluster ID. If it's -1, the default one will be used
   * @returns {Cypress.Chainable<object>} A promise that resolves to the datastore information
   */
  allocate(body) {
    return cy.apiAllocateDatastore(body).then((dsId) => {
      this.id = dsId

      return this.info()
    })
  }

  /**
   * @returns {Cypress.Chainable<Cypress.Response>}
   * A promise that resolves to the datastore id
   */
  delete() {
    return cy.apiDeleteDatastore(this.id).then((response) => {
      response?.isOkStatusCode && (this.json.STATE = 4) // DONE

      return response
    })
  }

  /**
   * @param {string} state - The state to wait for
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves when the datastore reaches the state
   */
  waitState(state) {
    return cy.waitUntil(() => this.info().then(() => this.state === state))
  }

  /**
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves when the datastore is disabled
   */
  waitDisabled() {
    return this.waitState('DISABLED')
  }

  /**
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves when the datastore is ready
   */
  waitReady() {
    return this.waitState('READY')
  }
}

export default Datastore
