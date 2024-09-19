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

import { VirtualMachine } from '@models'
import { stringToBoolean } from '@commands/helpers'
import { fillStorageSection } from '@commands/template/create'
import { hasRestrictedAttributes } from '@support/utils'

/**
 * Validate VM storage tab.
 *
 * @param {VirtualMachine} vm - VM
 */
const validateVmStorage = (vm) => {
  const { DISK = [] } = vm.json
  const ensuredDisks = Array.isArray(DISK) ? DISK : [DISK]

  if (ensuredDisks.length === 0) return

  cy.clickVmRow(vm)

  cy.navigateTab('storage').within(() => {
    ensuredDisks.forEach(
      ({ TYPE, CLONE, TARGET, DATASTORE, SIZE, DISK_ID }) => {
        cy.getBySel(`disk-${DISK_ID}`).within(() => {
          const noMatchCase = { matchCase: false }

          TYPE && cy.getBySel('type').contains(TYPE, noMatchCase)
          TARGET && cy.getBySel('target').contains(TARGET, noMatchCase)
          DATASTORE && cy.getBySel('datastore').contains(DATASTORE, noMatchCase)
          SIZE && cy.getBySel('disksize').contains(SIZE, noMatchCase)

          stringToBoolean(CLONE) && cy.getBySel('clone').should('exist')
        })
      }
    )
  })
}

/*
 * Add disk to a vm.
 *
 * @param {VirtualMachine} vm - VM info object
 * @param {object} disk - the data of the disk
 */
const addDiskToVM = (vm, disk) => {
  cy.clickVmRow(vm)
  fillStorageSection({ storage: disk })
}

/**
 * Validate restricted attributes in VM storage tab.
 *
 * @param {object} restrictedAttributes - Map of restricted attributes
 * @param {object} vm - VM to check
 * @param {string} check - Condition to check
 */
const validateRestrictedAttributesVmStorage = (
  restrictedAttributes,
  vm,
  check
) => {
  const { DISK = [] } = vm.json.TEMPLATE
  const ensuredDisks = Array.isArray(DISK) ? DISK : [DISK]

  if (ensuredDisks.length === 0) return

  cy.navigateTab('storage')

  ensuredDisks.forEach(({ DISK_ID, ...disk }) => {
    cy.getBySel(`disk-${DISK_ID}`).within(() => {
      // If exists a DISK restricted attribute in the disk and it's not admin, delete button has to be disabled
      hasRestrictedAttributes(disk, 'DISK', restrictedAttributes) &&
        cy.getBySelLike(`disk-detach-${DISK_ID}`).should(check)

      // If exists a DISK/SIZE restricted attribute in the disk and it's not admin, resize button has to be disabled
      restrictedAttributes.DISK.SIZE &&
        cy.getBySelLike(`disk-resize-${DISK_ID}`).should(check)
    })
  })
}

Cypress.Commands.add('validateVmStorage', validateVmStorage)
Cypress.Commands.add('addDiskToVM', addDiskToVM)
Cypress.Commands.add(
  'validateRestrictedAttributesVmStorage',
  validateRestrictedAttributesVmStorage
)
