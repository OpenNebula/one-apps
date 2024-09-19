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
import {
  configSelectMarketApp,
  configChangeOwnership,
} from '@support/commands/marketapp/jsdocs'
import { createIntercept, Intercepts } from '@support/utils'
import { FORCE } from '@support/commands/constants'

/**
 * Change ownership template.
 *
 * @param {string} action - action
 * @returns {function(configChangeOwnership):Cypress.Chainable<Cypress.Response>} change host state response
 */
const changeOwnership =
  (action) =>
  ({ marketapp = {}, resource = '' }) => {
    const getChangeOwn = createIntercept(
      Intercepts.SUNSTONE.MARKETAPP_CHANGE_OWN
    )
    const getTemplateInfo = createIntercept(Intercepts.SUNSTONE.MARKETAPP)
    const isChangeUser = action === 'chown'

    cy.clickMarketAppRow(marketapp)

    cy.getBySel('action-marketapp-ownership').click(FORCE)
    cy.getBySel(`action-${action}`).click(FORCE)

    cy.getBySel(`modal-${action}`)
      .should('exist')
      .then(($dialog) => {
        if (isChangeUser) {
          cy.getUserRow(resource).click(FORCE)
        } else {
          cy.getGroupRow(resource).click(FORCE)
        }

        cy.wrap($dialog).find(`[data-cy=dg-accept-button]`).click(FORCE)

        return cy.wait([getChangeOwn, getTemplateInfo])
      })
  }

/**
 * Change disable marketapp.
 *
 * @param {boolean} enable - enable
 * @returns {function(configSelectMarketApp):Cypress.Chainable<Cypress.Response>} change marketapp response
 */
const enableMarketapp =
  (enable) =>
  (marketapp = {}) => {
    const getEnableMarketapp = createIntercept(
      Intercepts.SUNSTONE.MARKETAPP_ENABLE
    )
    const getMarketappInfo = createIntercept(Intercepts.SUNSTONE.MARKETAPP)

    const action = enable ? 'enable' : 'disable'
    cy.clickMarketAppRow(marketapp)

    cy.getBySel('action-marketapp-enable').click(FORCE)
    cy.getBySel(`action-${action}`).click(FORCE)

    cy.getBySel(`modal-${action}`)
      .should('exist')
      .then(($dialog) => {
        cy.wrap($dialog).find(`[data-cy=dg-accept-button]`).click(FORCE)

        return cy.wait([getEnableMarketapp, getMarketappInfo])
      })
  }

/**
 * Change lock marketapp.
 *
 * @param {boolean} lock - lock
 * @returns {function(configSelectMarketApp):Cypress.Chainable<Cypress.Response>} change marketapp response
 */
const lockMarketapp =
  (lock) =>
  (marketapp = {}) => {
    const getLockMarketapp = createIntercept(
      lock
        ? Intercepts.SUNSTONE.MARKETAPP_LOCK
        : Intercepts.SUNSTONE.MARKETAPP_UNLOCK
    )
    const getMarketappInfo = createIntercept(Intercepts.SUNSTONE.MARKETAPP)

    const action = lock ? 'lock' : 'unlock'
    cy.clickMarketAppRow(marketapp)

    cy.getBySel('action-marketapp-lock').click(FORCE)
    cy.getBySel(`action-${action}`).click(FORCE)

    cy.getBySel(`modal-${action}`)
      .should('exist')
      .then(($dialog) => {
        cy.wrap($dialog).find(`[data-cy=dg-accept-button]`).click(FORCE)

        return cy.wait([getLockMarketapp, getMarketappInfo])
      })
  }

/**
 * Delete marketapp.
 *
 * @param {configSelectMarketApp} marketapp - config lock
 */
const deleteMarketapp = (marketapp = {}) => {
  const interceptDelete = createIntercept(Intercepts.SUNSTONE.MARKETAPP_DELETE)

  cy.clickMarketAppRow(marketapp)
  cy.getBySel('action-delete').click(FORCE)

  cy.getBySel(`modal-delete`)
    .should('exist')
    .then(($dialog) => {
      cy.wrap($dialog).find(`[data-cy=dg-accept-button]`).click(FORCE)

      return cy.wait(interceptDelete)
    })
}

/**
 * Navigate to the screen to show possible datastores to export to the app and verify that all are image datastores.
 *
 * @param {object} marketapp - App to export
 */
const verifyImageDatastoresToExport = (marketapp = {}) => {
  // Select the app
  cy.clickMarketAppRow(marketapp)

  // Click on export button
  cy.getBySel('action-export').click(FORCE)

  // Export modal appears
  cy.getBySel(`modal-export`)
    .should('exist')
    .then(($dialog) => {
      // Click on next button
      cy.wrap($dialog).find(`[data-cy=stepper-next-button]`).click(FORCE)

      // Get all rows of datastore table
      cy.getDatastoreRows().then(($rows) => {
        // Convert all rows to array
        const rows = $rows.toArray()

        // Iterate over each row
        rows.forEach((row) => {
          // Wrap row in a jQuery object
          const $row = Cypress.$(row)

          // Find IMAGE text on the element
          const text = $row.filter(function () {
            // Return if find IMAGE text
            return this.textContent.includes('IMAGE')
          })

          // Expect that IMAGE text was found
          return expect(text.length > 0).to.be.true
        })
      })
    })
}

Cypress.Commands.add('changeOwnerMarketapp', changeOwnership('chown'))
Cypress.Commands.add('changeGroupMarketapp', changeOwnership('chgrp'))
Cypress.Commands.add('enableMarketapp', enableMarketapp(true))
Cypress.Commands.add('disableMarketapp', enableMarketapp(false))
Cypress.Commands.add('lockMarketapp', lockMarketapp(true))
Cypress.Commands.add('unlockMarketapp', lockMarketapp(false))
Cypress.Commands.add('deleteMarketapp', deleteMarketapp)
Cypress.Commands.add(
  'verifyImageDatastoresToExport',
  verifyImageDatastoresToExport
)
