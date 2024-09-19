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
import { randomDate } from '@commands/helpers'

import {
  addNicToVM,
  afterActionTest,
  beforeActionTest,
  beforeEachTest,
  deleteTheVMSnapshot,
  performIncrementalBackupActionToVM,
  performIndividualDiskRestore,
  performChangeOwnershipActionToVM,
  performDeployActionToVM,
  performHoldActionToVM,
  performLockActionToVM,
  performMigrateActionToVM,
  performMigrateLiveActionToVM,
  performPoweroffActionToVM,
  performPoweroffHardActionToVM,
  performRebootActionToVM,
  performRebootHardActionToVM,
  performReleaseActionToVM,
  performResscheduleActionToVM,
  performResumeActionToVM,
  performStopActionToVM,
  performSuspendActionToVM,
  performUndeployActionToVM,
  performUndeployHardActionToVM,
  performUnlockActionToVM,
  performUnrescheduleActionToVM,
  revertTheVMSnapshot,
  takeVMSnapshot,
  updateNic,
  validateTheVMHistory,
  validateTheVMSnapshots,
  addDiskToVM,
  validateVmActionButtons,
  attachDetachPciToVM,
  checkVMRestrictedAttributes,
} from '@common/vms'

import { Datastore, Group, Host, User, VNet, VmTemplate } from '@models'

const HOST = new Host('localhost')
const HOST2 = new Host('127.0.0.1')
const DS_SYS = new Datastore('system')
const DS_BAK = new Datastore('backup')
const TEMPLATE = new VmTemplate()
const TEMPLATE_RESTRICTED_ATTRIBUTES = new VmTemplate()
const SERVERADMIN_USER = new User('serveradmin')
const USERS_GROUP = new Group('users')
const VNET = new VNet()
const restrictedAttributesException = {
  NIC: ['FILTER'],
}

/**
 * Initialize as {@link VirtualMachine} after template is instantiated.
 *
 * @param {string} user - user name
 * @returns {object} - vms
 */
const setVms = (user = '') => {
  const userName = user ? `_${user}` : ''

  return {
    snapshot: { name: `test_vm_snapshot${userName}`, deploy: true },
    backup: { name: `test_vm_backup${userName}`, deploy: true },
    suspend: { name: `test_vm_suspend${userName}`, deploy: true },
    stop: { name: `test_vm_stop${userName}`, deploy: true },
    poweroff: { name: `test_vm_poweroff${userName}`, deploy: true },
    poweroffHard: { name: `test_vm_poweroff_hard${userName}`, deploy: true },
    resume: { name: `test_vm_resume${userName}`, deploy: true },
    reboot: { name: `test_vm_reboot${userName}`, deploy: true },
    rebootHard: { name: `test_vm_reboot_hard${userName}`, deploy: true },
    undeploy: { name: `test_vm_undeploy${userName}`, deploy: true },
    undeployHard: { name: `test_vm_undeploy_hard${userName}`, deploy: true },
    deploy: { name: `test_vm_deploy${userName}`, deploy: true },
    migrate: { name: `test_vm_migrate${userName}`, deploy: true },
    migrateLive: { name: `test_vm_migrate_live${userName}`, deploy: true },
    lock: { name: `test_vm_lock${userName}`, deploy: true },
    ownership: { name: `test_vm_ownership${userName}`, deploy: true },
    resched: { name: `test_vm_resched${userName}`, deploy: true },
    hold: { name: `test_vm_hold${userName}`, hold: true },
    addNicPCIAutomatic: {
      name: `test_vm_nicPCIAutomatic${userName}`,
      deploy: true,
    },
    updateNic: {
      name: `test_vm_updateNic${userName}`,
      deploy: true,
    },
    updateNicVMPowerOff: {
      name: `test_vm_test_vm_updateNicPowerOff${userName}`,
    },
    addNicPCIManual: { name: `test_vm_nicPCIManual${userName}`, deploy: true },
    attachNic: { name: `test_vm_attach_nic${userName}`, deploy: true },
    attachDisk: { name: `test_vm_attach_disk${userName}`, deploy: true },
    validateActionButtons: {
      name: `test_vm_action_buttons${userName}`,
      deploy: true,
    },
    addPciDevice: {
      name: `test_vm_pci_device_${userName}`,
      deploy: true,
    },
    addPciDeviceAddress: {
      name: `test_vm_pci_device_address_${userName}`,
      deploy: true,
    },
    restrictedAttributes: {
      name: `test_vm_restricted_attributes_${userName}`,
      deploy: true,
    },
  }
}

const VMS_USER = setVms('user')
const VMS_ADMIN = setVms('admin')

const SNAPSHOT_NAME = 'test_snapshot'

const HOST_PARAMS = { hostname: HOST.name, imMad: 'dummy', vmmMad: 'dummy' }
const HOST2_PARAMS = { hostname: HOST2.name, imMad: 'dummy', vmmMad: 'dummy' }

const TEMPLATE_XML = {
  NAME: 'test_template',
  HYPERVISOR: 'dummy',
  PERSISTENT: false,
  HOLD: 'YES',
  MEMORY: 248,
  CPU: 0.1,
  VCPU: 1,
  CONTEXT: { NETWORK: true },
}

const date1 = randomDate()
const TEMPLATE_RESTRICTED_ATTRIBUTES_XML = {
  NAME: 'test_template_restricted_attributes',
  HYPERVISOR: 'dummy',
  PERSISTENT: false,
  HOLD: 'YES',
  MEMORY: 248,
  CPU: 0.1,
  VCPU: 1,
  CONTEXT: { NETWORK: true },
  DISK: [
    {
      SIZE: '128',
      TOTAL_BYTES_SEC: '120',
      TYPE: 'swap',
    },
    {
      SIZE: '256',
      TYPE: 'swap',
    },
  ],
  NIC: [
    {
      NETWORK: 'test_vnet',
      INBOUND_AVG_BW: 1,
    },
    {
      NETWORK: 'test_vnet',
    },
  ],
  SCHED_ACTION: [
    {
      ACTION: 'hold',
      DAYS: '1',
      END_TYPE: '0',
      REPEAT: '1',
      TIME: date1.epoch,
    },
  ],
}

const VNET_XML = {
  NAME: 'test_vnet',
  AR: [{ TYPE: 'IP4', IP: '10.0.0.10', SIZE: 100 }],
  VN_MAD: 'bridge',
}

const UPDATE_NIC = {
  INBOUND_AVG_BW: '1',
  INBOUND_PEAK_BW: '1',
  INBOUND_PEAK_KB: '1',
  OUTBOUND_AVG_BW: '1',
  OUTBOUND_PEAK_BW: '1',
  OUTBOUND_PEAK_KB: '1',
}

const DS_BAK_TEMPLATE = {
  NAME: 'BACKUP_DATASTORE',
  TYPE: 'BACKUP_DS',
  DS_MAD: 'rsync',
  DISK_TYPE: 'FILE',
  RSYNC_SPARSIFY: 'NO',
  RSYNC_USER: 'oneadmin',
  RSYNC_HOST: 'localhost',
  RESTIC_SPARSIFY: 'NO',
  QCOW2_STANDALONE: 'NO',
  DATASTORE_CAPACITY_CHECK: 'NO',
  NO_DECOMPRESS: 'NO',
  cluster: '-1',
}

describe('Sunstone GUI in VMs tab', function () {
  context('User', userContext, function () {
    before(function () {
      beforeActionTest({
        DS_SYS,
        HOST,
        HOST2,
        HOST_PARAMS,
        HOST2_PARAMS,
        TEMPLATE,
        TEMPLATE_XML,
        VMS: VMS_USER,
        VNET,
        VNET_XML,
        TEMPLATE_RESTRICTED_ATTRIBUTES,
        TEMPLATE_RESTRICTED_ATTRIBUTES_XML,
      })
    })

    beforeEach(function () {
      cy.fixture('auth')
        .then((auth) => cy.apiAuth(auth.user))
        .then(() => beforeEachTest())
    })

    it('Should validate VM action buttons', function () {
      validateVmActionButtons(VMS_USER.validateActionButtons)
    })

    it('Should perform Attach NIC when VM is running', function () {
      addNicToVM({
        VM: VMS_USER.attachNic,
        VNET: {
          id: VNET?.json?.ID,
        },
      })
    })

    it('Should perform Attach disk when VM is running', function () {
      addDiskToVM({
        VM: VMS_USER.attachDisk,
        DISK: {
          size: 1024,
          format: 'raw',
          type: 'fs',
        },
      })
    })

    it('Should perform Attach PCI when VM is poweroff', function () {
      attachDetachPciToVM({
        VM: VMS_USER.addPciDevice,
        PCI: {
          deviceName: 'MCP79 OHCI USB 1.1 Controller',
          VENDOR: '10de',
          DEVICE: '0aa7',
          CLASS: '0c03',
        },
      })
    })

    it('Should validate the VM history as User', function () {
      validateTheVMHistory(VMS_USER?.snapshot)
    })

    it('Should perform SUSPEND action to VM as User', function () {
      performSuspendActionToVM(VMS_USER?.suspend)
    })

    it('Should perform STOP action to VM as User', function () {
      performStopActionToVM(VMS_USER?.stop)
    })

    it('Should perform POWEROFF action to VM as User', function () {
      performPoweroffActionToVM(VMS_USER?.poweroff)
    })

    it('Should perform POWEROFF-HARD action to VM as User', function () {
      performPoweroffHardActionToVM(VMS_USER?.poweroffHard)
    })

    it('Should perform RESUME action to VM as User', function () {
      performResumeActionToVM(VMS_USER?.poweroffHard)
    })

    it('Should perform REBOOT action to VM as User', function () {
      performRebootActionToVM(VMS_USER?.reboot)
    })

    it('Should perform REBOOT-HARD action to VM as User', function () {
      performRebootHardActionToVM(VMS_USER?.rebootHard)
    })

    it('Should perform UNDEPLOY action to VM as User', function () {
      performUndeployActionToVM(VMS_USER?.undeploy)
    })

    it('Should perform UNDEPLOY-HARD action to VM as User', function () {
      performUndeployHardActionToVM(VMS_USER?.undeployHard)
    })

    it('Should perform LOCK action to VM as User', function () {
      performLockActionToVM(VMS_USER?.lock)
    })

    it('Should perform UNLOCK action to VM as User', function () {
      performUnlockActionToVM(VMS_USER?.lock)
    })

    it('Should perform RELEASE action to VM as User', function () {
      performReleaseActionToVM(VMS_USER?.host, HOST)
    })

    it('Should check restricted attributes', function () {
      checkVMRestrictedAttributes(
        VMS_USER.restrictedAttributes,
        false,
        restrictedAttributesException
      )
    })

    after(function () {
      // comment this line if you want to keep the VMs after the test
      afterActionTest(VMS_USER)
    })
  })

  context('Oneadmin', adminContext, function () {
    before(function () {
      beforeActionTest({
        DS_SYS,
        DS_BAK,
        DS_BAK_TEMPLATE,
        HOST,
        HOST2,
        HOST_PARAMS,
        HOST2_PARAMS,
        TEMPLATE,
        TEMPLATE_XML,
        VMS: VMS_ADMIN,
        VNET,
        VNET_XML,
        TEMPLATE_RESTRICTED_ATTRIBUTES,
        TEMPLATE_RESTRICTED_ATTRIBUTES_XML,
      })
    })

    beforeEach(function () {
      cy.fixture('auth')
        .then((auth) => cy.apiAuth(auth.admin))
        .then(() => beforeEachTest())
    })

    it('Should validate VM action buttons', function () {
      validateVmActionButtons(VMS_ADMIN.validateActionButtons)
    })

    it('Should perform Attach NIC when VM is running', function () {
      addNicToVM({
        VM: VMS_ADMIN.attachNic,
        VNET: {
          id: VNET?.json?.ID,
        },
      })
    })

    it('Should perform Attach disk when VM is running', function () {
      addDiskToVM({
        VM: VMS_ADMIN.attachDisk,
        DISK: {
          size: 1024,
          format: 'raw',
          type: 'fs',
        },
      })
    })

    it('Should perform ADD nic PCI Automatic', function () {
      addNicToVM({
        VM: VMS_ADMIN.addNicPCIAutomatic,
        VNET: {
          id: VNET?.json?.ID,
          pci: {
            type: 'PCI Passthrough - Automatic',
            name: 'MCP79 OHCI USB 1.1 Controller',
            VENDOR: '10de',
            DEVICE: '0aa7',
            CLASS: '0c03',
          },
        },
      })
    })

    it('Should perform ADD nic PCI Manual', function () {
      addNicToVM({
        VM: VMS_ADMIN.addNicPCIManual,
        VNET: {
          id: VNET?.json?.ID,
          pci: {
            type: 'PCI Passthrough - Manual',
            shortAddress: '02:00.0',
          },
        },
      })
    })

    it('Should perform Attach & Detach PCI device when VM is poweroff', function () {
      attachDetachPciToVM({
        VM: VMS_ADMIN.addPciDevice,
        PCI: {
          deviceName: 'MCP79 EHCI USB 2.0 Controller',
          VENDOR: '10de',
          DEVICE: '0aa9',
          CLASS: '0c03',
        },
      })
    })

    it('Should perform Attach & Detach PCI specific device when VM is poweroff', function () {
      attachDetachPciToVM({
        VM: VMS_ADMIN.addPciDeviceAddress,
        PCI: {
          specifyDevice: true,
          shortAddress: '00:06.1',
        },
      })
    })

    it('Should take a VM snapshot', function () {
      takeVMSnapshot(VMS_ADMIN?.snapshot, SNAPSHOT_NAME)
    })

    it('Should validate the VM snapshots', function () {
      validateTheVMSnapshots(VMS_ADMIN?.snapshot)
    })

    it('Should revert the VM snapshot', function () {
      revertTheVMSnapshot(VMS_ADMIN?.snapshot, SNAPSHOT_NAME)
    })

    it('Should delete the VM snapshot', function () {
      deleteTheVMSnapshot(VMS_ADMIN?.snapshot, SNAPSHOT_NAME)
    })

    it('Should validate the VM history', function () {
      validateTheVMHistory(VMS_ADMIN?.snapshot)
    })

    it('Should perform INCREMENTAL BACKUP action to VM', function () {
      performIncrementalBackupActionToVM(VMS_ADMIN?.backup, DS_BAK)
    })

    it('Should restore individual disk from backup', function () {
      performIndividualDiskRestore(VMS_ADMIN?.backup, DS_BAK)
    })

    it('Should perform SUSPEND action to VM', function () {
      performSuspendActionToVM(VMS_ADMIN?.suspend)
    })

    it('Should perform STOP action to VM', function () {
      performStopActionToVM(VMS_ADMIN?.stop)
    })

    it('Should perform POWEROFF action to VM', function () {
      performPoweroffActionToVM(VMS_ADMIN?.poweroff)
    })

    it('Should perform POWEROFF-HARD action to VM', function () {
      performPoweroffHardActionToVM(VMS_ADMIN?.poweroffHard)
    })

    it('Should perform RESUME action to VM', function () {
      performResumeActionToVM(VMS_ADMIN?.poweroffHard)
    })

    it('Should perform REBOOT action to VM', function () {
      performRebootActionToVM(VMS_ADMIN?.reboot)
    })

    it('Should perform REBOOT-HARD action to VM', function () {
      performRebootHardActionToVM(VMS_ADMIN?.rebootHard)
    })

    it('Should perform UNDEPLOY action to VM', function () {
      performUndeployActionToVM(VMS_ADMIN?.undeploy)
    })

    it('Should perform UNDEPLOY-HARD action to VM', function () {
      performUndeployHardActionToVM(VMS_ADMIN?.undeployHard)
    })

    it('Should perform DEPLOY action to VM', function () {
      performDeployActionToVM(VMS_ADMIN?.deploy, HOST, DS_SYS)
    })

    it('Should perform MIGRATE action to VM', function () {
      performMigrateActionToVM(VMS_ADMIN?.migrate, HOST, HOST2, DS_SYS)
    })

    it('Should perform MIGRATE-LIVE action to VM', function () {
      performMigrateLiveActionToVM(VMS_ADMIN?.migrateLive, HOST, HOST2, DS_SYS)
    })

    it('Should perform LOCK action to VM', function () {
      performLockActionToVM(VMS_ADMIN?.lock)
    })

    it('Should perform UNLOCK action to VM', function () {
      performUnlockActionToVM(VMS_ADMIN?.lock)
    })

    it('Should perform CHANGE-OWNERSHIP (user & group) action to VM', function () {
      performChangeOwnershipActionToVM(
        VMS_ADMIN?.ownership,
        SERVERADMIN_USER,
        USERS_GROUP
      )
    })

    it('Should perform RESCHEDULE action to VM', function () {
      performResscheduleActionToVM(VMS_ADMIN?.resched)
    })

    it('Should perform UN-RESCHEDULE action to VM', function () {
      performUnrescheduleActionToVM(VMS_ADMIN?.resched)
    })

    it('Should perform HOLD action to VM', function () {
      performHoldActionToVM(VMS_ADMIN?.hold, HOST, HOST2)
    })

    it('Should perform RELEASE action to VM', function () {
      performReleaseActionToVM(VMS_ADMIN?.host, HOST)
    })

    it('Should perform Update NIC when VM is running', function () {
      addNicToVM({
        VM: VMS_ADMIN.updateNic,
        VNET: {
          id: VNET?.json?.ID,
        },
      })
      updateNic({ VM: VMS_ADMIN.updateNic }, UPDATE_NIC)
    })

    it('Should perform Update NIC when VM is poweroff', function () {
      addNicToVM({
        VM: VMS_ADMIN.updateNicVMPowerOff,
        VNET: {
          id: VNET?.json?.ID,
        },
      })

      updateNic({ VM: VMS_ADMIN.updateNicVMPowerOff }, UPDATE_NIC, true)
    })

    it('Should check restricted attributes', function () {
      checkVMRestrictedAttributes(
        VMS_ADMIN.restrictedAttributes,
        true,
        restrictedAttributesException
      )
    })

    after(function () {
      // comment this line if you want to keep the VMs after the test
      afterActionTest(VMS_ADMIN)
    })
  })
})
