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

import { Image } from '@support/commands/template/jsdocs'
import { FORCE } from '@support/commands/constants'

/**
 * Fill configuration for image creation.
 *
 * @param {Image} image - template object
 */
const fillConfiguration = (image) => {
  const { name, description, type, persistent, size, path, upload, sizeunit } =
    image

  cy.getBySel('general-NAME').clear().type(name)

  description && cy.getBySel('general-DESCRIPTION').clear().type(description)

  type &&
    cy.getBySel('general-TYPE').then(({ selector }) => {
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

  persistent === 'YES' && cy.getBySel('general-PERSISTENT').click(FORCE)

  if (size) {
    cy.get('[data-cy=general-IMAGE_LOCATION] > button[value=empty]').click(
      FORCE
    )
    cy.getBySel('general-SIZE').clear().type(size)

    // Set size unit if exists
    if (sizeunit) {
      cy.getBySel('general-SIZEUNIT').then(({ selector }) => {
        cy.get(selector)
          .click()
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    sizeunit?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    sizeunit === $el?.text()
                  ) {
                    cy.wrap($el).click()

                    return false // Break
                  }
                })
            })
          })
      })
    }
  }

  if (path) {
    cy.get('[data-cy=general-IMAGE_LOCATION] > button[value=path]').click(FORCE)
    cy.getBySel('general-PATH').clear().type(path)
  }

  if (upload) {
    cy.get('[data-cy=general-IMAGE_LOCATION] > button[value=upload]').click(
      FORCE
    )
    cy.get('input[id=general-UPLOAD]').attachFile(upload)
  }
}

/**
 * Fill datastore for image creation.
 *
 * @param {Image} image - image object
 */
const fillDatastore = (image) => {
  const { datastore } = image

  cy.getDatastoreRow(datastore).click(FORCE)
}

/**
 * Fill Advance for image creation.
 *
 * @param {Image} image - image object
 */
const fillAdvance = (image) => {
  const { size, bus, device, format, fs } = image

  bus &&
    cy.getBySel('advanced-DEV_PREFIX').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  bus?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  bus === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })

  device && cy.getBySel('advanced-DEVICE').clear().type(device)

  if (size) {
    cy.getBySel('advanced-FORMAT').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  format?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  format === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })

    cy.getBySel('advanced-FS').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  fs?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  fs === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })
  }
}

/**
 * Fill custom attributes for image creation.
 *
 * @param {Image} image - image object
 */
const fillCustomAttributes = (image) => {
  const { customAttributes } = image

  Object.entries(customAttributes).forEach(([varName, varValue]) => {
    cy.getBySelLike('text-name-').clear().type(varName)
    cy.getBySelLike('text-value-').clear().type(`${varValue}{enter}`)
  })
}

/**
 * Fill forms image via GUI.
 *
 * @param {Image} image - image
 */
const fillImageGUI = (image) => {
  cy.getBySel('main-layout').click()

  fillConfiguration(image)
  cy.getBySel('stepper-next-button').click()
  fillDatastore(image)
  cy.getBySel('stepper-next-button').click()
  fillAdvance(image)
  cy.getBySel('stepper-next-button').click()
  fillCustomAttributes(image)

  cy.getBySel('stepper-next-button').click()
}

/**
 * Fill forms file via GUI.
 *
 * @param {Image} image - image
 */
const fillFileGUI = (image) => {
  cy.getBySel('main-layout').click()

  fillConfiguration(image)
  cy.getBySel('stepper-next-button').click()
  fillDatastore(image)
  cy.getBySel('stepper-next-button').click()
}

export {
  fillConfiguration,
  fillDatastore,
  fillAdvance,
  fillCustomAttributes,
  fillImageGUI,
  fillFileGUI,
}
