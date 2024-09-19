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

class Group extends OpenNebulaResource {
  /**
   * Retrieves information for the group.
   *
   * @returns {Cypress.Chainable<object>}
   * - A promise that resolves to the group information
   */
  info() {
    const id = this.id ?? this.name

    return cy.apiGetGroup(id).then((group) => {
      this.json = group

      return group
    })
  }

  /**
   * Allocates a new group in OpenNebula.
   *
   * @param {object} name - The name of the group
   * @returns {Cypress.Chainable<object>} A promise that resolves to the group information
   */
  allocate(name) {
    return cy.apiAllocateGroup(name).then((dsId) => {
      this.id = dsId

      return this.info()
    })
  }

  /**
   * @returns {Cypress.Chainable<Cypress.Response>}
   * A promise that resolves to the host id
   */
  delete() {
    if (this.id === undefined) {
      return this.info().then(() => cy.apiDeleteGroup(this.id))
    }

    return cy.apiDeleteGroup(this.id)
  }
}

export default Group
