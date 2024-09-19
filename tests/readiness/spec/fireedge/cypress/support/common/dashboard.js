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

const { userKey } = require('@utils/constants')
const { User } = require('@models')

/**
 * Go from sunstone to provision tests.
 */
const goFromSunstoneToOneProvision = () => {
  // from Sunstone => OneProvision
  cy.visit(`${Cypress.config('baseUrl')}/sunstone`)
  cy.getBySel('goto-provision').click()
  cy.url().should('include', '/provision')

  // from OneProvision => Sunstone
  cy.getBySel('goto-sunstone').click()
  cy.url().should('include', '/sunstone')
}

/**
 * Log in by single signon method.
 *
 * @param {object} defaults - config
 */
const loginBySingleSignOnMethod = (defaults) => {
  const { jwtName } = defaults

  cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
    qs: { externalToken: Cypress.env('TOKEN') },
  })

  cy.window().its(`localStorage.${jwtName}`).should('eq', Cypress.env('TOKEN'))

  cy.logout()
}

/**
 * Multiple Login with the same user.
 *
 * @param {object} auth - config
 */
const multipleLoginWithTheSameUser = (auth) => {
  const oneUser = Cypress.env(userKey) ? auth.user : auth.admin

  cy.login(oneUser)
  cy.task('externalBrowserLogin', {
    auth,
    cypress: Cypress.config(),
    isUser: !!Cypress.env(userKey),
  }).then((jwt) => {
    // eslint-disable-next-line no-unused-expressions
    expect(jwt).to.not.be.empty
    cy.window()
      .its('localStorage')
      .invoke('getItem', auth.jwtName)
      .then((mainJWT) => {
        cy.navigateMenu('instances', 'VMs')
        expect(mainJWT).to.equal(jwt)
      })
  })
}

/**
 * Check sunstone header has username.
 *
 * @param {object} auth - config
 */
const checkSunstoneHeaderHasUsername = (auth) => {
  const oneUser = Cypress.env(userKey) ? auth.user : auth.admin

  cy.login(oneUser)
  cy.get('[data-cy=header-user-button]').should('have.text', oneUser.username)
}

/**
 * Login with tow factor authentication.
 *
 * @param {object} auth - config
 */
const loginWith2FA = (auth) => {
  const oneUser = auth
  const { username, password } = oneUser
  const user = new User(username, password)
  user
    .getqr()
    .then(() => user.getAuthCode())
    .then((secretKey) => user.set2fa(secretKey))
    .then(() => user.getAuthCode())
    .then((secretKey) => cy.login({ ...oneUser, tfa: secretKey }))
    .then(() => user.delete2fa())
    .then((data) => {
      expect(data?.id).to.eq(200)
      expect(data?.message).to.eq('OK')
    })
    .then(() => cy.logout())
}

module.exports = {
  goFromSunstoneToOneProvision,
  loginBySingleSignOnMethod,
  multipleLoginWithTheSameUser,
  checkSunstoneHeaderHasUsername,
  loginWith2FA,
}
