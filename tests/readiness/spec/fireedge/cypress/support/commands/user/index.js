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

import '@commands/user/actions'
import { Intercepts } from '@utils/index'
import {
  getTable,
  getRow,
  clickRow,
  applyLabelsToRows,
} from '@commands/datatable'

const getUserTable = getTable({
  datatableCy: 'users',
  searchCy: 'search-users',
  poolIntercept: Intercepts.SUNSTONE.USERS,
})

const getUserRow = getRow({
  getTableFn: getUserTable,
  prefixRowId: 'user-',
})

const clickUserRow = clickRow({
  getRowFn: getUserRow,
  showIntercept: Intercepts.SUNSTONE.USER,
})

const applyLabelsToUserRows = applyLabelsToRows({
  clickRowFn: clickUserRow,
  updateIntercept: Intercepts.SUNSTONE.USER_UPDATE,
})

Cypress.Commands.add('getUserTable', getUserTable)
Cypress.Commands.add('getUserRow', getUserRow)
Cypress.Commands.add('clickUserRow', clickUserRow)
Cypress.Commands.add('applyLabelsToUserRows', applyLabelsToUserRows)
