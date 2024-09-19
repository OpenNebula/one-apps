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
import { mapCleanup, toSnakeCase } from '@commands/helpers'
import { Intercepts, createIntercept } from '@support/utils'

/**
 * Get element by selector.
 *
 * @param {string} selector - selector
 * @param {object} [args] - get object options
 * @param {boolean} [args.log] - log
 * @param {number} [args.timeout] - timeout
 * @param {null|object} [args.withinSubject] - null or cypress object parent
 * @param {object} [args.includeShadowDom] - traverse shadow DOM
 * @returns {object} cypress object
 */
const getBySelector = (selector, ...args) =>
  cy.get(`[data-cy=${selector}]`, ...args)

/**
 * Selects an option or multiple options from a Material-UI dropdown.
 *
 * @param {string} selector - The data-cy attribute of the MUI dropdown.
 * @param {string|string[]} options - The option(s) you want to select from the dropdown.
 * @param {object} [args] - Additional options for the Cypress `get` command.
 * @param {boolean} [args.log=true] - Whether to log the command to the Cypress log.
 * @param {number} [args.timeout=5000] - Time in milliseconds to wait for the element to appear.
 * @param {null|object} [args.withinSubject=null] - Cypress object to scope the command to.
 * @param {boolean} [args.includeShadowDom=false] - Enable/disable traverse shadow DOM boundaries.
 * @returns {object} cypress object - The Cypress chainable object.
 * @example
 * // Single option
 * cy.selectMUIDropdownOption('qc-type-selector', 'vm');
 *
 * // Multiple options
 * cy.selectMUIDropdownOption('qc-type-selector', ['vm', 'datastore']);
 *
 * // Data-cy format
 * // Dropdown: data-cy="qc-type-selector"
 * // Option: data-cy="qc-type-selector-vm"
 */
const selectMUIDropdownOption = (selector, options, args = {}) => {
  const {
    log = true,
    timeout = 2000,
    withinSubject = null,
    includeShadowDom = false,
  } = args

  const optionsArray = Array.isArray(options) ? options : [options]

  let currentScope

  // Open the dropdown
  return cy
    .get(`[data-cy=${selector}]`, {
      log,
      timeout,
      withinSubject,
      includeShadowDom,
    })
    .then(($scope) => {
      currentScope = $scope.closest('[data-cy]')
    })
    .scrollIntoView()
    .click()
    .should('be.visible')
    .wait(timeout) // Wait for the dropdown to load
    .then(() => {
      // Exit the .within() scope to interact with elements that might be portaled/outside the current scope
      cy.root()

      // Find and click each dropdown option from the global scope
      optionsArray.forEach((option) => {
        cy.get(`li[data-cy="${selector}-${option}"]`, {
          log,
          timeout,
          withinSubject,
          includeShadowDom,
        })
          .scrollIntoView()
          .click()
      })
    })
    .then(() => {
      cy.realType('{esc}') // closes any open menus
    })
    .then(() => {
      // Return to the original scope
      if (currentScope) {
        cy.wrap(currentScope).within(() => {})
      }
    })
}

/**
 * Get element by like selector.
 *
 * @param {string} selector - selector
 * @param {object} [args] - get object options
 * @param {boolean} [args.log] - log
 * @param {number} [args.timeout] - timeout
 * @param {null|object} [args.withinSubject] - null or cypress object parent
 * @param {object} [args.includeShadowDom] - traverse shadow DOM
 * @returns {object} cypress object
 */
const getBySelectorLike = (selector, ...args) =>
  cy.get(`[data-cy*=${selector}]`, ...args)

/**
 * Get element by selector ends with.
 *
 * @param {string} selector - selector
 * @param {object} [args] - get object options
 * @param {boolean} [args.log] - log
 * @param {number} [args.timeout] - timeout
 * @param {null|object} [args.withinSubject] - null or cypress object parent
 * @param {object} [args.includeShadowDom] - traverse shadow DOM
 * @returns {object} cypress object
 */
const getBySelectorEndsWith = (selector, ...args) =>
  cy.get(`[data-cy$=${selector}]`, ...args)

/**
 * Get dropdowns.
 *
 * @returns {object} - cypress elements options
 */
const getDropdownOptions = () =>
  cy.get('.MuiAutocomplete-popper [role="listbox"] [role="option"]')

/**
 * Navigate in principal menu.
 *
 * @param {string} parent - parent item
 * @param {string} item - item menu name
 */
const navigateMenu = (parent = '', item = '') => {
  cy.getBySel('sidebar')
    .realHover()
    .within(() => {
      if (parent) {
        cy.getBySel(parent).then(($parent) => {
          if (!$parent.hasClass('open')) {
            cy.wrap($parent).realClick()
          }
        })
      }

      if (item) {
        const noMatchCase = { matchCase: false }
        cy.contains('[data-cy=main-menu-item]', item, noMatchCase).click()
      }
    })

  cy.getBySel('main-layout').realHover()
}

/**
 * Navigate in section tabs.
 *
 * @param {string} tab - tab name
 * @returns {object} Tab content cypress object
 */
const navigateTab = (tab = '') => {
  cy.getBySel(`tab-${tab}`).click({ force: true })

  return cy.getBySel(`tab-content-${tab}`)
}

/**
 * Select zone.
 *
 * @param {string} zone - number or zone
 * @param {string} zoneName - Name of the zone
 */
const changeZoneGUI = (zone = '', zoneName = '') => {
  if (zone) {
    cy.getBySel('header-zone-button').click({ force: true })
    cy.getBySel('select-zone').select(zoneName)
  }
}

/**
 * Click element and wait for request.
 *
 * @param {object} config - configuration
 * @param {string} config.button - button
 * @param {string} config.intercept - intercept
 * @returns {object} cypress intercept
 */
const clickWithInterceptor = (config = {}) => {
  const { button = '', intercept: interceptName } = config
  const intercept = createIntercept(interceptName)

  cy.getBySel(button)
    .should('exist')
    .then(($buttonCreate) => {
      cy.wrap($buttonCreate).click()
    })

  return cy.wait(intercept)
}

/**
 * Login in app.
 *
 * @param {object} userData - User data
 * @param {string} userData.username - username
 * @param {string} userData.password - password
 * @param {boolean} [userData.rememberUser] - remember user
 * @param {string} [userData.tfa] - Two Factor Authentication
 * @param {string} [path] - App path
 * @returns {Promise<object[]>} - List of requests: login and auth user info
 */
const login = (userData = {}, path = '/') => {
  const { username, password, rememberUser = false, tfa } = userData

  Cypress.log({
    name: 'login',
    displayName: 'LOGIN',
    message: [`🔐 Authenticating | ${username}`],
    autoEnd: false,
  })

  const getLogin = createIntercept(Intercepts.SUNSTONE.LOGIN)
  const getUserInfo = createIntercept(Intercepts.SUNSTONE.USER_INFO)

  cy.location('pathname', { log: false }).then(
    (currentPath) => currentPath !== path && cy.visit(path)
  )

  cy.getBySel('login-user').clear().type(username)
  cy.getBySel('login-token').clear().type(password)
  rememberUser && cy.getBySel('login-remember').check()

  cy.getBySel('login-button').click({ force: true })

  cy.wait(getLogin)

  if (tfa) {
    cy.getBySel('login-token2fa').clear().type(tfa)
    cy.getBySel('login-button').click({ force: true })
  }

  return cy.wait(getUserInfo)
}

/**
 * Logout app.
 */
const logout = () => {
  cy.getBySel('header-user-button').then(($userButton) => {
    if ($userButton) {
      cy.wrap($userButton).click()
      cy.getBySel('header-logout-button').click()
    }
  })

  cy.fixture('auth').then((auth) => {
    cy.window().its('localStorage').invoke('removeItem', auth.jwtName)
  })
}

/**
 * Promise all.
 *
 * @param {...any} fns - promises functions
 * @returns {any} - promises resolved
 */
const all = (...fns) => {
  const results = []

  fns.reduce((_, fn) => {
    fn().then((result) => results.push(result))

    return results
  }, results)

  return cy.wrap(results)
}

/**
 * @param {object} options - Options
 * @param {string[]} options.attributes - Available attributes on the form
 * @param {object} options.data - Data to fill
 * @param {string} [options.prefix] - Prefix on selector input
 */
const fillDataByAttributes = ({ attributes = [], data, prefix = '' }) => {
  attributes.forEach((attr) => {
    const halfSelector = toSnakeCase(attr).toUpperCase()
    const fullSelector = `${prefix}${halfSelector}`
    const value = data?.[attr]

    if (value === undefined) return

    cy.getBySelEndsWith(fullSelector).then(($input) => {
      const tag = $input[0]?.tagName?.toLowerCase()
      const inputType = $input[0]?.type?.toLowerCase()

      return {
        select: () =>
          cy.wrap($input).then(({ selector }) => {
            cy.get(selector)
              .click()
              .then(() => {
                cy.document().then((doc) => {
                  cy.wrap(doc?.body)
                    .find('.MuiAutocomplete-option')
                    .each(($el) => {
                      if (
                        value?.toLowerCase() ===
                          $el?.attr('data-value')?.toLowerCase() ||
                        value === $el?.text()
                      ) {
                        cy.wrap($el).click()

                        return false // Break
                      }
                    })
                })
              })
          }),
        textarea: () => cy.wrap($input).clear().type(value),
        input: () => {
          if ($input[0]?.attributes?.autocomplete) {
            // search in the autocomplete list,
            cy.wrap($input).clear().type(value)

            // then, select the value
            return cy.getDropdownOptions().contains(value).click()
          }

          const FILL_BY_TYPE = {
            checkbox: () => cy.wrap($input)[value ? 'check' : 'uncheck'](),
            default: () => cy.wrap($input).clear().type(value),
          }

          return FILL_BY_TYPE[inputType]?.() || FILL_BY_TYPE.default()
        },
        div: () => {
          if ($input[0]?.attributes?.role?.value === 'group') {
            return cy
              .wrap($input)
              .find(`button[aria-pressed="false"]`)
              .each(($button) => {
                cy.wrap($button)
                  .invoke('attr', 'value')
                  .then(
                    ($value) => $value === value && cy.wrap($button).click()
                  )
              })
          }
        },
      }[tag]?.()
    })
  })
}

/**
 * Performs cleanup of resources. By default, it cleans up every resource available
 * but is further filtered by the protected configuration options in "cypress/fixtures/cleanup/protected.json"
 * and optional parameter options.
 *
 * @param {object} [objects={}] - Takes in a configuration similar to the one defined
 * in "fixtures/cleanup/protected.json". The input object is used to strictly filter
 * cleanup on a resource type/object.
 * @example
 * // Example 1: Filtering to include only select names and id's
 * cy.cleanup({
 * groups: { NAMES: ['users'] },
 * datastores: { NAMES: ['files'], IDS: ['0', '1'] },
 * })
 */
const cleanup = (objects = {}) => {
  cy.fixture('cleanup/protected.json').then((protectedResources) => {
    mapCleanup(objects, protectedResources).then((mappedData) =>
      cy.wrap(Object.keys(mappedData)).each((object) => {
        const ids = mappedData[object]?.ids || []

        if (!ids) {
          return
        }

        const mappedIds = ids.map((resource) => resource.ID)
        const deleteFunc = (id) => mappedData[object]?.deleteFunc(id)

        return cy.wrap(mappedIds).each((id) => deleteFunc(id))
      })
    )
  })
}

Cypress.Commands.add('all', all)
Cypress.Commands.add('cleanup', cleanup)
Cypress.Commands.add('getBySel', getBySelector)
Cypress.Commands.add('getBySelLike', getBySelectorLike)
Cypress.Commands.add('getBySelEndsWith', getBySelectorEndsWith)
Cypress.Commands.add('navigateMenu', navigateMenu)
Cypress.Commands.add('navigateTab', navigateTab)
Cypress.Commands.add('getDropdownOptions', getDropdownOptions)
Cypress.Commands.add('selectMUIDropdownOption', selectMUIDropdownOption)
Cypress.Commands.add('clickWithInterceptor', clickWithInterceptor)
Cypress.Commands.add('login', login)
Cypress.Commands.add('logout', logout)
Cypress.Commands.add('fillData', fillDataByAttributes)
Cypress.Commands.add('changeZoneGUI', changeZoneGUI)
