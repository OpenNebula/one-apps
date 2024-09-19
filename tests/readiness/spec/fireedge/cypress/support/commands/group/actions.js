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

import { fillGroupGUI } from '@support/commands/group/create'

import { Intercepts, createIntercept, accessAttribute } from '@support/utils'

import { Group, User } from '@models'

import { FORCE } from '@support/commands/constants'

import { QuotaTypes, Group as GroupDocs } from '@support/commands/user/jsdocs'

/**
 * Creates a new group via GUI.
 *
 * @param {object} group - The group to create
 * @returns {void} - No return value
 */
const groupGUI = (group) => {
  // Create interceptor for each request that is used on create a group
  const interceptGroupAllocate = createIntercept(
    Intercepts.SUNSTONE.GROUP_CREATE
  )
  const interceptGroupUpdate = createIntercept(Intercepts.SUNSTONE.GROUP_UPDATE)
  const interceptACLAllocate = createIntercept(Intercepts.SUNSTONE.ACL_CREATE)
  const interceptUserAllocate = createIntercept(Intercepts.SUNSTONE.USER_CREATE)

  // Click on create button
  cy.getBySel('action-create_dialog').click()

  // Fill form
  fillGroupGUI(group)

  // Wait and check that every request it's finished with 200 result
  cy.wait(interceptGroupAllocate).its('response.statusCode').should('eq', 200)
  cy.wait(interceptUserAllocate).its('response.statusCode').should('eq', 200)
  cy.wait(interceptACLAllocate).its('response.statusCode').should('eq', 200)
  cy.wait(interceptGroupUpdate).its('response.statusCode').should('eq', 200)
}

/**
 * Update a group via GUI.
 *
 * @param {object} group - The group to create
 * @returns {void} - No return value
 */
const updateGroupGUI = (group) => {
  // Create interceptor for each request that is used on create a group
  const interceptGroupUpdate = createIntercept(Intercepts.SUNSTONE.GROUP_UPDATE)

  // Click on update button
  cy.getBySel('action-update_dialog').click()

  // Fill form
  fillGroupGUI(group)

  // Wait and check that every request it's finished with 200 result
  cy.wait(interceptGroupUpdate).its('response.statusCode').should('eq', 200)
}

/**
 * Validates the information tab of a gorup.
 *
 * @param {object} params - Parameters
 * @param {number} params.id - User ID
 * @param {string} params.name - Name of the group
 */
const validateGroupInfoTab = ({ id, name }) => {
  cy.navigateTab('info').within(() => {
    cy.getBySel('id').should('have.text', id)
    cy.getBySel('name').should('have.text', name)
  })
}

/**
 * Validate the attributes of a group.
 *
 * @param {object} group - Group template
 * @param {Array} validateList - List of fields to validate
 */
const validateGroupInfo = (group, validateList) => {
  const groupResponse = new Group(group.name)
  groupResponse.info().then(() => {
    // Validate each field of validateList array
    validateList.forEach((element) => {
      // Validate each field
      expect(accessAttribute(groupResponse?.json, element.field)).eq(
        element.value
      )
    })
  })
}

/**
 * Validate that an admin group user has the views.
 *
 * @param {object} adminGroupUser - The admin group user info
 * @param {Array} views - Views to validate
 */
const validateAdminViews = (adminGroupUser, views) => {
  cy.apiAuth(adminGroupUser).then((token) => {
    cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
      qs: { externalToken: token },
    })

    // Validate views
    cy.getBySel('header-view-button').click()
    views.forEach((view) => {
      cy.get('#view-list').should('contain', view)
    })
  })
}

/**
 * Validate that an user has the views.
 *
 * @param {object} groupUser - The user info
 * @param {Array} views - Views to validate
 */
const validateUserViews = (groupUser, views) => {
  // Create user
  const user = new User(groupUser.username, groupUser.password)

  user.allocate().then(() => {
    // Login with new user
    cy.apiAuth(groupUser).then((token) => {
      cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
        qs: { externalToken: token },
      })

      // Validate views
      cy.getBySel('header-view-button').click()
      views.forEach((view) => {
        cy.get('#view-list').should('contain', view)
      })
    })
  })
}

/**
 * Validates the loading of the groups sub-tabs.
 *
 * @param {string[]} tabs - The tabs to validate
 */
const validateGroupTabs = (tabs) => {
  tabs.forEach((tabName) => {
    cy.navigateTab(tabName).should('exist').and('be.visible')
  })
}

/**
 * Validates the quota of a group.
 *
 * @param {QuotaTypes} params - Parameters
 * @param {number} params.quotaValue - Quota value
 * @param {string} params.quotaResourceIds - Quota resource IDs
 * @param {string} params.quotaType - Type of quota
 * @param {string[]} params.quotaIdentifiers - Quota identifiers
 * @returns {void} - No return value
 */
const validateGroupQuota = ({
  quotaValue,
  quotaResourceIds,
  quotaType,
  quotaIdentifiers,
}) => {
  const interceptQuota = createIntercept(Intercepts.SUNSTONE.GROUP_QUOTA_UPDATE)
  cy.navigateTab('quota').within(() => {
    cy.selectMUIDropdownOption('qc-type-selector', quotaType)
      .then(() => {
        if (quotaResourceIds) {
          quotaResourceIds.forEach((id) => {
            cy.getBySel('qc-id-input')
              .click()
              .type(id)
              .then(() => cy.realType('{enter}'))
          })
        }
      })
      .then(() => {
        cy.selectMUIDropdownOption('qc-identifier-selector', quotaIdentifiers)
      })
      .then(() => {
        if (quotaResourceIds?.length > 1) {
          cy.getBySel('qc-value-input').click(FORCE)
          quotaResourceIds.forEach((id, index) => {
            cy.document().then((doc) => {
              const selector = doc.querySelector(
                `[data-cy="qc-value-input-${index}"]`
              )
              if (selector) {
                cy.wrap(selector)
                  .click({ force: true })
                  .type(quotaValue?.[id] ?? quotaValue?.[0] ?? 0)
              }
            })
          })
          cy.realType('{esc}')
        } else {
          cy.getBySel('qc-value-input').type(quotaValue?.[0] ?? quotaValue ?? 0)
        }
      })
      .then(() => {
        cy.getBySel('qc-apply-button').click(FORCE)
      })
  })

  cy.wait(interceptQuota).its('response.statusCode').should('eq', 200)
}

/**
 * Delete all admins in a group.
 *
 * @param {GroupDocs} group - The group where delete admins
 */
const deleteAdminsGroupGUI = (group) => {
  // Create interceptor for each request that is used on create a group
  const interceptGroupDeleteAdmins = createIntercept(
    Intercepts.SUNSTONE.GROUP_ADMIN_DELETE
  )

  const interceptUsers = createIntercept(Intercepts.SUNSTONE.USERS)

  // Click group row on groups table
  cy.clickGroupRow({ id: group.id }).then(() => {
    // Navigate to the users tab
    cy.navigateTab('user')

    // Click on edit admins button
    cy.getBySel('edit-admins').click()
    cy.wait(interceptUsers)
    cy.getBySel('modal-edit-admins').within(() => {
      // Get users table and delete every selection
      cy.getBySel('users').within((container) => {
        container.find('[data-cy="itemSelected"]').length &&
          cy.getBySel('itemSelected').each(($element) => {
            cy.wrap($element).find('svg').click()
          })
      })

      // Submit changes
      cy.getBySel('dg-accept-button').click()

      // Wait for delete request
      cy.wait(interceptGroupDeleteAdmins)
        .its('response.statusCode')
        .should('eq', 200)
    })
  })
}

/**
 * Add an user as admin in a group.
 *
 * @param {GroupDocs} group - The group where add the admins.
 * @param {string} username - Name of the user
 */
const addAdminsGroupGUI = (group, username) => {
  // Create interceptor for each request that is used on create a group
  const interceptGroupDeleteAdmins = createIntercept(
    Intercepts.SUNSTONE.GROUP_ADMIN_ADD
  )

  // Get user info
  const user = new User(username)
  user.info().then(() => {
    // Click on group
    cy.clickGroupRow({ id: group.id }).then(() => {
      // Go to the users tab
      cy.navigateTab('user')

      // Click on edit admins button
      cy.getBySel('edit-admins').click()
      cy.getBySel('modal-edit-admins').within(() => {
        // Select the new administrator
        cy.getUserRow({ id: user.id }).click()

        // Submit changes
        cy.getBySel('dg-accept-button').click()

        // Wait for add request
        cy.wait(interceptGroupDeleteAdmins)
          .its('response.statusCode')
          .should('eq', 200)
      })
    })
  })
}

/**
 * Validate that a group has an user as admin.
 *
 * @param {GroupDocs} group - The group to get admins
 * @param {string} username - Name of the user that has to be an admin of the group
 */
const validateGroupAdmins = (group, username) => {
  // Get the info of the group
  group.info().then((groupData) => {
    // Get the info of the user
    const user = new User(username)
    user.info().then((userData) => {
      // Validate
      const adminsToValidate = username ? [{ ID: userData.ID }] : []
      const admins = Array.isArray(groupData?.ADMINS)
        ? groupData?.ADMINS
        : groupData.ADMINS
        ? [groupData.ADMINS]
        : []
      cy.wrap(adminsToValidate).should('deep.equal', admins)
    })
  })
}

/**
 * Deletes a group.
 *
 * @param {GroupDocs} group - The group to delete
 * @param {object} adminUser - Admin user to delete first
 * @param {object} groupUser - Group user to delete first
 */
const deleteGroup = (group, adminUser, groupUser) => {
  // Get info about the group
  group.info().then(() => {
    // Get the admin user of the group
    const userAdmin = new User(adminUser.username)
    const userGroup = new User(groupUser.username)
    userGroup.info().then(() => {
      // Delete the group user
      userGroup.delete().then(() => {
        userAdmin.info().then(() => {
          // Delete the admin user
          userAdmin.delete().then(() => {
            // Select the group
            cy.clickGroupRow({ id: group.id }).then(() => {
              // Create interceptor
              const interceptDelete = createIntercept(
                Intercepts.SUNSTONE.GROUP_DELETE
              )

              // Click on delete button
              cy.getBySel('action-group_delete').click()

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
          })
        })
      })
    })
  })
}

/**
 * Switch group of the user and check that the primary group is changed.
 *
 * @param {object} user - The user who is gonna change his primary group.
 * @param {object} newGroup - The new group of the user. If it is undefined, "Show all" option will be selected.
 * @param {boolean} showAll - Change to Show all view
 * @param {boolean} showUserGroup - Change to Show all owned by the user or his groups view
 * @param {boolean} showUser - Change to Show all owned by the user view
 */
const switchGroup = (user, newGroup, showAll, showUserGroup, showUser) => {
  cy.getBySel('header-group-button').click()

  if (newGroup) {
    // Create interceptor
    const interceptChangeGroup = createIntercept(Intercepts.SUNSTONE.USER_CHGRP)

    cy.getBySel('group-' + newGroup.id).click()

    // Check tha response is 200
    cy.wait(interceptChangeGroup).its('response.statusCode').should('eq', 200)

    // Check that the primary group of the uses it's changed
    user.info().then((data) => {
      expect(data.GID).to.equal(user.json.GID)
    })
  } else {
    // Data-cy for Show all option it's "always group--2"
    showAll && cy.getBySel('group--2').click()

    // Data-cy for Show all option it's "always group--1"
    showUserGroup && cy.getBySel('group--1').click()

    // Data-cy for Show all option it's "always group--3"
    showUser && cy.getBySel('group--3').click()
  }
}

/**
 * Check if templates are showed or not in the templates table.
 *
 * @param {Array} templatesGroup - Templates that have to be showed
 * @param {Array} templatesNotGroup - Templates that have not to be showed
 */
const validateGroupTemplates = (
  templatesGroup = [],
  templatesNotGroup = []
) => {
  cy.navigateMenu('templates', 'VM Templates')

  // templateGroup group should exist
  templatesGroup.forEach((template) =>
    cy.getTemplateRow(template).should('exist')
  )

  // templateNotGroup group should not exists
  templatesNotGroup.forEach((template) =>
    cy
      .getTemplateTable({ search: template.name })
      .find('[role="row"]')
      .should('not.exist')
  )
}

/**
 * Switch view of the user.
 *
 * @param {object} newView - The new view of the user.
 */
const switchView = (newView) => {
  cy.getBySel('header-view-button').click()
  cy.getBySel('view-' + newView).click()
}

/**
 * Validate menu items.
 *
 * @param {Array} menuItemsToFind - Menu items that have to exist
 * @param {Array} menuItemsNotToFind - Menu items that have not to exist
 */
const validateMenuItems = (menuItemsToFind = [], menuItemsNotToFind = []) => {
  // Check that items exists on the menu
  menuItemsToFind.forEach(({ parent, item }) => {
    cy.getBySel('sidebar')
      .realHover()
      .within(() => {
        cy.getBySel(parent).then(($parent) => {
          if (!$parent.hasClass('open')) {
            cy.wrap($parent)
              .realClick()
              .then(() => {
                const noMatchCase = { matchCase: false }
                cy.contains(
                  '[data-cy=main-menu-item]',
                  item,
                  noMatchCase
                ).should('exist')
              })
          }
        })
      })
  })

  // Check that items not exists on the menu
  menuItemsNotToFind.forEach(({ parent }) => {
    cy.getBySel('sidebar')
      .realHover()
      .within(() => {
        cy.getBySel(parent).should('not.exist')
      })
  })
}

Cypress.Commands.add('groupGUI', groupGUI)
Cypress.Commands.add('updateGroupGUI', updateGroupGUI)
Cypress.Commands.add('validateGroupInfoTab', validateGroupInfoTab)
Cypress.Commands.add('validateGroupInfo', validateGroupInfo)
Cypress.Commands.add('validateAdminViews', validateAdminViews)
Cypress.Commands.add('validateUserViews', validateUserViews)
Cypress.Commands.add('validateGroupTabs', validateGroupTabs)
Cypress.Commands.add('validateGroupQuota', validateGroupQuota)
Cypress.Commands.add('deleteAdminsGroupGUI', deleteAdminsGroupGUI)
Cypress.Commands.add('addAdminsGroupGUI', addAdminsGroupGUI)
Cypress.Commands.add('validateGroupAdmins', validateGroupAdmins)
Cypress.Commands.add('deleteGroup', deleteGroup)
Cypress.Commands.add('switchGroup', switchGroup)
Cypress.Commands.add('validateGroupTemplates', validateGroupTemplates)
Cypress.Commands.add('switchView', switchView)
Cypress.Commands.add('validateMenuItems', validateMenuItems)
