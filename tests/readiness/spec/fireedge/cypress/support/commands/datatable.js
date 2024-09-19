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

import { FORCE } from '@commands/constants'
// eslint-disable-next-line no-unused-vars
import { OpenNebulaResource } from '@models'
import { createIntercept } from '@utils/index'

/**
 * @typedef TableOptions
 * @property {boolean} [refresh] - If `false`, the refresh action will not perform
 * @property {boolean|string} [search] - If it's different as `false` will be search by string
 * @property {boolean} [clearSearch] - If `false`, the search input will not clear.
 * If {@link TableOptions.search} property exists, this will be `true` as default.
 */

/**
 * Gets the table element.
 *
 * @callback GetTableCb
 * @param {TableOptions} Options - Options
 * @returns {Cypress.Chainable} Element cypress
 */

/**
 * Gets the row from table.
 *
 * @callback GetRowCb
 * @param {OpenNebulaResource|number|'current-page'} resource
 * - Resource to select or position in datatable
 * @param {TableOptions} tableOptions - Table options
 * @returns {Cypress.Chainable} Element cypress
 */

/**
 * Click the row from table.
 *
 * @callback ClickRowCb
 * @param {OpenNebulaResource|number} resource - Resource or position in datatable
 * @param {object} [options] - Click options
 * @param {boolean} [options.noWait=false]
 * - If true, does not wait for the resource to be selected
 * @param {TableOptions} [tableOptions] - Table options
 * @returns {Cypress.Chainable} Element cypress
 */

/**
 * Applies list of labels to rows.
 *
 * @callback ApplyLabelsCb
 * @param {OpenNebulaResource[]|number[]} resources - Resources or positions in datatable
 * @param {string[]} [labels] - Labels
 * @param {boolean} [remove] - If true, the labels will be removed from rows
 * @returns {number[]} IDs from responses
 */

/**
 * Creates function to get the table element.
 *
 * @param {object} configuration - Configuration
 * @param {string} configuration.datatableCy - Selector for datatable
 * @param {string} configuration.searchCy - Selector for search
 * @param {object} configuration.poolIntercept - Intercept for the resource pool
 * @returns {GetTableCb} Function to get the datatable
 */
export const getTable =
  ({ datatableCy, searchCy, poolIntercept }) =>
  ({
    refresh = true,
    search = false,
    clearSearch = !!search,
    clearSelectedRows = false,
  } = {}) =>
    cy.getBySel(datatableCy).within(() => {
      if (refresh) {
        const interceptName = createIntercept(poolIntercept)
        cy.getBySel('refresh').should('not.be.disabled').click(FORCE)
        cy.wait(interceptName)
      }

      clearSearch && cy.getBySel(searchCy).clear(FORCE)
      clearSelectedRows && cy.get('input[type="checkbox"]').uncheck()
      search && cy.getBySel(searchCy).type(search, FORCE)
    })

/**
 * Creates function to get the table element and perform a waiting based on a condition using the response of the request associated to the poolIntercep.
 *
 * @param {object} configuration - Configuration
 * @param {string} configuration.datatableCy - Selector for datatable
 * @param {string} configuration.searchCy - Selector for search
 * @param {object} configuration.poolIntercept - Intercept for the resource pool
 * @returns {GetTableCb} Function to get the datatable
 */
export const getTableWaiting =
  ({ datatableCy, searchCy, poolIntercept }) =>
  ({
    search = false,
    clearSearch = !!search,
    clearSelectedRows = false,
    condition,
    configWait,
  } = {}) =>
    cy.getBySel(datatableCy).within(() => {
      // Wait unitl the condition function returns true
      cy.waitUntil(() => {
        const interceptName = createIntercept(poolIntercept)
        cy.getBySel('refresh').should('not.be.disabled').click(FORCE)

        return cy
          .wait(interceptName)
          .then((interceptorResponse) => condition(interceptorResponse))
      }, configWait)

      clearSearch && cy.getBySel(searchCy).clear(FORCE)
      clearSelectedRows && cy.get('input[type="checkbox"]').uncheck()
      search && cy.getBySel(searchCy).type(search)
    })

/**
 * Creates function to find a row on table.
 *
 * @param {object} configuration - Configuration
 * @param {GetTableCb} configuration.getTableFn - Function to get table
 * @param {string} configuration.prefixRowId - Prefix to select the row by id
 * @returns {GetRowCb} Function to looking for a row
 */
export const getRow =
  ({ getTableFn, prefixRowId }) =>
  (resource, { search = resource?.name, ...tableOptions } = {}) => {
    // If resource is a number, it's the position in the datatable
    if (typeof resource === 'number') {
      return getTableFn().find("[role='row']").eq(resource)
    }

    return getTableFn({ search, ...tableOptions })
      .find(`[role='row'][data-cy='${prefixRowId}${resource.id}']`)
      .first()
  }

/**
 * Creates function to select a resource on table.
 *
 * @param {object} configuration - Configuration
 * @param {GetRowCb} configuration.getRowFn - Function to get table
 * @param {string} configuration.showIntercept - Intercept for the resource info
 * @param {string} configuration.datatableCy - table Data-cy
 * @param {string} configuration.clickPosition - Click position
 * @returns {ClickRowCb} Function to click on row
 */
export const clickRow =
  ({ getRowFn, showIntercept, datatableCy, clickPosition = 'center' }) =>
  (
    resource,
    { noWait = false, removeSelections = false, checkSelected = true } = {},
    tableOptions
  ) =>
    getRowFn(resource, tableOptions).then(($row) => {
      const inter = createIntercept(showIntercept)
      // Multiple selection on datatable
      if (removeSelections) {
        cy.getBySel(datatableCy)
          .within((container) => {
            container.find('[data-cy="itemSelected"]').length &&
              cy.getBySel('itemSelected').each(($element) => {
                cy.wrap($element).find('svg').click()
              })
          })
          .then(() => {
            checkSelected
              ? cy
                  .wrap($row)
                  .click(clickPosition)
                  .should('have.class', 'selected')
              : cy.wrap($row).click(clickPosition)
          })
      } else {
        cy.get('body')
          .type('{ctrl}', { release: false })
          .then(() => {
            if (!$row.hasClass('selected')) {
              checkSelected
                ? cy
                    .wrap($row)
                    .click(clickPosition)
                    .should('have.class', 'selected')
                : cy.wrap($row).click(clickPosition)
            }
          })
      }

      if (!noWait) return cy.wait(inter)
    })

/**
 * Creates function to apply list of labels on rows.
 *
 * @param {object} configuration - Configuration
 * @param {ClickRowCb} configuration.clickRowFn - Function to get table
 * @param {string} configuration.updateIntercept - Intercept for the resource info
 * @returns {ApplyLabelsCb} IDs from responses
 */
export const applyLabelsToRows =
  ({ clickRowFn, updateIntercept }) =>
  (resources, labels = [], remove) => {
    const intercepts = resources.map(() => createIntercept(updateIntercept))

    const allRowClicks = resources.map(
      (resource) => () => clickRowFn(resource, { noWait: true })
    )

    return cy
      .all(...allRowClicks)
      .then(() => cy.applyLabelToResource(labels, remove))
      .then(() => cy.wait(intercepts))
      .then((responses) =>
        [responses].flat().map((res) => res.response.body.data)
      )
  }

/**
 * Function to return all rows in a table. Function gets rows of the first page, click on next button and add rows of second page, until the next button is disabled.
 *
 * @param {object} configuration - Configuration
 * @param {object} configuration.poolIntercept - Interceptor to use when find rows in a table
 * @param {string} configuration.datatableCy - data-cy of the table
 * @param {Function} configuration.getTableFn - Function to get table
 * @param {Array} configuration.results - Array with that will store all the rows
 * @returns {Array} - Every row of the table
 */
export const getRows =
  ({ poolIntercept, datatableCy, getTableFn, results }) =>
  (resource, { search = resource?.name, ...tableOptions } = {}) =>
    // Get the rows of a table that are in the HTML that is show to the user. So it's only a page of the table.
    getTableFn({ search, ...tableOptions })
      .find(`[role='row']`)
      .then((rows) =>
        // Find "next page" button
        cy
          .getBySel(datatableCy)
          .find(`[aria-label="next page"]`)
          .then((nextButton) => {
            // If button is disabled, push rows to results and return the results array. Else, add the rows in the results array an call the function itself
            if (nextButton[0].disabled) {
              // Push rows in array results
              results.push(...rows)

              // Return the results
              return results
            } else {
              // Push rows in array results
              results.push(...rows)

              // Click on export button
              nextButton.click()

              // Create function with results array
              const getMoreRows = getRows({
                poolIntercept: poolIntercept,
                datatableCy: datatableCy,
                getTableFn: getTableFn,
                results: results,
              })

              // Call itself and return data
              return getMoreRows().then((data) => data)
            }
          })
      )
