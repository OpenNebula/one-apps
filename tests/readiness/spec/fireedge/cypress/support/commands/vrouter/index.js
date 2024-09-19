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
import '@commands/vrouter/actions'
import { Intercepts } from '@utils/index'
import { getTable, getRow, clickRow } from '@commands/datatable'

const getVRouterTable = getTable({
  datatableCy: 'vrouters',
  searchCy: 'search-vrouters',
  poolIntercept: Intercepts.SUNSTONE.VROUTERS,
})

const getVRouterRow = getRow({
  getTableFn: getVRouterTable,
  prefixRowId: 'vrouter-',
})

const clickVRouterRow = clickRow({
  getRowFn: getVRouterRow,
  showIntercept: Intercepts.SUNSTONE.VROUTER,
  clickPosition: 'bottom',
})

Cypress.Commands.add('getVRouterTable', getVRouterTable)
Cypress.Commands.add('getVRouterRow', getVRouterRow)
Cypress.Commands.add('clickVRouterRow', clickVRouterRow)
