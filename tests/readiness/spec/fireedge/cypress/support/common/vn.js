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
import { transformAttributes } from '@support/utils'

const { ReserveLeaseTest, VirtualNetworkTest } = require('@commands/vnet/jsdoc')
const { Intercepts } = require('@support/utils/index')

/**
 * Authenticate as oneadmin and gives permission to manage the given vnets.
 *
 */
const beforeAllVNTest = () => {}

/**
 * Function to be executed before each Virtual Network test.
 */
const beforeEachVNTest = () => {
  cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
    qs: { externalToken: Cypress.env('TOKEN') },
  })
}

/**
 * Creates a new bridged vnet.
 *
 * @param {object} bridgedVnet - Vnet.
 */
const createBridgedNetwork = (bridgedVnet) => {
  /** @type {VirtualNetworkTest} */
  const vnet = {
    name: bridgedVnet.name,
    vnMad: 'bridge',
    bridge: 'br0',
    phydev: 'eth0',
    ranges: [
      { type: 'IP4', ip: '192.168.0.1', size: 250 },
      { type: 'IP4', ip: '10.0.0.1', size: 250 },
      {
        type: 'IP6_STATIC',
        ip6: '2001:a:b:c::1',
        prefixLength: 48,
        size: 250,
      },
    ],
    context: { dns: '8.8.8.8', gateway: '1.1.1.1' },
  }

  cy.navigateMenu('networks', 'Virtual Networks')

  cy.createVirtualNetwork(vnet)
    .its('response.body.id')
    .should('eq', 200)
    .then(() => bridgedVnet.info())
    .then(() => cy.validateVNetInfo(bridgedVnet))
    .then(() => {
      // extra validations (it is not include in the info tab)
      expect(bridgedVnet.json).to.have.property('VN_MAD', vnet.vnMad)
    })
}

/**
 * Creates a new 802.1Q vnet.
 *
 * @param {object} dotVnet - Vnet.
 */
const create802Dot1QNetwork = (dotVnet) => {
  /** @type {VirtualNetworkTest} */
  const vnet = {
    name: dotVnet.name,
    vnMad: '802.1Q',
    phydev: 'eth0',
    vlanId: '13',
  }

  cy.navigateMenu('networks', 'Virtual Networks')

  cy.createVirtualNetwork(vnet)
    .its('response.body.id')
    .should('eq', 200)
    .then(() => dotVnet.info())
    .then(() => cy.validateVNetInfo(dotVnet))
    .then(() => {
      // extra validations (it is not include in the info tab)
      expect(dotVnet.json).to.have.property('VN_MAD', vnet.vnMad)
      expect(dotVnet.json).to.have.property('BRIDGE', `onebr.${vnet.vlanId}`)
    })
}

/**
 * Updates a new 802.1Q vnet.
 *
 * @param {object} dotVnet - Vnet.
 */
const update802Dot1QNetwork = (dotVnet) => {
  /** @type {VirtualNetworkTest} */
  const vnet = {
    description: 'This virtual network was updated',
    inboundAvgBw: '1500',
    outboundAvgBw: '1000',
    context: { dns: '8.8.8.8' },
  }

  cy.navigateMenu('networks', 'Virtual Networks')

  cy.updateVirtualNetwork(dotVnet, vnet)
    .its('response.body.id')
    .should('eq', 200)
    .then(() => dotVnet.info())
    .then(() => cy.validateVNetInfo(dotVnet))
    .then(() => {
      // extra validations (it is not include in the info tab)
      const { TEMPLATE } = dotVnet.json

      expect(TEMPLATE).to.have.property('DESCRIPTION', vnet.description)
      expect(TEMPLATE).to.have.property('DNS', vnet.context.dns)
    })
}

/**
 * Renames the given vnet.
 *
 * @param {object} vnet - Vnet.
 * @param {string} newName - New name.
 */
const renameNetwork = (vnet, newName) => {
  cy.navigateMenu('networks', 'Virtual Networks')

  cy.clickVNetRow(vnet)
    .then(() => cy.renameResource(newName, Intercepts.SUNSTONE.NETWORK))
    .then(() => (vnet.name = newName))
    .then(() => cy.getVNetRow(vnet).contains(newName))
}

/**
 * Locks the given vnet.
 *
 * @param {object} vnet - Vnet.
 */
const lockNetwork = (vnet) => {
  cy.navigateMenu('networks', 'Virtual Networks')

  cy.lockVirtualNetwork(vnet)
    .then(() => vnet.info())
    .then(() => cy.validateLock(vnet))
}

/**
 * Unlocks the given vnet.
 *
 * @param {object} vnet - Vnet.
 */
const unlockNetwork = (vnet) => {
  cy.navigateMenu('networks', 'Virtual Networks')

  cy.unlockVirtualNetwork(vnet)
    .then(() => vnet.info())
    .then(() => cy.validateLock(vnet))
}

/**
 * Reserves a range on the vnet.
 *
 * @param {object} vnet - Vnet.
 * @returns {any} response of deletion
 */
const deleteNetwork = (vnet) => {
  cy.navigateMenu('networks', 'Virtual Networks')

  return cy.then(() => cy.deleteVirtualNetwork(vnet))
}

/**
 * Deletes the given vnet.
 *
 * @param {object} vnet - Vnet.
 */
const deleteNetworkAndValidate = (vnet) => {
  deleteNetwork(vnet).its('response.body.id').should('eq', 200)
}

/**
 * Fail to delete a network.
 *
 * @param {object} vnet - VNet
 * @param {string} extraError - Error
 */
const failDeleteNetwork = (vnet, extraError) => {
  deleteNetwork(vnet)
    .its('response.body.data')
    .should('contain', 'Cannot delete virtual network')
    .and('contain', extraError)
}

/**
 * Reserves a range on the vnet.
 *
 * @param {object} vnet - Vnet.
 * @param {ReserveLeaseTest} range -
 * @returns {any} response of reservation
 */
const reserveRange = (vnet, range) => {
  cy.navigateMenu('networks', 'Virtual Networks')

  return cy
    .then(() => cy.reserveVirtualNetwork(vnet, range))
    .its('response.body.data')
}

/**
 * Fail to reserve a range on the vnet.
 *
 * @param {object} vnet - Vnet.
 * @param {ReserveLeaseTest} range -
 * @param {string} error - Expected error message
 */
const failReserveRange = (vnet, range, error) => {
  cy.navigateMenu('networks', 'Virtual Networks')

  cy.then(() => cy.reserveVirtualNetwork(vnet, range))
    .its('response.body.data')
    .should('contain', error)
}

/**
 * Reserves a range on the vnet and validate it.
 *
 * @param {object} vnet - VNet
 * @param {ReserveLeaseTest} range - VNet range
 * @param {object} rangeVnet -
 */
const reserveRangeAndValidate = (vnet, range, rangeVnet) => {
  reserveRange(vnet, range)
    .then((rId) => rId && (rangeVnet.id = rId))
    .then(() => rangeVnet.info())
    .then(() => cy.validateVNetInfo(rangeVnet))
    .then(() => cy.validateVNetAddresses(rangeVnet))
}

/**
 * Deletes all the resources given.
 *
 * @param {object} vnets - VNets to be deleted.
 */
const deleteResources = (vnets) => {
  Object.entries(vnets).forEach(([, vnet]) => {
    vnet.delete()
  })
}

/**
 * Check restricted attributes.
 *
 * @param {object} vnet - Virtual Network to check.
 * @param {boolean} admin - If the user belongs to oneadmin group.
 * @param {Array} restrictedAttributesException - List of attributes that won't be checked
 */
const checkVnetRestrictedAttributes = (
  vnet,
  admin,
  restrictedAttributesException
) => {
  // Navigate to Virtaul Networks menu
  cy.navigateMenu('networks', 'Virtual Networks')

  // Get restricted attributes from OpenNebula config
  cy.getOneConf().then((config) => {
    // Virtual Network restricted attributes
    const vnetRestricteAttributes = transformAttributes(
      config.VNET_RESTRICTED_ATTR,
      restrictedAttributesException
    )

    // Check VM restricted attributes
    cy.checkVnetRestricteAttributes(vnetRestricteAttributes, vnet, admin)
  })
}

export {
  beforeAllVNTest,
  beforeEachVNTest,
  createBridgedNetwork,
  create802Dot1QNetwork,
  update802Dot1QNetwork,
  renameNetwork,
  lockNetwork,
  unlockNetwork,
  deleteNetworkAndValidate,
  failDeleteNetwork,
  reserveRangeAndValidate,
  failReserveRange,
  deleteResources,
  checkVnetRestrictedAttributes,
}
