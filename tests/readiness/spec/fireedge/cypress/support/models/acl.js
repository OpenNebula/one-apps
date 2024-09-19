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
import { parseAcl } from '@utils'

class Acl extends OpenNebulaResource {
  /**
   * Retrieves information for the acl.
   *
   * @returns {Cypress.Chainable<object>}
   * - A promise that resolves to the acl information
   */
  info() {
    const id = this.id

    return cy.apiGetAcl(id).then((acl) => {
      this.json = acl

      return acl
    })
  }

  /**
   * Allocates a new acl in OpenNebula.
   *
   * @param {object} rule - ACL rule to create
   * @returns {Cypress.Chainable<object>} A promise that resolves to the acl information
   */
  allocate(rule) {
    return cy.apiAllocateAcl(parseAcl(rule)).then((dsId) => {
      this.id = dsId

      return this.info()
    })
  }

  /**
   * @returns {Cypress.Chainable<Cypress.Response>}
   * A promise that resolves to the acl id
   */
  delete() {
    if (this.id === undefined) {
      return this.info().then(() => cy.apiDeleteAcl(this.id))
    }

    return cy.apiDeleteAcl(this.id)
  }
}

export default Acl
