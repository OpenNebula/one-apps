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
import { clickRow, getRow, getTable } from '@commands/datatable'
import '@commands/zone/info-tab'
import { Intercepts } from '@utils/index'

const datatableCy = 'zones'

const getZoneTable = getTable({
  datatableCy,
  searchCy: 'search-zones',
  poolIntercept: Intercepts.SUNSTONE.ZONES,
})

const getZoneRow = getRow({
  getTableFn: getZoneTable,
  prefixRowId: 'zone-',
})

const clickZoneRow = clickRow({
  getRowFn: getZoneRow,
  showIntercept: Intercepts.SUNSTONE.ZONE,
  datatableCy,
})

Cypress.Commands.add('getZoneTable', getZoneTable)
Cypress.Commands.add('getZoneRow', getZoneRow)
Cypress.Commands.add('clickZoneRow', clickZoneRow)
