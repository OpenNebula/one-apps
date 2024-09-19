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

const ZONE_STATES = ['ENABLED', 'DISABLED']

class Zone extends OpenNebulaResource {
  /** @returns {string} The zone state */
  get state() {
    return ZONE_STATES[this.json.STATE]
  }

  /** @returns {boolean} Whether the zone is disabled */
  get isDisabled() {
    return this.state === 'DISABLED'
  }

  /**
   * Retrieves information for the zone.
   *
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves to the zone information
   */
  info() {
    const id = this.id || this.name

    return cy.apiGetZone(id).then((zone) => {
      this.json = zone

      return zone
    })
  }

  /**
   * @param {string} state - The state to wait for
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves when the zone reaches the state
   */
  waitState(state) {
    return cy.waitUntil(() => this.info().then(() => this.state === state))
  }
}

export default Zone
