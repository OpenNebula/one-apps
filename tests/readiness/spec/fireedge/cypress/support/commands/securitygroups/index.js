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

import '@commands/securitygroups/actions'

import { Intercepts } from '@utils/index'
import {
  getTable,
  getRow,
  clickRow,
  applyLabelsToRows,
} from '@commands/datatable'

const getSecGroupTable = getTable({
  datatableCy: 'secgroup',
  searchCy: 'search-secgroup',
  poolIntercept: Intercepts.SUNSTONE.SECGROUPS,
})

const getSecGroupRow = getRow({
  getTableFn: getSecGroupTable,
  prefixRowId: 'secgroup-',
})

const clickSecGroupRow = clickRow({
  getRowFn: getSecGroupRow,
  showIntercept: Intercepts.SUNSTONE.SECGROUP,
})

const applyLabelsToSecGroupRows = applyLabelsToRows({
  clickRowFn: clickSecGroupRow,
  updateIntercept: Intercepts.SUNSTONE.SECGROUP_UPDATE,
})

Cypress.Commands.add('getSecGroupTable', getSecGroupTable)
Cypress.Commands.add('getSecGroupRow', getSecGroupRow)
Cypress.Commands.add('clickSecGroupRow', clickSecGroupRow)
Cypress.Commands.add('applyLabelsToSecGroupRows', applyLabelsToSecGroupRows)
