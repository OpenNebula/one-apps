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

import '@commands/marketapp/actions'
import '@commands/marketapp/info-tab'

import { MarketplaceApp, Datastore } from '@models'
import { Intercepts, createIntercept } from '@utils/index'
import {
  getTable,
  getRow,
  clickRow,
  applyLabelsToRows,
} from '@commands/datatable'
import { FORCE } from '@commands/constants'

/**
 * Downloads a marketplace app file.
 *
 * @param {MarketplaceApp} app - Marketplace App
 * @returns {Cypress.Chainable<Cypress.Response>} Element cypress
 */
const downloadMarketApp = (app = {}) => {
  const getDownloadMarketApp = createIntercept(
    Intercepts.SUNSTONE.MARKETAPP_DOWNLOAD
  )

  cy.clickMarketAppRow(app)
  cy.getBySel('action-download').click(FORCE)

  return cy.wait(getDownloadMarketApp)
}

/**
 * Import marketplace app on datastore.
 *
 * @param {MarketplaceApp} app - Marketplace App
 * @param {Datastore} datastore - Datastore
 * @returns {Cypress.Chainable<Cypress.Response>} Element cypress
 */
const importMarketApp = (app, datastore) => {
  const getExportMarketApp = createIntercept(
    Intercepts.SUNSTONE.MARKETAPP_EXPORT
  )

  cy.clickMarketAppRow(app)
  cy.getBySel('action-export').click(FORCE)

  cy.getBySel('modal-export').within(() => {
    cy.getBySel('stepper-next-button').click()
    cy.getDatastoreRow(datastore).click()
    cy.getBySel('stepper-next-button').click()
  })

  return cy.wait(getExportMarketApp)
}

const getMarketAppTable = getTable({
  datatableCy: 'apps',
  searchCy: 'search-apps',
  poolIntercept: Intercepts.SUNSTONE.MARKETAPPS,
})

const getMarketAppRow = getRow({
  getTableFn: getMarketAppTable,
  prefixRowId: 'app-',
})

const clickMarketAppRow = clickRow({
  getRowFn: getMarketAppRow,
  showIntercept: Intercepts.SUNSTONE.MARKETAPP,
})

const applyLabelsToMarketAppRows = applyLabelsToRows({
  clickRowFn: clickMarketAppRow,
  updateIntercept: Intercepts.SUNSTONE.MARKETAPP_UPDATE,
})

Cypress.Commands.add('getMarketAppTable', getMarketAppTable)
Cypress.Commands.add('getMarketAppRow', getMarketAppRow)
Cypress.Commands.add('clickMarketAppRow', clickMarketAppRow)
Cypress.Commands.add('applyLabelsToMarketAppRows', applyLabelsToMarketAppRows)

Cypress.Commands.add('importMarketApp', importMarketApp)
Cypress.Commands.add('downloadMarketApp', downloadMarketApp)
