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
import {
  AddressRangeTest,
  VirtualNetworkTest,
} from '@support/commands/vnetTemplate/jsdoc'

/**
 * Fill information for Virtual Network creation/update.
 *
 * @param {VirtualNetworkTest} data - Virtual network data to fill the form
 */
const fillGeneralStep = (data = {}) => {
  cy.fillData({
    data,
    prefix: 'general-information-',
    attributes: [data.name && 'name', 'description'].filter(Boolean),
  })
}

/**
 * Fill addresses range dialog.
 *
 * @param {AddressRangeTest} ar - Address Range data to fill the form
 */
const fillAddressRangeForm = (ar) => {
  cy.fillData({
    data: ar,
    attributes: [
      'type',
      'ip',
      'mac',
      'ip6',
      'size',
      'prefixLength',
      'globalPrefix',
      'ulaPrefix',
      'custom',
    ],
  })
}

/**
 * Fill addresses ranges for Virtual Network.
 *
 * @param {VirtualNetworkTest} data - Virtual network data to fill the form
 */
const fillAddressesSection = ({ ranges } = {}) => {
  if (!ranges) return

  const ensuredARs = Array.isArray(ranges) ? ranges : [ranges]

  cy.navigateTab('addresses')

  cy.wrap(ensuredARs).each((ar) => {
    cy.getBySel('add-ar').click()
    fillAddressRangeForm(ar)
    cy.getBySel('dg-accept-button').click()
  })
}

/**
 * Fill advanced options for Virtual Network.
 *
 * @param {VirtualNetworkTest} data - Virtual network data to fill the form
 * @param {boolean} isUpdate - true if update, false if create
 */
const fillAdvancedStep = (data, isUpdate) => {
  cy.navigateTab('configuration')

  // Check bridge switch if the test is gonna set this value
  data.bridge && cy.getBySel('configuration-bridgeSwitch').check()

  // Uncheck physical device switch if the test is gonna set this value
  data.phydev && cy.getBySel('configuration-phyDevSwitch').uncheck()

  cy.fillData({
    data,
    prefix: 'configuration-',
    attributes: [
      'vnMad',
      'bridge',
      'phydev',
      'filterIpSpoofing',
      'filterMacSpoofing',
      'mtu',
      'automaticVlanId',
      'vlanId',
      'automaticOuterVlanId',
      'outerVlanId',
      'vxlanMode',
      'vxlanMc',
      'vxlanTep',
    ],
  })

  if (data?.clusters) {
    cy.navigateTab('clusters')
    cy.getClusterRow(data.clusters).click(FORCE)
  }

  !isUpdate && fillAddressesSection(data)

  cy.navigateTab('qos')
  cy.fillData({
    data,
    prefix: 'extra-qos-',
    attributes: [
      'inboundAvgBw',
      'inboundPeakBw',
      'inboundPeakKb',
      'outboundAvgBw',
      'outboundPeakBw',
      'outboundPeakKb',
    ],
  })

  cy.navigateTab('context')
  cy.fillData({
    data: data.context,
    prefix: 'context-',
    attributes: [
      'address',
      'mask',
      'gateway',
      'gateway6',
      'dns',
      'method',
      'method6',
    ],
  })
}

/**
 * Fill forms Template via GUI.
 *
 * @param {VirtualNetworkTest} data - Virtual network data to fill the form
 * @param {boolean} isUpdate - is update
 */
const fillVirtualNetworkTemplate = (data, isUpdate = false) => {
  fillGeneralStep(data, isUpdate)
  // go to advanced options
  cy.getBySel('stepper-next-button').click()
  fillAdvancedStep(data, isUpdate)
}

export { fillAdvancedStep, fillGeneralStep, fillVirtualNetworkTemplate }
