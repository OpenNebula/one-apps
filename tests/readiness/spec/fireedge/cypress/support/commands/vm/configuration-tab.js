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

import { Intercepts, checkForm } from '@support/utils'
import { VmTemplate } from '@support/commands/template/jsdocs'
import {
  fillOsAndCpuSection,
  fillIOSection,
  fillContextSection,
  fillBackupSection,
} from '@support/commands/template/create'
import { VirtualMachine } from '@support/models'
import { isObject } from '@support/commands/helpers'

const ATTR_CONF_CAN_BE_UPDATED = {
  OS: [
    'ARCH',
    'MACHINE',
    'KERNEL',
    'INITRD',
    'BOOTLOADER',
    'BOOT',
    'SD_DISK_BUS',
    'UUID',
  ],
  FEATURES: ['ACPI', 'PAE', 'APIC', 'LOCALTIME', 'HYPERV', 'GUEST_AGENT'],
  INPUT: ['TYPE', 'BUS'],
  GRAPHICS: ['TYPE', 'LISTEN', 'PASSWD', 'KEYMAP'],
  RAW: ['DATA', 'DATA_VMX', 'TYPE'],
  CONTEXT: '*',
  BACKUP_CONFIG: '*',
}

/**
 * Updates VM configuration via GUI.
 *
 * @param {VirtualMachine} vm - VM
 * @param {VmTemplate} newConfiguration - New configuration
 */
const updateVmConfiguration = (vm, newConfiguration) => {
  cy.clickVmRow(vm)

  cy.navigateTab('configuration').within(() => {
    cy.getBySel('update-conf').click()
  })

  cy.getBySel('modal-update-conf').within(() => {
    fillOsAndCpuSection(newConfiguration)
    fillIOSection(newConfiguration)
    fillContextSection(newConfiguration)
    fillBackupSection(newConfiguration)

    // SUBMIT
    cy.clickWithInterceptor({
      button: 'dg-accept-button',
      intercept: Intercepts.SUNSTONE.VM_UPDATE_CONF,
    })
      .its('response.body.id')
      .should('eq', 200)
  })
}

/**
 * Validate VM configuration in info-tab.
 *
 * @param {VirtualMachine} vm - VM
 */
const validateVmConfiguration = (vm) => {
  const checkAttribute = (name, value) => {
    // check only if value is not undefined or empty
    if (!value || value === '') return
    if (Array.isArray(value)) return

    cy.getBySel(name).should('have.text', value)
  }

  const checkAttributes = (section, attributes) => {
    const sectionToCheck = vm.json.TEMPLATE?.[section]

    if (attributes === '*' && isObject(sectionToCheck)) {
      return Object.entries(sectionToCheck).forEach(([attr, value]) =>
        checkAttribute(attr, value)
      )
    }

    if (Array.isArray(attributes)) {
      attributes.forEach((attr) => {
        checkAttribute(attr, sectionToCheck?.[attr])
      })
    }
  }

  cy.clickVmRow(vm)
  cy.navigateTab('configuration').within(() => {
    const entries = Object.entries(ATTR_CONF_CAN_BE_UPDATED)

    for (const [section, attributes] of entries) {
      checkAttributes(section, attributes)
    }
  })
}

/**
 * Validate restricted attributes in VM storage tab.
 *
 * @param {object} restrictedAttributes - Map of restricted attributes
 * @param {object} vm - VM to check
 * @param {string} check - Condition to check
 */
const validateRestrictedAttributesVmConfiguration = (
  restrictedAttributes,
  vm,
  check
) => {
  cy.navigateTab('configuration')

  // Click on update button
  cy.getBySel(`update-conf`).click()

  // Check OS&CPU tab
  cy.navigateTab('booting')
  checkForm(restrictedAttributes.OS, check)

  // Check Input/Output tab
  cy.navigateTab('input_output')
  checkForm(restrictedAttributes.GRAPHICS, check)
  checkForm(restrictedAttributes.INPUT, check)
  checkForm(restrictedAttributes.VIDEO, check)

  // Check Context tab
  cy.navigateTab('context')
  checkForm(restrictedAttributes.CONTEXT, check)
  checkForm(restrictedAttributes.USER_INPUTS, check)

  // Check backup tab
  cy.getBySel('modal-update-conf').within(() => {
    cy.navigateTab('backup')
  })
  checkForm(restrictedAttributes.BACKUP_CONFIG, check)

  cy.getBySel('dg-cancel-button').click()
}

Cypress.Commands.add('updateVmConfiguration', updateVmConfiguration)
Cypress.Commands.add('validateVmConfiguration', validateVmConfiguration)
Cypress.Commands.add(
  'validateRestrictedAttributesVmConfiguration',
  validateRestrictedAttributesVmConfiguration
)
