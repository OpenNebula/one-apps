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

import '@commands/cluster/actions'

import {
  applyLabelsToRows,
  clickRow,
  getRow,
  getTable,
} from '@commands/datatable'
import { Intercepts } from '@support/utils'

const datatableCy = 'clusters'

const getClusterTable = getTable({
  datatableCy,
  searchCy: 'search-clusters',
  poolIntercept: Intercepts.SUNSTONE.CLUSTERS,
})

const getClusterRow = getRow({
  getTableFn: getClusterTable,
  prefixRowId: 'cluster-',
})

const clickClusterRow = clickRow({
  getRowFn: getClusterRow,
  showIntercept: Intercepts.SUNSTONE.CLUSTER,
  datatableCy,
})

const applyLabelsToClusterRows = applyLabelsToRows({
  clickRowFn: clickClusterRow,
  updateIntercept: Intercepts.SUNSTONE.CLUSTER_UPDATE,
})

Cypress.Commands.add('getClusterTable', getClusterTable)
Cypress.Commands.add('getClusterRow', getClusterRow)
Cypress.Commands.add('clickClusterRow', clickClusterRow)
Cypress.Commands.add('applyLabelsToClusterRows', applyLabelsToClusterRows)
