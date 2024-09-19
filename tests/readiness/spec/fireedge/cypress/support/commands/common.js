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

import { OpenNebulaResource } from '@support/models'
import { Intercepts, createIntercept } from '@support/utils'
import { FORCE } from './constants'

/**
 * @typedef Ownership - Permissions
 * @property {string} UNAME - User name
 * @property {string} GNAME - Group name
 */

/**
 * @typedef {'1'|'0'} PermissionValue - Permission value
 */

/**
 * @typedef Permissions - Permissions
 * @property {PermissionValue} OWNER_U - Owner use
 * @property {PermissionValue} OWNER_M - Owner manage
 * @property {PermissionValue} OWNER_A - Owner admin
 * @property {PermissionValue} GROUP_U - Group use
 * @property {PermissionValue} GROUP_M - Group manage
 * @property {PermissionValue} GROUP_A - Group admin
 * @property {PermissionValue} OTHER_U - Other use
 * @property {PermissionValue} OTHER_M - Other manage
 * @property {PermissionValue} OTHER_A - Other admin
 */

/**
 * @typedef PermissionsGui - Permissions
 * @property {PermissionValue} ownerUse - Owner use
 * @property {PermissionValue} ownerManage - Owner manage
 * @property {PermissionValue} ownerAdmin - Owner admin
 * @property {PermissionValue} groupUse - Group use
 * @property {PermissionValue} groupManage - Group manage
 * @property {PermissionValue} groupAdmin - Group admin
 * @property {PermissionValue} otherUse - Other use
 * @property {PermissionValue} otherManage - Other manage
 * @property {PermissionValue} otherAdmin - Other admin
 */

/**
 * Transforms a {@link Permissions} object to a {@link PermissionsGui} object.
 *
 * @param {Permissions} permissions - Permissions object
 * @returns {PermissionsGui} PermissionsGui object
 * @example
 * { OWNER_U: 1, OWNER_M: 1, ... } => { ownerUse: 1, ownerManage: 1, ... }
 */
const parsePermissionsToGUI = (permissions) => {
  const {
    OWNER_U: ownerUse,
    OWNER_M: ownerManage,
    OWNER_A: ownerAdmin,

    GROUP_U: groupUse,
    GROUP_M: groupManage,
    GROUP_A: groupAdmin,

    OTHER_U: otherUse,
    OTHER_M: otherManage,
    OTHER_A: otherAdmin,
  } = permissions || {}

  return {
    ownerUse,
    ownerManage,
    ownerAdmin,
    groupUse,
    groupManage,
    groupAdmin,
    otherUse,
    otherManage,
    otherAdmin,
  }
}

/**
 * Validate permissions on OpenNebula resource.
 *
 * @param {OpenNebulaResource|PermissionsGui} permissions
 * - Permissions to validate or OpenNebula resource
 */
const validatePermissions = (permissions) => {
  const entries =
    permissions instanceof OpenNebulaResource
      ? parsePermissionsToGUI(permissions.json.PERMISSIONS)
      : permissions

  const permissionsChanged = Object.entries(entries)
    .map(([_, value]) => [_, String(value)])
    .filter(([_, value]) => ['0', '1'].includes(value))

  for (const [name, value] of permissionsChanged) {
    cy.getBySel(`permission-${name}`).should('have.value', value)
  }
}

/**
 * Validate ownership on OpenNebula resource.
 *
 * @param {OpenNebulaResource} resource - VM to validate
 */
const validateOwnership = (resource) => {
  const { UNAME, GNAME } = resource.json

  cy.getBySel('owner').should('have.text', UNAME)
  cy.getBySel('group').should('have.text', GNAME)
}

/**
 * Changes permissions to OpenNebula resource.
 *
 * @param {PermissionsGui} newPermissions - Permissions to change
 * @param {object} intercept - intercept
 * @param {boolean} [delay=false] - Optionally enables a 1s delay for every click
 * @returns {Cypress.Chainable} Chainable command after changing permissions
 */
const changePermissions = (newPermissions, intercept, { delay = false } = {}) =>
  cy.navigateTab('info').within(() => {
    const inter = createIntercept(intercept)
    for (const [name, value] of Object.entries(newPermissions)) {
      cy.getBySel(`permission-${name}`).then(($button) => {
        if ($button.val() !== `${value}`) {
          $button.click()
          // Gives the GET call a little bit of time to complete after it POSTs 200
          // eslint-disable-next-line cypress/no-unnecessary-waiting
          delay && cy.wait(5000)
          cy.wait(inter)
        }
      })
    }
  })

/**
 * Validates if the resource is locked.
 *
 * @param {OpenNebulaResource} resource - Resource
 */
const validateLock = (resource) => {
  cy.navigateTab('info').within(() => {
    cy.getBySel('locked').should('have.text', resource.lockLevel)
  })
}

/**
 * Rename OpenNebula resource.
 *
 * @param {string} newName - New name
 * @param {object} intercept - Interceptor
 */
const renameResource = (newName, intercept = {}) => {
  const inter = createIntercept(intercept)
  cy.navigateTab('info').within(() => {
    cy.getBySel('edit-name').first().click()
    cy.getBySel('text-name').clear().type(newName)
    cy.getBySel('accept-name')
      .click()
      .then(() => {
        intercept && cy.wait(inter)
      })
    cy.getBySel('name').should('have.text', newName)
  })
}

/**
 * Adds or removes labels in OpenNebula resource.
 *
 * @param {string[]} labels - Labels
 * @param {boolean} remove - If true, the labels will be removed from rows
 * @returns {Cypress.Chainable} Chainable command after changing labels
 */
const applyLabelToResource = (labels, remove = false) => {
  cy.getBySel('filter-by-label').click()

  cy.get("#filter-by-label [role='option']").each(($option) => {
    cy.wrap($option)
      .invoke('attr', 'aria-selected')
      .then(($ariaSelected) => {
        const isSelected = /true/i.test($ariaSelected)

        if (labels.includes($option.text()) && remove === isSelected) {
          cy.wrap($option).click()
        } else if (remove && isSelected) {
          cy.wrap($option).click()
        }
      })
  })

  labels.forEach((label) => {
    cy.get('#filter-by-label')
      .contains(label)
      .closest("[role='option']")
      .should('have.attr', 'aria-selected', remove ? 'false' : 'true')
  })

  return cy.getBySel('main-layout').click(FORCE)
}

/**
 * Filters datatable by labels.
 *
 * @param {string[]} labels - Labels to add
 * @returns {Cypress.Chainable} Chainable command after changing labels
 */
const filterByLabels = (labels) => {
  cy.getBySel('filter-by-label').click()

  labels.forEach((label) => {
    cy.get('#filter-by-label')
      .contains(label)
      .closest("[role='option']")
      .click()
      .should('have.attr', 'aria-selected', 'true')
  })

  return cy.getBySel('main-layout').click(FORCE)
}

/**
 * Saves labels in the authenticated user's template.
 *
 * @param {string[]} labels - Labels to save
 * @returns {Cypress.Chainable} Chainable command after saving
 */
const saveLabelsToUserTemplate = (labels) => {
  cy.getBySel('filter-by-label').click()

  labels.forEach((label) => {
    cy.get('#filter-by-label')
      .contains(label)
      .siblings('button')
      .click({ force: true })
      .should('not.be.visible')
  })

  return cy.getBySel('main-layout').click({ force: true })
}

/**
 * Deletes label from the authenticated user in the settings tab.
 *
 * @param {string} label - Label to delete
 * @returns {Cypress.Chainable} Chainable command after saving
 */
const deleteUserLabel = (label) => {
  const intercept = createIntercept(Intercepts.SUNSTONE.USER_UPDATE)
  cy.getBySel(`delete-label-${label}`).click()

  return cy.wait(intercept)
}

/**
 * Deletes label from the authenticated user in the settings tab.
 *
 * @param {Array[Object]} stepsValues - Data to be filled on each step.
 */
const fillStepper = (stepsValues) => {
  for (const step of stepsValues) {
    const { stepType, stepId, ...values } = step

    if (stepType === 'simple') {
      fillStep(stepId, values)
    } else if (stepType === 'table') {
      selectOnTable(values)
    } else if (stepType === 'custom') {
      fillCustomVariables(values)
    } else {
      throw new Error('Invalid step type')
    }

    cy.getBySel('stepper-next-button').click()
  }
}

const fillStep = (stepId, values) => {
  for (const [fieldName, value] of Object.entries(values)) {
    cy.getBySel(`${stepId}-${fieldName}`).then((field) => {
      const fieldNode = field.prop('nodeName')
      const fieldRole = field.attr('role')
      const fieldType = field.attr('type')
      const fieldAutocomplete = field.attr('aria-autocomplete')

      if (
        fieldNode === 'SELECT' ||
        (fieldNode === 'INPUT' &&
          fieldType === 'text' &&
          fieldAutocomplete === 'list')
      ) {
        cy.getBySel(`${stepId}-${fieldName}`).then(({ selector }) => {
          cy.get(selector)
            .click()
            .then(() => {
              if (value && Array.isArray(value)) {
                cy.wrap(value).each(($input) => {
                  cy.get(selector).type(`${$input}{enter}`)
                })
              } else {
                cy.get('body')
                  .find('.MuiAutocomplete-option')
                  .each(($el) => {
                    if (
                      value.toLowerCase() ===
                        $el.attr('data-value').toLowerCase() ||
                      value === $el.text()
                    ) {
                      cy.wrap($el).click()

                      return false // Break
                    }
                    cy.get(selector).type('{downArrow}')
                  })
              }
            })
        })
      } else if (
        fieldNode === 'INPUT' &&
        ['text', 'number'].includes(fieldType)
      ) {
        cy.getBySel(`${stepId}-${fieldName}`).type(value)
      } else if (fieldNode === 'DIV' && fieldRole === 'group') {
        cy.getBySel(`${stepId}-${fieldName}`).contains(value).click()
      } else if (fieldNode === 'INPUT' && fieldType === 'checkbox') {
        cy.getBySel(`${stepId}-${fieldName}`).click()
      } else {
        throw new Error(`Field "${fieldName}" has no defined action.
        Please define how to handle this type of field.`)
      }
    })
  }
}

const selectOnTable = (values) => {
  const { id, resource, searchSelector } = values

  cy.getBySel(`search-${searchSelector}`).type(id)
  cy.getBySel(`${resource}-${id}`).click()
}

const fillCustomVariables = (values = {}) => {
  const checkAndType = (selector, text, retries = 10) => {
    if (retries <= 0) {
      throw new Error(
        `Element ${selector} is still disabled after multiple retries.`
      )
    }

    return cy
      .get(selector)
      .should('be.visible')
      .then(($el) => {
        if ($el.is(':disabled')) {
          cy.log(
            `${selector} is disabled, retrying... (${retries} retries left)`
          )
          // eslint-disable-next-line cypress/no-unnecessary-waiting
          cy.wait(500)

          return checkAndType(selector, text, retries - 1)
        }
        cy.wrap($el).type(text)
      })
  }

  for (const [key, value] of Object.entries(values)) {
    checkAndType('[data-cy^="text-name"]', key)
      .then(() => checkAndType('[data-cy^="text-value"]', value))
      .then(() => {
        const checkAndClick = (selector, retries = 10) => {
          if (retries <= 0) {
            throw new Error(
              `Element ${selector} is still disabled after multiple retries.`
            )
          }

          return cy
            .getBySel(selector)
            .should('be.visible')
            .then(($el) => {
              if ($el.is(':disabled')) {
                cy.log(
                  `${selector} is disabled, retrying... (${retries} retries left)`
                )
                // eslint-disable-next-line cypress/no-unnecessary-waiting
                cy.wait(500)

                return checkAndClick(selector, retries - 1)
              }
              cy.wrap($el).click()
            })
        }

        checkAndClick('action-add')
      })
  }
}

/**
 * Simulate the interaction of an user with the Datepicker component.
 *
 * @param {string} dataCy - Value of data-cy html attribute
 * @param {object} date - Date to set in the component
 * @param {string} date.year - Year of the date
 * @param {string} date.month - Month of the date
 * @param {string} date.day - Day of the date
 * @param {string} date.period - Period of the date
 * @param {string} date.hours - Hours of the date
 * @param {string} date.minutes - Minutes of the date
 */
const fillDatetimePicker = (
  dataCy,
  { year, month, day, period, hours, minutes }
) => {
  // Use body to find the calendar icon
  cy.get('body').then((body) => {
    // Checking if the attribute exists on the DOM
    const desktop = body.find(`[data-testid="CalendarIcon"]`).length > 0

    // Open Datepicker dialog
    desktop
      ? cy
          .getBySel(dataCy)
          .siblings()
          .find('[data-testid="CalendarIcon"]')
          .click(FORCE)
      : cy.getBySel(dataCy).click(FORCE)

    // Find the component
    cy.get('[role="dialog"]')
      .eq(1)
      .within(() => {
        // Click on the div that changes to year's view
        cy.get('[role="presentation"]').click({ waitForAnimations: false })

        // Select year
        cy.contains('button', year).click({ waitForAnimations: false })

        // Select month
        cy.contains('button', month).click({ waitForAnimations: false })

        // Select the day of the month
        cy.get('button.MuiPickersDay-root')
          .contains(day)
          .click({ waitForAnimations: false })

        // Select pick time section
        cy.get('button[aria-label="pick time"]').click({
          waitForAnimations: false,
        })

        // Select AM/PM
        cy.get('span').contains(period).realClick()

        // Select hours
        cy.get('span[aria-label*=hours]').contains(hours).realClick()

        // Select minutes
        cy.get('span[aria-label*=minutes]').contains(minutes).realClick()

        // Click ok button if it is not desktop
        !desktop &&
          cy.contains('button', 'OK').click({ waitForAnimations: false })
      })
  })
}

Cypress.Commands.add('validatePermissions', validatePermissions)
Cypress.Commands.add('changePermissions', changePermissions)
Cypress.Commands.add('validateOwnership', validateOwnership)
Cypress.Commands.add('validateLock', validateLock)
Cypress.Commands.add('renameResource', renameResource)
Cypress.Commands.add('applyLabelToResource', applyLabelToResource)
Cypress.Commands.add('filterByLabels', filterByLabels)
Cypress.Commands.add('saveLabelsToUserTemplate', saveLabelsToUserTemplate)
Cypress.Commands.add('deleteUserLabel', deleteUserLabel)
Cypress.Commands.add('fillStepper', fillStepper)
Cypress.Commands.add('fillDatetimePicker', fillDatetimePicker)
