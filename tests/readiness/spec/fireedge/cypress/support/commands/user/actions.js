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

import { FORCE } from '@support/commands/constants'
import { fillUserGUI } from '@support/commands/user/create'
import {
  User as UserDocs,
  Group,
  QuotaTypes,
} from '@support/commands/user/jsdocs'
import { Intercepts, createIntercept } from '@support/utils'

/**
 * Deletes a user.
 *
 */
const deleteUser = () => {
  const interceptDelete = createIntercept(Intercepts.SUNSTONE.USER_DELETE)

  cy.getBySel('action-user_delete').click(FORCE)

  cy.getBySel(`modal-delete`)
    .should('exist')
    .then(($dialog) => {
      cy.wrap($dialog).find(`[data-cy=dg-accept-button]`).click(FORCE)

      return cy
        .wait(interceptDelete)
        .its('response.statusCode')
        .should('eq', 200)
    })
}

/**
 * Locks/Disables a user.
 *
 * @param {UserDocs} [user={}] - The user to lock
 * @returns {void} - No return value
 */
const lockUser = (user = {}) => {
  const interceptLock = createIntercept(Intercepts.SUNSTONE.USER_LOCK)

  cy.getBySel('action-user_disable')
    .click(FORCE)
    .then(() => {
      validateInfoTab({
        id: user.json.ID,
        username: user.json.NAME,
        state: 'No',
      })
    })

  return cy.wait(interceptLock).its('response.statusCode').should('eq', 200)
}

/**
 * Unlocks/Enables a user.
 *
 * @param {UserDocs} [user={}] - The user to unlock
 * @returns {void} - No return value
 */
const unlockUser = (user = {}) => {
  const interceptUnlock = createIntercept(Intercepts.SUNSTONE.USER_UNLOCK)

  cy.getBySel('action-user_enable')
    .click(FORCE)
    .then(() => {
      validateInfoTab({
        id: user.json.ID,
        username: user.json.NAME,
        state: 'Yes',
      })
    })

  return cy.wait(interceptUnlock).its('response.statusCode').should('eq', 200)
}

/**
 * Creates a new user via GUI.
 *
 * @param {UserDocs} user - The user to create
 * @returns {void} - No return value
 */
const userGUI = (user) => {
  const interceptUserAllocate = createIntercept(Intercepts.SUNSTONE.USER_CREATE)

  cy.getBySel('action-create_dialog').click()

  fillUserGUI(user)

  cy.getBySel('stepper-next-button').click(FORCE)

  return cy
    .wait(interceptUserAllocate)
    .its('response.statusCode')
    .should('eq', 200)
}

/**
 * Validates the information tab of a user.
 *
 * @param {object} params - Parameters
 * @param {number} params.id - User ID
 * @param {string} params.username - Username
 * @param {string} params.state - User state
 */
const validateInfoTab = ({ id, username, state }) => {
  cy.navigateTab('info').within(() => {
    cy.getBySel('id').should('have.text', id)
    cy.getBySel('name').should('have.text', username)
    cy.getBySel('state').should('have.text', state)
  })
}

/**
 * Validates the user information.
 *
 * @param {UserDocs} user - The user to validate
 */
const validateUserInfo = (user) => {
  validateInfoTab(user)
}

/**
 * Validates the loading of the user sub-tabs.
 *
 * @param {string[]} tabs - The tabs to validate
 */
const validateUserTabs = (tabs) => {
  tabs.forEach((tabName) => {
    cy.navigateTab(tabName).should('exist').and('be.visible')
  })
}

/**
 * Validates the groups of a user.
 *
 * @param {object} params - Parameters
 * @param {Group} params.primaryGroup - Primary group ID
 * @param {Group[]} params.secondaryGroups - Array of secondary group IDs
 */
const validateUserGroups = ({ primaryGroup, secondaryGroups }) => {
  cy.navigateTab('group').within(() => {
    cy.apiGetGroup(primaryGroup).then((group) => {
      cy.getBySel('primary-group').should('have.text', group.NAME)
    })

    secondaryGroups.forEach((id, index) => {
      cy.apiGetGroup(id).then((group) => {
        cy.getBySel(`secondary-group-${index}`).should('have.text', group.NAME)
      })
    })
  })
}

/**
 * Validates the quota of a user.
 *
 * @param {QuotaTypes} params - Parameters
 * @param {number} params.quotaValue - Quota value
 * @param {string} params.quotaResourceIds - Quota resource IDs
 * @param {string} params.quotaType - Type of quota
 * @param {string[]} params.quotaIdentifiers - Quota identifiers
 * @returns {void} - No return value
 */
const validateUserQuota = ({
  quotaValue,
  quotaResourceIds,
  quotaType,
  quotaIdentifiers,
}) => {
  const interceptQuota = createIntercept(Intercepts.SUNSTONE.USER_QUOTA_UPDATE)

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
 * Changes the authentication driver and password of a user.
 *
 * @param {string} id - User ID
 * @param {string} authDriver - Primary group ID
 * @param {string} password - Array of secondary group IDs
 */
const changeAuth = (id, authDriver, password) => {
  const interceptChauth = createIntercept(Intercepts.SUNSTONE.USER_CHAUTH)

  cy.navigateTab('authentication')
    .within(() => {
      cy.selectMUIDropdownOption('auth-driver-selector', authDriver).then(
        () => {
          cy.getBySel('auth-password-input')
            .click()
            .type(password)
            .then(() => {
              cy.getBySel('auth-save').click()
            })
        }
      )
    })
    .then(() => {
      cy.getBySel('refresh').click()
    })
    .then(() => {
      cy.getBySel(`auth-driver-${id}`).should('have.text', authDriver)
    })

  cy.wait(interceptChauth).its('response.statusCode').should('eq', 200)
}

Cypress.Commands.add('userGUI', userGUI)
Cypress.Commands.add('deleteUser', deleteUser)
Cypress.Commands.add('validateInfoTab', validateInfoTab)
Cypress.Commands.add('validateUserInfo', validateUserInfo)
Cypress.Commands.add('validateUserTabs', validateUserTabs)
Cypress.Commands.add('validateUserGroups', validateUserGroups)
Cypress.Commands.add('validateUserQuota', validateUserQuota)
Cypress.Commands.add('lockUser', lockUser)
Cypress.Commands.add('unlockUser', unlockUser)
Cypress.Commands.add('changeAuth', changeAuth)
