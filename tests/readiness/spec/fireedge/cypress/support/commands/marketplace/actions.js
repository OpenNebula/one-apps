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
import { Intercepts, createIntercept } from '@support/utils'

import { fillMarketplaceGUI } from '@support/commands/marketplace/create'
import Marketplace from '@support/models/marketplace'

/**
 * Creates a new marketplace via GUI.
 *
 * @param {object} marketplace - The marketplace to create
 * @returns {void} - No return value
 */
const marketplaceGUI = (marketplace) => {
  // Create interceptor for each request that is used on create a marketplace
  const interceptMarketplaceAllocate = createIntercept(
    Intercepts.SUNSTONE.MARKET_ALLOCATE
  )

  // Click on create button
  cy.getBySel('action-create_dialog').click()

  // Fill form
  fillMarketplaceGUI(marketplace)

  // Wait and check that every request it's finished with 200 result
  cy.wait(interceptMarketplaceAllocate)
    .its('response.statusCode')
    .should('eq', 200)
}

/**
 * Update a marketplace.
 *
 * @param {object} marketplace - Marketplace to update
 */
const updateMarketplaceGUI = (marketplace) => {
  // Create interceptor for rename
  const interceptMarketplaceRename = createIntercept(
    Intercepts.SUNSTONE.MARKET_RENAME
  )

  // Create interceptor for update
  const interceptMarketplaceUpdate = createIntercept(
    Intercepts.SUNSTONE.MARKET_UPDATE
  )

  // Click on update button
  cy.getBySel('action-update_dialog').click()

  // Fill form
  fillMarketplaceGUI(marketplace)

  // Wait and check that every request it's finished with 200 result
  if (marketplace.general?.name)
    cy.wait(interceptMarketplaceRename)
      .its('response.statusCode')
      .should('eq', 200)

  cy.wait(interceptMarketplaceUpdate)
    .its('response.statusCode')
    .should('eq', 200)
}

/**
 * Delete a marketplace.
 *
 * @param {Marketplace} marketplace - Marketplace to delete
 */
const deleteMarketplaceGUI = (marketplace) => {
  cy.clickMarketplaceRow({ id: marketplace.id }).then(() => {
    // Create interceptor
    const interceptDelete = createIntercept(Intercepts.SUNSTONE.MARKET_DELETE)

    // Click on delete button
    cy.getBySel('action-marketplace_delete').click()

    // Accept the modal of delete market
    cy.getBySel(`modal-delete`)
      .should('exist')
      .then(($dialog) => {
        cy.wrap($dialog).find(`[data-cy=dg-accept-button]`).click()

        return cy
          .wait(interceptDelete)
          .its('response.statusCode')
          .should('eq', 200)
      })
  })
}

/**
 * Disable a marketplace.
 *
 * @param {Marketplace} marketplace - Marketplace to disable
 * @param {boolean} noWait - No wait for info request
 */
const disableMarketplaceGUI = (marketplace, noWait = false) => {
  cy.clickMarketplaceRow({ id: marketplace.id }, { noWait: noWait }).then(
    () => {
      // Create interceptor
      const interceptDisabled = createIntercept(
        Intercepts.SUNSTONE.MARKET_ENABLE_DISABLE
      )

      // Click on disable button
      cy.getBySel('action-marketplace-enable').click()
      cy.getBySel('action-disable').click()

      // Accept the modal of disabled market
      cy.getBySel(`modal-disable`)
        .should('exist')
        .then(($dialog) => {
          cy.wrap($dialog).find(`[data-cy=dg-accept-button]`).click()

          return cy
            .wait(interceptDisabled)
            .its('response.statusCode')
            .should('eq', 200)
        })
    }
  )
}

/**
 * Enable a marketplace.
 *
 * @param {Marketplace} marketplace - Marketplace to enable
 * @param {boolean} noWait - No wait for info request
 */
const enableMarketplaceGUI = (marketplace, noWait = false) => {
  cy.clickMarketplaceRow({ id: marketplace.id }, { noWait: noWait }).then(
    () => {
      // Create interceptor
      const interceptEnabled = createIntercept(
        Intercepts.SUNSTONE.MARKET_ENABLE_DISABLE
      )

      // Click on enable button
      cy.getBySel('action-marketplace-enable').click()
      cy.getBySel('action-enable').click()

      // Accept the modal of enable market
      cy.getBySel(`modal-enable`)
        .should('exist')
        .then(($dialog) => {
          cy.wrap($dialog).find(`[data-cy=dg-accept-button]`).click()

          return cy
            .wait(interceptEnabled)
            .its('response.statusCode')
            .should('eq', 200)
        })
    }
  )
}

/**
 * Change owner of a marketplace.
 *
 * @param {Marketplace} marketplace - Marketplace to use
 * @param {object} user - Owner user
 */
const changeOwnerMarketplaceGUI = (marketplace, user) => {
  cy.clickMarketplaceRow({ id: marketplace.id }).then(() => {
    // Create interceptor
    const interceptChangeOwner = createIntercept(
      Intercepts.SUNSTONE.MARKET_CHOWN
    )

    // Click on enable button
    cy.getBySel('action-marketplace-ownership').click()
    cy.getBySel('action-chown').click()

    cy.getBySelLike('modal-chown').within(() => {
      cy.getUserRow(user).click()
      cy.getBySel('dg-accept-button').click()

      cy.wait(interceptChangeOwner)
    })
  })
}

/**
 * Change group of a marketplace.
 *
 * @param {Marketplace} marketplace - Marketplace to use
 * @param {object} group - Group
 */
const changeGroupMarketplaceGUI = (marketplace, group) => {
  cy.clickMarketplaceRow({ id: marketplace.id }).then(() => {
    // Create interceptor
    const interceptChangeOwner = createIntercept(
      Intercepts.SUNSTONE.MARKET_CHOWN
    )

    // Click on enable button
    cy.getBySel('action-marketplace-ownership').click()
    cy.getBySel('action-chgrp').click()

    cy.getBySelLike('modal-chgrp').within(() => {
      cy.getGroupRow(group).click()
      cy.getBySel('dg-accept-button').click()

      cy.wait(interceptChangeOwner)
    })
  })
}

/**
 * Validates the data of a marketplace.
 *
 * @param {string} id - Template id
 * @param {object} expectedData - The marketplace expected data to validate
 * @returns {void} - No return value
 */
const validateMarketplace = (id, expectedData) => {
  // Wait because the update action could take some seconds in the core
  // eslint-disable-next-line cypress/no-unnecessary-waiting
  cy.wait(5000)

  new Marketplace(id).info().then((data) => {
    // Validate marketplace name
    cy.log('Checking marketplace name')
    cy.wrap(data.NAME).should('eq', expectedData.NAME)

    // Validate marketplace type
    cy.log('Checking marketplace type')
    cy.wrap(data.MARKET_MAD).should('eq', expectedData.MARKET_MAD)

    // Validate template
    cy.log('Checking marketplace template')
    cy.log('OpenNebula template: ', JSON.stringify(data.TEMPLATE))
    cy.log('Test template: ', JSON.stringify(expectedData.TEMPLATE))
    cy.wrap(data.TEMPLATE).should('deep.equal', expectedData.TEMPLATE)
  })
}

/**
 * Validate info tab of a cluster.
 *
 * @param {object} marketplace - Marketplace to validate
 * @param {object} expectedData - Expected data
 */
const validateInfoTabMarketplace = (marketplace, expectedData) => {
  const { name, type, state, owner, group } = expectedData

  cy.clickMarketplaceRow({ id: marketplace.id }).then(() => {
    // Check info tab
    cy.navigateTab('info')
      .should('exist')
      .and('be.visible')
      .within(() => {
        cy.getBySel('id').should('have.text', marketplace.id)
        name && cy.getBySel('name').should('have.text', expectedData.name)
        type && cy.getBySel('market_mad').should('have.text', expectedData.type)
        state && cy.getBySel('state').should('have.text', expectedData.state)
        owner && cy.getBySel('owner').should('have.text', expectedData.owner)
        group && cy.getBySel('group').should('have.text', expectedData.group)
      })
  })
}

/**
 * Validate apps tab of a cluster.
 *
 * @param {object} marketplace - Marketplace to validate
 * @param {boolean} noWait - No wait for info request
 */
const validateAppsTabMarketplace = (marketplace, noWait = false) => {
  cy.clickMarketplaceRow({ id: marketplace.id }, { noWait: noWait }).then(
    () => {
      // Check apps tab
      cy.navigateTab('apps').should('exist').and('be.visible')
    }
  )
}

Cypress.Commands.add('marketplaceGUI', marketplaceGUI)
Cypress.Commands.add('updateMarketplaceGUI', updateMarketplaceGUI)
Cypress.Commands.add('deleteMarketplaceGUI', deleteMarketplaceGUI)
Cypress.Commands.add('disableMarketplaceGUI', disableMarketplaceGUI)
Cypress.Commands.add('enableMarketplaceGUI', enableMarketplaceGUI)
Cypress.Commands.add('changeOwnerMarketplaceGUI', changeOwnerMarketplaceGUI)
Cypress.Commands.add('changeGroupMarketplaceGUI', changeGroupMarketplaceGUI)
Cypress.Commands.add('validateInfoTabMarketplace', validateInfoTabMarketplace)
Cypress.Commands.add('validateAppsTabMarketplace', validateAppsTabMarketplace)
Cypress.Commands.add('validateMarketplace', validateMarketplace)
