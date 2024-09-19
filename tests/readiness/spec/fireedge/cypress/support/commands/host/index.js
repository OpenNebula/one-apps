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

import '@commands/host/actions'
import '@commands/host/info-tab'
import '@commands/host/numa-tab'

import {
  applyLabelsToRows,
  clickRow,
  getRow,
  getTable,
} from '@commands/datatable'
import { Intercepts } from '@utils/index'

const datatableCy = 'hosts'

const getHostTable = getTable({
  datatableCy,
  searchCy: 'search-hosts',
  poolIntercept: Intercepts.SUNSTONE.HOSTS,
})

const getHostRow = getRow({
  getTableFn: getHostTable,
  prefixRowId: 'host-',
})

const clickHostRow = clickRow({
  getRowFn: getHostRow,
  showIntercept: Intercepts.SUNSTONE.HOST,
  datatableCy,
})

const applyLabelsToHostRows = applyLabelsToRows({
  clickRowFn: clickHostRow,
  updateIntercept: Intercepts.SUNSTONE.HOST_UPDATE,
})

Cypress.Commands.add('getHostTable', getHostTable)
Cypress.Commands.add('getHostRow', getHostRow)
Cypress.Commands.add('clickHostRow', clickHostRow)
Cypress.Commands.add('applyLabelsToHostRows', applyLabelsToHostRows)
