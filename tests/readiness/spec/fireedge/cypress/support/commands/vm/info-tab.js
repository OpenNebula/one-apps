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
  booleanToString,
  formatNumberByCurrency,
  timeToString,
} from '@commands/helpers'
import { VirtualMachine } from '@models'
import { createIntercept, Intercepts, checkForm } from '@support/utils'

const FORCE = { force: true }

/**
 * Check IPs on VM.
 *
 * @param {VirtualMachine} vm - VM
 */
const validateVmIps = (vm) => {
  cy.clickVmRow(vm)

  cy.navigateTab('info').within(() => {
    for (const ip of vm.ips) {
      cy.getBySel('ips').contains(ip)
    }
  })
}

/**
 * Resizes a VM.
 *
 * @param {VirtualMachine} vm - VM
 * @param {object} newCapacity - New VM capacity
 * @param {string} newCapacity.memory - Memory
 * @param {string} newCapacity.cpu - CPU
 * @param {string} newCapacity.vcpu - VCPU
 */
const resizeVm = (vm, { memory = '', cpu = '', vcpu = '' } = {}) => {
  const getVmResize = createIntercept(Intercepts.SUNSTONE.VM_RESIZE)

  cy.clickVmRow(vm)

  cy.navigateTab('info').within(() => {
    cy.getBySel('resize-capacity').click(FORCE)
  })

  cy.getBySel('modal-resize-capacity').within(() => {
    cy.getBySel('form-dg-MEMORY').clear(FORCE)

    cy.get('[data-cy="form-dg-MEMORY-unit"] select').select('MB')
    cy.getBySel('form-dg-MEMORY').clear(FORCE).type(memory)
    cy.getBySel('form-dg-CPU').clear(FORCE).type(cpu)
    cy.getBySel('form-dg-VCPU').clear(FORCE).type(vcpu)

    cy.getBySel('dg-accept-button').click(FORCE)

    cy.wait(getVmResize)
  })
}

/**
 * Validate capacity.
 *
 * @param {VirtualMachine} vm - VM
 * @param {boolean} cost - Validate cost
 */
const validateVmCapacity = (vm = {}, cost) => {
  const {
    CPU,
    VCPU,
    MEMORY,
    CPU_COST = 0,
    MEMORY_COST = 0,
  } = vm.json.TEMPLATE || {}

  cy.navigateTab('info').within(() => {
    CPU && cy.getBySel('cpu').should('have.text', CPU)
    VCPU && cy.getBySel('vcpu').should('have.text', VCPU)
    MEMORY && cy.getBySel('memory').contains(MEMORY)

    if (cost) {
      const cpuMonthCost = formatNumberByCurrency(MEMORY * CPU_COST * 24 * 30)
      const memMonthCost = formatNumberByCurrency(CPU * MEMORY_COST * 24 * 30)

      cy.getBySel('cpucost').contains(cpuMonthCost)
      cy.getBySel('memorycost').contains(memMonthCost)
    }
  })
}

/**
 * Validate VM state.
 *
 * @param {string|RegExp} state - VM state in readable format
 */
const validateVmState = (state) => {
  cy.navigateTab('info').within(() => {
    state instanceof RegExp
      ? cy.getBySel('state').invoke('text').should('match', state)
      : cy.getBySel('state').should('have.text', state)
  })
}

/**
 * Validate Info.
 *
 * @param {VirtualMachine} vm - VM
 * @param {boolean} permission - validate permissions
 * @param {boolean} cost - validate cost
 */
const validateVmInfo = (vm, permission, cost) => {
  const { ID, NAME, RESCHED, STIME, ETIME } = vm.json

  cy.clickVmRow(vm)

  cy.navigateTab('info').within(() => {
    cy.getBySel('id').should('have.text', ID)
    cy.getBySel('name').should('have.text', NAME)
    cy.getBySel('reschedule').should('have.text', booleanToString(RESCHED))
    cy.getBySel('starttime').should('have.text', timeToString(STIME))
    cy.getBySel('endtime').should('have.text', timeToString(ETIME))

    cy.validateOwnership(vm)
    permission && cy.validatePermissions(vm)
  })

  cy.validateVmState(vm.state)
  cy.validateVmCapacity(vm, cost)
}

/**
 * Validate restricted attributes in VM info tab.
 *
 * @param {object} restrictedAttributes - Map of restricted attributes
 * @param {object} vm - VM to check
 * @param {string} check - Condition to check
 * @param {string} checkHidden - Condition to checkHidden
 */
const validateRestrictedAttributesVmInfo = (
  restrictedAttributes,
  vm,
  check,
  checkHidden
) => {
  cy.navigateTab('info')

  // Check name
  if (restrictedAttributes.PARENT.NAME)
    cy.getBySelLike(`edit-name`).should(checkHidden)

  // Click on resize capacity button
  cy.getBySel(`resize-capacity`).click()

  // Check capacity form
  cy.get('[role="presentation"]').then(() =>
    checkForm(restrictedAttributes.PARENT, check)
  )

  cy.getBySel('dg-cancel-button').click()
}

Cypress.Commands.add('validateVmState', validateVmState)
Cypress.Commands.add('validateVmInfo', validateVmInfo)
Cypress.Commands.add('validateVmCapacity', validateVmCapacity)
Cypress.Commands.add('resizeVm', resizeVm)
Cypress.Commands.add('validateVmIps', validateVmIps)
Cypress.Commands.add(
  'validateRestrictedAttributesVmInfo',
  validateRestrictedAttributesVmInfo
)
