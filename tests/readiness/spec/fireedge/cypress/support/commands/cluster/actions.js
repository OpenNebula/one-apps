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

import { FORCE } from '@support/commands/constants'
import { Intercepts, createIntercept } from '@support/utils'
import { Host, Cluster } from '@models'
import {
  fillClusterGUI,
  fillUpdateClusterGUI,
} from '@support/commands/cluster/create'

/**
 * Creates a new cluster via GUI.
 *
 * @param {object} cluster - The cluster to create
 * @returns {void} - No return value
 */
const clusterGUI = (cluster) => {
  // Create interceptor for each request that is used on create a cluster
  const interceptClusterAllocate = createIntercept(
    Intercepts.SUNSTONE.CLUSTER_ALLOCATE
  )

  // Create interceptors for addHost
  const hostsInterceptors = cluster.hosts?.map(() =>
    createIntercept(Intercepts.SUNSTONE.CLUSTER_ADD_HOST)
  )

  // Create interceptors for addVnet
  const vnetsInterceptors = cluster.vnets?.map(() =>
    createIntercept(Intercepts.SUNSTONE.CLUSTER_ADD_VNET)
  )

  // Create interceptors for addHost
  const datastoresInterceptors = cluster.datastores?.map(() =>
    createIntercept(Intercepts.SUNSTONE.CLUSTER_ADD_DATASTORE)
  )

  // Click on create button
  cy.getBySel('action-create_dialog').click()

  // Fill form
  fillClusterGUI(cluster)

  // Wait and check that every request it's finished with 200 result
  cy.wait(interceptClusterAllocate).its('response.statusCode').should('eq', 200)

  hostsInterceptors?.forEach((hostInterceptor) => {
    cy.wait(hostInterceptor).its('response.statusCode').should('eq', 200)
  })

  vnetsInterceptors?.forEach((vnetInterceptor) => {
    cy.wait(vnetInterceptor).its('response.statusCode').should('eq', 200)
  })

  datastoresInterceptors?.forEach((datastoreInterceptor) => {
    cy.wait(datastoreInterceptor).its('response.statusCode').should('eq', 200)
  })
}

/**
 * Update a cluster.
 *
 * @param {object} cluster - Cluser to update
 */
const updateClusterGUI = (cluster) => {
  // Create interceptor for each request that is used on create a cluster
  const interceptClusterRename = createIntercept(
    Intercepts.SUNSTONE.CLUSTER_RENAME
  )

  // Create interceptors for addHost
  const addHostsInterceptors = cluster.updateData.hosts?.add?.map(() =>
    createIntercept(Intercepts.SUNSTONE.CLUSTER_ADD_HOST)
  )

  // Create interceptors for addVnet
  const addVnetsInterceptors = cluster.updateData.vnets?.add?.map(() =>
    createIntercept(Intercepts.SUNSTONE.CLUSTER_ADD_VNET)
  )

  // Create interceptors for addDatastores
  const addDatastoresInterceptors = cluster.updateData.datastores?.add?.map(
    () => createIntercept(Intercepts.SUNSTONE.CLUSTER_ADD_DATASTORE)
  )

  // Create interceptors for removeHost
  const removeHostsInterceptors = cluster.updateData.hosts?.remove?.map(() =>
    createIntercept(Intercepts.SUNSTONE.CLUSTER_REMOVE_HOST)
  )

  // Create interceptors for removeVnet
  const removeVnetsInterceptors = cluster.updateData.vnets?.remove?.map(() =>
    createIntercept(Intercepts.SUNSTONE.CLUSTER_REMOVE_VNET)
  )

  // Create interceptors for removeDatastore
  const removeDatastoresInterceptors =
    cluster.updateData.datastores?.remove?.map(() =>
      createIntercept(Intercepts.SUNSTONE.CLUSTER_REMOVE_DATASTORE)
    )

  // Click on update button
  cy.getBySel('action-update_dialog').click()

  // Fill form
  fillUpdateClusterGUI(cluster)

  // Wait and check that every request it's finished with 200 result
  if (cluster.updateData?.general?.name)
    cy.wait(interceptClusterRename).its('response.statusCode').should('eq', 200)

  addHostsInterceptors?.forEach((hostInterceptor) => {
    cy.wait(hostInterceptor).its('response.statusCode').should('eq', 200)
  })

  addVnetsInterceptors?.forEach((vnetInterceptor) => {
    cy.wait(vnetInterceptor).its('response.statusCode').should('eq', 200)
  })

  addDatastoresInterceptors?.forEach((datastoreInterceptor) => {
    cy.wait(datastoreInterceptor).its('response.statusCode').should('eq', 200)
  })

  removeHostsInterceptors?.forEach((hostInterceptor) => {
    cy.wait(hostInterceptor).its('response.statusCode').should('eq', 200)
  })

  removeVnetsInterceptors?.forEach((vnetInterceptor) => {
    cy.wait(vnetInterceptor).its('response.statusCode').should('eq', 200)
  })

  removeDatastoresInterceptors?.forEach((datastoreInterceptor) => {
    cy.wait(datastoreInterceptor).its('response.statusCode').should('eq', 200)
  })
}

/**
 * Validates the data of a cluster.
 *
 * @param {object} cluster - The cluster to validate
 * @returns {void} - No return value
 */
const validateCluster = (cluster) => {
  new Cluster(cluster.general.name).info().then((data) => {
    // Validate cluster name
    cy.log('Checking cluster name')
    cy.wrap(data.NAME).should('eq', cluster.general.name)

    // Validate hosts
    const hosts = data.HOSTS?.ID
      ? Array.isArray(data.HOSTS?.ID)
        ? data.HOSTS?.ID
        : [data.HOSTS.ID]
      : []
    const hostsToValidate = cluster.hosts
      ? cluster.hosts?.map((resource) => resource.host.json.ID)
      : []

    cy.log('Checking cluster hosts')
    cy.wrap(hosts).should('deep.equal', hostsToValidate)

    // Validate vnets
    const vnets = data.VNETS?.ID
      ? Array.isArray(data.VNETS?.ID)
        ? data.VNETS?.ID
        : [data.VNETS.ID]
      : []
    const vnetsToValidate = cluster.vnets
      ? cluster.vnets?.map((resource) => resource.vnet.json.ID)
      : []

    cy.log('Checking cluster vnets')
    cy.wrap(vnets).should('deep.equal', vnetsToValidate)

    // Validate datastores
    const datastores = data.DATASTORES?.ID
      ? Array.isArray(data.DATASTORES?.ID)
        ? data.DATASTORES?.ID
        : [data.DATASTORES.ID]
      : []
    const datastoresToValidate = cluster.datastores
      ? cluster.datastores?.map((resource) => resource.datastore.json.ID)
      : []

    cy.log('Checking cluster datastores')
    cy.wrap(datastores).should('deep.equal', datastoresToValidate)
  })
}

/**
 * Add Host in cluster.
 *
 * @param {Host} host - Host
 * @param {Cluster} cluster - Cluster
 * @returns {Cypress.Chainable<Cypress.Response>} add host in cluster response
 */
const addHostCluster = (host, cluster) => {
  const getClusters = createIntercept(Intercepts.SUNSTONE.CLUSTERS)
  const getClusterAddHost = createIntercept(
    Intercepts.SUNSTONE.CLUSTER_ADD_HOST
  )

  cy.clickHostRow(host)

  cy.getBySel('action-host-change_cluster').click()
  cy.wait(getClusters)

  cy.getBySel('modal-select-cluster').within(() => {
    cy.getClusterRow(cluster).click(FORCE)
    cy.getBySel('dg-accept-button').click(FORCE)
  })

  return cy.wait(getClusterAddHost)
}

/**
 * Delete a cluster.
 *
 * @param {Cluster} cluster - Cluster to delete
 */
const deleteClusterGUI = (cluster) => {
  cy.clickClusterRow({ id: cluster.ID }).then(() => {
    // Create interceptor
    const interceptDelete = createIntercept(Intercepts.SUNSTONE.CLUSTER_DELETE)

    // Click on delete button
    cy.getBySel('action-cluster_delete').click()

    // Accept the modal of delete cluster
    cy.getBySel(`modal-delete`)
      .should('exist')
      .then(($dialog) => {
        cy.wrap($dialog).find(`[data-cy=dg-accept-button]`).click()

        return cy
          .wait(interceptDelete)
          .its('response.statusCode')
          .should('eq', 200)
      })
  })
}

/**
 * Validate tabs of a cluster.
 *
 * @param {Cluster} cluster - Cluster to validate
 * @param {string} id - Cluster id
 */
const validateTabsCluster = (cluster, id) => {
  cy.clickClusterRow({ id: id }).then(() => {
    // Check info tab
    cy.navigateTab('info')
      .should('exist')
      .and('be.visible')
      .within(() => {
        cy.getBySel('id').should('have.text', id)
        cy.getBySel('name').should('have.text', cluster.general.name)
      })

    // Check host tab
    cy.navigateTab('host')
      .should('exist')
      .and('be.visible')
      .within(() => {
        cy.getHostTable().within(() => {
          cluster?.hosts?.forEach((resource) => {
            cy.getBySel('host-' + resource.host.json.ID).should(
              'contain',
              resource.host.json.NAME
            )
          })
        })
      })

    // Check vnet tab
    cy.navigateTab('vnet')
      .should('exist')
      .and('be.visible')
      .within(() => {
        cy.getVNetTable().within(() => {
          cluster?.vnets?.forEach((resource) => {
            cy.getBySel('network-' + resource.vnet.json.ID).should(
              'contain',
              resource.vnet.json.NAME
            )
          })
        })
      })

    // Check datastore tab
    cy.navigateTab('datastore')
      .should('exist')
      .and('be.visible')
      .within(() => {
        cy.getDatastoreTable().within(() => {
          cluster?.datastores?.forEach((resource) => {
            cy.getBySel('datastore-' + resource.datastore.json.ID).should(
              'contain',
              resource.datastore.json.NAME
            )
          })
        })
      })
  })
}

/**
 * Update cluster template (only memory and CPU).
 *
 * @param {object} cluster - Cluster template to update
 */
const updateClusterTemplateGUI = (cluster) => {
  // Navidate to info tab
  cy.navigateTab('info').within(() => {
    // Update cpu
    if (cluster?.general?.cpu) {
      const interceptorUpdateCpu = createIntercept(
        Intercepts.SUNSTONE.CLUSTER_UPDATE
      )
      cy.getBySel('edit-allocatedCpu').click()
      cy.getBySel('text-allocatedCpu')
        .clear()
        .type(`${cluster.general.cpu}{del}`)
      cy.getBySel('accept-allocatedCpu').click()
      cy.wait(interceptorUpdateCpu).its('response.statusCode').should('eq', 200)
    }

    // Update memory
    if (cluster?.general?.memory) {
      const interceptorUpdateMemory = createIntercept(
        Intercepts.SUNSTONE.CLUSTER_UPDATE
      )

      cy.getBySel('edit-allocatedMemory').click()
      cy.getBySel('text-allocatedMemory')
        .clear()
        .type(`${cluster.general.memory}{del}`)
      cy.getBySel('accept-allocatedMemory').click()

      cy.wait(interceptorUpdateMemory)
        .its('response.statusCode')
        .should('eq', 200)
    }

    // Check that the values were updated
    cluster?.general?.cpu &&
      cy.getBySel('allocated-cpu').should('contain', cluster?.general?.cpu)
    cluster?.general?.memory &&
      cy
        .getBySel('allocated-memory')
        .should('contain', cluster?.general?.memory)
  })
}

/**
 * Validate the card view of a cluster table.
 *
 * @param {string} idCluster - Id of the cluster
 * @param {object} cluster - Cluster to validate
 */
const validateClusterCardView = (idCluster, cluster) => {
  // Click on the cluster row
  cy.getClusterRow({ id: idCluster }).then((row) => {
    cy.wrap(row).within(() => {
      // Check id
      cy.getBySel('cluster-card-id').should('have.text', '#' + idCluster)

      // Check name
      cy.getBySel('cluster-card-name').should('have.text', cluster.general.name)

      // Check hosts
      cy.getBySel('cluster-card-hosts').should(
        'have.text',
        cluster.hosts ? cluster.hosts.length : 0
      )

      // Check vnets
      cy.getBySel('cluster-card-vnets').should(
        'have.text',
        '#' + cluster.vnets ? cluster.vnets.length : 0
      )

      // Check datastores
      cy.getBySel('cluster-card-datastores').should(
        'have.text',
        '#' + cluster.datastores ? cluster.datastores.length : 0
      )
    })
  })
}

Cypress.Commands.add('clusterGUI', clusterGUI)
Cypress.Commands.add('updateClusterGUI', updateClusterGUI)
Cypress.Commands.add('deleteClusterGUI', deleteClusterGUI)
Cypress.Commands.add('validateTabsCluster', validateTabsCluster)
Cypress.Commands.add('validateCluster', validateCluster)
Cypress.Commands.add('addHostCluster', addHostCluster)
Cypress.Commands.add('updateClusterTemplateGUI', updateClusterTemplateGUI)
Cypress.Commands.add('validateClusterCardView', validateClusterCardView)
