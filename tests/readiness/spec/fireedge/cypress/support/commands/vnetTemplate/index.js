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

import '@commands/vnetTemplate/actions'
import '@commands/vnetTemplate/info-tab'

import {
  applyLabelsToRows,
  clickRow,
  getRow,
  getTable,
} from '@commands/datatable'
import { Intercepts } from '@utils/index'

const datatableCy = 'vnet-templates'

const getVNTemplateTable = getTable({
  datatableCy,
  searchCy: 'search-vnet-templates',
  poolIntercept: Intercepts.SUNSTONE.NETWORK_TEMPLATES,
})

const getVNTemplateRow = getRow({
  getTableFn: getVNTemplateTable,
  prefixRowId: 'network-template-',
})

const clickVNTemplateRow = clickRow({
  getRowFn: getVNTemplateRow,
  showIntercept: Intercepts.SUNSTONE.NETWORK_TEMPLATE,
  datatableCy,
})

const applyLabelsToVnetRows = applyLabelsToRows({
  clickRowFn: clickVNTemplateRow,
  updateIntercept: Intercepts.SUNSTONE.NETWORK_TEMPLATE_UPDATE,
})

Cypress.Commands.add('getVNTemplateTable', getVNTemplateTable)
Cypress.Commands.add('getVNTemplateRow', getVNTemplateRow)
Cypress.Commands.add('clickVNTemplateRow', clickVNTemplateRow)
Cypress.Commands.add('applyLabelsToVnetRows', applyLabelsToVnetRows)
