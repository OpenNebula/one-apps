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
import { Intercepts } from '@utils/index'
import { VmTemplateCreate } from '@commands/vm/jsdocs'
import {
  fillStorageSection,
  fillNetworkSection,
  fillSchedActionsSection,
} from '@commands/template/create'
import VirtualMachine from '@support/models/vm'

import { accessAttribute } from '@support/utils'

/**
 * Instantiate a VM Template via GUI.
 *
 * @param {VmTemplateCreate} instantiateVMTemplate - template VM
 * @returns {Cypress.Chainable<Cypress.Response>} Instantiate VM response
 */
const instantiateVM = ({ templateId = '', vmTemplate = {} }) => {
  // open modal to select VM Template
  cy.getBySel('action-vm_create_dialog')
    .should('exist')
    .then(($buttonCreate) => {
      cy.wrap($buttonCreate).click()
    })

  // select VM Template
  cy.clickWithInterceptor({
    button: `template-${templateId}`,
    intercept: Intercepts.SUNSTONE.TEMPLATE,
  })

  const {
    name,
    instances,
    hold,
    persistent,
    memory,
    cpu,
    vcpu,
    user,
    group,
    vmgroup,
    placement,
    osBooting,
    context,
  } = vmTemplate

  // INFORMATION
  cy.getBySel('main-layout').click()
  cy.getBySel('information-name').clear().type(name)
  instances && cy.getBySel('information-instances').clear().type(instances)
  hold && cy.getBySel('information-hold').click()
  persistent && cy.getBySel('information-persistent').click()
  memory && cy.getBySel('capacity-MEMORY').clear().type(memory)
  cpu && cy.getBySel('capacity-CPU').clear().type(cpu)
  vcpu && cy.getBySel('capacity-VCPU').clear().type(vcpu)
  if (user) {
    cy.getBySel('ownership-AS_UID').clear().type(user)
    cy.getDropdownOptions().contains(user).click()
  }
  if (group) {
    cy.getBySel('ownership-AS_GID').clear().type(group)
    cy.getDropdownOptions().contains(group).click()
  }
  if (vmgroup) {
    cy.getBySel('vm_group-VMGROUP-VMGROUP_ID').clear().type(vmgroup)
    cy.getDropdownOptions().contains(vmgroup).click()
  }
  cy.getBySel('stepper-next-button').click()

  // USER INPUTS
  if (context?.userInputs) {
    context.userInputs.forEach((input) => {
      const inputKey = Object.keys(input)[0]
      cy.getBySel('user-inputs-' + inputKey)
        .clear()
        .type(input[inputKey])
    })
    cy.getBySel('stepper-next-button').click()
  }

  // STORAGE
  fillStorageSection(vmTemplate)
  fillNetworkSection(vmTemplate)
  fillSchedActionsSection(vmTemplate)

  // PLACEMENT
  if (placement) {
    cy.navigateTab('placement')
    const { schedRequirement, schedRank, dsSchedRequirement, dsSchedRank } =
      placement
    schedRequirement &&
      cy.getBySel('ownership-AS_GID').clear().type(schedRequirement)
    schedRank && cy.getBySel('ownership-AS_GID').clear().type(schedRank)
    dsSchedRequirement &&
      cy.getBySel('ownership-AS_GID').clear().type(dsSchedRequirement)
    dsSchedRank && cy.getBySel('ownership-AS_GID').clear().type(dsSchedRank)
  }

  // OS BOOTING
  if (osBooting) {
    cy.navigateTab('booting')
    cy.wrap(Array.isArray(osBooting) ? osBooting : [osBooting]).each(
      (bootElement) => {
        cy.getBySel(bootElement).click()
      }
    )
  }

  return cy
    .clickWithInterceptor({
      button: 'stepper-next-button',
      intercept: Intercepts.SUNSTONE.TEMPLATE_INSTANTIATE,
    })
    .its('response.body.id')
    .should('eq', 200)
}

/**
 * Instantiate a VM and validate the template.
 *
 * @param {object} resources - Resources of the template
 * @param {string} resources.templateId - Id of the template
 * @param {object} resources.vmTemplate - Attributes of the vm
 * @param {Array} validateList - List of attributes to validate it
 */
const instantiateVMandValidate = (
  { templateId = '', vmTemplate = {} },
  validateList
) => {
  // Use instantiate test
  instantiateVM({ templateId, vmTemplate }).then(() => {
    // After instantiate go to VMs menu
    cy.navigateMenu('instances', 'VMs')

    // Get the vm
    const vm = new VirtualMachine(vmTemplate.name)
    vm.info().then(() => {
      // Select the vm
      cy.clickVmRow(vm)

      // Navigate to info tab of the image
      cy.navigateTab('template').within(() => {
        // Select Templates div
        cy.get('.MuiAccordionSummary-content')
          .filter(':contains("Template")')
          .filter(
            (index, element) => Cypress.$(element).text().trim() === 'Template'
          )
          .click()

        // Get code element, which has the JSON template
        cy.get('code').then((data) => {
          // Get JSON and parse to object
          const templateJSON = JSON.parse(data.text())

          // Validate each field of validateList array
          validateList.forEach((element) => {
            // Validate each field
            expect(accessAttribute(templateJSON, element.field)).eq(
              element.value
            )
          })
        })
      })
    })
  })
}

Cypress.Commands.add('instantiateVM', instantiateVM)
Cypress.Commands.add('instantiateVMandValidate', instantiateVMandValidate)
