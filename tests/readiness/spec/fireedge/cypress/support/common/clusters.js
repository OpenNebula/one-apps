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

const { Cluster } = require('@models')

/**
 * Create hosts, vnets and datastores to use in the cluster tests.
 *
 * @param {object} resources - Rsources to create
 */
const beforeAllCluster = (resources = {}) => {
  const { hosts = [], vnets = [], datastores = [] } = resources

  cy.fixture('auth')
    .then((auth) => cy.apiAuth(auth.admin))
    .then(() => cy.apiSunstoneConf())
    .then(() => cy.cleanup())
    .then(() => {
      // Create hosts
      const allocateFn =
        ({ host, template }) =>
        async () =>
          await host.allocate(template)

      return cy.all(...hosts.map(allocateFn))
    })
    .then(() => {
      // Create vnets
      const allocateFn =
        ({ vnet, template }) =>
        async () =>
          await vnet.allocate({
            template: { ...template },
          })

      return cy.all(...vnets.map(allocateFn))
    })
    .then(() => {
      // Create datastores
      const allocateFn =
        ({ datastore, template }) =>
        async () =>
          await datastore.allocate({
            template: { ...template },
          })

      return cy.all(...datastores.map(allocateFn))
    })
}

/**
 * Create a new cluster via GUI.
 *
 * @param {object} cluster - cluster template.
 */
const clusterGUI = (cluster) => {
  cy.navigateMenu('infrastructure', 'Cluster')
  cy.clusterGUI(cluster)
  cy.validateCluster(cluster)
}

/**
 * Update a new cluster via GUI.
 *
 * @param {object} cluster - cluster template.
 */
const updateGUI = (cluster) => {
  // Create cluster with the API
  new Cluster(cluster.initialData.general.name)
    .allocate({ name: cluster.initialData.general.name })
    .then((newCluster) => {
      // Add hosts with the API
      cluster?.initialData?.hosts?.forEach((resource) => {
        cy.apiAddHostCluster(newCluster.ID, { host: resource.host.json.ID })
      })

      // Add vnets with the API
      cluster?.initialData?.vnets?.forEach((resource) => {
        cy.apiAddVNetCluster(newCluster.ID, { vnet: resource.vnet.json.ID })
      })

      // Add datastores with the API
      cluster?.initialData?.datastores?.forEach((resource) => {
        cy.apiAddDatastoreCluster(newCluster.ID, {
          datastore: resource.datastore.json.ID,
        })
      })

      // Naviage to the clusters section
      cy.navigateMenu('infrastructure', 'Cluster')

      // Click on the cluster row
      cy.clickClusterRow({ id: newCluster.ID }).then(() => {
        // Update cluster
        cy.updateClusterGUI(cluster)

        // Validate cluster
        cy.validateCluster(cluster.finalData)
      })
    })
}

/**
 * Deletes a cluster.
 *
 * @param {object} cluster - Cluster template.
 */
const deleteGUI = (cluster) => {
  cy.navigateMenu('infrastructure', 'Cluster')

  // Create cluster with the API
  new Cluster(cluster.general.name)
    .allocate({ name: cluster.general.name })
    .then((newCluster) => {
      cy.deleteClusterGUI(newCluster).then(() => {
        cy.getClusterTable({ search: newCluster.NAME }).within(() => {
          cy.get(`[role='row'][data-cy$='${newCluster.ID}']`).should(
            'not.exist'
          )
        })
      })
    })
}

/**
 * Validate all the tabs of a cluster.
 *
 * @param {object} cluster - Cluster template
 */
const validateTabs = (cluster) => {
  cy.navigateMenu('infrastructure', 'Cluster')

  // Create cluster with the API
  new Cluster(cluster.general.name)
    .allocate({ name: cluster.general.name })
    .then((newCluster) => {
      // Add hosts with the API
      cluster?.hosts?.forEach((resource) => {
        cy.apiAddHostCluster(newCluster.ID, { host: resource.host.json.ID })
      })

      // Add vnets with the API
      cluster?.vnets?.forEach((resource) => {
        cy.apiAddVNetCluster(newCluster.ID, { vnet: resource.vnet.json.ID })
      })

      // Add datastores with the API
      cluster?.datastores?.forEach((resource) => {
        cy.apiAddDatastoreCluster(newCluster.ID, {
          datastore: resource.datastore.json.ID,
        })
      })

      cy.validateTabsCluster(cluster, newCluster.ID)
    })
}

/**
 * Update a cluster template (cluster only updates allocated CPU and memory).
 *
 * @param {object} cluster - Cluster to update
 */
const updateTemplateGUI = (cluster) => {
  cy.navigateMenu('infrastructure', 'Cluster')

  // Create cluster with the API
  new Cluster(cluster.general.name)
    .allocate({ name: cluster.general.name })
    .then((newCluster) => {
      // Click on the cluster row
      cy.clickClusterRow({ id: newCluster.ID }).then(() => {
        // Update Template
        cy.updateClusterTemplateGUI(cluster)
      })
    })
}

/**
 * Validate the card of the cluster table.
 *
 * @param {object} cluster - Cluster to validate
 */
const validateCardView = (cluster) => {
  cy.navigateMenu('infrastructure', 'Cluster')

  // Create cluster with the API
  new Cluster(cluster.general.name)
    .allocate({ name: cluster.general.name })
    .then((newCluster) => {
      // Add hosts with the API
      cluster?.hosts?.forEach((resource) => {
        cy.apiAddHostCluster(newCluster.ID, { host: resource.host.json.ID })
      })

      // Add vnets with the API
      cluster?.vnets?.forEach((resource) => {
        cy.apiAddVNetCluster(newCluster.ID, { vnet: resource.vnet.json.ID })
      })

      // Add datastores with the API
      cluster?.datastores?.forEach((resource) => {
        cy.apiAddDatastoreCluster(newCluster.ID, {
          datastore: resource.datastore.json.ID,
        })
      })

      // Validate view
      cy.validateClusterCardView(newCluster.ID, cluster)
    })
}

/**
 * Cleanup after test execution.
 */
const afterAllCluster = () => {
  cy.cleanup()
}

export {
  beforeAllCluster,
  clusterGUI,
  updateGUI,
  deleteGUI,
  validateTabs,
  updateTemplateGUI,
  validateCardView,
  afterAllCluster,
}
