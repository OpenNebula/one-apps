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

import '@commands/vroutertemplate/actions'
import { Intercepts } from '@utils/index'
import { getTable, getRow, clickRow } from '@commands/datatable'

const getVrTemplateTable = getTable({
  datatableCy: 'vrouter-templates',
  searchCy: 'search-vrouter-templates',
  poolIntercept: Intercepts.SUNSTONE.VROUTERTEMPLATES,
})

const getVrTemplateRow = getRow({
  getTableFn: getVrTemplateTable,
  prefixRowId: 'template-',
})

const clickVrTemplateRow = clickRow({
  getRowFn: getVrTemplateRow,
  showIntercept: Intercepts.SUNSTONE.VROUTERTEMPLATE,
  clickPosition: 'bottom',
})

Cypress.Commands.add('getVrTemplateTable', getVrTemplateTable)
Cypress.Commands.add('getVrTemplateRow', getVrTemplateRow)
Cypress.Commands.add('clickVrTemplateRow', clickVrTemplateRow)
