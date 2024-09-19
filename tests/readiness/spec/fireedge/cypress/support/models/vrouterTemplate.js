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

class VRouterTemplate extends OpenNebulaResource {
  /**
   * Retrieves information for the VRouterTemplate.
   *
   * @returns {Cypress.Chainable<object>}
   * - A promise that resolves to the VRouterTemplate information
   */
  info() {
    const id = this.id ?? this.name

    return cy.apiGetVRouterTemplate(id).then((vroutertemplate) => {
      this.json = vroutertemplate

      return VRouterTemplate
    })
  }

  /**
   * Allocates a new VRouterTemplate in OpenNebula.
   *
   * @param {object} body - Request body for the POST request
   * @param {object} body.template - An object containing the template of the VRouterTemplate
   * @returns {Cypress.Chainable<object>} A promise that resolves to the VRouterTemplate information
   */
  allocate(body) {
    return cy
      .apiAllocateVRouterTemplate(body)
      .then((response) => {
        const templateId = response // directly returns ID
        this.id = templateId
      })
      .then(
        () => cy.wait(20) // eslint-disable-line cypress/no-unnecessary-waiting
      )
    // .then(() => this.info())
  }

  /**
   * @returns {Cypress.Chainable<Cypress.Response>}
   * A promise that resolves to the VRouterTemplate id
   */
  delete() {
    return cy.apiDeleteVRouterTemplate(this.id)
  }

  /**
   * Updates the permissions for a VRouterTemplate in OpenNebula.
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
   * @returns {Cypress.Chainable<object>} A promise that resolves to the VRouterTemplate information
   */
  chmod(body) {
    return cy.apiChmodVRouterTemplate(this.id, body).then(() => this.info())
  }
}

export default VRouterTemplate
