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

import '@commands/vnet/actions'
import '@commands/vnet/addr-tab'
import '@commands/vnet/info-tab'

import {
  applyLabelsToRows,
  clickRow,
  getRow,
  getTable,
} from '@commands/datatable'
import { Intercepts } from '@utils/index'

const datatableCy = 'vnets'

const getVNetTable = getTable({
  datatableCy,
  searchCy: 'search-vnets',
  poolIntercept: Intercepts.SUNSTONE.NETWORKS,
})

const getVNetRow = getRow({
  getTableFn: getVNetTable,
  prefixRowId: 'network-',
})

const clickVNetRow = clickRow({
  getRowFn: getVNetRow,
  showIntercept: Intercepts.SUNSTONE.NETWORK,
  datatableCy,
})

const applyLabelsToVnetRows = applyLabelsToRows({
  clickRowFn: clickVNetRow,
  updateIntercept: Intercepts.SUNSTONE.NETWORK_UPDATE,
})

Cypress.Commands.add('getVNetTable', getVNetTable)
Cypress.Commands.add('getVNetRow', getVNetRow)
Cypress.Commands.add('clickVNetRow', clickVNetRow)
Cypress.Commands.add('applyLabelsToVnetRows', applyLabelsToVnetRows)
