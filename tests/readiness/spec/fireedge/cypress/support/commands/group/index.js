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
import '@commands/group/actions'
import {
  applyLabelsToRows,
  clickRow,
  getRow,
  getTable,
} from '@commands/datatable'
import { Intercepts } from '@utils/index'

const datatableCy = 'groups'

const getGroupTable = getTable({
  datatableCy,
  searchCy: 'search-groups',
  poolIntercept: Intercepts.SUNSTONE.GROUPS,
})

const getGroupRow = getRow({
  getTableFn: getGroupTable,
  prefixRowId: 'group-',
})

const clickGroupRow = clickRow({
  getRowFn: getGroupRow,
  showIntercept: Intercepts.SUNSTONE.GROUP,
  datatableCy,
})

const applyLabelsToGroupRows = applyLabelsToRows({
  clickRowFn: clickGroupRow,
  updateIntercept: Intercepts.SUNSTONE.GROUP_UPDATE,
})

Cypress.Commands.add('getGroupTable', getGroupTable)
Cypress.Commands.add('getGroupRow', getGroupRow)
Cypress.Commands.add('clickGroupRow', clickGroupRow)
Cypress.Commands.add('applyLabelsToGroupRows', applyLabelsToGroupRows)
