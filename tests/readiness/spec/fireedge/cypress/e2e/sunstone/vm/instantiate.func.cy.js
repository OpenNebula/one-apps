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
import { adminContext, userContext } from '@utils/constants'

import {
  afterInstantiateTest,
  beforeEachTest,
  beforeInstantiateTest,
  changePermissionsVM,
  instantiateVMbyGUI,
  renameVM,
  resizeVM,
  updateVMConfiguration,
  validateConfigurationAfterUpdate,
  validateConfigurationBeforeUpdate,
  validateInfoTabOnVMInstantiated,
  validateNetworkTabOnVMInstantiated,
  validateStorageTabOnVMInstantiated,
} from '@common/vms'

import {
  Datastore,
  Host,
  Image,
  VNet,
  VirtualMachine,
  VmTemplate,
} from '@models'
import { PermissionsGui } from '@support/commands/common'

import { randomDate } from '@commands/helpers'

const date1 = randomDate()

const HOST = new Host()
const DS = new Datastore('default')
const IMG = new Image()
const VNET = new VNet()
const TEMPLATE = new VmTemplate()
const TEMPLATE_INPUTS = new VmTemplate()
const VM_USER = new VirtualMachine('test_vm_fireedge_user') // set after template is instantiated
const VM_ADMIN = new VirtualMachine('test_vm_fireedge_admin') // set after template is instantiated
const VM_USER_INPUTS = new VirtualMachine('test_vm_fireedge_inputs_user') // set after template is instantiated
const VM_ADMIN_INPUTS = new VirtualMachine('test_vm_fireedge_inputs_admin') // set after template is instantiated

const ALLOCATE_HOST_PARAMS = {
  hostname: 'localhost',
  imMad: 'dummy',
  vmmMad: 'dummy',
}

const VNET_XML = {
  NAME: 'test_vnet',
  VN_MAD: 'dummy',
  BRIDGE: 'br0',
  AR: [{ TYPE: 'IP4', IP: '10.0.0.10', SIZE: 100 }],
  INBOUND_AVG_BW: '1500',
}

const IMAGE_XML = {
  NAME: 'test_img',
  SIZE: 100,
  TYPE: 'datablock',
}

const TEMPLATE_XML = {
  NAME: 'test_template',
  MEMORY: 248,
  CPU: 1,
  VCPU: 1,
  HYPERVISOR: 'dummy',
  CONTEXT: { NETWORK: 'YES' },
}

const TEMPLATE_XML_INPUTS = {
  NAME: 'test_template_inputs',
  MEMORY: 248,
  CPU: 1,
  VCPU: 1,
  HYPERVISOR: 'dummy',
  CONTEXT: { NETWORK: 'YES' },
  USER_INPUTS: {
    INPUT1: 'M|text|Input1 description| |',
  },
}

const INSTANTIATE_INFO = (vmName) => ({
  name: vmName,
  instances: 1,
  hold: true,
  persistent: true,
  schedActions: [
    {
      action: 'hold',
      time: date1,
      periodic: 'ONETIME',
    },
    {
      action: 'terminate-hard',
      time: date1,
      periodic: 'PERIODIC',
      repeat: 'Monthly',
      repeatValue: '15',
      endType: 'Never',
    },
    {
      action: 'poweroff',
      periodic: 'RELATIVE',
      time: 3,
      period: 'days',
    },
  ],
})

const INSTANTIATE_INFO_USER = INSTANTIATE_INFO(VM_USER.name)
const INSTANTIATE_INFO_ADMIN = INSTANTIATE_INFO(VM_ADMIN.name)
const INSTANTIATE_INFO_INPUTS_USER = {
  ...INSTANTIATE_INFO(VM_USER_INPUTS.name),
  context: {
    userInputs: [
      {
        INPUT1: 'testinput1',
      },
    ],
  },
}
const INSTANTIATE_INFO_INPUTS_ADMIN = {
  ...INSTANTIATE_INFO(VM_ADMIN_INPUTS.name),
  context: {
    userInputs: [
      {
        INPUT1: 'testinput1',
      },
    ],
  },
}

const NEW_CONF = {
  osCpu: {
    arch: 'x86_64',
  },
  inputOutput: {
    inputs: [{ type: 'tablet', bus: 'usb' }],
  },
  context: {
    startScript: 'start script',
    encodeScript: true,
    customVars: {
      CUSTOM_VAR: 'CUSTOM_VALUE',
    },
  },
}

/** @type {PermissionsGui} */
const NEW_PERMISSIONS = {
  ownerUse: '0',
  ownerManage: '0',
  ownerAdmin: '1',
  groupUse: '1',
  groupManage: '1',
  groupAdmin: '1',
  otherUse: '1',
  otherManage: '1',
  otherAdmin: '1',
}

const localeSettings = {
  template: {
    FIREEDGE: {
      SCHEME: 'system',
      LANG: 'en',
      DEFAULT_VIEW: '',
      DEFAULT_ZONE_ENDPOINT: '',
    },
  },
}

// Modern cypress fails automatically on any exceptions
// should be removed once VM template async schema loading
// bug is resolved
Cypress.on('uncaught:exception', () => false)

// testIsolation clears all locale + session storage & cookies
describe('Sunstone GUI in VMs tab', { testIsolation: false }, function () {
  context('User', userContext, function () {
    before(function () {
      cy.fixture('auth')
        .then((auth) => cy.apiAuth(auth.admin))
        .then(() => cy.apiGetUser('user'))
        .then((user) => cy.apiUpdateUser(user.ID, localeSettings))
      beforeInstantiateTest({
        VNET,
        VNET_XML,
        DS,
        IMG,
        IMAGE_XML,
        HOST,
        ALLOCATE_HOST_PARAMS,
        TEMPLATE,
        TEMPLATE_XML,
        TEMPLATE_INPUTS,
        TEMPLATE_XML_INPUTS,
      })
    })

    beforeEach(function () {
      cy.fixture('auth')
        .then((auth) => cy.apiAuth(auth.user))
        .then(() => beforeEachTest())
    })

    it('Instantiate VM by GUI', function () {
      instantiateVMbyGUI({
        TEMPLATE,
        INSTANTIATE_INFO: INSTANTIATE_INFO_USER,
        VNET,
        IMG,
        VM: VM_USER,
      })
    })

    it('Validate INFO TAB on the VM instantiated by GUI', function () {
      validateInfoTabOnVMInstantiated({
        vm: VM_USER,
        validatePermissions: false,
        validateCost: false,
      })
    })

    it('Instantiate VM with user inputs by GUI', function () {
      instantiateVMbyGUI({
        TEMPLATE: TEMPLATE_INPUTS,
        INSTANTIATE_INFO: INSTANTIATE_INFO_INPUTS_USER,
        VNET,
        IMG,
        VM: VM_USER_INPUTS,
      })
    })

    it('Validate STORAGE TAB on the VM instantiated by GUI', function () {
      validateStorageTabOnVMInstantiated(VM_USER)
    })

    it('Validate NETWORKS TAB on the VM instantiated by GUI', function () {
      validateNetworkTabOnVMInstantiated(VM_USER)
    })

    it('Validate configuration tab BEFORE update it', function () {
      validateConfigurationBeforeUpdate(VM_USER)
    })

    it('Update VM configuration', function () {
      updateVMConfiguration({
        VM: VM_USER,
        NEW_CONF,
        INSTANTIATE_INFO: INSTANTIATE_INFO_USER,
      })
    })

    it('Validate configuration tab AFTER update it', function () {
      validateConfigurationAfterUpdate(VM_USER)
    })

    it('Rename VM', function () {
      renameVM(VM_USER, 'vmRenamed')
    })

    it('Resize VM', function () {
      resizeVM({
        VM: VM_USER,
        INSTANTIATE_INFO: INSTANTIATE_INFO_USER,
        newCapacity: { memory: '512', cpu: '2', vcpu: '2' },
      })
    })

    after(function () {
      afterInstantiateTest({
        INSTANTIATE_INFO: INSTANTIATE_INFO_USER,
        TEMPLATE,
        TEMPLATE_INPUTS,
        VM: VM_USER,
        VM_INPUTS: VM_USER_INPUTS,
      })
    })
  })

  context('Oneadmin', adminContext, function () {
    before(function () {
      beforeInstantiateTest({
        VNET,
        VNET_XML,
        DS,
        IMG,
        IMAGE_XML,
        HOST,
        ALLOCATE_HOST_PARAMS,
        TEMPLATE,
        TEMPLATE_XML,
        TEMPLATE_INPUTS,
        TEMPLATE_XML_INPUTS,
      })
    })

    beforeEach(function () {
      cy.fixture('auth')
        .then((auth) => cy.apiAuth(auth.admin))
        .then(() => beforeEachTest())
    })

    it('Instantiate VM by GUI', function () {
      instantiateVMbyGUI({
        TEMPLATE,
        INSTANTIATE_INFO: INSTANTIATE_INFO_ADMIN,
        VNET,
        IMG,
        VM: VM_ADMIN,
      })
    })

    it('Validate INFO TAB on the VM instantiated by GUI', function () {
      validateInfoTabOnVMInstantiated({
        vm: VM_ADMIN,
        validatePermissions: true,
        validateCost: false,
      })
    })

    it('Instantiate VM with user inputs by GUI', function () {
      instantiateVMbyGUI({
        TEMPLATE: TEMPLATE_INPUTS,
        INSTANTIATE_INFO: INSTANTIATE_INFO_INPUTS_ADMIN,
        VNET,
        IMG,
        VM: VM_ADMIN_INPUTS,
      })
    })

    it('Validate STORAGE TAB on the VM instantiated by GUI', function () {
      validateStorageTabOnVMInstantiated(VM_ADMIN)
    })

    it('Validate NETWORKS TAB on the VM instantiated by GUI', function () {
      validateNetworkTabOnVMInstantiated(VM_ADMIN)
    })

    it('Validate configuration tab BEFORE update it', function () {
      validateConfigurationBeforeUpdate(VM_ADMIN)
    })

    it('Update VM configuration', function () {
      updateVMConfiguration({
        VM: VM_ADMIN,
        NEW_CONF,
        INSTANTIATE_INFO: INSTANTIATE_INFO_USER,
      })
    })

    it('Validate configuration tab AFTER update it', function () {
      validateConfigurationAfterUpdate(VM_ADMIN)
    })

    it('Change Permissions VM', function () {
      changePermissionsVM({
        VM: VM_ADMIN,
        NEW_PERMISSIONS,
      })
    })

    it('Rename VM', function () {
      renameVM(VM_ADMIN, 'vmRenamed')
    })

    it('Resize VM', function () {
      resizeVM({
        VM: VM_ADMIN,
        INSTANTIATE_INFO: INSTANTIATE_INFO_USER,
        newCapacity: { memory: '512', cpu: '2', vcpu: '2' },
      })
    })

    after(function () {
      afterInstantiateTest({
        INSTANTIATE_INFO: INSTANTIATE_INFO_USER,
        TEMPLATE,
        TEMPLATE_INPUTS,
        VM: VM_ADMIN,
        VM_INPUTS: VM_ADMIN_INPUTS,
      })
    })
  })
})
