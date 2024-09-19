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

class BackupJobs extends OpenNebulaResource {
  /** @returns {boolean} Whether the backup job is public */
  get isPublic() {
    return (
      this.json?.PERMISSIONS?.GROUP_U === '1' ||
      this.json?.PERMISSIONS?.OTHER_U === '1'
    )
  }

  /**
   * Retrieves information for the backup job.
   *
   * @param {boolean} [extended] - True to include extended information
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves to the backup job information
   */
  info(extended = false) {
    const id = this.id ?? this.name

    return cy.apiGetBackupJob(id, { extended }).then((backupjob) => {
      this.json = backupjob

      return backupjob
    })
  }

  /**
   * Allocates a new backup job in OpenNebula.
   *
   * @param {object} [template] - An object containing the template
   * @returns {Cypress.Chainable<object>} A promise that resolves to the template information
   */
  allocate(template) {
    template.NAME ??= this.name

    return cy.apiAllocateBackupJob(template).then((backupJobId) => {
      this.id = backupJobId

      return this.info()
    })
  }

  /**
   * Replaces the template contents in Backup Job.
   *
   * @param {object} template - An object containing the template
   * @param {0|1} replace - Update type
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves to the backup job information
   */
  update(template, replace) {
    return cy
      .apiUpdateBackupJob(this.id, { template, replace })
      .then(() => this.info())
  }

  /**
   * Delete Backup Job.
   *
   * @returns {Cypress.Chainable<Cypress.Response>}
   * A promise that resolves to the backup job id
   */
  delete() {
    return cy.apiDeleteBackupJob(this.id)
  }

  /**
   * @param {object} permissions - permissions
   * @returns {Cypress.Chainable<Cypress.Response>}
   * A promise that resolves to the Backup Job id
   */
  chmod(permissions) {
    return cy.apiChmodBackupJob(this.id, permissions)
  }

  /**
   * @param {number} user - user ID
   * @returns {Cypress.Chainable<Cypress.Response>}
   * A promise that resolves to the Backup Job id
   */
  chown(user) {
    return cy.apiChownBackupJob(this.id, user)
  }
}

export default BackupJobs
