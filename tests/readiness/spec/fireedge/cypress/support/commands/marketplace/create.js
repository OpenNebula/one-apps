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

/**
 * Fills in the GUI settings for a marketplace.
 *
 * @param {object} marketplace - The marketplace whose GUI settings are to be filled
 */
const fillMarketplaceGUI = (marketplace) => {
  // Start form
  cy.getBySel('main-layout').click()

  // Fill general data and continue
  if (marketplace.general) {
    fillGeneral(marketplace.general)
  }
  cy.getBySel('stepper-next-button').click()

  // Fill hosts data and continue
  if (marketplace.configuration) {
    fillConfiguration(marketplace.configuration)
  }
  cy.getBySel('stepper-next-button').click()
}

/**
 * Fills in the general settings for a marketplace.
 *
 * @param {object} general - General settings to be filled
 */
const fillGeneral = (general) => {
  // Get marketplace info
  const { name, description, type } = general

  // Set name of the marketplace
  name
    ? cy.getBySel('general-NAME').clear().type(name)
    : name === '' && cy.getBySel('general-NAME').clear()

  // Set description of the marketplace
  description
    ? cy.getBySel('general-DESCRIPTION').clear().type(description)
    : description === '' && cy.getBySel('general-DESCRIPTION').clear()

  // Set type of the marketplace
  type &&
    cy.getBySel('general-MARKET_MAD').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  type?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  type === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })
}

/**
 * Fills in the configuration settings for a marketplace.
 *
 * @param {object} configuration - Configuration settings to be filled
 */
const fillConfiguration = (configuration) => {
  // Get marketplace info
  const {
    endpoint,
    ssl,
    baseUrl,
    path,
    bridgeList,
    aws,
    accessKey,
    secretAccessKey,
    bucket,
    region,
    size,
    length,
  } = configuration

  // Set endpoint
  endpoint
    ? cy.getBySel('configuration-ENDPOINT').clear().type(endpoint)
    : endpoint === '' && cy.getBySel('configuration-ENDPOINT').clear()

  // Set baseUrl
  baseUrl
    ? cy.getBySel('configuration-BASE_URL').clear().type(baseUrl)
    : baseUrl === '' && cy.getBySel('configuration-BASE_URL').clear()

  // Set ssl
  ssl
    ? cy.getBySel('configuration-SSL').check()
    : ssl === false && cy.getBySel('configuration-SSL').uncheck()

  // Set path
  path
    ? cy.getBySel('configuration-PUBLIC_DIR').clear().type(path)
    : path === '' && cy.getBySel('configuration-PUBLIC_DIR').clear()

  // Set bridgeList
  if (bridgeList) {
    bridgeList.forEach((bridge) => {
      cy.getBySel('configuration-BRIDGE_LIST').clear()
      cy.getBySel('configuration-BRIDGE_LIST').type(`${bridge}{enter}`)
    })
  } else if (bridgeList?.length === 0) {
    cy.getBySel('configuration-BRIDGE_LIST').clear()
  }

  // Set aws
  aws
    ? cy.getBySel('configuration-AWS').check()
    : aws === false && cy.getBySel('configuration-AWS').uncheck()

  // Set accessKey
  accessKey
    ? cy.getBySel('configuration-ACCESS_KEY_ID').clear().type(accessKey)
    : accessKey === '' && cy.getBySel('configuration-ACCESS_KEY_ID').clear()

  // Set secretAccessKey
  secretAccessKey
    ? cy
        .getBySel('configuration-SECRET_ACCESS_KEY')
        .clear()
        .type(secretAccessKey)
    : secretAccessKey === '' &&
      cy.getBySel('configuration-SECRET_ACCESS_KEY').clear()

  // Set bucket
  bucket
    ? cy.getBySel('configuration-BUCKET').clear().type(bucket)
    : bucket === '' && cy.getBySel('configuration-BUCKET').clear()

  // Set region
  region
    ? cy.getBySel('configuration-REGION').clear().type(region)
    : region === '' && cy.getBySel('configuration-REGION').clear()

  // Set size
  size
    ? cy.getBySel('configuration-TOTAL_MB').clear().type(size)
    : size === '' && cy.getBySel('configuration-TOTAL_MB').clear()

  // Set length
  length
    ? cy.getBySel('configuration-READ_LENGTH').clear().type(length)
    : length === '' && cy.getBySel('configuration-READ_LENGTH').clear()
}

export { fillMarketplaceGUI }
