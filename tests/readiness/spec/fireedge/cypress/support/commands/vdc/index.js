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

import '@commands/vdc/actions'

import { clickRow, getRow, getTable } from '@commands/datatable'
import { Intercepts } from '@utils/index'

const getVdcTable = getTable({
  datatableCy: 'vdcs',
  searchCy: 'search-vdcs',
  poolIntercept: Intercepts.SUNSTONE.VDCS,
})

const getVdcRow = getRow({
  getTableFn: getVdcTable,
  prefixRowId: 'vdc-',
})

const clickVdcRow = clickRow({
  getRowFn: getVdcRow,
  showIntercept: Intercepts.SUNSTONE.VDC,
})

Cypress.Commands.add('getVdcTable', getVdcTable)
Cypress.Commands.add('getVdcRow', getVdcRow)
Cypress.Commands.add('clickVdcRow', clickVdcRow)
