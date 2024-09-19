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

class VmTemplate extends OpenNebulaResource {
  /** @returns {boolean} Whether the template is public */
  get isPublic() {
    return (
      this.json?.PERMISSIONS?.GROUP_U === '1' ||
      this.json?.PERMISSIONS?.OTHER_U === '1'
    )
  }

  /** @returns {object[]} Get disks */
  get disks() {
    return [this.json?.TEMPLATE?.DISK ?? []].flat()
  }

  /** @returns {object[]} Get vnets */
  get vnets() {
    return [this.json?.TEMPLATE?.NIC_ALIAS ?? []].flat()
  }

  /**
   * Retrieves information for the template.
   *
   * @param {boolean} [extended] - True to include extended information
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves to the template information
   */
  info(extended = false) {
    const id = this.id ?? this.name

    return cy.apiGetVmTemplate(id, { extended }).then((template) => {
      this.json = template

      return template
    })
  }

  /**
   * Allocates a new template in OpenNebula.
   *
   * @param {object} [template] - An object containing the template
   * @returns {Cypress.Chainable<object>} A promise that resolves to the template information
   */
  allocate(template) {
    template.NAME ??= this.name

    return cy.apiAllocateVmTemplate(template).then((templateId) => {
      this.id = templateId

      return this.info()
    })
  }

  /**
   * Replaces the template contents.
   *
   * @param {object} template - An object containing the template
   * @param {0|1} replace - Update type
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves to the template information
   */
  update(template, replace) {
    return cy
      .apiUpdateVmTemplate(this.id, { template, replace })
      .then(() => this.info())
  }

  /**
   * Allocates a new template in OpenNebula.
   *
   * @param {object} body - Request body for the POST request
   * @param {string} body.name - Name for the new VM instance
   * @param {boolean} body.hold - True to create it on hold state. By default it is `false`
   * @param {boolean} body.persistent
   * - True to create a private persistent copy. By default it is `false`
   * @param {object} body.template
   * - Extra template to be merged with the one being instantiated
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves to the vm instance id
   */
  instantiate(body) {
    return cy.apiInstantiateVmTemplate(this.id, body)
  }

  /**
   * @param {boolean} deleteAllImages
   * - `true` to delete the template plus any image defined in DISK
   * @returns {Cypress.Chainable<Cypress.Response>}
   * A promise that resolves to the image id
   */
  delete(deleteAllImages = false) {
    return cy.apiDeleteVmTemplate(this.id, deleteAllImages)
  }

  /**
   * @param {object} permissions - permissions
   * @returns {Cypress.Chainable<Cypress.Response>}
   * A promise that resolves to the template id
   */
  chmod(permissions) {
    return cy.apiChmodVmtemplate(this.id, permissions)
  }

  /**
   * @param {number} user - user ID
   * @returns {Cypress.Chainable<Cypress.Response>}
   * A promise that resolves to the template id
   */
  chown(user) {
    return cy.apiChownVmtemplate(this.id, user)
  }

  /**
   * @param {number} group - group ID
   * @returns {Cypress.Chainable<Cypress.Response>}
   * A promise that resolves to the template id
   */
  chgrp(group) {
    return cy.apiChgrpVmtemplate(this.id, group)
  }
}

export default VmTemplate
