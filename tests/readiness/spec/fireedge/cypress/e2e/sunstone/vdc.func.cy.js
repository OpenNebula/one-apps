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
import { Cluster, Datastore, Group, Host, VNet, Vdc } from '@models'

import { deleteVdc, renameVdc, vdcGUI, vdcInfo } from '@common/vdcs'

const CLUSTER = new Cluster('vdc_cluster')
const CLUSTER2 = new Cluster('vdc_cluster2')
const DS = new Datastore('vdc_datastore')
const DS2 = new Datastore('vdc_datastore2')
const HOST = new Host('192.168.0.1')
const HOST2 = new Host('localhost')
const VNET = new VNet('vdc_network')
const VNET2 = new VNet('vdc_network2')
const GROUP = new Group('vdc_group')
const GROUP2 = new Group('vdc_group2')

const NAME = 'tests_vdc'
const VDC = new Vdc(NAME)

const DUMMY_MAD = { imMad: 'dummy', vmmMad: 'dummy' }

const clusterTemplate = (name) => ({ name })

const datastoreTemplate = (name) => ({ name, DS_MAD: 'fs', TM_MAD: 'ssh' })

const hostTemplate = (hostname) => ({
  hostname,
  ...DUMMY_MAD,
})

const vnetTemplate = (name, ip) => ({
  NAME: name,
  DESCRIPTION: `description ${name}`,
  VN_MAD: 'dummy',
  BRIDGE: 'br0',
  AR: [{ TYPE: 'IP4', IP: ip, SIZE: 100 }],
  INBOUND_AVG_BW: '1500',
})

const groupTemplate = (name) => name

const templateHost = hostTemplate(HOST.name)
const templateHost2 = hostTemplate(HOST2.name)
const vnet = vnetTemplate(VNET.name, '192.168.150.100')
const vnet2 = vnetTemplate(VNET2.name, '192.168.149.100')

describe('Sunstone GUI in VMs tab', function () {
  before(function () {
    cy.fixture('auth')
      .then((auth) => cy.apiAuth(auth.admin))

      // CLUSTERS
      .then(() => CLUSTER.allocate(clusterTemplate(CLUSTER.name)))
      .then(() => CLUSTER2.allocate(clusterTemplate(CLUSTER2.name)))

      // DATASTORES
      .then(() =>
        DS.allocate({
          template: datastoreTemplate(DS.name),
          cluster: CLUSTER.json.ID,
        })
      )
      .then(() =>
        DS2.allocate({
          template: datastoreTemplate(DS2.name),
          cluster: CLUSTER2.json.ID,
        })
      )

      // HOSTS
      .then(() => HOST.allocate({ ...templateHost, cluster: CLUSTER.json.ID }))
      .then(() => !HOST.isMonitored && HOST.enable())
      .then(() =>
        HOST2.allocate({ ...templateHost2, cluster: CLUSTER2.json.ID })
      )
      .then(() => !HOST2.isMonitored && HOST2.enable())

      // VNETS
      .then(() => VNET.allocate({ template: vnet, cluster: CLUSTER.json.ID }))
      .then(() =>
        VNET2.allocate({ template: vnet2, cluster: CLUSTER2.json.ID })
      )

      // GROUPS
      .then(() => GROUP.allocate(groupTemplate(GROUP.name)))
      .then(() => GROUP2.allocate(groupTemplate(GROUP2.name)))
  })

  beforeEach(function () {
    cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
      qs: { externalToken: Cypress.env('TOKEN') },
    })
  })

  it('Should Create a new VDC', function () {
    vdcGUI({
      name: NAME,
      description: 'description tests_vdc',
      groups: { id: GROUP.id },
      clusters: { id: CLUSTER.id },
      datastores: { id: DS2.id },
      hosts: { id: HOST2.id },
      networks: { id: VNET2.id },
      customAttributes: { a: 'b', c: 'd' },
    })
  })

  it('Should Validate VDC info after created', function () {
    VDC.info().then(() => {
      vdcInfo(
        {
          name: NAME,
          description: 'description tests_vdc',
          groups: { id: GROUP.id },
          clusters: { id: CLUSTER.id },
          datastores: { id: DS2.id },
          hosts: { id: HOST2.id },
          networks: { id: VNET2.id },
          customAttributes: { a: 'b', c: 'd' },
        },
        { id: VDC.id, name: VDC.name }
      )
    })
  })

  it('Should Update a new VDC', function () {
    VDC.info().then(() => {
      vdcGUI(
        {
          description: 'updated description tests_vdc',
          groups: { id: GROUP2.id },
          clusters: { id: CLUSTER2.id },
          datastores: { id: DS.id },
          hosts: { id: HOST.id },
          networks: { id: VNET.id },
          customAttributes: { e: 'f', g: 'h' },
        },
        { id: VDC.id }
      )
    })
  })

  it('Should Validate VDC info after updated', function () {
    VDC.info().then(() => {
      vdcInfo(
        {
          name: NAME,
          description: 'updated description tests_vdc',
          groups: { id: GROUP2.id },
          clusters: { id: CLUSTER2.id },
          datastores: { id: DS.id },
          hosts: { id: HOST.id },
          networks: { id: VNET.id },
          customAttributes: { e: 'f', g: 'h' },
        },
        { id: VDC.id, name: VDC.name }
      )
    })
  })

  it('Should Rename VDC', function () {
    VDC.info().then(() => {
      renameVdc(VDC, `${NAME}_renamed`)
    })
  })

  it('Should DELETE a VDC', function () {
    VDC.info().then(() => {
      deleteVdc(VDC)
    })
  })
})
