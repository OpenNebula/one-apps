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

import OpenNebulaResource from './resource'

class SecurityGroup extends OpenNebulaResource {
  /**
   * Retrieves information for the Security Group.
   *
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves to the Security Group information
   */
  info() {
    const id = this.id ?? this.name

    return cy.apiGetSecGroup(id).then((user) => {
      this.json = user

      return user
    })
  }

  /**
   * Allocates a new Security Group in OpenNebula.
   *
   * @param {object} body - Request body for the POST request
   * @param {string} body.name - Security Group name
   * @returns {Cypress.Chainable<object>} A promise that resolves to the Security Group information
   */
  allocate(body) {
    return cy.apiAllocateSecGroup(body).then((sgId) => {
      this.id = sgId

      return this.info()
    })
  }

  /**
   * @returns {Cypress.Chainable<Cypress.Response>}
   * A promise that resolves to the image id
   */
  delete() {
    return cy.apiDeleteSecGroup(this.id)
  }
}

export default SecurityGroup
