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
import { VmTemplate, VRouter, VRouterTemplate, User, VNet, Host } from '@models'

import {
  vrtemplateUpdate,
  vrtemplateDelete,
  vrtemplateRename,
  vrtemplateChown,
  vrtemplateInstantiate,
  vrtemplatePermissions,
} from '@common/vrouterTemplate'

import {
  vrouterinstancePermissions,
  vrouterRename,
  vrouterDelete,
} from '@common/vrouter'

const TEST_VMTEMPLATE = new VmTemplate('TEMP_VmTemplate')
const TESTVROUTERTEMPLATE = new VRouterTemplate('TestVRouterTemplate')
const TESTVROUTER = new VRouter('TESTVR1')
const VNET1 = new VNet('TestVNetTemplate')
const VNET2 = new VNet('TestVNetTemplate')
const TESTHOST = new Host('localhost')
const DUMMY_MAD = { imMad: 'dummy', vmmMad: 'dummy' }
const HOST_PARAMS = { hostname: TESTHOST.name, ...DUMMY_MAD }
const NEWOWNER = new User('NewVRouterTemplateOwner', 'opennebula')

const VNET_TEMPLATE_NIC1 = (VNET_TEMPLATE_NAME, CLUSTER_ID) => ({
  template: {
    NAME: VNET_TEMPLATE_NAME,
    VN_MAD: 'bridge',
    CLUSTER_IDS: CLUSTER_ID,
    AR: [
      {
        IP: '10.0.0.1',
        SIZE: '5',
        TYPE: 'IP4',
      },
    ],
  },
})

const VNET_TEMPLATE_NIC2 = (VNET_TEMPLATE_NAME, CLUSTER_ID) => ({
  template: {
    NAME: VNET_TEMPLATE_NAME,
    VN_MAD: 'bridge',
    CLUSTER_IDS: CLUSTER_ID,
    AR: [
      {
        IP: '10.10.0.1',
        SIZE: '5',
        TYPE: 'IP4',
      },
    ],
  },
})

const VM_TEMPLATE_JSON = () => ({
  NAME: 'TEMP_VmTemplate',
  CPU: 1,
  MEMORY: 128,
})

const VROUTER_TEMPLATE_XML = () => ({
  NAME: 'VRouterTemplateTesting',
  VROUTER: 'YES',
  HYPERVISOR: 'dummy',
  MEMORY: 1,
  MEMORYUNIT: 'MB',
  CPU: 1,
})

const BASE_VROUTER_TEMPLATE_JSON = () => ({
  hypervisor: 'dummy',
  NAME: 'VRouterTemplateTestingGUI',
  description: 'vr template description',
  memory: 1,
  cpu: 1,
  vcpu: 1,
})

const VRTEMPLATE_GUI = () => ({
  ...BASE_VROUTER_TEMPLATE_JSON,
  hypervisor: 'dummy',
  vrouter: 'yes',
  user: 'oneadmin',
  group: 'oneadmin',
  context: {
    network: true,
    token: true,
    report: true,
    autoAddSshKey: true,
    sshKey: '',
    startScript: '',
    encodeScript: true,
    userInputs: [
      {
        type: 'text',
        name: 'name',
        description: 'description',
        defaultValue: 'defaultValue',
        mandatory: true,
      },
    ],
    customVars: {
      CUSTOM_VAR: 'CUSTOM_VALUE',
    },
  },
})

const VROUTER_TEMPLATE_INSTANTIATE_GUI = ({ vnets, secgroups }) => ({
  general: {
    name: 'TESTVR1',
    description: 'Test Description',
    keepaliveid: '123',
    keepalivepassword: 'password',
    vmname: 'TESTVR1CUSTOMVM',
    numberofinstances: 2,
    startonhold: false,
    instantiateaspersistent: false,
  },
  networking: [
    {
      alias: false,
      autonetworkselect: false,
      rdp: true,
      ssh: true,
      vnet: vnets?.nic1,
      secgroup: secgroups?.default,
    },
    {
      alias: false,
      autonetworkselect: false,
      rdp: true,
      ssh: true,
      vnet: vnets?.nic2,
      secgroup: secgroups?.default,
    },
  ],
})

const NEW_PERMISSIONS = {
  ownerUse: '1',
  ownerManage: '1',
  groupUse: '1',
  groupManage: '1',
  otherUse: '1',
  otherManage: '1',
}

// Modern cypress fails automatically on any exceptions
// should be removed once VM template async schema loading
// bug is resolved
Cypress.on('uncaught:exception', () => false)

describe('Sunstone GUI in VRouter Templates tab', function () {
  before(function () {
    cy.fixture('auth')
      .then((auth) => cy.apiAuth(auth.admin))
      .then(() => cy.cleanup())
      .then(() => TEST_VMTEMPLATE.allocate(VM_TEMPLATE_JSON()))
      .then(() => TESTVROUTERTEMPLATE.allocate(VROUTER_TEMPLATE_XML()))
      .then(() => NEWOWNER.allocate())
      .then(() => TESTHOST.allocate(HOST_PARAMS))
      .then(() => !TESTHOST.isMonitored && TESTHOST.enable())
      .then(
        () => VNET1.allocate(VNET_TEMPLATE_NIC1('TestVNet1', 0)) // Use default cluster
      )
      .then(
        () => VNET2.allocate(VNET_TEMPLATE_NIC2('TestVNet2', 0)) // Use default cluster
      )
  })

  beforeEach(function () {
    cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
      qs: { externalToken: Cypress.env('TOKEN') },
    })
  })

  it('Should instantiate VRouter Template', function () {
    vrtemplateInstantiate({
      existingId: TESTVROUTERTEMPLATE.id,
      template: VROUTER_TEMPLATE_INSTANTIATE_GUI({
        vnets: {
          nic1: VNET1,
          nic2: VNET2,
        },
        secgroups: {
          default: 0,
        },
      }),
    }).then(({ response }) => {
      const { body: { data: id } = {} } = response
      TESTVROUTER.id = id
    })
  })

  it('Should rename a vrouter', function () {
    vrouterRename(TESTVROUTER, 'RenamedVRouterInstanceTest')
  })

  it('Should change vrouter permissions', function () {
    vrouterinstancePermissions({
      VRouterInstance: TESTVROUTER,
      NEW_PERMISSIONS: NEW_PERMISSIONS,
    })
  })

  it('Should delete a vrouter', function () {
    vrouterDelete(TESTVROUTER)
  })

  it('Should update VRouter Template', function () {
    vrtemplateUpdate({
      existingId: TESTVROUTERTEMPLATE.id,
      template: VRTEMPLATE_GUI(),
    })
  })

  it('Should change owner VRouter Template', function () {
    vrtemplateChown(TESTVROUTERTEMPLATE, NEWOWNER)
  })

  it('Should change permissions VRouter Template', function () {
    vrtemplatePermissions({
      VrTemplate: TESTVROUTERTEMPLATE,
      NEW_PERMISSIONS: NEW_PERMISSIONS,
    })
  })

  it('Should rename VRouter Template', function () {
    vrtemplateRename(TESTVROUTERTEMPLATE, 'RenamedVRouterTemplateTest')
  })

  it('Should delete VRouter Template', function () {
    vrtemplateDelete(TESTVROUTERTEMPLATE)
  })

  it('Should cleanup allocated resources...', function () {
    cy.cleanup()
  })
})
