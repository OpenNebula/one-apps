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

import { Cluster as ClusterDocs } from '@support/commands/cluster/jsdocs'

/**
 * Fills in the GUI settings for a cluster.
 *
 * @param {ClusterDocs} cluster - The cluster whose GUI settings are to be filled
 */
const fillClusterGUI = (cluster) => {
  // Start form
  cy.getBySel('main-layout').click()

  // Fill general data and continue
  if (cluster.general) {
    fillGeneral(cluster.general)
  }
  cy.getBySel('stepper-next-button').click()

  // Fill hosts data and continue
  if (cluster.hosts) {
    fillHosts(cluster.hosts)
  }
  cy.getBySel('stepper-next-button').click()

  // Fill vnets data and continue
  if (cluster.vnets) {
    fillVnets(cluster.vnets)
  }
  cy.getBySel('stepper-next-button').click()

  // Fill datastores data and continue
  if (cluster.datastores) {
    fillDatastores(cluster.datastores)
  }
  cy.getBySel('stepper-next-button').click()
}

/**
 * Fills in the general settings for a cluster.
 *
 * @param {object} general - General settings to be filled
 */
const fillGeneral = (general) => {
  // Get cluster info
  const { name } = general

  // Set name of the cluster
  name && cy.getBySel('general-NAME').clear().type(name)
}

/**
 * Fills in the host settings for a cluster.
 *
 * @param {object} hosts - The host settings to be filled
 */
const fillHosts = (hosts) => {
  hosts &&
    hosts.forEach((resource) =>
      cy.clickHostRow(
        { name: resource?.host?.json?.NAME, id: resource?.host?.json?.ID },
        { noWait: true }
      )
    )
}

/**
 * Remove hosts of the table.
 *
 * @param {object} hosts - Hosts to remove
 */
const removeHosts = (hosts) => {
  hosts &&
    hosts.forEach((resource) => {
      // Get row
      cy.getHostRow(
        { name: resource?.host?.json?.NAME, id: resource?.host?.json?.ID },
        { noWait: true }
      )

      // Click on item selected to not select the row
      cy.getBySel('itemSelected')
        .contains('span', resource?.host?.json?.NAME)
        .siblings('svg')
        .should('be.visible')
        .click()
    })
}

/**
 * Fills in the vnet settings for a cluster.
 *
 * @param {object} vnets - The vnet settings to be filled
 */
const fillVnets = (vnets) => {
  vnets &&
    vnets.forEach((resource) =>
      cy.clickVNetRow(
        { name: resource?.vnet?.json?.NAME, id: resource?.vnet?.json?.ID },
        { noWait: true }
      )
    )
}

/**
 * Remove vnets of the table.
 *
 * @param {object} vnets - Vnets to remove
 */
const removeVNets = (vnets) => {
  vnets &&
    vnets.forEach((resource) => {
      // Get row
      cy.getVNetRow(
        { name: resource?.vnet?.json?.NAME, id: resource?.vnet?.json?.ID },
        { noWait: true }
      )

      // Click on item selected to not select the row
      cy.getBySel('itemSelected')
        .contains('span', resource?.vnet?.json?.NAME)
        .siblings('svg')
        .should('be.visible')
        .click()
    })
}

/**
 * Fills in the datastore settings for a cluster.
 *
 * @param {object} datastores - The datastore settings to be filled
 */
const fillDatastores = (datastores) => {
  datastores &&
    datastores.forEach((resource) =>
      cy.clickDatastoreRow(
        {
          name: resource?.datastore?.json?.NAME,
          id: resource?.datastore?.json?.ID,
        },
        { noWait: true }
      )
    )
}

/**
 * Remove datastores of the table.
 *
 * @param {object} datastores - Datastores to remove
 */
const removeDatastores = (datastores) => {
  datastores &&
    datastores.forEach((resource) => {
      // Get row
      cy.getDatastoreRow(
        {
          name: resource?.datastore?.json?.NAME,
          id: resource?.datastore?.json?.ID,
        },
        { noWait: true }
      )

      // Click on item selected to not select the row
      cy.getBySel('itemSelected')
        .contains('span', resource?.datastore?.json?.NAME)
        .siblings('svg')
        .should('be.visible')
        .click()
    })
}

/**
 * Fills an update in the GUI settings for a cluster.
 *
 * @param {ClusterDocs} cluster - The cluster whose GUI settings are to be filled
 */
const fillUpdateClusterGUI = (cluster) => {
  // Start form
  cy.getBySel('main-layout').click()

  // Fill general data and continue
  if (cluster.updateData?.general?.name) {
    fillGeneral(cluster.updateData.general)
  }
  cy.getBySel('stepper-next-button').click()

  // Fill and remove hosts data and continue
  if (cluster.updateData?.hosts?.add) {
    fillHosts(cluster.updateData.hosts.add)
  }
  if (cluster.updateData?.hosts?.remove) {
    removeHosts(cluster.updateData.hosts.remove)
  }
  cy.getBySel('stepper-next-button').click()

  // Fill and remove vnets data and continue
  if (cluster.updateData?.vnets?.add) {
    fillVnets(cluster.updateData.vnets.add)
  }
  if (cluster.updateData?.vnets?.remove) {
    removeVNets(cluster.updateData.vnets.remove)
  }
  cy.getBySel('stepper-next-button').click()

  // Fill and remove datastores data and continue
  if (cluster.updateData?.datastores?.add) {
    fillDatastores(cluster.updateData.datastores.add)
  }
  if (cluster.updateData?.datastores?.remove) {
    removeDatastores(cluster.updateData.datastores.remove)
  }
  cy.getBySel('stepper-next-button').click()
}

export { fillClusterGUI, fillUpdateClusterGUI }
