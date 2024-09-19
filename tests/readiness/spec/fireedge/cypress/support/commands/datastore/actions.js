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
  configSelectDatastore,
  configChangeOwnership,
} from '@support/commands/datastore/jsdocs'
import { createIntercept, Intercepts } from '@support/utils'
import { FORCE } from '@support/commands/constants'

/**
 * Enables/Disables a datastore.
 *
 * @param {string} action - action
 * @returns {function(configSelectDatastore):Cypress.Chainable<Cypress.Response>} change image response
 */
const enableDatastore =
  (action) =>
  (datastore = {}) => {
    const getEnableDatastore = createIntercept(
      Intercepts.SUNSTONE.DATASTORE_ENABLE
    )

    const getDatastoreInfo = createIntercept(Intercepts.SUNSTONE.DATASTORE)

    cy.clickDatastoreRow(datastore)

    cy.getBySel('action-datastore-options').click(FORCE)
    cy.getBySel(`action-${action}`).click(FORCE)

    cy.getBySel(`modal-${action}`)
      .should('exist')
      .then(($dialog) => {
        cy.wrap($dialog).find(`[data-cy=dg-accept-button]`).click(FORCE)

        return cy.wait([getEnableDatastore, getDatastoreInfo])
      })
  }

/**
 * Change ownership of a adatastore.
 *
 * @param {string} action - action
 * @returns {function(configChangeOwnership):Cypress.Chainable<Cypress.Response>} change host state response
 */
const changeOwnership =
  (action) =>
  ({ datastore = {}, resource = '' }) => {
    const getChangeOwn = createIntercept(
      Intercepts.SUNSTONE.DATASTORE_CHANGE_OWN
    )
    const getDatastoreInfo = createIntercept(Intercepts.SUNSTONE.DATASTORE)
    const isChangeUser = action === 'chown'

    cy.clickDatastoreRow(datastore)

    cy.getBySel('action-datastore-ownership').click(FORCE)
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

        return cy.wait([getChangeOwn, getDatastoreInfo])
      })
  }

const validateDatastoreState = (state) => {
  cy.navigateTab('info').within(() => {
    state instanceof RegExp
      ? cy.getBySel('state').invoke('text').should('match', state)
      : cy.getBySel('state').should('have.text', state)
  })
}

/**
 * Delete datastore.
 *
 * @param {configSelectDatastore} datastore - Datastore to delete
 */
const deleteDatastore = (datastore = {}) => {
  const interceptDelete = createIntercept(Intercepts.SUNSTONE.DATASTORE_DELETE)

  cy.clickDatastoreRow(datastore)
  cy.getBySel('action-datastore-delete').click(FORCE)

  cy.getBySel(`modal-delete`)
    .should('exist')
    .then(($dialog) => {
      cy.wrap($dialog).find('[data-cy=dg-accept-button]').click(FORCE)

      return cy.wait(interceptDelete)
    })
}

Cypress.Commands.add('validateDatastoreState', validateDatastoreState)
Cypress.Commands.add('enableDatastore', enableDatastore('enable'))
Cypress.Commands.add('disableDatastore', enableDatastore('disable'))
Cypress.Commands.add('changeOwnerDatastore', changeOwnership('chown'))
Cypress.Commands.add('changeGroupDatastore', changeOwnership('chgrp'))
Cypress.Commands.add('deleteDatastore', deleteDatastore)
