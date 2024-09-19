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

import {
  VirtualNetworkTest,
  AddressRangeTest,
  ReserveLeaseTest,
} from '@support/commands/vnet/jsdoc'

/**
 * Fill information for Virtual Network creation/update.
 *
 * @param {VirtualNetworkTest} data - Virtual network data to fill the form
 * @param {boolean} isUpdate - true if update, false if create
 */
const fillGeneralStep = (data, isUpdate = false) => {
  cy.fillData({
    data,
    prefix: 'information-',
    attributes: [!isUpdate && 'name', 'description', 'cluster'].filter(Boolean),
  })

  // Check bridge switch if the test is gonna set this value
  data.bridge && cy.getBySel('general-configuration-bridgeSwitch').check()

  cy.fillData({
    data,
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
    prefix: 'configuration-',
  })
}

/**
 * Fill addresses range dialog.
 *
 * @param {ReserveLeaseTest} data - Reservation data
 */
const fillReservationForm = (data) => {
  cy.fillData({
    data,
    attributes: ['__switch__', 'size', 'networkId', 'name', 'arId', 'addr'],
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
  !isUpdate && fillAddressesSection(data)

  cy.navigateTab('qos')
  cy.fillData({
    data,
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
const fillVirtualNetwork = (data, isUpdate = false) => {
  fillGeneralStep(data, isUpdate)
  // go to advanced options
  cy.getBySel('stepper-next-button').click()
  fillAdvancedStep(data, isUpdate)
}

export {
  fillGeneralStep,
  fillAdvancedStep,
  fillVirtualNetwork,
  fillReservationForm,
}
