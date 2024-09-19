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

describe('Sunstone GUI in Settings Tab (TFA)', function () {
  // eslint-disable-next-line mocha/no-hooks-for-single-case
  before(function () {
    cy.fixture('auth').then((auth) => cy.apiAuth(auth.admin))
  })

  // eslint-disable-next-line mocha/no-hooks-for-single-case
  beforeEach(function () {
    cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
      qs: { externalToken: Cypress.env('TOKEN') },
    })
  })

  it('Should Manipulate 2FA', function () {
    cy.manipulate2Fa().its('response.body.id').should('eq', 200)
  })
})
