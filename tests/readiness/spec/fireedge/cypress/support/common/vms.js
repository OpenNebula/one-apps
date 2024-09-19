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
const {
  Host,
  Datastore,
  VirtualMachine,
  User,
  Group,
  VmTemplate,
} = require('@models')
const { Intercepts, createIntercept } = require('@support/utils')

/**
 * Take snapshot.
 *
 * @param {VirtualMachine} vm - VM
 * @param {string} name - name
 */
const takeVMSnapshot = (vm, name) => {
  if (!vm || !name) return

  cy.navigateMenu('instances', 'VMs')
  cy.takeVmSnapshot(vm, name).its('response.body.id').should('eq', 200)
}

/**
 * Validate Snapshot.
 *
 * @param {VirtualMachine} vm - VM
 */
const validateTheVMSnapshots = (vm) => {
  if (!vm) return

  cy.navigateMenu('instances', 'VMs')
  vm.info(() => cy.validateVmSnapshots(vm))
}

/**
 * Revert Snapshot.
 *
 * @param {VirtualMachine} vm - VM
 * @param {string} name - name
 */
const revertTheVMSnapshot = (vm, name) => {
  if (!vm || !name) return

  cy.navigateMenu('instances', 'VMs')
  cy.revertVmSnapshot(vm, name).its('response.body.id').should('eq', 200)
}

/**
 * Delete Snapshot.
 *
 * @param {VirtualMachine} vm - VM
 * @param {string} name - NAME
 */
const deleteTheVMSnapshot = (vm, name) => {
  if (!vm || name) return

  cy.navigateMenu('instances', 'VMs')
  cy.deleteVmSnapshot(vm, name).its('response.body.id').should('eq', 200)
}

/**
 * Validate Vm history.
 *
 * @param {VirtualMachine} vm - VM
 */
const validateTheVMHistory = (vm) => {
  if (!vm) return

  cy.navigateMenu('instances', 'VMs')
  vm.info(() => cy.validateVmHistory(vm))
}

/**
 * Perform suspend action.
 *
 * @param {VirtualMachine} vm - VM
 */
const performSuspendActionToVM = (vm) => {
  if (!vm) return

  cy.navigateMenu('instances', 'VMs')
  cy.suspendVm(vm).then(() => cy.validateVmState('SUSPENDED'))
}

/**
 * Perform stop action.
 *
 * @param {VirtualMachine} vm - VM
 */
const performStopActionToVM = (vm) => {
  if (!vm) return

  cy.navigateMenu('instances', 'VMs')
  cy.stopVm(vm).then(() => cy.validateVmState(/STOPPED|POWEROFF/g))
}

/**
 * Perform poweroff action.
 *
 * @param {VirtualMachine} vm - VM
 */
const performPoweroffActionToVM = (vm) => {
  if (!vm) return

  cy.navigateMenu('instances', 'VMs')
  cy.powerOffVm(vm).then(() => cy.validateVmState(/STOPPED|POWEROFF/g))
}

/**
 * Perform poweroff hard action.
 *
 * @param {VirtualMachine} vm - VM
 */
const performPoweroffHardActionToVM = (vm) => {
  if (!vm) return

  cy.navigateMenu('instances', 'VMs')
  cy.powerOffHardVm(vm).then(() => cy.validateVmState(/STOPPED|POWEROFF/g))
}

/**
 * Perform Resume action.
 *
 * @param {VirtualMachine} vm - VM
 */
const performResumeActionToVM = (vm) => {
  if (!vm) return

  cy.navigateMenu('instances', 'VMs')
  cy.resumeVm(vm).then(() => cy.validateVmState('RUNNING'))
}

/**
 * Perform Reboot action.
 *
 * @param {VirtualMachine} vm - VM
 */
const performRebootActionToVM = (vm) => {
  if (!vm) return

  cy.navigateMenu('instances', 'VMs')
  cy.rebootHardVm(vm).then(() => cy.validateVmState('RUNNING'))
}

/**
 * Perform Reboot hard action.
 *
 * @param {VirtualMachine} vm - VM
 */
const performRebootHardActionToVM = (vm) => {
  if (!vm) return

  cy.navigateMenu('instances', 'VMs')
  cy.rebootHardVm(vm).then(() => cy.validateVmState('RUNNING'))
}

/**
 * Perform Undeploy action.
 *
 * @param {VirtualMachine} vm - VM
 */
const performUndeployActionToVM = (vm) => {
  if (!vm) return

  cy.navigateMenu('instances', 'VMs')
  cy.undeployVm(vm).then(() =>
    cy.validateVmState(/UNDEPLOYED|SHUTDOWN_UNDEPLOY/g)
  )
}

/**
 * Perform Undeploy hard action.
 *
 * @param {VirtualMachine} vm - VM
 */
const performUndeployHardActionToVM = (vm) => {
  if (!vm) return
  const intercept = createIntercept(Intercepts.SUNSTONE.VM_ACTION)
  cy.navigateMenu('instances', 'VMs')
  cy.undeployHardVm(vm)
    .then(() => cy.wait(intercept))
    .then(() => cy.validateVmState(/UNDEPLOYED|SHUTDOWN_UNDEPLOY/g))
}

/**
 * Perform deploy action.
 *
 * @param {VirtualMachine} vm - VM
 * @param {Host} host - HOST
 * @param {Datastore} ds - DATASTORE
 */
const performDeployActionToVM = (vm, host, ds) => {
  if (!vm || !host || !ds) return

  const deployOptions = { host: host, ds }
  cy.navigateMenu('instances', 'VMs')
  host
    .waitMonitored()
    .then(() => cy.deployVm(vm, deployOptions))
    .then(() => cy.validateVmState('RUNNING'))
}

/**
 * Perform Migrate action.
 *
 * @param {VirtualMachine} vm - VM
 * @param {Host} host1 - HOST
 * @param {Host} host2 - HOST
 * @param {Datastore} ds - DATASTORE
 */
const performMigrateActionToVM = (vm, host1, host2, ds) => {
  if (!vm || !host1 || !host2 || !ds) return

  const migrateOptions = { host: host2, ds }
  cy.navigateMenu('instances', 'VMs')
  host1
    .waitMonitored()
    .then(() => cy.migrateVm(vm, migrateOptions))
    .then(() => cy.validateVmState('RUNNING'))
    .then(() => {
      cy.navigateTab('info').within(() => {
        cy.getBySel('hostid').should('include.text', migrateOptions.host.id)
        cy.getBySel('hostid').should('include.text', migrateOptions.host.name)
      })
    })
}

/**
 * Perform Migrate Live action.
 *
 * @param {VirtualMachine} vm - VM
 * @param {Host} host1 - HOST
 * @param {Host} host2 - HOST
 * @param {Datastore} ds - DATASTORE
 */
const performMigrateLiveActionToVM = (vm, host1, host2, ds) => {
  if (!vm || !host1 || !host2 || !ds) return

  const migrateOptions = { host: host2, ds }
  cy.navigateMenu('instances', 'VMs')
  host1
    .waitMonitored()
    .then(() => cy.migrateLiveVm(vm, migrateOptions))
    .then(() => cy.validateVmState('RUNNING'))
    .then(() => {
      cy.navigateTab('info').within(() => {
        cy.getBySel('hostid').should('include.text', migrateOptions.host.id)
        cy.getBySel('hostid').should('include.text', migrateOptions.host.name)
      })
    })
}

/**
 * Perform lock action.
 *
 * @param {VirtualMachine} vm - VM
 */
const performLockActionToVM = (vm) => {
  if (!vm) return
  const intercept = createIntercept(Intercepts.SUNSTONE.VM_LOCK)
  cy.navigateMenu('instances', 'VMs')
  cy.lockVm(vm)
    .then(() => cy.wait(intercept))
    .then(() => {
      // checks the row has lock icon 🔒
      cy.getVmRow(vm).find("svg[data-cy='lock']").should('exist')
      // checks VM is locked in the info tab
      cy.navigateTab('info').within(() => {
        cy.getBySel('locked').should('have.text', 'Use')
      })
    })
}

/**
 * Perform unlock action.
 *
 * @param {VirtualMachine} vm - VM
 */
const performUnlockActionToVM = (vm) => {
  if (!vm) return

  cy.navigateMenu('instances', 'VMs')
  cy.unlockVm(vm).then(() => {
    // checks the row has NOT lock icon 🔒
    cy.getVmRow(vm).find("svg[data-cy='lock']").should('not.exist')
    // checks VM is unlocked in the info tab
    cy.navigateTab('info').within(() => {
      cy.getBySel('locked').should('have.text', '-')
    })
  })
}

/**
 * Perform ownership action.
 *
 * @param {VirtualMachine} vm - VM
 * @param {User} user - USER
 * @param {Group} group - GROUP
 */
const performChangeOwnershipActionToVM = (vm, user, group) => {
  if (!vm || !user || !group) return

  cy.navigateMenu('instances', 'VMs')
  cy.all(
    () => user.info(),
    () => group.info()
  )
    .then(() => cy.changeVmOwner(vm, { user }))
    .then(() => cy.changeVmGroup(vm, { group }))
    .then(() => {
      cy.navigateTab('info').within(() => {
        cy.getBySel('owner').should('have.text', user.name)
        cy.getBySel('group').should('have.text', group.name)
      })
    })
}

/**
 * Perform Reschedule action.
 *
 * @param {VirtualMachine} vm - VM
 */
const performResscheduleActionToVM = (vm) => {
  if (!vm) return

  const intercept = createIntercept(Intercepts.SUNSTONE.VM_ACTION)

  cy.navigateMenu('instances', 'VMs')
  cy.reschedVm(vm)
    .then(() => cy.wait(intercept))
    .its('response.body.id')
    .should('eq', 200)
}

/**
 * Perform UN-Reschedule action.
 *
 * @param {VirtualMachine} vm - VM
 */
const performUnrescheduleActionToVM = (vm) => {
  if (!vm) return

  cy.navigateMenu('instances', 'VMs')
  cy.unreschedVm(vm).then(() => {
    cy.navigateTab('info').within(() => {
      cy.getBySel('reschedule').should('have.text', 'No')
    })
  })
}

/**
 * Perform HOLD action.
 *
 * @param {VirtualMachine} vm - VM
 * @param {Host} host1 - HOST1
 * @param {Host} host2 - HOST2
 */
const performHoldActionToVM = (vm, host1, host2) => {
  if (!vm || !host1 || !host2) return

  cy.all(
    () => host1.disable(),
    () => host2.disable()
  )
    .then(() => host1.waitDisabled())
    .then(() => host2.waitDisabled())
    .then(() => cy.navigateMenu('instances', 'VMs'))
    .then(() => cy.holdVm(vm))
    .then(() => cy.validateVmState('HOLD'))
}

/**
 * Perform RELEASE action.
 *
 * @param {VirtualMachine} vm - VM
 * @param {Host} host - HOST
 */
const performReleaseActionToVM = (vm, host) => {
  if (!vm || !host) return

  cy.navigateMenu('instances', 'VMs')
  cy.releaseVm(vm)
    .then(() => {
      cy.wait(5000) // eslint-disable-line cypress/no-unnecessary-waiting
      // refresh detail view to display the alert error
      cy.getBySel('detail-refresh').click()
      cy.navigateTab('info').within(() => {
        // forced error
        cy.get("[role='alert']").should(
          'include.text',
          'Cannot dispatch VM: No hosts enabled to run VMs',
          { timeout: 80000 }
        )
        cy.getBySel('state').should('have.text', 'PENDING')
      })
    })
    .then(() => host.enable())
    .then(() => cy.validateVmState('RUNNING'))
}

/**
 * @param {object} resources - resources
 */
const beforeInstantiateTest = (resources = {}) => {
  const {
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
  } = resources

  cy.fixture('auth')
    .then((auth) => cy.apiAuth(auth.admin))
    .then(() => cy.cleanup())
    .then(() => cy.apiSunstoneConf())
    .then(() => VNET.allocate({ template: VNET_XML }))
    .then(() => DS.info())
    .then(() => IMG.allocate({ template: IMAGE_XML, datastore: DS.id }))
    .then(() => {
      IMG.chmod({
        ownerUse: 1,
        ownerManage: 0,
        ownerAdmin: 0,
        groupUse: 1,
        groupManage: 0,
        groupAdmin: 0,
        otherUse: 1,
        otherManage: 0,
        otherAdmin: 0,
      })
    })
    .then(() => HOST.allocate(ALLOCATE_HOST_PARAMS))
    .then(() => !HOST.isMonitored && HOST.enable())
    .then((shouldWait) => shouldWait && HOST.waitMonitored())
    .then(() => TEMPLATE.allocate(TEMPLATE_XML))
    .then(() => TEMPLATE.chmod({ otherUse: '1', otherManage: '1' }))
    .then(() => TEMPLATE_INPUTS.allocate(TEMPLATE_XML_INPUTS))
    .then(() => TEMPLATE_INPUTS.chmod({ otherUse: '1', otherManage: '1' }))
}

/**
 * @param {object} resources - resources
 */
const beforeActionTest = (resources = {}) => {
  const {
    DS_SYS,
    DS_BAK,
    DS_BAK_TEMPLATE,
    HOST,
    HOST2,
    HOST_PARAMS,
    HOST2_PARAMS,
    TEMPLATE,
    TEMPLATE_XML,
    VMS,
    VNET,
    VNET_XML,
    TEMPLATE_RESTRICTED_ATTRIBUTES,
    TEMPLATE_RESTRICTED_ATTRIBUTES_XML,
  } = resources

  cy.fixture('auth')
    .then((auth) => cy.apiAuth(auth.admin))
    .then(() => cy.apiSunstoneConf())
    .then(() => DS_SYS.info())
    .then(() => cy.cleanup())
    .then(() => HOST.allocate(HOST_PARAMS))
    .then(() => !HOST.isMonitored && HOST.enable())
    .then((shouldWait) => shouldWait && HOST.waitMonitored())

    .then(() => HOST2.allocate(HOST2_PARAMS))
    .then(() => !HOST2.isMonitored && HOST2.enable())
    .then((shouldWait) => shouldWait && HOST2.waitMonitored())

    .then(() => VNET.allocate({ template: VNET_XML }))
    .then(() => DS_BAK?.allocate({ template: DS_BAK_TEMPLATE }))

    .then(() => TEMPLATE.allocate(TEMPLATE_XML))
    .then(() =>
      TEMPLATE_RESTRICTED_ATTRIBUTES.allocate(
        TEMPLATE_RESTRICTED_ATTRIBUTES_XML
      )
    )
    .then(() => {
      Object.entries(VMS).forEach(([key, { deploy, ...vmData }]) => {
        if (vmData.name.startsWith('test_vm_restricted_attributes_')) {
          TEMPLATE_RESTRICTED_ATTRIBUTES.instantiate(vmData).then((vmId) => {
            VMS[key] = new VirtualMachine(vmId)
            VMS[key]
              .waitRunning()
              .then(() => VMS[key].chmod({ otherUse: '1', otherManage: '1' }))
          })
        } else {
          TEMPLATE.instantiate(vmData).then((vmId) => {
            VMS[key] = new VirtualMachine(vmId)

            // deploy if needed
            deploy &&
              VMS[key]
                .deploy(HOST.id)
                .then(() => VMS[key].waitRunning())
                .then(() => VMS[key].chmod({ otherUse: '1', otherManage: '1' }))

            vmData.hold && VMS[key].waitHold()
          })
        }
      })
    })
}

/**
 *
 */
const beforeEachTest = () => {
  cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
    qs: { externalToken: Cypress.env('TOKEN') },
  })
}

/**
 * @param {object} vms - VMS
 */
const afterActionTest = (vms) => {
  Object.values(vms).forEach((vm) => vm?.terminate?.(true))
}

/**
 * @param {object} resources - RESOURCES
 */
const afterInstantiateTest = (resources) => {
  const { INSTANTIATE_INFO, TEMPLATE, TEMPLATE_INPUTS, VM, VM_INPUTS } =
    resources
  const persistentTemplate = new VmTemplate(INSTANTIATE_INFO.name)
  VM.terminate(true)
    .then(() => VM_INPUTS.terminate(true))
    .then(() => persistentTemplate.info())
    .then(() => persistentTemplate.delete(true))
    .then(() => TEMPLATE.delete(true))
    .then(() => TEMPLATE_INPUTS.delete(true))
}

/**
 * @param {object} resources - RESOURCES
 */
const instantiateVMbyGUI = (resources) => {
  const { TEMPLATE, INSTANTIATE_INFO, VNET, IMG, VM } = resources

  cy.navigateMenu('instances', 'VMs')

  cy.instantiateVM({
    templateId: TEMPLATE.id,
    vmTemplate: {
      ...INSTANTIATE_INFO,
      networks: [{ id: VNET.id, name: VNET.name }],
      storage: [
        {
          image: IMG.id,
          size: 100,
          type: 'fs',
          format: 'raw',
          target: 'ds',
          readOnly: 'YES',
          bus: 'vd',
          cache: 'default',
          io: 'native',
          discard: 'unmap',
        },
      ],
    },
  })
    .then(() =>
      INSTANTIATE_INFO.hold ? VM.waitState('HOLD') : VM.waitRunning()
    )
    .then(() => VM.info()) // to set the VM id
}

/**
 * @param {object} resource - Configuration
 * @param {VirtualMachine} resource.vm - VM
 * @param {boolean} resource.validatePermissions - validate permissions
 */
const validateInfoTabOnVMInstantiated = (resource) => {
  const { vm, validatePermissions, validateCost } = resource
  cy.navigateMenu('instances', 'VMs')
  cy.validateVmInfo(vm, validatePermissions, validateCost)
}

/**
 * @param {VirtualMachine} vm - VM
 */
const validateStorageTabOnVMInstantiated = (vm) => {
  cy.navigateMenu('instances', 'VMs')
  cy.validateVmStorage(vm)
}

/**
 * @param {VirtualMachine} vm - VM
 */
const validateNetworkTabOnVMInstantiated = (vm) => {
  cy.navigateMenu('instances', 'VMs')
  cy.validateVmNetworks(vm)
}

/**
 * @param {VirtualMachine} vm - VM
 */
const validateConfigurationBeforeUpdate = (vm) => {
  cy.navigateMenu('instances', 'VMs')
  cy.validateVmConfiguration(vm)
}

/**
 * @param {object} resource - OpenNebula resource to be updated
 */
const updateVMConfiguration = (resource) => {
  const { VM, NEW_CONF, INSTANTIATE_INFO } = resource

  cy.navigateMenu('instances', 'VMs')
  cy.updateVmConfiguration(VM, NEW_CONF).then(() =>
    INSTANTIATE_INFO.hold ? VM.waitState('HOLD') : VM.waitRunning()
  )
}

/**
 * @param {VirtualMachine} vm - VM
 */
const validateConfigurationAfterUpdate = (vm) => {
  cy.navigateMenu('instances', 'VMs')
  cy.validateVmConfiguration(vm)
}

/**
 * @param {object} resource - OpenNebula resource to be updated
 */
const changePermissionsVM = (resource) => {
  const { VM, NEW_PERMISSIONS } = resource

  cy.navigateMenu('instances', 'VMs')
  cy.clickVmRow(VM)
    .then(() =>
      cy.changePermissions(NEW_PERMISSIONS, Intercepts.SUNSTONE.VM_CHANGE_MOD)
    )
    .then(() => VM.info()) // update VM object with new permissions
    .then(() => cy.validatePermissions(NEW_PERMISSIONS))
}

/**
 * @param {VirtualMachine} vm - VM
 * @param {string} name - new name
 */
const renameVM = (vm, name) => {
  cy.navigateMenu('instances', 'VMs')
  cy.clickVmRow(vm)
    .then(() => cy.renameResource(name))
    .then(() => (vm.name = name))
    .then(() => cy.getVmRow(vm).contains(name))
}

/**
 * @param {object} resources - OpenNebula resource to be updated
 */
const addNicToVM = (resources) => {
  const { VNET, VM } = resources
  if (!VM || !VNET) return

  cy.navigateMenu('instances', 'VMs')
  cy.addNicToVM(VM, VNET)
    // eslint-disable-next-line cypress/no-unnecessary-waiting
    .then(() => cy.wait(2000)) // Waiting for the backend to catch up
    .then(() => VM.info())
    .then(() => {
      if (VNET?.pci?.name) {
        const { DEVICE, VENDOR, CLASS } = VNET?.pci
        expect(VM.json.TEMPLATE.PCI).to.have.property('VENDOR', VENDOR)
        expect(VM.json.TEMPLATE.PCI).to.have.property('CLASS', CLASS)
        expect(VM.json.TEMPLATE.PCI).to.have.property('DEVICE', DEVICE)
      }

      VNET?.pci?.shortAddress &&
        expect(VM.json.TEMPLATE.PCI).to.have.property(
          'SHORT_ADDRESS',
          VNET?.pci?.shortAddress
        )
    })
}

/**
 * @param {object} resources - OpenNebula resource to be updated
 */
const attachDetachPciToVM = (resources) => {
  const { PCI, VM } = resources
  if (!VM || !PCI) return

  VM.poweroff()
    .then(() => VM.waitStop())
    .then(() => {
      cy.navigateMenu('instances', 'VMs')
      cy.attachPciToVm(VM, PCI)
        .then(() => VM.info())
        .then(() => {
          const { DEVICE, VENDOR, CLASS, shortAddress } = PCI
          if (shortAddress) {
            expect(VM.json.TEMPLATE.PCI).to.have.property(
              'SHORT_ADDRESS',
              shortAddress
            )
          } else {
            expect(VM.json.TEMPLATE.PCI).to.have.property('VENDOR', VENDOR)
            expect(VM.json.TEMPLATE.PCI).to.have.property('CLASS', CLASS)
            expect(VM.json.TEMPLATE.PCI).to.have.property('DEVICE', DEVICE)
          }
        })
    })
    .then(() => {
      cy.navigateMenu('instances', 'VMs')
      cy.detachPciToVm(VM, 0)
        .then(() => VM.info())
        .then(() => {
          expect(VM.json.TEMPLATE).to.not.have.property('PCI')
        })
    })
}

/**
 *
 * @param {VirtualMachine} vm - VM
 */
const validateVmActionButtons = (vm) => {
  cy.navigateMenu('instances', 'VMs')
  cy.validateVmActionButtons(vm)
}

/**
 * @param {object} resources - OpenNebula resource to be updated
 */
const addDiskToVM = (resources) => {
  const { VM, DISK } = resources

  const intercept = createIntercept(Intercepts.SUNSTONE.VM_ATTACH_DISK)

  cy.navigateMenu('instances', 'VMs')
  cy.addDiskToVM(VM, DISK)
    .then(() => cy.wait(intercept))
    .its('response.body.id')
    .should('eq', 200)
}

/**
 * @param {object} resources - OpenNebula resource to be updated
 * @param {object} qos - nic data to add
 * @param {boolean} poweroff - Vm poweroff
 */
const updateNic = (resources, qos, poweroff = false) => {
  const { VM } = resources
  const update = () => {
    cy.navigateMenu('instances', 'VMs')
    cy.updateNicVM(VM, qos)
      .its('response.body.id')
      .should('eq', 200)
      .then(() => VM.info())
      .then(() => {
        const {
          INBOUND_AVG_BW,
          INBOUND_PEAK_BW,
          INBOUND_PEAK_KB,
          OUTBOUND_AVG_BW,
          OUTBOUND_PEAK_BW,
          OUTBOUND_PEAK_KB,
        } = VM.json?.TEMPLATE?.NIC || {}
        const {
          INBOUND_AVG_BW: INBOUND_AVG_BW_QOS,
          INBOUND_PEAK_BW: INBOUND_PEAK_BW_QOS,
          INBOUND_PEAK_KB: INBOUND_PEAK_KB_QOS,
          OUTBOUND_AVG_BW: OUTBOUND_AVG_BW_QOS,
          OUTBOUND_PEAK_BW: OUTBOUND_PEAK_BW_QOS,
          OUTBOUND_PEAK_KB: OUTBOUND_PEAK_KB_QOS,
        } = qos

        expect(INBOUND_AVG_BW).to.equal(INBOUND_AVG_BW_QOS)
        expect(INBOUND_PEAK_BW).to.equal(INBOUND_PEAK_BW_QOS)
        expect(INBOUND_PEAK_KB).to.equal(INBOUND_PEAK_KB_QOS)
        expect(OUTBOUND_AVG_BW).to.equal(OUTBOUND_AVG_BW_QOS)
        expect(OUTBOUND_PEAK_BW).to.equal(OUTBOUND_PEAK_BW_QOS)
        expect(OUTBOUND_PEAK_KB).to.equal(OUTBOUND_PEAK_KB_QOS)
      })
  }

  poweroff
    ? cy
        .powerOffHardVm(VM)
        .then(() => VM.waitStop())
        .then(update)
    : update()
}

/**
 * @param {object} resources - OpenNebula resource to be updated
 */
const resizeVM = (resources) => {
  const { INSTANTIATE_INFO, VM, newCapacity } = resources

  cy.navigateMenu('instances', 'VMs')
  cy.resizeVm(VM, newCapacity)
    .then(() =>
      INSTANTIATE_INFO.hold ? VM.waitState('HOLD') : VM.waitRunning()
    )
    .then(() => {
      // validate VM capacity
      expect(VM.json.TEMPLATE).to.have.property('MEMORY', newCapacity.memory)
      expect(VM.json.TEMPLATE).to.have.property('CPU', newCapacity.cpu)
      expect(VM.json.TEMPLATE).to.have.property('VCPU', newCapacity.vcpu)
      // validate on the interface
      cy.validateVmCapacity(VM)
    })
}

/**
 * Perform BACKUP action.
 *
 * @param {VirtualMachine} vm - VM
 * @param {object} options - Options for the backup action
 * @param {Datastore} [options.ds] - DATASTORE (optional)
 * @param {boolean} [options.reset] - Reset switch (optional)
 * @returns {Cypress.Chainable} Chainable command
 */
const performBackupActionToVM = (vm, options = {}) => {
  if (!vm) return

  const { ds, reset, forceNext } = options

  cy.navigateMenu('instances', 'VMs')

  return cy.backupVm(vm, { ds, reset, forceNext }).then(() => {
    vm.waitRunning({ timeout: 500000 })
      .then(() => {
        // Create interceptor for images request
        const interceptName = createIntercept(Intercepts.SUNSTONE.IMAGES)

        // Define condition to wait at backup table
        const condition = (interceptorResponse) => {
          // Check that exists an image for the vm id
          const imagePool =
            interceptorResponse?.response?.body?.data?.IMAGE_POOL

          // If no results, return false
          if (!imagePool) return false

          // If there is data, create array result
          const images = Array.isArray(imagePool.IMAGE)
            ? imagePool.IMAGE
            : [imagePool.IMAGE]

          // Check that id of the vm is equal to the image vm id
          return images.some((image) => image.VMS.ID === vm.id)
        }

        // Navigate to backup tab of the VM
        cy.navigateTab('backup').within(() => {
          cy.getBySel('refresh').click({ force: true })
          // Wait for images request
          cy.wait(interceptName).then((data) => {
            // Check images request response with condition function
            if (condition(data)) {
              // If condition is true, return table and click row
              cy.getBackupsTable({
                search: vm.id,
              }).within(() => {
                cy.get(`[role='row']`).eq(0).click({ force: true })
              })
            } else {
              // If condition is false, wait until condition is true and then return table and click row
              cy.getBackupsTableWaiting({
                search: vm.id,
                condition: condition,
                configWait: {
                  errorMsg: 'Timeout when waiting to search for backups',
                  timeout: 100000,
                },
              }).within(() => {
                cy.get(`[role='row']`).eq(0).click({ force: true })
              })
            }
          })
        })
      })
      .then(() => vm.info())
      .then(() => vm?.json?.BACKUPS.BACKUP_IDS.ID)
  })
}

/**
 * Perform BACKUP action but not checks that an image is created.
 *
 * @param {VirtualMachine} vm - VM
 * @param {object} options - Options for the backup action
 * @param {Datastore} [options.ds] - DATASTORE (optional)
 * @param {boolean} [options.reset] - Reset switch (optional)
 * @returns {Cypress.Chainable} Chainable command
 */
const performBackupActionToVMWithoutCheckImage = (vm, options = {}) => {
  if (!vm) return

  const { ds, reset, forceNext } = options

  cy.navigateMenu('instances', 'VMs')

  return cy.backupVm(vm, { ds, reset, forceNext }).then(() => {
    vm.waitRunning({ timeout: 500000 })
      .then(() => cy.getBySel('detail-refresh').click({ force: true }))
      .then(() => vm.info())
      .then(() => vm?.json?.BACKUPS.BACKUP_IDS.ID)
  })
}

/**
 * Perform INCREMENTAL BACKUP action.
 *
 * @param {VirtualMachine} vm - VM
 * @param {Datastore} ds - DATASTORE
 */
const performIncrementalBackupActionToVM = (vm, ds) => {
  cy.wrap(null)
    .then(() => {
      updateVMConfiguration({
        VM: vm,
        NEW_CONF: {
          osCpu: {
            arch: 'x86_64',
          },
          inputOutput: {
            graphics: true,
            keymap: 'en-us',
          },
          context: {},
          backupConfig: {
            backupVolatile: true,
            fsFreeze: 'None',
            keepLast: '4',
            mode: 'INCREMENT',
          },
        },
        INSTANTIATE_INFO: vm.name,
      })
    })
    .then(() =>
      performBackupActionToVM(vm, { ds, reset: false, forceNext: true })
    )
    .then(() =>
      performBackupActionToVMWithoutCheckImage(vm, { forceNext: true })
    )
    .then(() =>
      performBackupActionToVMWithoutCheckImage(vm, {
        ds,
        reset: true,
        forceNext: true,
      })
    )
}

/**
 * Perform individual disk restore action.
 *
 * @param {VirtualMachine} vm - VM
 * @param {Datastore} ds - DATASTORE
 */
const performIndividualDiskRestore = (vm, ds) => {
  cy.wrap(null)
    .then(() => {
      updateVMConfiguration({
        VM: vm,
        NEW_CONF: {
          context: {},
          backupConfig: {
            backupVolatile: true,
            fsFreeze: 'None',
            keepLast: '4',
            mode: 'INCREMENT',
          },
        },
        INSTANTIATE_INFO: vm.name,
      })
    })
    .then(() =>
      addDiskToVM({
        VM: vm,
        DISK: {
          size: 1024,
          format: 'qcow2',
          fs: 'ext4',
          type: 'fs',
        },
      })
    )
    .then(() => {
      performBackupActionToVMWithoutCheckImage(vm, {
        ds,
        reset: false,
        forceNext: true,
      }).then(() => {
        performPoweroffHardActionToVM(vm)
      })
    })
    .then(() => {
      cy.restoreVm(vm, {
        image: vm.backupIds?.[0],
        restoreIndividual: true,
        incrementId: vm.backupConfig?.LAST_INCREMENT_ID,
      }).then(() =>
        vm
          .waitState('POWEROFF', { timeout: 500000 })
          .then(() => cy.getBySel('detail-refresh').click({ force: true }))
          .then(() => vm.info())
          .then(() => vm?.json?.BACKUPS.BACKUP_IDS.ID)
      )
    })
}

/**
 * Check VM restricted attributes.
 *
 * @param {object} template - VM template
 * @param {boolean} admin - If the user belongs to oneadmin group.
 * @param {Array} restrictedAttributesException - List of attributes that won't be checked
 */
const checkVMRestrictedAttributes = (
  template,
  admin,
  restrictedAttributesException
) => {
  // Navigate to vms menu
  cy.navigateMenu('instances', 'VMs')

  // Get restricted attributes from OpenNebula config
  cy.getOneConf().then((config) => {
    // Virtual Machine restricted attributes
    const vmRestricteAttributes = transformAttributes(
      config.VM_RESTRICTED_ATTR,
      restrictedAttributesException
    )

    // Check VM restricted attributes
    cy.checkVMRestricteAttributes(vmRestricteAttributes, template, admin)
  })
}

export {
  beforeInstantiateTest,
  beforeActionTest,
  beforeEachTest,
  afterInstantiateTest,
  afterActionTest,
  instantiateVMbyGUI,
  validateInfoTabOnVMInstantiated,
  validateStorageTabOnVMInstantiated,
  validateNetworkTabOnVMInstantiated,
  validateConfigurationBeforeUpdate,
  validateConfigurationAfterUpdate,
  changePermissionsVM,
  renameVM,
  addNicToVM,
  updateNic,
  resizeVM,
  updateVMConfiguration,
  takeVMSnapshot,
  validateTheVMSnapshots,
  revertTheVMSnapshot,
  deleteTheVMSnapshot,
  validateTheVMHistory,
  performSuspendActionToVM,
  performStopActionToVM,
  performPoweroffActionToVM,
  performPoweroffHardActionToVM,
  performResumeActionToVM,
  performRebootActionToVM,
  performRebootHardActionToVM,
  performUndeployActionToVM,
  performUndeployHardActionToVM,
  performDeployActionToVM,
  performMigrateActionToVM,
  performMigrateLiveActionToVM,
  performLockActionToVM,
  performUnlockActionToVM,
  performChangeOwnershipActionToVM,
  performResscheduleActionToVM,
  performUnrescheduleActionToVM,
  performHoldActionToVM,
  performReleaseActionToVM,
  performBackupActionToVM,
  performIndividualDiskRestore,
  performIncrementalBackupActionToVM,
  addDiskToVM,
  validateVmActionButtons,
  attachDetachPciToVM,
  checkVMRestrictedAttributes,
}
