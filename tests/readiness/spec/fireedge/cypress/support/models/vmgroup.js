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

class Vmgroup extends OpenNebulaResource {
  /** @returns {boolean} - Whether the vmgroup is disabled */
  get isDisabled() {
    return !!this?.LOCK
  }

  /** @returns {boolean} - Whether the vmgroup is public */
  get isPublic() {
    return (
      this.json?.PERMISSIONS?.GROUP_U === '1' ||
      this.json?.PERMISSIONS?.OTHER_U === '1'
    )
  }

  /**
   * Retrieves information for the vmgroup.
   *
   * @returns {Cypress.Chainable<object>}
   * - A promise that resolves to the vmgroup information
   */
  info() {
    const id = this.id ?? this.name

    return cy.apiGetVmGroup(id).then((vmgroup) => {
      this.json = vmgroup

      return vmgroup
    })
  }

  /**
   * Allocates a new vmgroup in OpenNebula.
   *
   * @param {object} body - Request body for the POST request
   * @param {object} body.template - An object containing the template of the vmgroup
   * @returns {Cypress.Chainable<object>} A promise that resolves to the vmgroup information
   */
  allocate(body) {
    return cy
      .apiAllocateVmGroup(body)
      .then((VmGroupID) => {
        this.id = VmGroupID
      })
      .then(
        () => cy.wait(20) // eslint-disable-line cypress/no-unnecessary-waiting
      )
      .then(() => this.info())
  }

  /**
   * @returns {Cypress.Chainable<Cypress.Response>}
   * A promise that resolves to the vmgroup id
   */
  delete() {
    return cy.apiDeleteVmGroup(this.id)
  }

  /**
   *@returns {Cypress.Chainable<object>}
   * A promise that resolves when the vmgroup is locked
   */
  waitDisabled() {
    return cy.waitUntil(() => this.info().then(() => !!this?.LOCK === true))
  }

  /**
   *@returns {Cypress.Chainable<object>}
   * A promise that resolves when the vmgroup is locked
   */
  waitEnabled() {
    return cy.waitUntil(() => this.info().then(() => !!this?.LOCK === false))
  }

  /**
   * Updates the permissions for a vmgroup in OpenNebula.
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
   * @returns {Cypress.Chainable<object>} A promise that resolves to the vmgroup information
   */
  chmod(body) {
    return cy.apiChmodVmGroup(this.id, body).then(() => this.info())
  }
}

export default Vmgroup
