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
  timeToString,
  replaceJsonWithStringValues,
} from '@support/commands/helpers'
import { VmTemplate } from '@models'

/**
 * Validate Template information: name, description, logo, ...
 *
 * @param {VmTemplate} template - VM Template from CLI
 */
const validateInfoTab = (template) => {
  const { REGTIME } = template.json

  cy.clickTemplateRow(template)

  cy.navigateTab('info').within(() => {
    // INFORMATION
    cy.getBySel('id').should('have.text', template.id)
    cy.getBySel('name').should('have.text', template.name)
    cy.getBySel('starttime').should('have.text', timeToString(REGTIME))

    cy.validateOwnership(template)
    cy.validatePermissions(template)
  })
}

/**
 * Validate Template from VM Template.
 *
 * @param {VmTemplate} template - Template
 */
const validateTemplateTab = (template) => {
  cy.navigateTab('template').within(($content) => {
    const templateFromGui = $content.find('code').text()
    const jsonTemplate = JSON.parse(templateFromGui)
    const { TEMPLATE } = replaceJsonWithStringValues(template.json) || {}

    // check if template from CLI is equal to template from GUI
    expect(TEMPLATE).to.deep.include(jsonTemplate)
  })
}

/**
 * Validate VM Template on the GUI.
 *
 * @param {VmTemplate} template - Template
 */
const validateTabs = (template) => {
  validateInfoTab(template)
  validateTemplateTab(template)
}

Cypress.Commands.add('validateVmTemplateInfo', validateTabs)
