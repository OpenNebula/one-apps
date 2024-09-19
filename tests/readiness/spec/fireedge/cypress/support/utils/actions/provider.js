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
import { createIntercept, Intercepts, fillInputs } from '../../utils'

/**
 * Creates a provider.
 *
 * @param {object} data - Necessary data to fill the step
 * @param {string} data.provisionType - Provision type
 * @param {string} data.providerType - Provider type
 * @param {string} data.templateName - Provider template name
 * @param {object} data.overview - Overview step data
 * @param {object} data.connection - Connection step data
 * @returns {Promise} Wait for create action to resolve
 */
const create = ({
  provisionType,
  providerType,
  templateName,
  overview,
  connection,
}) => {
  cy.contains('[data-cy=main-menu-item]', 'providers', {
    matchCase: false,
  }).click()

  const createProvider = createIntercept(Intercepts.PROVIDER.CREATE)

  cy.getBySel('create-provider').click()

  // Select provision and provider type
  cy.getBySel('select-provision-type').select(provisionType)
  cy.getBySel('select-provider-type').select(providerType)

  cy.contains('[data-cy=provider-card-title]', templateName)
    .closest('[data-cy=provider-card]')
    .find('>button')
    .click()

  cy.getBySel('provider-card-selected').contains(templateName)

  cy.getBySel('stepper-next-button').click()

  // fill "Provider overview" tab
  fillInputs(overview, 'form-provider-')

  cy.getBySel('stepper-next-button').click()

  // fill "Configure connection" tab
  fillInputs(connection, 'form-provider-')

  // Submit CREATE
  cy.getBySel('stepper-next-button').click()

  return cy.wait(createProvider)
}

/**
 * Updates an existing provider.
 *
 * @param {string} providerName - Provider name
 * @param {object} data - New provider data
 * @param {object} data.overview - New overview data
 * @param {object} data.connection - New connection data
 * @returns {Promise} Wait for update action to resolve
 */
const update = (providerName, { overview, connection }) => {
  cy.contains('[data-cy=main-menu-item]', 'providers', {
    matchCase: false,
  }).click()

  const refreshProviderList = createIntercept(Intercepts.PROVIDER.LIST)
  const getConnection = createIntercept(Intercepts.PROVIDER.CONNECTION)
  const updateProvider = createIntercept(Intercepts.PROVIDER.UPDATE)

  cy.getBySel('refresh-provider-list').click()
  cy.wait(refreshProviderList)

  // Find provider by name in title card
  cy.contains('[data-cy=provider-card-title]', providerName)
    .closest('[data-cy=provider-card]')
    .find('[data-cy=provider-edit]')
    .click()

  // Waiting until update form is loaded
  cy.wait([getConnection])

  // fill "Provider Overview" tab
  fillInputs(overview, 'form-provider-')

  cy.getBySel('stepper-next-button').click()

  // fill "Configure Connection" tab
  fillInputs(connection, 'form-provider-')

  // Submit UPDATE
  cy.getBySel('stepper-next-button').click()

  return cy.wait(updateProvider)
}

/**
 * Removes an existing provider.
 *
 * @param {string} providerName - Provider name
 * @returns {Promise} Wait for remove action to resolve
 */
const remove = (providerName) => {
  cy.contains('[data-cy=main-menu-item]', 'providers', {
    matchCase: false,
  }).click()

  const refreshProviderList = createIntercept(Intercepts.PROVIDER.LIST)
  const deleteProvider = createIntercept(Intercepts.PROVIDER.DELETE)

  cy.getBySel('refresh-provider-list').click()
  cy.wait(refreshProviderList)

  // Open provider dialog to action delete
  cy.contains('[data-cy=provider-card-title]', providerName)
    .closest('[data-cy=provider-card]')
    .find('[data-cy=provider-delete]')
    .click()

  // Submit DELETE
  cy.getBySel('dg-accept-button').click()

  return cy.wait(deleteProvider)
}

/**
 * Checks a provider data.
 *
 * @param {object} data - Provider information
 * @param {string} data.providerType - Provider type
 * @param {object} data.overview - Overview data
 * @param {object} data.connection - Connection data
 */
const checkDetail = ({ providerType: type, overview, connection }) => {
  cy.contains('[data-cy=main-menu-item]', 'providers', {
    matchCase: false,
  }).click()

  const refreshProviderList = createIntercept(Intercepts.PROVIDER.LIST)
  const getConnection = createIntercept(Intercepts.PROVIDER.CONNECTION)

  cy.getBySel('refresh-provider-list').click()
  cy.wait(refreshProviderList)

  // Open provider dialog with detailed information
  cy.contains('[data-cy=provider-card-title]', overview.name)
    .closest('[data-cy=provider-card]')
    .find('>button')
    .click()

  cy.getBySel('provider-connection').click()
  // Waiting until credentials connection are shown
  cy.wait(getConnection)

  Object.entries({ type, ...overview, ...connection }).forEach(
    ([key, value]) => {
      cy.getBySel(`provider-${key}`).should('have.text', value)
    }
  )

  // Close dialog
  cy.getBySel('dg-cancel-button').click()
}

export { create, update, remove, checkDetail }
