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

import { fillAclStringGUI, fillAclGUI } from '@support/commands/acl/create'
import { Intercepts, createIntercept } from '@support/utils'
import { Acl } from '@models'

/**
 * Creates a new acl via String GUI.
 *
 * @param {object} rule - The acl to create
 * @returns {void} - No return value
 */
const aclStringGUI = (rule) => {
  // Create interceptor for request that is used on create an acl
  const interceptAclAllocate = createIntercept(Intercepts.SUNSTONE.ACL_CREATE)

  // Click on create button
  cy.getBySel('action-create_dialog_string').click()

  // Fill form
  fillAclStringGUI(rule)

  // Wait and check that every request it's finished with 200 result
  cy.wait(interceptAclAllocate).then(
    (interceptResponse) => interceptResponse.response.body
  )
}

/**
 * Creates a new acl via GUI.
 *
 * @param {object} acl - The acl to create
 * @returns {void} - No return value
 */
const aclGUI = (acl) => {
  // Create interceptor for request that is used on create an acl
  const interceptAclAllocate = createIntercept(Intercepts.SUNSTONE.ACL_CREATE)

  // Click on create button
  cy.getBySel('action-create_dialog').click()

  // Fill form
  fillAclGUI(acl)

  // Wait and check that every request it's finished with 200 result
  cy.wait(interceptAclAllocate).then(
    (interceptResponse) => interceptResponse.response.body
  )
}

/**
 * Check if the rule is created ok.
 *
 * @param {string} aclId - ACL identifier
 * @param {string} aclString - ACL to check
 */
const validateACL = (aclId, aclString) => {
  // Create Acl object
  const acl = new Acl()
  acl.id = aclId

  // Get info about acl
  acl.info().then((data) => {
    // Check string rule
    cy.wrap(data.STRING).should('eq', aclString)
  })
}

/**
 * Delete an acl rule.
 *
 * @param {string} aclId - Id of the rule
 */
const deleteACL = (aclId) => {
  // Select acl
  cy.clickAclRow(
    { name: aclId, id: aclId },
    { search: aclId, noWait: true },
    { refresh: false }
  ).then(() => {
    // Create interceptor
    const interceptDelete = createIntercept(Intercepts.SUNSTONE.ACL_DELETE)

    // Click on delete button
    cy.getBySel('action-acl_delete').click()

    // Accept the modal of delete group
    cy.getBySel(`modal-delete`)
      .should('exist')
      .then(($dialog) => {
        cy.wrap($dialog).find(`[data-cy=dg-accept-button]`).click()

        return cy
          .wait(interceptDelete)
          .its('response.statusCode')
          .should('eq', 200)
      })
  })
}

/**
 * Check that the card in ICONS format is correct.
 *
 * @param {object} validateRule - Rule to validate
 * @param {string} id - The id of the rule
 */
const validateAclIconView = (validateRule, id) => {
  // Change view to ICONS view
  cy.getBySel('changeviewtable-by-button').click()
  cy.getBySel('ICONS').click()
  cy.getBySel('main-layout').click()

  // Get the acl row
  cy.clickAclRow(
    { name: id, id: id },
    { search: id, noWait: true },
    { refresh: false }
  ).then((row) => {
    cy.wrap(row).within(() => {
      // Check id
      cy.getBySel('acl-card-id').should('have.text', '#' + id)

      // Check resource icons
      cy.get('[data-cy=acl-card-icons]')
        .find('svg')
        .each(($svg) => {
          // Check that each resource has the correct color
          const cyValue = $svg.attr('data-cy')
          const colorExpected = validateRule.resources.includes(
            cyValue.replace('acl-card-icon-', '')
          )
            ? 'rgb(0, 0, 0)'
            : 'rgb(128, 128, 128)'

          const colorAttributeValue = Cypress.$($svg).css('color')

          expect(colorAttributeValue).to.include(colorExpected)
        })

      // Check resources identifier
      cy.getBySel('acl-card-resourcesIdentifier').should(
        'have.text',
        validateRule.resourcesIdentifier
      )

      // Check user
      cy.getBySel('acl-card-user').should('have.text', validateRule.user)

      // Check rights
      cy.get('[data-cy=acl-card-rights]')
        .find('span')
        .each(($span) => {
          // Check that each right has the correct color
          const cyValue = $span.attr('data-cy')
          const colorExpected = validateRule.rights.includes(
            cyValue.replace('acl-card-rights-', '')
          )
            ? 'rgb(0, 0, 0)'
            : 'rgb(128, 128, 128)'

          const colorAttributeValue = Cypress.$($span).css('color')

          expect(colorAttributeValue).to.include(colorExpected)
        })

      // Check zone
      cy.getBySel('acl-card-zone').should('have.text', validateRule.zone)
    })
  })
}

/**
 * Check that the card in RESOURCES format is correct.
 *
 * @param {object} validateRule - Rule to validate
 * @param {string} id - The id of the rule
 */
const validateAclResourcesView = (validateRule, id) => {
  // Change view to RESOURCES view
  cy.getBySel('changeviewtable-by-button').click()
  cy.getBySel('RESOURCES').click()
  cy.getBySel('main-layout').click()

  // Get the acl row
  cy.clickAclRow(
    { name: id, id: id },
    { search: id, noWait: true },
    { refresh: false }
  ).then((row) => {
    cy.wrap(row).within(() => {
      // Check id
      cy.getBySel('acl-card-id').should('have.text', '#' + id)

      // Check resource icons
      cy.get('[data-cy=acl-card-icons]')
        .find('svg')
        .each(($svg) => {
          // Check that each resource has the correct color
          const cyValue = $svg.attr('data-cy')
          const colorExpected = validateRule.resources.includes(
            cyValue.replace('acl-card-icon-', '')
          )
            ? 'rgb(0, 0, 0)'
            : 'rgb(128, 128, 128)'

          const colorAttributeValue = Cypress.$($svg).css('color')

          expect(colorAttributeValue).to.include(colorExpected)
        })
        .should('have.length', validateRule.resources.length)

      // Check resources identifier
      cy.getBySel('acl-card-resourcesIdentifier').should(
        'have.text',
        validateRule.resourcesIdentifier
      )

      // Check user
      cy.getBySel('acl-card-user').should('have.text', validateRule.user)

      // Check rights
      cy.get('[data-cy=acl-card-rights]')
        .find('span')
        .each(($span) => {
          // Check that each right has the correct color
          const cyValue = $span.attr('data-cy')
          const colorExpected = validateRule.rights.includes(
            cyValue.replace('acl-card-rights-', '')
          )
            ? 'rgb(0, 0, 0)'
            : 'rgb(128, 128, 128)'

          const colorAttributeValue = Cypress.$($span).css('color')

          expect(colorAttributeValue).to.include(colorExpected)
        })

      // Check zone
      cy.getBySel('acl-card-zone').should('have.text', validateRule.zone)
    })
  })
}

/**
 * Check that the card in NAMES format is correct.
 *
 * @param {object} validateRule - Rule to validate
 * @param {string} id - The id of the rule
 */
const validateAclNamesView = (validateRule, id) => {
  // Change view to NAMES view
  cy.getBySel('changeviewtable-by-button').click()
  cy.getBySel('NAMES').click()
  cy.getBySel('main-layout').click()

  // Get the acl row
  cy.clickAclRow(
    { name: id, id: id },
    { search: id, noWait: true },
    { refresh: false }
  ).then((row) => {
    cy.wrap(row).within(() => {
      // Check id
      cy.getBySel('acl-card-id').should('have.text', '#' + id)

      // Check resource icons
      cy.get('[data-cy=acl-card-names]')
        .find('span')
        .each(($span) => {
          // Check that each resource has the correct color
          const cyValue = $span.attr('data-cy')
          const colorExpected = validateRule.resources.includes(
            cyValue.replace('acl-card-name-', '')
          )
            ? 'rgb(0, 0, 0)'
            : 'rgb(128, 128, 128)'

          const colorAttributeValue = Cypress.$($span).css('color')

          expect(colorAttributeValue).to.include(colorExpected)
        })

      // Check resources identifier
      cy.getBySel('acl-card-resourcesIdentifier').should(
        'have.text',
        validateRule.resourcesIdentifier
      )

      // Check user
      cy.getBySel('acl-card-user').should('have.text', validateRule.user)

      // Check rights
      cy.get('[data-cy=acl-card-rights]')
        .find('span')
        .each(($span) => {
          // Check that each right has the correct color
          const cyValue = $span.attr('data-cy')
          const colorExpected = validateRule.rights.includes(
            cyValue.replace('acl-card-rights-', '')
          )
            ? 'rgb(0, 0, 0)'
            : 'rgb(128, 128, 128)'

          const colorAttributeValue = Cypress.$($span).css('color')

          expect(colorAttributeValue).to.include(colorExpected)
        })

      // Check zone
      cy.getBySel('acl-card-zone').should('have.text', validateRule.zone)
    })
  })
}

/**
 * Check that the card in CLI format is correct.
 *
 * @param {object} validateRule - Rule to validate
 * @param {string} id - The id of the rule
 */
const validateAclCLIView = (validateRule, id) => {
  // Change view to CLI view
  cy.getBySel('changeviewtable-by-button').click()
  cy.getBySel('CLI').click()
  cy.getBySel('main-layout').click()

  // Get the acl row
  cy.clickAclRow(
    { name: id, id: id },
    { search: id, noWait: true },
    { refresh: false }
  ).then((row) => {
    cy.wrap(row).within(() => {
      // Check id
      cy.getBySel('acl-card-id').should('have.text', '#' + id)

      // Check resource icons
      cy.get('[data-cy=acl-card-resources]').should(
        'have.text',
        validateRule.cli.resources
      )

      // Check resources identifier
      cy.getBySel('acl-card-resourcesIdentifier').should(
        'have.text',
        validateRule.cli.resourcesIdentifier
      )

      // Check user
      cy.getBySel('acl-card-user').should('have.text', validateRule.cli.user)

      // Check rights
      cy.get('[data-cy=acl-card-rights]').should(
        'have.text',
        validateRule.cli.rights
      )

      // Check zone
      cy.getBySel('acl-card-zone').should('have.text', validateRule.cli.zone)
    })
  })
}

/**
 * Check that the card in rule format is correct.
 *
 * @param {object} validateRule - Rule to validate
 * @param {string} id - The id of the rule
 */
const validateAclRuleView = (validateRule, id) => {
  // Change view to ICONS view
  cy.getBySel('changeviewtable-by-button').click()
  cy.getBySel('RULE').click()
  cy.getBySel('main-layout').click()

  // Get the acl row
  cy.clickAclRow(
    { name: id, id: id },
    { search: id, noWait: true },
    { refresh: false }
  ).then((row) => {
    cy.wrap(row).within(() => {
      // Check id
      cy.getBySel('acl-card-id').should('have.text', '#' + id)

      // Check rule
      cy.getBySel('acl-card-string').should('have.text', validateRule.rule)
    })
  })
}

/**
 * Check that the card in rule format is correct.
 *
 * @param {object} validateRule - Rule to validate
 * @param {string} id - The id of the rule
 */
const validateAclReadableView = (validateRule, id) => {
  // Change view to READABLE view
  cy.getBySel('changeviewtable-by-button').click()
  cy.getBySel('READABLERULE').click()
  cy.getBySel('main-layout').click()

  // Get the acl row
  cy.clickAclRow(
    { name: id, id: id },
    { search: id, noWait: true },
    { refresh: false }
  ).then((row) => {
    cy.wrap(row).within(() => {
      // Check id
      cy.getBySel('acl-card-id').should('have.text', '#' + id)

      // Check rule
      cy.getBySel('acl-card-readable').should(
        'have.text',
        validateRule.readable
      )
    })
  })
}

Cypress.Commands.add('aclStringGUI', aclStringGUI)
Cypress.Commands.add('validateACL', validateACL)
Cypress.Commands.add('aclGUI', aclGUI)
Cypress.Commands.add('deleteACL', deleteACL)
Cypress.Commands.add('validateAclIconView', validateAclIconView)
Cypress.Commands.add('validateAclResourcesView', validateAclResourcesView)
Cypress.Commands.add('validateAclNamesView', validateAclNamesView)
Cypress.Commands.add('validateAclCLIView', validateAclCLIView)
Cypress.Commands.add('validateAclRuleView', validateAclRuleView)
Cypress.Commands.add('validateAclReadableView', validateAclReadableView)
