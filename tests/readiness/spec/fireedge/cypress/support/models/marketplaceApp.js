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

const APP_STATES = ['INIT', 'READY', 'LOCKED', 'ERROR', 'DISABLED']
const APP_TYPES = ['UNKNOWN', 'IMAGE', 'VMTEMPLATE', 'SERVICE_TEMPLATE']

class MarketplaceApp extends OpenNebulaResource {
  /** @returns {boolean} Whether the app is public */
  get isPublic() {
    return (
      this.json?.PERMISSIONS?.GROUP_U === '1' ||
      this.json?.PERMISSIONS?.OTHER_U === '1'
    )
  }

  /** @returns {string} - The app type */
  get type() {
    return APP_TYPES[this.json.TYPE]
  }

  /** @returns {string} - The app state */
  get state() {
    return APP_STATES[this.json.STATE]
  }

  /**
   * Retrieves information for the marketplace app.
   *
   * @returns {Cypress.Chainable<object>}
   * - A promise that resolves to the app information
   */
  info() {
    const id = this.id ?? this.name

    return cy.apiGetMarketplaceApp(id).then((app) => {
      this.json = app

      return app
    })
  }

  /**
   * Replaces the App template contents.
   *
   * @param {object} template - An object containing the template
   * @param {0|1} replace - Update type
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves to the app information
   */
  update(template, replace) {
    return cy
      .apiUpdateMarketplaceApp(this.id, { template, replace })
      .then(() => this.info())
  }

  /**
   * Allocates a new host in OpenNebula.
   *
   * @param {number} market - market id
   * @param {object} body - Request body for the POST request
   * @param {string} body.hostname - Hostname of the machine we want to add
   * @param {string} body.imMad - The name of the information manager (im_mad_name)
   * @param {string} body.vmmMad - The name of the  manager mad name (vmm_mad_name)
   * @param {string} [body.cluster] - The cluster ID
   * @returns {Cypress.Chainable<object>} A promise that resolves to the host information
   */
  allocate(market, body) {
    return cy.apiAllocateMarketplaceApp(market, body).then((marketappId) => {
      this.id = marketappId

      return this.info()
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
  exportApp(body) {
    return cy
      .apiExportMarketplaceApp(this.id, body)
      .then((marketapp) => marketapp)
  }

  /**
   * @param {string} state - The state to wait for
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves when the app reaches the state
   */
  waitState(state) {
    return cy.waitUntil(() => this.info().then(() => this.state === state))
  }

  /**
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves when the app is locked
   */
  waitLocked() {
    return this.waitState('LOCKED')
  }

  /**
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves when the app is error
   */
  waitError() {
    return this.waitState('ERROR')
  }

  /**
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves when the app is disabled
   */
  waitDisabled() {
    return this.waitState('DISABLED')
  }

  /**
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves when the app is ready
   */
  waitReady() {
    return this.waitState('READY')
  }

  /**
   * Updates the permissions for the OpenNebula resource.
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
    return this.info()
      .then(() => {
        cy.apiChmodMarketplaceApp(this.json.ID, body)
      })
      .then(() => this.info())
  }
}

export default MarketplaceApp
