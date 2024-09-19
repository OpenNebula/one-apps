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
  Datastore,
  Host,
  MarketplaceApp,
  VNet,
  VirtualMachine,
  VmTemplate,
} from '@models'

import {
  afterBackupTest,
  beforeBackupTest,
  beforeEachTest,
  checkImportedVMTemplate,
  checkTheIPsFromVM,
  deployVM,
  importMarketplaceApp,
  instantiateVM,
  instantiateVMandValidate,
  openGuacamoleVNC,
  performBackup,
} from '@common/kvm'

import { adminContext, userContext } from '@utils/constants'

// Need to be host 0 because the host it's in a different virtual machine, so localhost is not valid.
const HOST = new Host('0')
const DS_IMG = new Datastore('default')
const DS_SYSTEM = new Datastore('system')
const VNET = new VNet()
const MARKET_APP = new MarketplaceApp('Ttylinux - KVM')
const MARKET_APP_BKS_USER = new MarketplaceApp('Alpine Linux 3.16')
const MARKET_APP_BKS_ADMIN = new MarketplaceApp('Alpine Linux 3.17')
const VM_USER = new VirtualMachine('test_vm_kvm_fireedge_user')
const VM_ADMIN = new VirtualMachine('test_vm_kvm_fireedge_admin')

const VNET_XML = {
  NAME: 'test_vnet_kvm',
  DESCRIPTION: 'vnet_kvm',
  VN_MAD: 'dummy',
  BRIDGE: 'br0',
  AR: [{ TYPE: 'IP4', IP: '192.168.150.100', SIZE: 100 }],
  INBOUND_AVG_BW: '1500',
}

const appName = (user = '') => {
  const userName = user ? `_${user}` : ''

  return `test export${userName}`
}

const setVms = (user = '') => {
  const userName = user ? `_${user}` : ''

  return {
    restic: { name: `test_kvm_restic${userName}`, deploy: true },
    rsync: { name: `test_kvm_rsync${userName}`, deploy: true },
  }
}

const VMS_ADMIN = setVms('admin')
const VMS_USER = setVms('user')
const TEMPLATE_NAME_ADMIN = appName('admin')
const TEMPLATE_NAME_USER = appName('user')
const DATASTORES = {
  restic: 'DS_RESTIC', // this is created in the file kvm_fireedge.rb
  rsync: 'DS_RSYNC', // this is created in the file kvm_fireedge.rb
}

const DATASTORES_ADMIN = {
  restic: 'DS_RESTIC', // this is created in the file kvm_fireedge.rb
  rsync: 'DS_RSYNC', // this is created in the file kvm_fireedge.rb
}

const TEMPLATE_CPU_MODEL_BASE = {
  HYPERVISOR: 'kvm',
  MEMORY: 128,
  CPU: 0.5,
  CPU_MODEL: {
    MODEL: 'host-passthrough',
    FEATURES: 'amd-ssbd',
  },
}

const TEMPLATE_CPU_MODEL_BASE_USER = {
  ...TEMPLATE_CPU_MODEL_BASE,
  name: 'template-cpu-model-user',
}

const TEMPLATE_CPU_MODEL_BASE_ADMIN = {
  ...TEMPLATE_CPU_MODEL_BASE,
  name: 'template-cpu-model-admin',
}

describe('Sunstone GUI in VMs tab - KVM', function () {
  context('User', userContext, function () {
    before(function () {
      beforeBackupTest({
        VNET,
        VNET_XML,
        DS_IMG,
        HOST,
        MARKET_APP,
        MARKET_APP_BKS: MARKET_APP_BKS_USER,
        DATASTORES,
        TEMPLATE_NAME: TEMPLATE_NAME_USER,
        VMS: VMS_USER,
        USER: 'user',
        TEMPLATES: [TEMPLATE_CPU_MODEL_BASE_USER],
      })
    })

    beforeEach(function () {
      cy.fixture('auth')
        .then((auth) => {
          cy.wrapperAuth(auth)
        })
        .then(() => beforeEachTest())
    })

    it('Should import a marketplace app', function () {
      importMarketplaceApp({
        MARKET_APP,
        DS_IMG,
      })
    })

    it('Should check imported VM Template', function () {
      checkImportedVMTemplate({
        APP_TEMPLATE: new VmTemplate(MARKET_APP.name),
        MARKET_APP,
      })
    })

    it('Should instantiate a VM', function () {
      instantiateVM({
        APP_TEMPLATE: new VmTemplate(MARKET_APP.name),
        VM: VM_USER,
        VNET,
      })
    })

    it('Should instantiate a VM with CPU model&features and check template', function () {
      // Attributes to validate
      const validateList = [
        {
          field: 'CPU_MODEL.MODEL',
          value: 'host-passthrough',
        },
        {
          field: 'CPU_MODEL.FEATURES',
          value: 'amd-ssbd',
        },
      ]

      instantiateVMandValidate(
        {
          APP_TEMPLATE: new VmTemplate(TEMPLATE_CPU_MODEL_BASE_USER.name),
          VM: new VirtualMachine('test_vm_kvm_cpu_model_user'),
        },
        validateList
      )
    })

    it('Should check the IPs from VM', function () {
      checkTheIPsFromVM(VM_USER)
    })

    it('Should open Guacamole VNC', function () {
      openGuacamoleVNC(VM_USER)
    })

    it('Should perform BACKUP RESTIC action to vm', function () {
      performBackup({ VM: VMS_USER?.restic, DATASTORE: DATASTORES?.restic })
    })

    it('Should perform BACKUP RSYNC action to vm', function () {
      performBackup({ VM: VMS_USER?.rsync, DATASTORE: DATASTORES?.rsync })
    })
  })

  context('Oneadmin', adminContext, function () {
    before(function () {
      beforeBackupTest({
        VNET,
        VNET_XML,
        DS_IMG,
        HOST,
        MARKET_APP,
        MARKET_APP_BKS: MARKET_APP_BKS_ADMIN,
        DATASTORES: DATASTORES_ADMIN,
        TEMPLATE_NAME: TEMPLATE_NAME_ADMIN,
        VMS: VMS_ADMIN,
        USER: 'oneadmin',
        TEMPLATES: [TEMPLATE_CPU_MODEL_BASE_ADMIN],
      })
    })

    after(function () {
      afterBackupTest({ VMS: VMS_ADMIN, TEMPLATE_NAME: TEMPLATE_NAME_ADMIN })
    })

    beforeEach(function () {
      cy.fixture('auth')
        .then((auth) => {
          cy.wrapperAuth(auth)
        })
        .then(() => beforeEachTest())
    })

    it('Should import a marketplace app', function () {
      importMarketplaceApp({
        MARKET_APP,
        DS_IMG,
      })
    })

    it('Should check imported VM Template', function () {
      checkImportedVMTemplate({
        APP_TEMPLATE: new VmTemplate(MARKET_APP.name),
        MARKET_APP,
      })
    })

    it('Should instantiate a VM', function () {
      instantiateVM({
        APP_TEMPLATE: new VmTemplate(MARKET_APP.name),
        VM: VM_ADMIN,
        VNET,
      })
    })

    it('Should instantiate a VM with CPU model&features and check template', function () {
      // Attributes to validate
      const validateList = [
        {
          field: 'CPU_MODEL.MODEL',
          value: 'host-passthrough',
        },
        {
          field: 'CPU_MODEL.FEATURES',
          value: 'amd-ssbd',
        },
      ]

      instantiateVMandValidate(
        {
          APP_TEMPLATE: new VmTemplate(TEMPLATE_CPU_MODEL_BASE_ADMIN.name),
          VM: new VirtualMachine('test_vm_kvm_cpu_model_admin'),
        },
        validateList
      )
    })

    it('Should deploy a VM', function () {
      deployVM({
        VM: VM_ADMIN,
        HOST,
        DS_SYSTEM,
      })
    })

    it('Should check the IPs from VM', function () {
      checkTheIPsFromVM(VM_ADMIN)
    })

    it('Should open Guacamole VNC', function () {
      openGuacamoleVNC(VM_ADMIN)
    })

    it('Should perform BACKUP RESTIC action to vm', function () {
      performBackup({
        VM: VMS_ADMIN?.restic,
        DATASTORE: DATASTORES_ADMIN?.restic,
      })
    })

    it('Should perform BACKUP RSYNC action to vm', function () {
      performBackup({
        VM: VMS_ADMIN?.rsync,
        DATASTORE: DATASTORES_ADMIN?.rsync,
      })
    })
  })
})
