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
import { createIntercept, Intercepts, fillInputs } from '@utils/index'

/**
 * Creates a provision.
 *
 * @param {object} provision - Provision information
 * @param {object} provision.provisionType - Provision type
 * @param {object} provision.providerType - Provider type
 * @param {object} provision.templateName - Provision template name
 * @param {object} provision.overview - Overview information
 * @param {string} providerName - Provider name
 * @returns {Promise} Wait for create action to resolve
 */
const create = (provision, providerName) => {
  const { provisionType, providerType, templateName, overview, inputs } =
    provision

  cy.contains('[data-cy=main-menu-item]', 'provisions', {
    matchCase: false,
  }).click()

  const getProviderDetail = createIntercept(Intercepts.PROVIDER.DETAIL)
  const createProvision = createIntercept(Intercepts.PROVISION.CREATE)

  cy.getBySel('create-provision').click()

  // Select provision and provider type
  cy.getBySel('select-provision-type').select(provisionType)
  cy.getBySel('select-provider-type').select(providerType)

  // Select provision template
  cy.contains('[data-cy=provision-card-title]', templateName)
    .closest('[data-cy=provision-card]')
    .find('>button')
    .click()

  cy.getBySel('provision-card-selected').contains(templateName)

  cy.getBySel('stepper-next-button').click()

  // Select provider
  cy.contains('[data-cy=provider-card-title]', providerName)
    .closest('[data-cy=provider-card]')
    .find('>button')
    .click()

  cy.getBySel('provider-card-selected').contains(providerName)

  cy.getBySel('stepper-next-button').click()

  // fill "Provision overview" tab
  fillInputs(overview, 'form-provision-')

  cy.getBySel('stepper-next-button').click()

  // Waiting until inputs form is loaded
  cy.wait(getProviderDetail)

  // fill "Configure inputs" tab
  fillInputs(inputs, 'form-provision-')

  // Submit CREATE
  cy.getBySel('stepper-next-button').click()

  return cy.wait(createProvision)
}

/**
 * Configures a provision by name.
 *
 * @param {string} provisionName - Provision name
 * @param {object} formData - Data to configure form
 * @returns {Promise} Wait for create configure to resolve
 */
const configure = (provisionName, formData) => {
  cy.contains('[data-cy=main-menu-item]', 'provisions', {
    matchCase: false,
  }).click()

  const refreshProvisionList = createIntercept(Intercepts.PROVISION.LIST)
  const configureProvision = createIntercept(Intercepts.PROVISION.CONFIGURE)

  cy.getBySel('refresh-provision-list').click()
  cy.wait(refreshProvisionList)

  // Click on configure button
  cy.contains('[data-cy=provision-card-title]', provisionName)
    .closest('[data-cy=provision-card]')
    .find('[data-cy=provision-configure]')
    .click()

  // fill configure form
  fillInputs(formData, 'form-dg-')

  // Submit CONFIGURE
  cy.getBySel('dg-accept-button').click()

  return cy.wait(configureProvision)
}

/**
 * Removes a provision by name.
 *
 * @param {string} provisionName - Provision name
 * @param {object} formData - Data to delete form
 * @returns {Promise} Wait for remove action to resolve
 */
const remove = (provisionName, formData = {}) => {
  cy.contains('[data-cy=main-menu-item]', 'provisions', {
    matchCase: false,
  }).click()

  const refreshProvisionList = createIntercept(Intercepts.PROVISION.LIST)
  const deleteProvision = createIntercept(Intercepts.PROVISION.DELETE)

  cy.getBySel('refresh-provision-list').click()
  cy.wait(refreshProvisionList)

  // Open delete provision dialog
  cy.contains('[data-cy=provision-card-title]', provisionName)
    .closest('[data-cy=provision-card]')
    .find('[data-cy=provision-delete]')
    .click()

  // fill delete form
  fillInputs(formData, 'form-dg-')

  // Submit DELETE
  cy.getBySel('dg-accept-button').click()

  return cy.wait(deleteProvision)
}

/**
 * Checks a provision data.
 *
 * @param {object} provision - Provision name
 * @param {object} provision.overview - Overview data
 * @param {object} provision.overview.name - Name
 * @param {object} provision.overview.description - Description
 * @param {string} providerName - Provider name
 */
const checkDetail = (provision, providerName) => {
  const {
    overview: { name, description },
  } = provision

  cy.contains('[data-cy=main-menu-item]', 'provisions', {
    matchCase: false,
  }).click()

  const refreshProvisionList = createIntercept(Intercepts.PROVISION.LIST)
  const getProvisionDetail = createIntercept(Intercepts.PROVISION.DETAIL)

  cy.getBySel('refresh-provision-list').click()
  cy.wait(refreshProvisionList)

  // Open provision dialog with detailed information
  cy.contains('[data-cy=provision-card-title]', name)
    .closest('[data-cy=provision-card]')
    .find('>button')
    .click()

  // Waiting until dialog is open
  cy.wait(getProvisionDetail)

  cy.getBySel('provider-name').should('have.text', providerName)
  cy.getBySel('provider-cluster').should('include.text', name)
  cy.getBySel('provision-description').should('have.text', description)

  // Close dialog
  cy.getBySel('dg-cancel-button').click()
}

export { create, configure, remove, checkDetail }
