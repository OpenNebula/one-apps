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
  beforeEachVNTest,
  create802Dot1QNetwork,
  createBridgedNetwork,
  deleteNetworkAndValidate,
  deleteResources,
  failDeleteNetwork,
  failReserveRange,
  lockNetwork,
  renameNetwork,
  reserveRangeAndValidate,
  unlockNetwork,
  update802Dot1QNetwork,
  checkVnetRestrictedAttributes,
} from '@common/vn'
import { VNet } from '@models'
import { adminContext, userContext } from '@utils/constants'
import { v4 as uuidv4 } from 'uuid'
const { ReserveLeaseTest } = require('@commands/vnet/jsdoc')

const setVnets = (user = '') => {
  const userName = user ? `_${user}` : ''

  return {
    bridgedVnet: new VNet(`bridge_${uuidv4()}${userName}`),
    renameVnet: new VNet(`rename_${uuidv4()}${userName}`),
    lockUnlockVnet: new VNet(`lock_unlock_${uuidv4()}${userName}`),
    deleteVnet: new VNet(`delete_${uuidv4()}${userName}`),
    dotVnet: new VNet(`dot_${uuidv4()}${userName}`),
    r1Vnet: new VNet(`r1_${uuidv4()}${userName}`),
    r2Vnet: new VNet(`r2_${uuidv4()}${userName}`),
    r3Vnet: new VNet(`r3_${uuidv4()}${userName}`),
    r4Vnet: new VNet(`r4_${uuidv4()}${userName}`),
    r5Vnet: new VNet(`r5_${uuidv4()}${userName}`),
    r6Vnet: new VNet(`r6_${uuidv4()}${userName}`),
  }
}

const getUserVNets = () => {
  const { renameVnet, lockUnlockVnet, deleteVnet, bridgedVnet } =
    setVnets('user')

  return {
    renameVnet,
    lockUnlockVnet,
    deleteVnet,
    bridgedVnet,
  }
}

const VNETS_USER = getUserVNets()
const VNETS_ADMIN = setVnets('admin')

describe('Sunstone GUI in Virtual Network tab', function () {
  context('User', userContext, function () {
    before(function () {
      cy.fixture('auth')
        .then((auth) => cy.apiAuth(auth.admin))
        .then(() => {
          cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
            qs: { externalToken: Cypress.env('TOKEN') },
          })
        })
        .then(() => {
          Object.entries(VNETS_USER).forEach(([, vnet]) => {
            vnet
              .allocate({
                template: {
                  NAME: vnet.name,
                  VN_MAD: 'bridge',
                  AR: {
                    TYPE: 'IP4',
                    IP: '172.20.0.1',
                    SIZE: '1',
                    NAME: 'AR0',
                  },
                },
              })
              .then(() =>
                vnet.chmod({
                  ownerUse: 1,
                  ownerManage: 1,
                  ownerAdmin: 0,
                  groupUse: 0,
                  groupManage: 0,
                  groupAdmin: 0,
                  otherUse: 1,
                  otherManage: 1,
                  otherAdmin: 0,
                })
              )
          })
        })
    })

    beforeEach(function () {
      cy.fixture('auth')
        .then((auth) => cy.apiAuth(auth.user))
        .then(() => beforeEachVNTest())
    })

    it('should rename vnet', function () {
      const newName = VNETS_USER.renameVnet.name.replace(
        'rename_',
        'rename_update_'
      )
      renameNetwork(VNETS_USER.renameVnet, newName)
    })

    it('should lock vnet', function () {
      lockNetwork(VNETS_USER.lockUnlockVnet)
    })

    it('should unlock vnet', function () {
      unlockNetwork(VNETS_USER.lockUnlockVnet)
    })

    it('should delete vnet', function () {
      deleteNetworkAndValidate(VNETS_USER.deleteVnet)
    })

    it('should check restricted attributes', function () {
      checkVnetRestrictedAttributes(VNETS_USER.bridgedVnet, false, [])
    })

    after(function () {
      deleteResources(VNETS_USER)
    })
  })

  context('Oneadmin', adminContext, function () {
    before(function () {
      cy.fixture('auth')
        .then((auth) => cy.apiAuth(auth.admin))
        .then(() => {
          const { renameVnet, lockUnlockVnet, deleteVnet } = VNETS_ADMIN

          Object.entries({ renameVnet, lockUnlockVnet, deleteVnet }).forEach(
            ([, vnet]) => {
              vnet.allocate({ template: { NAME: vnet.name, VN_MAD: 'bridge' } })
            }
          )
        })
    })

    beforeEach(beforeEachVNTest)

    it('should create a new bridged vnet', function () {
      createBridgedNetwork(VNETS_ADMIN.bridgedVnet)
    })

    it('should check restricted attributes', function () {
      checkVnetRestrictedAttributes(VNETS_ADMIN.bridgedVnet, true, [])
    })

    it('should create a new 802.1Q vnet', function () {
      create802Dot1QNetwork(VNETS_ADMIN.dotVnet)
    })

    it('should update the 802.1Q vnet', function () {
      update802Dot1QNetwork(VNETS_ADMIN.dotVnet)
    })

    it('should rename vnet', function () {
      const newName = VNETS_ADMIN.renameVnet.name.replace(
        'rename_',
        'rename_update_'
      )
      renameNetwork(VNETS_ADMIN.renameVnet, newName)
    })

    it('should lock vnet', function () {
      lockNetwork(VNETS_ADMIN.lockUnlockVnet)
    })

    it('should unlock vnet', function () {
      unlockNetwork(VNETS_ADMIN.lockUnlockVnet)
    })

    it('should delete a vnet', function () {
      deleteNetworkAndValidate(VNETS_ADMIN.deleteVnet)
    })

    it('should reserve a range1 and validate it', function () {
      const rangeVnet = VNETS_ADMIN.r1Vnet
      /** @type {ReserveLeaseTest} */
      const range = {
        __switch__: 'vnet',
        name: rangeVnet.name,
        size: 2,
      }
      reserveRangeAndValidate(VNETS_ADMIN.bridgedVnet, range, rangeVnet)
    })

    it('should reserve a range2 and validate it', function () {
      const rangeVnet = VNETS_ADMIN.r2Vnet
      /** @type {ReserveLeaseTest} */
      const range = {
        __switch__: 'vnet',
        name: rangeVnet.name,
        size: 6,
      }
      reserveRangeAndValidate(VNETS_ADMIN.bridgedVnet, range, rangeVnet)
    })

    it('should reserve a range3 and validate it', function () {
      const rangeVnet = VNETS_ADMIN.r3Vnet
      /** @type {ReserveLeaseTest} */
      const range = {
        __switch__: 'vnet',
        name: rangeVnet.name,
        size: 1,
      }
      reserveRangeAndValidate(VNETS_ADMIN.bridgedVnet, range, rangeVnet)
    })

    it('should reserve a range4 and validate it', function () {
      const rangeVnet = VNETS_ADMIN.r4Vnet
      /** @type {ReserveLeaseTest} */
      const range = {
        __switch__: 'vnet',
        name: rangeVnet.name,
        size: 20,
      }
      reserveRangeAndValidate(VNETS_ADMIN.bridgedVnet, range, rangeVnet)
    })

    it('should reserve a range5 and validate it', function () {
      const rangeVnet = VNETS_ADMIN.r5Vnet
      /** @type {ReserveLeaseTest} */
      const range = {
        __switch__: 'vnet',
        name: rangeVnet.name,
        size: 240,
      }
      reserveRangeAndValidate(VNETS_ADMIN.bridgedVnet, range, rangeVnet)
    })

    it('should reserve IPv6 to range6 and validate it', function () {
      const rangeVnet = VNETS_ADMIN.r6Vnet
      /** @type {ReserveLeaseTest} */
      const range = {
        __switch__: 'vnet',
        name: rangeVnet.name,
        size: 10,
        arId: '2',
      }
      reserveRangeAndValidate(VNETS_ADMIN.bridgedVnet, range, rangeVnet)
    })

    it('should fail to reserve more addresses than available', function () {
      /** @type {ReserveLeaseTest} */
      const range = { __switch__: 'vnet', name: `rFail_${uuidv4()}`, size: 500 }

      failReserveRange(
        VNETS_ADMIN.bridgedVnet,
        range,
        'Not enough free addresses in an address range'
      )
    })

    it('should fail to reserve with an existing reservation name', function () {
      /** @type {ReserveLeaseTest} */
      const range = {
        __switch__: 'vnet',
        name: VNETS_ADMIN.r1Vnet.name,
        size: 1,
      }

      failReserveRange(
        VNETS_ADMIN.bridgedVnet,
        range,
        'NAME is already taken by NET'
      )
    })

    it('should add to an existing reservation', function () {
      /** @type {ReserveLeaseTest} */
      const ar = {
        __switch__: 'ar',
        networkId: `${VNETS_ADMIN.r6Vnet.id}`,
        arId: '1',
        size: 4,
      }

      reserveRangeAndValidate(VNETS_ADMIN.bridgedVnet, ar, VNETS_ADMIN.r6Vnet)
    })

    it('should not allow to make double reservations', function () {
      /** @type {ReserveLeaseTest} */
      const range = { __switch__: 'vnet', name: `rFail_${uuidv4()}`, size: 1 }

      failReserveRange(
        VNETS_ADMIN.r1Vnet,
        range,
        'Cannot reserve addresses from a reserved'
      )
    })

    it('should fail to delete vnet with reservations', function () {
      failDeleteNetwork(
        VNETS_ADMIN.bridgedVnet,
        'Can not remove a virtual network with leases in use'
      )
    })

    after(function () {
      deleteResources(VNETS_ADMIN)
    })
  })
})
