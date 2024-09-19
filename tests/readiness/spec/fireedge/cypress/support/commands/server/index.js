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
import { createIntercept, Intercepts } from '@support/utils'

const validateExternalTokenRequest = () => {
  const getUser = createIntercept(Intercepts.SUNSTONE.USER_INFO)
  cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
    qs: { externalToken: Cypress.env('TOKEN') },
  })

  return cy.wait(getUser)
}
const validateLogInRemoteAuth = (userData = '') => {
  const getUser = createIntercept(Intercepts.SUNSTONE.USER_INFO)
  cy.visit({
    url: `${Cypress.config('baseUrl')}/sunstone`,
    headers: { HTTP_X_AUTH_USERNAME: userData },
  })

  return cy.wait(getUser)
}
const validateLogInFormRemoteAuth = (userData = '') =>
  cy.visit({
    url: `${Cypress.config('baseUrl')}/sunstone`,
    headers: { HTTP_X_AUTH_USERNAME: userData },
  })

const validateMessageError = () => cy.getBySel('error-text').should('exist')

Cypress.Commands.add(
  'validateExternalTokenRequest',
  validateExternalTokenRequest
)
Cypress.Commands.add('validateLogInRemoteAuth', validateLogInRemoteAuth)
Cypress.Commands.add('validateMessageError', validateMessageError)
Cypress.Commands.add('validateLogInFormRemoteAuth', validateLogInFormRemoteAuth)
