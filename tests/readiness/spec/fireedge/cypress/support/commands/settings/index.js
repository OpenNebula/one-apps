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
import { Decoder } from '@nuintun/qrcode'
import { FORCE } from '@support/commands/constants'
import { createIntercept, Intercepts } from '@support/utils'
import { URI } from 'otpauth'

const decodeQR = new Decoder()

const changeSSHSettings = (setting, value) => {
  cy.navigateMenu(null, 'settings')

  const intercept = createIntercept(Intercepts.SUNSTONE.USER_UPDATE)

  cy.getBySel(`settings-ui-${setting}`).find('button').click()

  cy.getBySel(`settings-ui-text-${setting}`).clear().type(value).type('{enter}')

  return cy.wait(intercept)
}

const changeSettingUISelector = (
  uiSelector,
  value,
  settingsTabName = 'settings'
) => {
  cy.navigateMenu(null, settingsTabName)

  const intercept = createIntercept(Intercepts.SUNSTONE.USER_UPDATE)

  cy.getBySel(`settings-ui-${uiSelector}`).then(({ selector }) => {
    cy.get(selector)
      .click()
      .then(() => {
        cy.document().then((doc) => {
          cy.wrap(doc?.body)
            .find('.MuiAutocomplete-option')
            .each(($el) => {
              if (
                value?.toLowerCase() ===
                  $el?.attr('data-value')?.toLowerCase() ||
                value === $el?.text()
              ) {
                cy.wrap($el).click()

                return false // Break
              }
            })
        })
      })
  })

  return cy.wait(intercept)
}

const validateLogoChange = (LOGO, { shouldFail = false }) => {
  const intercept = createIntercept(Intercepts.SUNSTONE.LOGO)

  cy.reload()

  return cy
    .wait(intercept)
    .then(({ response }) => {
      if (shouldFail) {
        expect(response?.body?.id).to.eq(404)
      } else {
        expect(response?.body?.id).to.eq(200)
        if (!LOGO) {
          expect(response?.body).to.not.have.property('data')
        } else {
          expect(response?.body?.data?.logoName).to.eq(LOGO)
        }
      }
    })
    .then(() => {
      if (!shouldFail && LOGO) {
        cy.reload()
        cy.wait(intercept).then(({ response }) => {
          // Should be unmodified
          const statusCode = response?.body?.id ?? response?.statusCode
          expect(statusCode).to.eq(304)
        })
      }
    })
}

const changeLoginToken = (expire, egid, settingsTabName = 'settings') => {
  cy.navigateMenu(null, settingsTabName)

  const intercept = createIntercept(Intercepts.SUNSTONE.USER_LOGIN)

  cy.getBySel('logintoken-ui-EXPIRE').clear().type(expire)
  cy.getBySel('logintoken-ui-EGID').then(({ selector }) => {
    cy.get(selector)
      .click()
      .then(() => {
        cy.document().then((doc) => {
          cy.wrap(doc?.body)
            .find('.MuiAutocomplete-option')
            .each(($el) => {
              if (
                egid?.toLowerCase() ===
                  $el?.attr('data-value')?.toLowerCase() ||
                egid === $el?.text()
              ) {
                cy.wrap($el).click()

                return false // Break
              }
            })
        })
      })
  })

  cy.getBySel('addLoginToken').click(FORCE)

  return cy.wait(intercept)
}

const toggleAnimations = (settingsTabName = 'settings') => {
  cy.navigateMenu(null, settingsTabName)

  const intercept = createIntercept(Intercepts.SUNSTONE.USER_UPDATE)

  cy.getBySel('settings-ui-DISABLE_ANIMATIONS').click()

  cy.wait(intercept)
}

const addUserLabels = (labels) => {
  cy.navigateMenu(null, 'settings')

  const intercept = createIntercept(Intercepts.SUNSTONE.USER_UPDATE)

  const allCreations = labels.map((label) => () => {
    cy.getBySel('new-label').type(`${label}{enter}`)
    cy.wait(intercept)

    // checks if the label is created on the UI
    return cy.getBySel(label).should('have.text', label)
  })

  return cy.all(...allCreations).then((responses) => [responses].flat())
}

const removeUserLabels = (labels) => {
  cy.navigateMenu(null, 'settings')

  const intercept = createIntercept(Intercepts.SUNSTONE.USER_UPDATE)

  const allDeletions = labels.map((label) => () => {
    cy.getBySel('new-label').clear().type(`${label}`)
    cy.getBySel(`delete-label-${label}`).click()
    cy.wait(intercept)

    // checks if the label is created on the UI
    return cy.getBySel(label).should('not.exist')
  })

  return cy.all(...allDeletions).then((responses) => [responses].flat())
}

const manipulate2Fa = () => {
  cy.navigateMenu(null, 'settings')

  const keyAdd = 'addTfa'
  const keyDelete = 'removeTfa'
  const keySetToken = '2fa-ui-TOKEN'

  const interceptEnable = createIntercept(Intercepts.SUNSTONE.USER_ENABLE_2FA)
  const interceptDisable = createIntercept(Intercepts.SUNSTONE.USER_DISABLE_2FA)
  cy.getBySel(keyAdd).scrollIntoView().click(FORCE)

  return cy
    .getBySel('qrTfa')
    .should('be.visible')
    .invoke('attr', 'src')
    .then((src) => decodeQR.scan(src))
    .then(({ data = '' }) => URI.parse(data).generate())
    .then((secret) => {
      cy.getBySel(keySetToken).clear().type(secret)
      cy.getBySel(keyAdd).click(FORCE)
    })
    .then(() => cy.wait(interceptEnable))
    .then(() => cy.getBySel(keyDelete).scrollIntoView().click(FORCE))
    .then(() => cy.wait(interceptDisable))
}

const changeUserPassword = (user, newPassword, disabled = false) => {
  // Create interceptors
  const interceptChangePassword = createIntercept(
    Intercepts.SUNSTONE.USER_CHANGE_PASSWORD
  )

  // Navigate to settings
  cy.navigateMenu(null, 'settings')

  if (disabled) {
    // Check button change password is disabled
    cy.getBySelLike('change-password-button').should('be.disabled')
  } else {
    // Click on the change password button
    cy.getBySel('change-password-button').click()

    // Fill password
    cy.getBySel('form-dg-password').clear().type(newPassword)
    cy.getBySel('form-dg-confirmPassword').type(newPassword)

    // Accept form
    cy.getBySel('dg-accept-button').click()

    // Wait for the response
    cy.wait(interceptChangePassword)

    // Log out and log in again with the new password
    cy.logout()
    cy.login(
      {
        username: user.credentials.username,
        password: newPassword,
      },
      '/sunstone'
    )
  }
}

const toggleInfoFullScreen = (settingsTabName = 'settings') => {
  cy.navigateMenu(null, settingsTabName)

  const intercept = createIntercept(Intercepts.SUNSTONE.USER_UPDATE)

  cy.getBySel('settings-ui-FULL_SCREEN_INFO').click()

  cy.wait(intercept)
}

Cypress.Commands.add('changeSSHSettings', changeSSHSettings)
Cypress.Commands.add('changeSettingUISelector', changeSettingUISelector)
Cypress.Commands.add('toggleAnimations', toggleAnimations)
Cypress.Commands.add('addUserLabels', addUserLabels)
Cypress.Commands.add('removeUserLabels', removeUserLabels)
Cypress.Commands.add('changeLoginToken', changeLoginToken)
Cypress.Commands.add('manipulate2Fa', manipulate2Fa)
Cypress.Commands.add('validateLogoChange', validateLogoChange)
Cypress.Commands.add('changeUserPassword', changeUserPassword)
Cypress.Commands.add('toggleInfoFullScreen', toggleInfoFullScreen)
