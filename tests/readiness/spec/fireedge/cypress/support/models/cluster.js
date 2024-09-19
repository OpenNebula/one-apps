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

class Cluster extends OpenNebulaResource {
  /**
   * Retrieves information for the cluster.
   *
   * @returns {Cypress.Chainable<object>}
   * - A promise that resolves to the cluster information
   */
  info() {
    const id = this.id ?? this.name

    return cy.apiGetCluster(id).then((cluster) => {
      this.json = cluster

      return cluster
    })
  }

  /**
   * Allocates a new cluster in OpenNebula.
   *
   * @param {object} body - Request body for the POST request
   * @param {string} body.name - cluster name
   * @returns {Cypress.Chainable<object>} A promise that resolves to the cluster information
   */
  allocate(body) {
    return cy.apiAllocateCluster(body).then((clusterId) => {
      this.id = clusterId

      return this.info()
    })
  }

  /**
   * Add a host to a cluster.
   *
   * @param {string} id - Cluster id
   * @param {object} body - Host info
   * @returns {Cypress.Chainable<object>} A promise that resolves to the cluster information
   */
  addHost(id, body) {
    return cy.apiAddHostCluster(id, body).then(() => this.info())
  }
}

export default Cluster
