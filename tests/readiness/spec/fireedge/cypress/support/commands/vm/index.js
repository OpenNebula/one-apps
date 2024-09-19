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

import '@commands/vm/actions'
import '@commands/vm/instantiate'
import '@commands/vm/info-tab'
import '@commands/vm/configuration-tab'
import '@commands/vm/network-tab'
import '@commands/vm/pci-tab'
import '@commands/vm/storage-tab'
import '@commands/vm/snapshot-tab'
import '@commands/vm/history-tab'
import '@commands/vm/table'
import '@commands/vm/schedule-tab'

import { Intercepts } from '@utils/index'
import {
  getTable,
  getRow,
  clickRow,
  applyLabelsToRows,
} from '@commands/datatable'

const getVmTable = getTable({
  datatableCy: 'vms',
  searchCy: 'search-vms',
  poolIntercept: Intercepts.SUNSTONE.VMS,
})

const getVmRow = getRow({
  getTableFn: getVmTable,
  prefixRowId: 'vm-',
})

const clickVmRow = clickRow({
  getRowFn: getVmRow,
  showIntercept: Intercepts.SUNSTONE.VM,
})

const applyLabelsToVmRows = applyLabelsToRows({
  clickRowFn: clickVmRow,
  updateIntercept: Intercepts.SUNSTONE.VM_UPDATE,
})

Cypress.Commands.add('getVmTable', getVmTable)
Cypress.Commands.add('getVmRow', getVmRow)
Cypress.Commands.add('clickVmRow', clickVmRow)
Cypress.Commands.add('applyLabelsToVmRows', applyLabelsToVmRows)
