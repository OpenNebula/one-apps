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
let supportTicket
let supportData

describe('Sunstone GUI in Support Tab', function () {
  before(function () {
    cy.fixture('support')
      .then((support) => (supportData = support))
      .then(() => cy.getFSunstoneServerConf())
      .then((config) =>
        cy.updateFSunstoneServerConf({
          ...config,
          token_remote_support: supportData.token,
        })
      )
      .then(() => cy.restartServer())
  })

  after(function () {
    cy.restoreFSunstoneServerConf().then(() => cy.restartServer())
  })

  beforeEach(function () {
    cy.fixture('auth').then((auth) => {
      cy.visit(`${Cypress.config('baseUrl')}/sunstone`)
      cy.login(auth.admin)
    })
  })

  it('Should show "Officially support" in footer', function () {
    cy.getBySel('officialSupport').should('exist')
  })

  it('Should login in SUPPORT tab', function () {
    cy.fixture('support').then(({ email = '', pass = '' }) => {
      cy.loginSupportChat(email, pass).its('response.body.id').should('eq', 200)
    })
  })

  it('Should create a ticket SUPPORT tab', function () {
    cy.fixture('support').then(({ email = '', pass = '', ...message }) => {
      cy.loginSupportChat(email, pass)
        .then(() => cy.createSupportTicket(message))
        .then((interception) => {
          supportTicket = interception?.response?.body?.data?.id
          cy.wrap(interception.response.body.id).should('eq', 200)
        })
    })
  })

  it('Should solve a ticket SUPPORT tab', function () {
    if (!supportTicket) return

    cy.fixture('support').then(
      ({ email = '', pass = '', subject = '', commentSolved = '' }) => {
        cy.loginSupportChat(email, pass)
          .then(() =>
            cy.solvedSupportTicket(subject, supportTicket, commentSolved)
          )
          .its('response.body.id')
          .should('eq', 200)
      }
    )
  })
})
