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
import { User, Group, SecurityGroup } from '@models'

import {
  configSelectSecGroup,
  SecurityGroup as SecurityGroupDoc,
} from '@support/commands/securitygroups/jsdocs'
import { createIntercept, Intercepts } from '@support/utils'
import { FORCE } from '@support/commands/constants'
import { fillSecurityGroupGUI } from '@support/commands/securitygroups/create'

/**
 * Create Security Group via GUI.
 *
 * @param {SecurityGroupDoc} SecurityGroupTemplate - template
 * @param {SecurityGroupDoc} row - row
 * @returns {Cypress.Chainable<Cypress.Response>} create/update security group response
 */
const secGroupGUI = (SecurityGroupTemplate, row) => {
  let interceptSecGroup = createIntercept(Intercepts.SUNSTONE.SECGROUP_ALLOCATE)
  if (row) {
    interceptSecGroup = createIntercept(Intercepts.SUNSTONE.SECGROUP_UPDATE)
    cy.clickSecGroupRow(row)
    cy.getBySel('action-update_dialog').click()
  } else {
    cy.getBySel('action-securityGroup_create_dialog').click()
  }

  fillSecurityGroupGUI(SecurityGroupTemplate)

  cy.getBySel('stepper-next-button').click(FORCE)

  return cy.wait(interceptSecGroup)
}

/**
 * Commit Security Group.
 *
 * @param {configSelectSecGroup} secGroup - security group for commit
 */
const commitSecurityGroup = (secGroup = {}) => {
  const getSecGroupCommit = createIntercept(Intercepts.SUNSTONE.SECGROUP_COMMIT)

  cy.clickSecGroupRow(secGroup)

  cy.getBySel('action-commit').click()

  cy.getBySel('modal-commit')
    .should('exist')
    .then(($dialog) => {
      cy.wrap($dialog).find('[data-cy=dg-accept-button]').click(FORCE)

      return cy.wait(getSecGroupCommit)
    })
}

/**
 * Clone Security Group via GUI.
 *
 * @param {configSelectSecGroup} secGroup - security group for clone
 * @param {string} newname - new name
 */
const cloneSecurityGroup = (secGroup = {}, newname = '') => {
  const getSecGroupClone = createIntercept(Intercepts.SUNSTONE.SECGROUP_CLONE)

  cy.clickSecGroupRow(secGroup)

  cy.getBySel('action-clone').click()

  cy.getBySel('modal-clone')
    .should('exist')
    .then(($dialog) => {
      cy.wrap($dialog).find('[data-cy=form-dg-name]').clear(FORCE).type(newname)
      cy.wrap($dialog).find('[data-cy=dg-accept-button]').click(FORCE)

      return cy.wait(getSecGroupClone)
    })
}

/**
 * Changes Security Group ownership: user or group.
 *
 * @param {SecurityGroup} secgroup - VM to change owner
 * @param {object} options - Options to fill the form
 * @param {User} [options.user] - The new owner
 * @param {Group} [options.group] - The new group
 * @returns {Cypress.Chainable} Chainable command to change SECURITY GROUP owner
 */
const changeSecGroupOwnership = (secgroup, { user, group } = {}) =>
  cy.getBySelLike('modal-').within(() => {
    user && cy.getUserRow(user).click(FORCE)
    group && cy.getGroupRow(group).click(FORCE)
    cy.getBySel('dg-accept-button').click(FORCE)
  })

/**
 * Performs an action on a Security Group.
 *
 * @param {'ownership'} group - Group action name
 * @param {string} action - Action name to perform
 * @param {Function} form - Function to fill the form. By default is a confirmation dialog.
 * @returns {function(secGroup, any):Cypress.Chainable}
 * Chainable command to perform an action on a Security group
 */
const groupAction = (group, action, form) => (secGroup, options) => {
  cy.clickSecGroupRow(secGroup)

  cy.getBySel(`action-securityGroup-${group}`).click(FORCE)
  cy.getBySel(`action-${action}`).click(FORCE)

  if (form) return form(secGroup, options)

  return cy.getBySel(`modal-${action}`).within(() => {
    cy.getBySel('dg-accept-button').click(FORCE)
  })
}

/**
 * Delete security group.
 *
 * @param {configSelectSecGroup} secGroup - config lock
 */
const deleteSecGroup = (secGroup = {}) => {
  const interceptDelete = createIntercept(Intercepts.SUNSTONE.SECGROUP_DELETE)

  cy.clickSecGroupRow(secGroup)
  cy.getBySel('action-secGroups_delete').click(FORCE)

  cy.getBySel(`modal-delete`)
    .should('exist')
    .then(($dialog) => {
      cy.wrap($dialog).find(`[data-cy=dg-accept-button]`).click(FORCE)

      return cy.wait(interceptDelete)
    })
}

Cypress.Commands.add('createSecurityGroupGUI', secGroupGUI)
Cypress.Commands.add('updateSecurityGroupGUI', secGroupGUI)
Cypress.Commands.add('commitSecurityGroup', commitSecurityGroup)
Cypress.Commands.add('cloneSecurityGroup', cloneSecurityGroup)
Cypress.Commands.add(
  'changeSecGroupOwner',
  groupAction('ownership', 'chown', changeSecGroupOwnership)
)
Cypress.Commands.add(
  'changeSecGroupGroup',
  groupAction('ownership', 'chgrp', changeSecGroupOwnership)
)
Cypress.Commands.add('deleteSecGroup', deleteSecGroup)
