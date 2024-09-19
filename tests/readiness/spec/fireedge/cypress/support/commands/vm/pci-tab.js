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
import { fillPciDevicesSection } from '@commands/template/create'
import { Intercepts, createIntercept } from '@support/utils'

/*
 * Add PCI to a virtual machine.
 *
 * @param {VirtualMachine} vm - VM info object
 * @param {object} pci - PCI device
 */
const attachPciToVm = (vm, pci) => {
  // Create interceptors for addPci
  const interceptAddPci = createIntercept(Intercepts.SUNSTONE.VM_ATTACH_PCI)

  cy.clickVmRow(vm)
  fillPciDevicesSection({ pcis: pci })

  cy.wait(interceptAddPci).its('response.statusCode').should('eq', 200)
}

/*
 * Detach PCI to a virtual machine.
 *
 * @param {VirtualMachine} vm - VM info object
 * @param {number} index - Index of the PCI device
 */
const detachPciToVm = (vm, index) => {
  // Create interceptors for addPci
  const interceptAddPci = createIntercept(Intercepts.SUNSTONE.VM_DETACH_PCI)

  cy.clickVmRow(vm)
  cy.navigateTab('pci')
  cy.getBySel(`detach-pci-${index}`).click()
  cy.getBySel(`dg-accept-button`).click()

  cy.wait(interceptAddPci).its('response.statusCode').should('eq', 200)
}

Cypress.Commands.add('attachPciToVm', attachPciToVm)
Cypress.Commands.add('detachPciToVm', detachPciToVm)
