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
import { clickRow, getRow, getTable } from '@commands/datatable'
import { FORCE } from '@support/commands/constants'
import { Intercepts, createIntercept } from '@support/utils'
const MENU = 'Support'

const navigate = () => cy.navigateMenu(null, MENU)

const loginSupportChat = (email, pass) => {
  Cypress.log({
    name: 'login in support chat',
    displayName: 'LOGIN Zendesk',
    message: [`🔐 Authenticating | ${email}`],
    autoEnd: false,
  })

  const interceptLoginSupport = createIntercept(
    Intercepts.SUNSTONE.SUPPORT_LOGIN
  )

  navigate()

  cy.getBySel('login-user').clear().type(email)

  cy.getBySel('login-pass').clear().type(pass)

  cy.getBySel('login-button').click()

  return cy.wait(interceptLoginSupport)
}

const createSupportTicket = (message = {}) => {
  const { subject = '', description = '', severity = '' } = message
  const interceptCreateTicket = createIntercept(
    Intercepts.SUNSTONE.SUPPORT_CREATE_TICKET
  )

  navigate()

  // Click on create ticket
  cy.getBySel('action-support_create_dialog').click(FORCE)
  // Fill inputs
  cy.getBySel('support-SUBJECT').clear().type(subject)
  cy.getBySel('support-BODY').clear().type(description)
  cy.getBySel('support-SEVERITY').then(({ selector }) => {
    cy.get(selector)
      .click()
      .then(() => {
        cy.document().then((doc) => {
          cy.wrap(doc?.body)
            .find('.MuiAutocomplete-option')
            .each(($el) => {
              if (
                severity?.toLowerCase() ===
                  $el?.attr('data-value')?.toLowerCase() ||
                severity === $el?.text()
              ) {
                cy.wrap($el).click()

                return false // Break
              }
            })
        })
      })
  })

  cy.getBySel('stepper-next-button').click()

  return cy.wait(interceptCreateTicket)
}

const solvedSupportTicket = (name, id, comment = '') => {
  const interceptSolvedTicket = createIntercept(
    Intercepts.SUNSTONE.UPDATE_TICKET
  )

  cy.clickSupportRow({ name, id }, { noWait: true })
  cy.getBySel('change-resolution').click(FORCE)
  cy.getBySel('body-resolution').clear().type(comment)
  cy.getBySel('change-resolution').click(FORCE)

  return cy.wait(interceptSolvedTicket)
}

const getSupportTable = getTable({
  datatableCy: 'support',
  searchCy: 'search-support',
  poolIntercept: Intercepts.SUNSTONE.SUPPORT_TICKETS,
})

const getSupportRow = getRow({
  getTableFn: getSupportTable,
  prefixRowId: 'ticket-',
})

const clickSupportRow = clickRow({
  getRowFn: getSupportRow,
  showIntercept: Intercepts.SUNSTONE.BACKUPJOB,
})

Cypress.Commands.add('loginSupportChat', loginSupportChat)
Cypress.Commands.add('createSupportTicket', createSupportTicket)
Cypress.Commands.add('solvedSupportTicket', solvedSupportTicket)
Cypress.Commands.add('getSupportTable', getSupportTable)
Cypress.Commands.add('getSupportRow', getSupportRow)
Cypress.Commands.add('clickSupportRow', clickSupportRow)
