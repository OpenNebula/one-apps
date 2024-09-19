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

import '@commands/marketplace/actions'

import {
  applyLabelsToRows,
  clickRow,
  getRow,
  getTable,
} from '@commands/datatable'
import { Intercepts } from '@support/utils'

const datatableCy = 'marketplaces'

const getMarketplaceTable = getTable({
  datatableCy,
  searchCy: 'search-marketplaces',
  poolIntercept: Intercepts.SUNSTONE.MARKETS,
})

const getMarketplaceRow = getRow({
  getTableFn: getMarketplaceTable,
  prefixRowId: 'marketplace-',
})

const clickMarketplaceRow = clickRow({
  getRowFn: getMarketplaceRow,
  showIntercept: Intercepts.SUNSTONE.MARKET,
  datatableCy,
})

const applyLabelsToMarketplaceRows = applyLabelsToRows({
  clickRowFn: clickMarketplaceRow,
  updateIntercept: Intercepts.SUNSTONE.MARKET_UPDATE,
})

Cypress.Commands.add('getMarketplaceTable', getMarketplaceTable)
Cypress.Commands.add('getMarketplaceRow', getMarketplaceRow)
Cypress.Commands.add('clickMarketplaceRow', clickMarketplaceRow)
Cypress.Commands.add(
  'applyLabelsToMarketplaceRows',
  applyLabelsToMarketplaceRows
)
