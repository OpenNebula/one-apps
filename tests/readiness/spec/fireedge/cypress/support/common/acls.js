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

/**
 * Creates a new ACL via String GUI and validate it.
 *
 * @param {object} acl - ACL rule.
 */
const aclStringGUIAndValidate = (acl) => {
  // Navigate to ACL menu
  cy.navigateMenu('system', 'ACLs')

  // Create acl rule
  cy.aclStringGUI(acl.rule).then((body) => {
    // Check that create operation returns 200
    cy.wrap(body.id).should('eq', 200)

    // Validate acl rule
    cy.validateACL(body.data, acl.result)
  })
}

/**
 * Creates a new ACL via GUI and validate it.
 *
 * @param {object} acl - ACL rule.
 */
const aclGUIAndValidate = (acl) => {
  // Navigate to ACL menu
  cy.navigateMenu('system', 'ACLs')

  // Create acl rule
  cy.aclGUI(acl).then((body) => {
    // Check that create operation returns 200
    cy.wrap(body.id).should('eq', 200)

    // Validate acl rule
    cy.validateACL(body.data, acl.result)
  })
}

/**
 * Delete a rule trough the GUI.
 *
 * @param {object} acl - The ACL rule
 */
const deleteGUI = (acl) => {
  // Navigate to ACL menu
  cy.navigateMenu('system', 'ACLs')

  // Create acl rule
  cy.aclStringGUI(acl.rule).then((body) => {
    // Check that create operation returns 200
    cy.wrap(body.id).should('eq', 200)

    // Delete ACL
    cy.deleteACL(body.data)

    cy.getAclTable({ search: body.data }).within(() => {
      cy.get(`[role='row'][data-cy$='${body.data}']`).should('not.exist')
    })
  })
}

/**
 * Validate the different card views of acl table.
 *
 * @param {object} validateRule - Rule to validate
 */
const validateViews = (validateRule) => {
  // Navigate to ACL menu
  cy.navigateMenu('system', 'ACLs')

  // Create acl rule
  cy.aclStringGUI(validateRule.rule).then((body) => {
    // Check that create operation returns 200
    cy.wrap(body.id).should('eq', 200)

    // Validate icon view
    cy.validateAclIconView(validateRule, body.data)

    // Validate resources view
    cy.validateAclResourcesView(validateRule, body.data)

    // Validate names view
    cy.validateAclNamesView(validateRule, body.data)

    // Validate CLI view
    cy.validateAclCLIView(validateRule, body.data)

    // Validate CLI view
    cy.validateAclRuleView(validateRule, body.data)

    // Validate readable view
    cy.validateAclReadableView(validateRule, body.data)
  })
}

export { aclStringGUIAndValidate, aclGUIAndValidate, deleteGUI, validateViews }
