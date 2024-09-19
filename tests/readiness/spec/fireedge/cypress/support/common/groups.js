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

import Acl from '@support/models/acl'

/**
 * Creates a new group via GUI.
 *
 * @param {object} group - group template.
 */
const groupGUI = (group) => {
  cy.navigateMenu('system', 'Groups')
  cy.groupGUI(group)
}

/**
 * Creates a new group via GUI and validates it.
 *
 * @param {object} group - Group template.
 * @param {Array} validateList - List of fields to validate
 */
const groupGUIAndValidate = (group, validateList) => {
  cy.navigateMenu('system', 'Groups')
  cy.groupGUI(group)
  cy.validateGroupInfo(group, validateList)
}

/**
 * Updates a group via GUI and validates it.
 *
 * @param {object} group - Group template.
 * @param {object} updateTemplate - Group template.
 * @param {Array} validateList - List of fields to validate
 */
const updateGroupGUIAndValidate = (group, updateTemplate, validateList) => {
  cy.navigateMenu('system', 'Groups')
  cy.clickGroupRow({ id: group.id }).then(() => {
    cy.updateGroupGUI(updateTemplate)
    cy.validateGroupInfo(group, validateList)
  })
}

/**
 * Validates group information tab.
 *
 * @param {object} group - Group template.
 * @param {object} row - Holds group ID property.
 */
const groupInfoTab = (group, row) => {
  if (row.id === undefined) return
  cy.navigateMenu('system', 'Groups')
  cy.clickGroupRow(row).then(() => {
    cy.validateGroupInfoTab({ ...group, id: row.id })
  })
}

/**
 * Validate that an admin group user has some views.
 *
 * @param {object} adminGroupUser - Info about the user
 * @param {Array} views - List of views to validate
 */
const validateAdminGroupViews = (adminGroupUser, views) => {
  // Validate views
  cy.validateAdminViews(adminGroupUser, views)
}

/**
 * Validate that a group user has some views.
 *
 * @param {object} groupUser - Info about the user
 * @param {Array} views - List of views to validate
 */
const validateUserViews = (groupUser, views) => {
  // Validate views
  cy.validateUserViews(groupUser, views)
}

/**
 * Validates group tabs.
 *
 * @param {object} group - Group template.
 * @param {string[]} tabs - Array of sub-tab names to validate.
 */
const groupTabs = (group, tabs) => {
  cy.navigateMenu('system', 'Groups')
  cy.clickGroupRow({ id: group.id }).then(() => {
    cy.validateGroupTabs(tabs)
  })
}

/**
 * Validates group quota.
 *
 * @param {object} group - Group template.
 * @param {object} quota - Quota config.
 */
const groupQuota = (group, quota) => {
  cy.navigateMenu('system', 'Groups')
  cy.clickGroupRow({ id: group.id }).then(() => {
    cy.validateGroupQuota(quota)
  })
}

/**
 * Delete all administrators in a group.
 *
 * @param {object} group - Group where delete admins
 */
const deleteAdminsGroupGUIAndValidate = (group) => {
  cy.navigateMenu('system', 'Groups')
  cy.deleteAdminsGroupGUI(group)
  cy.validateGroupAdmins(group)
}

/**
 * Add a administrator in a group.
 *
 * @param {object} group - Group where add admin
 * @param {string} username - The name of the user
 */
const addAdminsGroupGUIAndValidate = (group, username) => {
  cy.navigateMenu('system', 'Groups')
  cy.addAdminsGroupGUI(group, username)
  cy.validateGroupAdmins(group, username)
}

/**
 * Deletes a group.
 *
 * @param {object} group - Group template.
 * @param {object} adminUser - Admin user to delete first
 * @param {object} groupUser - Group user to delete first
 */
const groupDelete = (group, adminUser, groupUser) => {
  if (group.id === undefined) return
  cy.navigateMenu('system', 'Groups')
  cy.deleteGroup(group, adminUser, groupUser).then(() => {
    cy.getGroupTable({ search: group.name }).within(() => {
      cy.get(`[role='row'][data-cy$='${group.id}']`).should('not.exist')
    })
  })
}

/**
 * Create groups and user to use in the change group tests.
 *
 * @param {object} infoSwitchGroupTests - Resources to create for change user tests
 */
const beforeAllSwitchGroupTests = (infoSwitchGroupTests) => {
  const groups = infoSwitchGroupTests.groups
  const users = infoSwitchGroupTests.users
  const templates = infoSwitchGroupTests.templates

  cy.fixture('auth')
    .then((auth) => cy.apiAuth(auth.admin))
    .then(() => {
      cy.cleanup({
        groups: {
          NAMES: [
            groups.group1.template.name,
            groups.group2.template.name,
            groups.group3.template.name,
          ],
        },
        templates: {
          NAMES: [
            templates.template1.template.name,
            templates.template2.template.name,
            templates.template3.template.name,
          ],
        },
        users: {
          NAMES: [users.user1.template.name],
        },
      })
    })
    .then(() => groups.group1.group.allocate(groups.group1.template.name))
    .then(() => groups.group2.group.allocate(groups.group2.template.name))
    .then(() => groups.group3.group.allocate(groups.group3.template.name))
    .then(() => {
      users.user1.user.allocate({
        ...users.user1.template,
        group: [groups.group1.group.id, groups.group2.group.id],
      })
    })
    .then(() => {
      templates.template1.item
        .allocate(templates.template1.template)
        .then(() => templates.template1.item.chgrp(groups.group1.group.id))
    })
    .then(() => {
      templates.template2.item
        .allocate(templates.template2.template)
        .then(() => {
          templates.template2.item.chgrp(groups.group2.group.id)
          templates.template2.item.chown(users.user1.user.id)
        })
    })
    .then(() => {
      templates.template3.item
        .allocate(templates.template3.template)
        .then(() => {
          templates.template3.item.chgrp(groups.group3.group.id)
        })
    })
    .then(() => {
      console.log(infoSwitchGroupTests)
      const acl = new Acl()
      acl.allocate(
        `#${infoSwitchGroupTests.users.user1.user.json.ID} TEMPLATE/@${infoSwitchGroupTests.groups.group3.group.json.ID} USE *`
      )
    })
}

/**
 * Delete all the resources used in swicth group tests.
 *
 * @param {object} infoSwitchGroupTests - Resources to create for switch group tests
 */
const afterSwitchGroupTests = (infoSwitchGroupTests) => {
  const groups = infoSwitchGroupTests.groups
  const users = infoSwitchGroupTests.users
  const templates = infoSwitchGroupTests.templates

  cy.fixture('auth')
    .then((auth) => cy.apiAuth(auth.admin))
    .then(() => {
      cy.cleanup({
        groups: {
          NAMES: [groups.group1.template.name, groups.group2.template.name],
        },
        templates: {
          NAMES: [templates.template1.template.name],
        },
        users: {
          NAMES: [users.user1.template.name],
        },
      })
    })
}

/**
 * Auth the user to use in change group tests.
 *
 * @param {object} user - User to log
 */
const beforeEachSwitchGroupTest = (user) => {
  cy.fixture('auth')
    .then((auth) => {
      auth.user.username = user.username
      auth.user.password = user.password
      cy.wrapperAuth(auth)
    })
    .then(() =>
      cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
        qs: { externalToken: Cypress.env('TOKEN') },
      })
    )
}

/**
 * Verify that the list of groups is correct.
 *
 * @param {Array} groups - List of groups
 */
const verifySwitchGroupsList = (groups) => {
  // Create a list of names of the groups of the user
  const listOfGroups = Object.values(groups).map((group) => group.template.name)

  // Click groups menu
  cy.getBySel('header-group-button').click()

  // Verify groups
  listOfGroups.forEach((group) => {
    cy.get('#group-list').should('contain', group)
  })
}

/**
 * Switch the group of an user.
 *
 * @param {object} user - User used to switch between groups.
 * @param {object} group - Group to switch.
 * @param {object} templateToFind - Template that the user has to see after the switched.
 * @param {object} templateNotToFind - Template that the user has not to see after the switched.
 * @param {object} showOptions - Show views
 * @param {boolean} showOptions.showAll - Change to Show all view
 * @param {boolean} showOptions.showUserGroup - Change to Show all owned by the user or his groups view
 * @param {boolean} showOptions.showUser - Change to Show all owned by the user view
 */
const switchGroup = (
  user,
  group,
  templateToFind,
  templateNotToFind,
  { showAll = false, showUserGroup = false, showUser = false } = {}
) => {
  // Switch user to group
  cy.switchGroup(user, group, showAll, showUserGroup, showUser)

  // Validate that the user see the correct templates if he switch the group
  cy.validateGroupTemplates(templateToFind, templateNotToFind)
}

/**
 * Create groups and user to use in the switch view tests.
 *
 * @param {object} infoSwitchViewTests - Resources to create for switch view tests
 */
const beforeAllSwitchViewTests = (infoSwitchViewTests) => {
  const groupView = infoSwitchViewTests.groupView
  const userView = infoSwitchViewTests.userView

  cy.fixture('auth')
    .then((auth) => cy.apiAuth(auth.admin))
    .then(() => {
      cy.cleanup({
        groups: {
          NAMES: [groupView.template.name],
        },
        users: {
          NAMES: [userView.template.name],
        },
      })
    })
    .then(() => groupView.group.allocate(groupView.template.name))
    .then(() => {
      userView.user.allocate({
        ...userView.user.template,
        group: [groupView.group.id],
      })
    })
    .then(() => {})
}

/**
 * Delete all the resources used in switch view tests.
 *
 * @param {object} infoSwitchViewTests - Resources to create for swtich view tests
 */
const afterSwitchViewTests = (infoSwitchViewTests) => {
  const group = infoSwitchViewTests.groupView
  const user = infoSwitchViewTests.userView

  cy.fixture('auth')
    .then((auth) => cy.apiAuth(auth.admin))
    .then(() => {
      cy.cleanup({
        groups: {
          NAMES: [group.template.name, group.template.name],
        },
        users: {
          NAMES: [user.template.name],
        },
      })
    })
}

/**
 * Auth the user to use in switch view tests.
 *
 * @param {object} user - User to log
 */
const beforeEachSwitchViewTest = (user) => {
  cy.fixture('auth')
    .then((auth) => {
      auth.user.username = user.username
      auth.user.password = user.password
      cy.wrapperAuth(auth)
    })
    .then(() =>
      cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
        qs: { externalToken: Cypress.env('TOKEN') },
      })
    )
}

/**
 * Verify that the list of views is correct.
 *
 * @param {Array} views - List of views
 */
const verifySwitchViewsList = (views) => {
  // Click views menu
  cy.getBySel('header-view-button').click()

  // Verify groups
  views.forEach((group) => {
    cy.get('#view-list').should('contain', group)
  })
}

/**
 * Switch the view of an user.
 *
 * @param {object} view - View to switch.
 * @param {Array} menuItemsToFind - Menu items that the user has to see after the switched.
 * @param {Array} menuItemsNotToFind - Menu items that the user has not to see after the switched.
 */
const switchView = (view, menuItemsToFind, menuItemsNotToFind) => {
  // Switch view to user
  cy.switchView(view)

  // Validate that the user see the correct templates if he switch the group
  cy.validateMenuItems(menuItemsToFind, menuItemsNotToFind)
}

export {
  groupGUI,
  groupGUIAndValidate,
  groupInfoTab,
  updateGroupGUIAndValidate,
  validateAdminGroupViews,
  validateUserViews,
  groupTabs,
  groupQuota,
  deleteAdminsGroupGUIAndValidate,
  addAdminsGroupGUIAndValidate,
  groupDelete,
  beforeAllSwitchGroupTests,
  beforeEachSwitchGroupTest,
  switchGroup,
  afterSwitchGroupTests,
  verifySwitchGroupsList,
  beforeAllSwitchViewTests,
  afterSwitchViewTests,
  beforeEachSwitchViewTest,
  verifySwitchViewsList,
  switchView,
}
