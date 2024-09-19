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

import Marketplace from '@support/models/marketplace'

/**
 * Create all the resources needed in the marketplace tests.
 *
 * @param {object} resources - Resources to create
 * @param {Array} resources.marketplaces - List of marketplaces to be created
 * @param {object} resources.user - User info
 * @param {object} resources.group - Group info
 */
const beforeAllMarketplace = ({ marketplaces, user, group }) => {
  cy.fixture('auth')
    .then((auth) => cy.apiAuth(auth.admin))
    .then(() => cy.apiSunstoneConf())
    .then(() => cy.cleanup())
    .then(() =>
      marketplaces.forEach((marketplace) =>
        new Marketplace(marketplace.general.name).allocate({
          NAME: marketplace.general.name,
          DESCRIPTION: marketplace.general.description,
          MARKET_MAD: 'linuxcontainers',
        })
      )
    )
    .then(() => group.allocate(group.name))
    .then(() => group.info())
    .then(() =>
      user.allocate({
        username: user.name,
        password: 'opennebula',
        group: [group.id],
      })
    )
    .then(() => user.info())
}

/**
 * Create a new marketplace via GUI.
 *
 * @param {object} marketplace - marketplace template.
 */
const createMarketplace = (marketplace) => {
  cy.navigateMenu('storage', 'Marketplace')
  cy.marketplaceGUI(marketplace.data)

  // Validate template
  cy.validateMarketplace(
    marketplace.data.general.name,
    marketplace.expectedTemplate
  )

  // Validate info tab
  const expectedData = {
    name: marketplace.data.general.name,
    type: marketplace.expectedTemplate.MARKET_MAD,
  }
  validateInfoTab(marketplace.data, expectedData)

  // Validate apps tab
  validateAppsTab(marketplace.data, true)
}

/**
 * Update a marketplace via GUI.
 *
 * @param {object} marketplace - Marketplace update actions.
 */
const updateMarketplace = (marketplace) => {
  const market = new Marketplace(marketplace.initialData.data.general.name)
  market.info().then(() => {
    marketplace?.updates?.forEach((update) => {
      // Naviage to the marketplaces section
      cy.navigateMenu('storage', 'Marketplace')

      // Click on the marketplace row
      cy.clickMarketplaceRow({ id: market.id }, { noWait: true }).then(() => {
        // Update marketplace
        cy.updateMarketplaceGUI(update.data)

        // Validate marketplace
        cy.validateMarketplace(market.id, update.expectedTemplate)
      })
    })
  })
}

/**
 * Delete a marketplace via GUI.
 *
 * @param {object} marketplace - Marketplace to be deleted.
 */
const deleteMarketplace = (marketplace) => {
  const market = new Marketplace(marketplace.general.name)
  market.info().then(() => {
    // Naviage to the marketplaces section
    cy.navigateMenu('storage', 'Marketplace')

    // Delete marketplace
    cy.deleteMarketplaceGUI(market)
  })
}

/**
 * Enable and disable a marketplace via GUI.
 *
 * @param {object} marketplace - Marketplace to be enabled and disabled.
 */
const enabledDisabledMarketplace = (marketplace) => {
  const market = new Marketplace(marketplace.general.name)
  market.info().then(() => {
    // Naviage to the marketplaces section
    cy.navigateMenu('storage', 'Marketplace')

    // Disabled marketplace
    cy.disableMarketplaceGUI(market)

    // Validate info tab
    const expectedDataDisabled = {
      name: marketplace.general.name,
      type: 'linuxcontainers',
      status: 'DISABLED',
    }
    validateInfoTab(marketplace, expectedDataDisabled)

    // Naviage to the marketplaces section
    cy.navigateMenu('storage', 'Marketplace')

    // Disabled marketplace
    cy.enableMarketplaceGUI(market, true)

    // Validate info tab
    const expectedDataEnabled = {
      name: marketplace.general.name,
      type: 'linuxcontainers',
      status: 'ENABLED',
    }
    validateInfoTab(marketplace, expectedDataEnabled)
  })
}

/**
 * Change owner and group of a marketplace via GUI.
 *
 * @param {object} marketplace - Marketplace to use.
 * @param {object} user - User info
 * @param {object} group - Group info
 */
const changeOwnerGroupMarketplace = (marketplace, user, group) => {
  const market = new Marketplace(marketplace.general.name)
  market.info().then(() => {
    // Naviage to the marketplaces section
    cy.navigateMenu('storage', 'Marketplace')

    // Change marketplace owner
    cy.changeOwnerMarketplaceGUI(market, user)

    // Naviage to the marketplaces section
    cy.navigateMenu('storage', 'Marketplace')

    // Disabled marketplace
    cy.changeGroupMarketplaceGUI(market, group)

    // Validate info tab
    const expectedData = {
      name: marketplace.general.name,
      type: 'linuxcontainers',
      owner: 'user',
      group: 'users',
    }
    validateInfoTab(marketplace, expectedData)
  })
}

/**
 * Validate info tab of a marketplace.
 *
 * @param {object} marketplace - Marketplace template
 * @param {object} expectedData - Data to validte in the tab
 */
const validateInfoTab = (marketplace, expectedData) => {
  cy.navigateMenu('storage', 'Marketplace')

  const market = new Marketplace(marketplace.general.name)
  market.info().then(() => {
    cy.validateInfoTabMarketplace(market, expectedData)
  })
}

/**
 * Validate apps tab of a marketplace.
 *
 * @param {object} marketplace - Marketplace template
 * @param {boolean} noWait - No wait for info request
 */
const validateAppsTab = (marketplace, noWait) => {
  cy.navigateMenu('storage', 'Marketplace')

  const market = new Marketplace(marketplace.general.name)
  market.info().then(() => {
    cy.validateAppsTabMarketplace(market, noWait)
  })
}

/**
 * Cleanup after test execution.
 */
const afterAllMarketplace = () => {
  cy.cleanup()
}

export {
  beforeAllMarketplace,
  afterAllMarketplace,
  createMarketplace,
  updateMarketplace,
  enabledDisabledMarketplace,
  changeOwnerGroupMarketplace,
  deleteMarketplace,
}
