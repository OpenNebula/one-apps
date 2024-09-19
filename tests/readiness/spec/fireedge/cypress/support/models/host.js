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

const HOST_STATES = [
  'INIT',
  'MONITORING_MONITORED',
  'MONITORED',
  'ERROR',
  'DISABLED',
  'MONITORING_ERROR',
  'MONITORING_INIT',
  'MONITORING_DISABLED',
  'OFFLINE',
]

class Host extends OpenNebulaResource {
  /** @returns {string} The host state */
  get state() {
    return HOST_STATES[this.json.STATE]
  }

  /** @returns {boolean} Whether the host is disabled */
  get isDisabled() {
    return this.state === 'DISABLED'
  }

  /** @returns {boolean} Whether the host is monitored */
  get isMonitored() {
    return this.state === 'MONITORED'
  }

  /** @returns {boolean} List of Numa nodes from host */
  get numaNodes() {
    return [this.json?.HOST_SHARE?.NUMA_NODES?.NODE ?? []].flat()
  }

  /**
   * Retrieves information for the host.
   *
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves to the host information
   */
  info() {
    const id = this.id || this.name

    return cy.apiGetHost(id).then((host) => {
      this.json = host

      return host
    })
  }

  /**
   * Allocates a new host in OpenNebula.
   *
   * @param {object} body - Request body for the POST request
   * @param {string} body.hostname - Hostname of the machine we want to add
   * @param {string} body.imMad - The name of the information manager (im_mad_name)
   * @param {string} body.vmmMad - The name of the  manager mad name (vmm_mad_name)
   * @param {string} [body.cluster] - The cluster ID
   * @returns {Cypress.Chainable<object>} A promise that resolves to the host information
   */
  allocate(body) {
    return cy.apiAllocateHost(body).then((hostId) => {
      this.id = hostId

      return this.info()
    })
  }

  /**
   * @returns {Cypress.Chainable<Cypress.Response>}
   * A promise that resolves to the host id
   */
  delete() {
    return cy.apiDeleteHost(this.id)
  }

  /**
   * @param {string} state - The state to wait for
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves when the host reaches the state
   */
  waitState(state) {
    return cy.waitUntil(() => this.info().then(() => this.state === state))
  }

  /**
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves when the host is monitored
   */
  waitMonitored() {
    return this.waitState('MONITORED')
  }

  /**
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves when the host is error
   */
  waitError() {
    return this.waitState('ERROR')
  }

  /**
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves when the host is disabled
   */
  waitDisabled() {
    return this.waitState('DISABLED')
  }

  /**
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves when the host is offline
   */
  waitOffline() {
    return this.waitState('OFFLINE')
  }

  /** @returns {Cypress.Chainable<string>} Enables the host if it is disabled */
  enable() {
    return this.isEnabled ? cy.then(() => this.id) : cy.apiEnableHost(this.id)
  }

  /** @returns {Cypress.Chainable<string>} Disables the host */
  disable() {
    return cy.apiDisableHost(this.id)
  }
}

export default Host
