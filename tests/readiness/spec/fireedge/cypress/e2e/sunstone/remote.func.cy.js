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
// import { User } from '@models'
//
// const CREDENTIAL_REMOTE_USER = 'remote-user:opennebula'
// const [user, pass] = CREDENTIAL_REMOTE_USER.split(':')
// const USER_REMOTE = new User(user, pass)
// const URL = 'https://www.google.com'
//
// describe('Sunstone GUI server', function () {
//   before(function () {
//     cy.fixture('auth')
//       .then((auth) => cy.apiAuth(auth.admin))
//       .then(() => USER_REMOTE.allocate({ driver: 'public' }))
//       .then(() => cy.getFireedgeServerConf())
//       .then((config) => {
//         const { auth, ...restConfig } = config
//         cy.updateFireedgeServerConf({
//           ...restConfig,
//           auth: 'remote',
//           auth_redirect: URL,
//         })
//       })
//       .then(() => cy.apiSunstoneConf())
//   })
//
//   after(function () {
//     cy.restoreFireedgeServerConf()
//   })
//
// Temporarily disabled, needs redesign
// it('Should login when have REMOTE AUTH', function () {
//   cy.validateLogInRemoteAuth(CREDENTIAL_REMOTE_USER).then(() =>
//     cy.get('[data-cy=header-user-button]').should('have.text', user)
//   )
// })
//
//   it('Should go to remote redirect when have REMOTE AUTH', function () {
//     cy.visit({
//       url: `${Cypress.config('baseUrl')}/sunstone`,
//     })
//     cy.get('[data-cy=login-button]').should('be.visible').click()
//     cy.url({ timeout: Cypress.config('baseUrl') * 2 }).should('contains', URL)
//   })
//
//   it('Should login when have OPENNEBULA AUTH', function () {
//     cy.restoreFireedgeServerConf()
//       .then(() => cy.validateLogInFormRemoteAuth(CREDENTIAL_REMOTE_USER))
//       .then(() => {
//         cy.get('[data-cy=login-user]').should('be.visible')
//         cy.get('[data-cy=login-token]').should('be.visible')
//         cy.get('[data-cy=login-button]').should('be.visible')
//       })
//   })
// })
