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
import '@commands/acl/actions'
import { clickRow, getRow, getTable } from '@commands/datatable'
import { Intercepts } from '@utils/index'

const datatableCy = 'acls'

const getAclTable = getTable({
  datatableCy,
  searchCy: 'search-acls',
  poolIntercept: Intercepts.SUNSTONE.ACLS,
})

const getAclRow = getRow({
  getTableFn: getAclTable,
  prefixRowId: 'acl-',
})

const clickAclRow = clickRow({
  getRowFn: getAclRow,
  showIntercept: Intercepts.SUNSTONE.ACLS,
  datatableCy,
})

Cypress.Commands.add('getAclTable', getAclTable)
Cypress.Commands.add('getAclRow', getAclRow)
Cypress.Commands.add('clickAclRow', clickAclRow)
