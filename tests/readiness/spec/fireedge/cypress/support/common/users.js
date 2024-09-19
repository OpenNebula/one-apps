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
 * Deletes a user.
 *
 * @param {object} user - User template.
 */
const userDelete = (user) => {
  if (user.id === undefined) return
  cy.navigateMenu('system', 'Users')
  cy.clickUserRow({ id: user.id }).then(() => {
    cy.deleteUser().then(() => {
      cy.getUserTable({ search: user.name }).within(() => {
        cy.get(`[role='row'][data-cy$='${user.id}']`).should('not.exist')
      })
    })
  })
}

/**
 * Validates user information.
 *
 * @param {object} user - User template.
 * @param {object} row - Holds user ID property.
 */
const userInfo = (user, row) => {
  if (row.id === undefined) return
  cy.navigateMenu('system', 'Users')
  cy.clickUserRow(row).then(() => {
    cy.validateUserInfo({ ...user, id: row.id })
  })
}

/**
 * Creates a new user via GUI.
 *
 * @param {object} user - User template.
 */
const userGUI = (user) => {
  cy.navigateMenu('system', 'Users')
  cy.userGUI(user)
}

/**
 * Validates user tabs.
 *
 * @param {object} user - User template.
 * @param {string[]} tabs - Array of sub-tab names to validate.
 */
const userTabs = (user, tabs) => {
  cy.navigateMenu('system', 'Users')
  cy.clickUserRow({ id: user.id }).then(() => {
    cy.validateUserTabs(tabs)
  })
}

/**
 * Validates user groups.
 *
 * @param {object} user - User template.
 */
const userGroups = (user) => {
  cy.navigateMenu('system', 'Users')
  cy.clickUserRow({ id: user.id }).then(() => {
    const { GROUPS } = user.json
    const groupIds = Array.isArray(GROUPS.ID) ? GROUPS.ID : [GROUPS.ID]

    const [primaryGroup, ...secondaryGroups] = groupIds

    cy.validateUserGroups({ primaryGroup, secondaryGroups })
  })
}

/**
 * Validates user quota.
 *
 * @param {object} user - User template.
 * @param {object} quota - Quota config.
 */
const userQuota = (user, quota) => {
  cy.navigateMenu('system', 'Users')
  cy.clickUserRow({ id: user.id }).then(() => {
    cy.validateUserQuota(quota)
  })
}

/**
 * Locks a user.
 *
 * @param {object} user - User template.
 */
const userLock = (user) => {
  cy.navigateMenu('system', 'Users')
  cy.clickUserRow({ id: user.id }).then(() => {
    cy.lockUser(user)
  })
}

/**
 * Unlocks a user.
 *
 * @param {object} user - User template.
 */
const userUnlock = (user) => {
  cy.navigateMenu('system', 'Users')
  cy.clickUserRow({ id: user.id }).then(() => {
    cy.unlockUser(user)
  })
}

/**
 * Validates the change of a users authentication driver and password.
 *
 * @param {object} user - User template.
 * @param {string} authDriver - Select authentiaction driver.
 * @param {string} password - New password.
 */
const userAuthUpdate = (user, authDriver, password) => {
  cy.navigateMenu('system', 'Users')
  cy.clickUserRow({ id: user.id }).then(() => {
    cy.changeAuth(user.id, authDriver, password)
  })
}

module.exports = {
  userGUI,
  userDelete,
  userInfo,
  userTabs,
  userGroups,
  userQuota,
  userLock,
  userUnlock,
  userAuthUpdate,
}
