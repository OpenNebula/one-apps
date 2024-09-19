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

import { Datastore, Group, Host, User, VirtualMachine } from '@models'

const FORCE = { force: true }

/**
 * Performs an action on a VM.
 *
 * @param {string} action - Action name to perform
 * @returns {function(VirtualMachine):Cypress.Chainable}
 * Chainable command to perform an action on a VM
 */
const performSimpleAction = (action) => (vm) => {
  cy.clickVmRow(vm)

  return cy.getBySel(`action-${action}`).click(FORCE)
}

/**
 * Performs an action on a VM.
 *
 * @param {'manage'|'host'|'ownership'|'lock'} group - Group action name
 * @param {string} action - Action name to perform
 * @param {Function} form - Function to fill the form. By default is a confirmation dialog.
 * @returns {function(VirtualMachine, any):Cypress.Chainable}
 * Chainable command to perform an action on a VM
 */
const groupAction = (group, action, form) => (vm, options) => {
  cy.clickVmRow(vm)

  cy.getBySel(`action-vm-${group}`).click(FORCE)
  cy.getBySel(`action-${action}`).click(FORCE)

  if (form) return form(vm, options)

  return cy.getBySel(`modal-${action}`).within(() => {
    cy.getBySel('dg-accept-button').click(FORCE)
  })
}

/**
 * Deploys a VM.
 *
 * @param {VirtualMachine} vm - VM to deploy
 * @param {object} options - Options to fill the form
 * @param {Host} options.host - Host to deploy the VM
 * @param {Datastore} [options.ds] - Datastore to deploy the VM
 * @param {boolean} [options.enforceCheck] - Host capacity will be checked
 * @param {boolean} [options.reset] - Reset switch (optional)
 * @returns {Cypress.Chainable} Chainable command to deploy a VM
 */
const deployVm = (vm, { host, ds, enforceCheck, reset = false } = {}) =>
  cy.getBySelLike('modal-').within(() => {
    host && cy.getHostRow(host).click(FORCE)
    reset && cy.getBySel('restore-configuration-reset').check(FORCE)
    cy.getBySel('stepper-next-button').click()

    ds && cy.getDatastoreRow(ds).click(FORCE)
    enforceCheck && cy.getBySelEndsWith('-advanced-enforce').click()
    cy.getBySel('stepper-next-button').click(FORCE)
  })

const backupVm = (
  vm,
  { host, ds, enforceCheck, reset = false, forceNext = false } = {}
) =>
  cy.getBySelLike('modal-').within(() => {
    host && cy.getHostRow(host).click(FORCE)
    reset && cy.getBySel('restore-configuration-reset').check(FORCE)
    cy.getBySel('stepper-next-button').click()

    ds && cy.getDatastoreRow(ds).click(FORCE)
    enforceCheck && cy.getBySelEndsWith('-advanced-enforce').click()

    cy.getBySel('stepper-next-button').click(forceNext && FORCE)
  })

const restoreVm = (
  vm,
  { image, restoreIndividual = false, name, incrementId, disk } = {}
) =>
  cy.getBySelLike('modal-').within(() => {
    image && cy.getBySel(`image-${image}`).click(FORCE)
    cy.getBySel('stepper-next-button').click()
    name && cy.getBySel('restore-configuration-name').clear().type(name)
    incrementId &&
      cy.getBySel('restore-configuration-increment_id').then(({ selector }) => {
        cy.get(selector)
          .click()
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    incrementId?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    incrementId === $el?.text()
                  ) {
                    cy.wrap($el).click()

                    return false // Break
                  }
                })
            })
          })
      })
    restoreIndividual &&
      cy.getBySel('restore-configuration-restoreIndividualDisk').check()
    cy.getBySel('stepper-next-button').click()
    disk && cy.getBySel(`disk-${disk}`).click(FORCE)
    !disk &&
      cy.getBySelLike('disk-').then((disks) => {
        if (disks?.length > 0) {
          const randomIndex = Math.floor(Math.random() * disks?.length)

          cy.wrap(disks[randomIndex]).click()
        }
      })
    cy.getBySel('stepper-next-button').click()
  })

/**
 * Changes VM ownership: user or group.
 *
 * @param {VirtualMachine} vm - VM to change owner
 * @param {object} options - Options to fill the form
 * @param {User} [options.user] - The new owner
 * @param {Group} [options.group] - The new group
 * @returns {Cypress.Chainable} Chainable command to change VM owner
 */
const changeVmOwnership = (vm, { user, group } = {}) =>
  cy.getBySelLike('modal-').within(() => {
    user && cy.getUserRow(user).click(FORCE)
    group && cy.getGroupRow(group).click(FORCE)
    cy.getBySel('dg-accept-button').click(FORCE)
  })

/**
 * Check the vm restricted attributes on a template.
 *
 * @param {object} restrictedAttributes - Map of restricted attributes
 * @param {object} vm - VM to check
 * @param {boolean} admin - If the user belongs to oneadmin group.
 */
const checkVMRestricteAttributes = (restrictedAttributes, vm, admin) => {
  // Check disabled or not depending if the user is an admin
  const check = admin ? 'not.be.disabled' : 'be.disabled'
  const checkHidden = admin ? 'exist' : 'not.exist'

  // Get info template
  vm.info().then(() => {
    // Click on the template
    cy.clickVmRow(vm)

    // Checki info tab
    cy.validateRestrictedAttributesVmInfo(
      restrictedAttributes,
      vm,
      check,
      checkHidden
    )

    // Check storage tab
    cy.validateRestrictedAttributesVmStorage(restrictedAttributes, vm, check)

    // Check nic tab
    cy.validateRestrictedAttributesVmNetwork(restrictedAttributes, vm, check)

    // Check sched actions tab
    cy.validateRestrictedAttributesVmScheduleActions(
      restrictedAttributes,
      vm,
      check
    )

    // Chech configuration tab
    cy.validateRestrictedAttributesVmConfiguration(
      restrictedAttributes,
      vm,
      check
    )
  })
}

Cypress.Commands.add('resumeVm', performSimpleAction('vm_resume'))

Cypress.Commands.add('suspendVm', groupAction('manage', 'suspend'))
Cypress.Commands.add('stopVm', groupAction('manage', 'stop'))
Cypress.Commands.add('powerOffVm', groupAction('manage', 'poweroff'))
Cypress.Commands.add('powerOffHardVm', groupAction('manage', 'poweroff-hard'))
Cypress.Commands.add('rebootVm', groupAction('manage', 'reboot'))
Cypress.Commands.add('rebootHardVm', groupAction('manage', 'reboot-hard'))
Cypress.Commands.add('undeployVm', groupAction('manage', 'undeploy'))
Cypress.Commands.add('undeployHardVm', groupAction('manage', 'undeploy-hard'))

Cypress.Commands.add('holdVm', groupAction('host', 'hold'))
Cypress.Commands.add('releaseVm', groupAction('host', 'release'))
Cypress.Commands.add('reschedVm', groupAction('host', 'resched'))
Cypress.Commands.add('unreschedVm', groupAction('host', 'unresched'))
Cypress.Commands.add('deployVm', groupAction('host', 'deploy', deployVm))
Cypress.Commands.add('migrateVm', groupAction('host', 'migrate', deployVm))
Cypress.Commands.add('backupVm', groupAction('host', 'backup', backupVm))
Cypress.Commands.add('restoreVm', groupAction('host', 'restore', restoreVm))
Cypress.Commands.add(
  'migrateLiveVm',
  groupAction('host', 'live-migrate', deployVm)
)

Cypress.Commands.add('lockVm', groupAction('lock', 'lock'))
Cypress.Commands.add('unlockVm', groupAction('lock', 'unlock'))

Cypress.Commands.add(
  'changeVmOwner',
  groupAction('ownership', 'chown', changeVmOwnership)
)
Cypress.Commands.add(
  'changeVmGroup',
  groupAction('ownership', 'chgrp', changeVmOwnership)
)

Cypress.Commands.add('checkVMRestricteAttributes', checkVMRestricteAttributes)
