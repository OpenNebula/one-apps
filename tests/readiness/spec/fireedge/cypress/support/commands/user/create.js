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

import { User as UserDocs } from '@support/commands/user/jsdocs'

/**
 * Fills in the configuration settings for a user.
 *
 * @param {UserDocs} user - The user whose configuration settings are to be filled
 */
const fillConfiguration = (user) => {
  const { username, authType, password } = user

  username && cy.getBySel('general-username').clear().type(username)

  authType &&
    cy
      .getBySel('general-authType')

      .then(({ selector }) => {
        cy.get(selector)
          .click()
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    authType?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    authType === $el?.text()
                  ) {
                    cy.wrap($el).click()

                    return false // Break
                  }
                })
            })
          })
      })

      .should('have-value', authType)
  password && cy.getBySel('general-password').clear().type(password)
  password && cy.getBySel('general-confirmPassword').clear().type(password)
}

/**
 * Fills in the primary group for a user.
 *
 * @param {UserDocs} user - The user whose primary group is to be filled
 */
const fillPrimaryGroup = (user) => {
  const { primaryGroup } = user
  if (primaryGroup !== undefined) {
    cy.clickGroupRow(primaryGroup, { noWait: true })
  }
}

/**
 * Fills in the secondary group for a user.
 *
 * @param {UserDocs} user - The user whose secondary group is to be filled
 */
const fillSecondaryGroup = (user) => {
  const { secondaryGroup } = user
  if (secondaryGroup !== undefined) {
    cy.clickGroupRow(secondaryGroup, { noWait: true })
  }
}

/**
 * Fills in the GUI settings for a user.
 *
 * @param {UserDocs} user - The user whose GUI settings are to be filled
 */
const fillUserGUI = (user) => {
  cy.getBySel('main-layout').click()

  fillConfiguration(user)
  cy.getBySel('stepper-next-button').click()
  fillPrimaryGroup(user)
  cy.getBySel('stepper-next-button').click()
  fillSecondaryGroup(user)
  cy.getBySel('stepper-next-button').click()
}

export { fillConfiguration, fillPrimaryGroup, fillSecondaryGroup, fillUserGUI }
