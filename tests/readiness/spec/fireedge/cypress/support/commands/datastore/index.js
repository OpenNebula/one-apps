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
import '@commands/datastore/actions'

import { Intercepts } from '@utils/index'

import {
  applyLabelsToRows,
  clickRow,
  getRow,
  getRows,
  getTable,
} from '@commands/datatable'

const datatableCy = 'datastores'

const getDatastoreTable = getTable({
  datatableCy,
  searchCy: 'search-datastores',
  poolIntercept: Intercepts.SUNSTONE.DATASTORES,
})

const getDatastoreRow = getRow({
  getTableFn: getDatastoreTable,
  prefixRowId: 'datastore-',
})

const clickDatastoreRow = clickRow({
  getRowFn: getDatastoreRow,
  showIntercept: Intercepts.SUNSTONE.DATASTORE,
  datatableCy,
})

const applyLabelsToDatastoreRows = applyLabelsToRows({
  clickRowFn: clickDatastoreRow,
  updateIntercept: Intercepts.SUNSTONE.DATASTORE_UPDATE,
})

// Get all rows in a datastore table
const getDatastoreRows = getRows({
  poolIntercept: Intercepts.SUNSTONE.DATASTORES,
  datatableCy: 'datastores',
  getTableFn: getDatastoreTable,
  results: [],
})

Cypress.Commands.add('getDatastoreTable', getDatastoreTable)
Cypress.Commands.add('getDatastoreRow', getDatastoreRow)
Cypress.Commands.add('clickDatastoreRow', clickDatastoreRow)
Cypress.Commands.add('applyLabelsToDatastoreRows', applyLabelsToDatastoreRows)
Cypress.Commands.add('getDatastoreRows', getDatastoreRows)
