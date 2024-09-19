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

const EXPIRE_TIME = 2 /** Minutes */
const MIN_EXPIRE_TIME = 1 /** Minutes */

// const CURRENCIES = {
//   EUR: '€',
//   USD: '$',
// }

describe('Sunstone GUI server', function () {
  // eslint-disable-next-line mocha/no-hooks-for-single-case
  after(function () {
    cy.restoreFireedgeServerConf(true)
    // cy.restoreFSunstoneServerConf(true)
  })

  it('Should not login with expired JWT', function () {
    cy.getFireedgeServerConf()
      .then((config) =>
        cy.updateFireedgeServerConf({
          ...config,
          session_expiration: EXPIRE_TIME,
          minimun_opennebula_expiration: MIN_EXPIRE_TIME,
        })
      )
      .then(() => cy.restartServer())
      .then(() => cy.fixture('auth'))
      .then((auth) => cy.apiAuth(auth.admin))
      .then(() => cy.apiSunstoneConf())
      .then(() => {
        cy.wait(EXPIRE_TIME * 60000) /** Milliseconds */
        cy.validateExternalTokenRequest()
          .its('response.body.id')
          .should('eq', 401)
          .then(() => cy.validateMessageError())
      })
  })

  // DISABLED UNTIL REVIEWED PROPERLY
  // eslint-disable-next-line mocha/no-setup-in-describe
  // Object.entries(CURRENCIES).forEach(([currency, symbol]) => {
  //   it(`Currency should equal ${symbol}`, function () {
  //     cy.getFSunstoneServerConf()
  //       .then((config) =>
  //         cy.updateFSunstoneServerConf({
  //           ...config,
  //           currency: currency,
  //         })
  //       )
  //       .then(() => cy.restartServer())
  //       .then(() =>
  //         cy.fixture('auth').then((auth) => {
  //           cy.visit(`${Cypress.config('baseUrl')}/sunstone`)
  //           cy.login(auth.admin)
  //         })
  //       )
  //       .then(() => {
  //         cy.visit(`${Cypress.config('baseUrl')}/sunstone/vm-template/create`)
  //         cy.get('input[name="general.MEMORY"').clear().type('1')
  //         cy.get('input[name="general.CPU"').clear().type('1')
  //         cy.get('input[name="general.MEMORY_COST"').clear().type('1')
  //         cy.get('input[name="general.CPU_COST"').clear().type('1')
  //         cy.get('input[name="general.DISK_COST"').clear().type('1')
  //         cy.get('[data-cy="general-showback-MEMORY_COST-error"]', {
  //           timeout: 100000,
  //         }).should('contain', symbol)
  //         cy.get('[data-cy="general-showback-CPU_COST-error"]', {
  //           timeout: 100000,
  //         }).should('contain', symbol)
  //       })
  //   })
  // })
})
