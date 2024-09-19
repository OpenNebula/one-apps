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

import { levelLockToString } from '@commands/helpers'

class OpenNebulaResource {
  /**
   * @param {string} id - The resource id
   * @param {object} resource - The resource information
   */
  constructor(id, resource) {
    const idIsName = typeof id === 'string' && isNaN(+id)

    this.json = { [idIsName ? 'NAME' : 'ID']: `${id}`, ...resource }
  }

  /** @returns {string} Resource id */
  get id() {
    return this.json.ID
  }

  /** @param {string} newId - New resource id */
  set id(newId) {
    this.json.ID = `${newId}`
  }

  /** @returns {string} Resource name */
  get name() {
    return this.json.NAME
  }

  /** @param {string} newName - New resource name */
  set name(newName) {
    this.json.NAME = `${newName}`
  }

  /** @returns {string[]} Labels */
  get labels() {
    const labels = this.json.TEMPLATE?.LABELS?.split(',') ?? []

    return labels.filter(Boolean).map((label) => label.toUpperCase())
  }

  /** @returns {'None'|'Use'|'Manage'|'Admin'|'All'|'-'} Lock level in readable format */
  get lockLevel() {
    return levelLockToString(this.json?.LOCK?.LOCKED)
  }
}

export default OpenNebulaResource
