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

import {
  applyLabelsToRows,
  clickRow,
  getRow,
  getTable,
  getTableWaiting,
} from '@commands/datatable'
import { booleanToString, timeToString } from '@commands/helpers'
import { Image } from '@models'
import { Intercepts } from '@utils/index'

const getBackupsTableWaiting = getTableWaiting({
  datatableCy: 'backups',
  searchCy: 'search-backups',
  poolIntercept: Intercepts.SUNSTONE.IMAGES,
})

const getBackupsTable = getTable({
  datatableCy: 'backups',
  searchCy: 'search-backups',
  poolIntercept: Intercepts.SUNSTONE.IMAGES,
})

const getBackupsRow = getRow({
  getTableFn: getBackupsTable,
  prefixRowId: 'image-',
})

const clickBackupsRow = clickRow({
  getRowFn: getBackupsRow,
  showIntercept: Intercepts.SUNSTONE.IMAGE,
})

const applyLabelsToBackupsRows = applyLabelsToRows({
  clickRowFn: clickBackupsRow,
  updateIntercept: Intercepts.SUNSTONE.IMAGE_UPDATE,
})

/**
 * Validate Info bakcup.
 *
 * @param {Image} image - VM
 */
const validateBackupInfo = (image) => {
  const { ID, NAME, DATASTORE, SIZE, REGTIME, PERSISTENT } = image.json
  cy.navigateTab('info').within(() => {
    cy.getBySel('id').should('have.text', ID)
    cy.getBySel('name').should('have.text', NAME)
    cy.getBySel('datastoreId').contains(DATASTORE)
    cy.getBySel('size').contains(SIZE)
    cy.getBySel('regtime').should('have.text', timeToString(REGTIME))
    cy.getBySel('persistent').should('have.text', booleanToString(PERSISTENT))
    cy.getBySel('diskType').should('have.text', 'FILE')
    cy.getBySel('type').should('have.text', 'BACKUP')
    cy.validateOwnership(image)
  })
}

Cypress.Commands.add('getBackupsTable', getBackupsTable)
Cypress.Commands.add('getBackupsTableWaiting', getBackupsTableWaiting)
Cypress.Commands.add('getBackupsRow', getBackupsRow)
Cypress.Commands.add('clickBackupsRow', clickBackupsRow)
Cypress.Commands.add('applyLabelsToBackupsRows', applyLabelsToBackupsRows)
Cypress.Commands.add('validateBackupInfo', validateBackupInfo)
