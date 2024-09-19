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

/**
 * @param {object} vdc - VDC template
 * @param {object} row - VDC element
 */
const vdcGUI = (vdc, row) => {
  cy.navigateMenu('system', 'VDCs')
  cy.vdcGUI(vdc, row).its('response.body.id').should('eq', 200)
}

/**
 * @param {object} vdc - VDC Template
 */
const deleteVdc = (vdc) => {
  if (vdc.id === undefined) return
  cy.navigateMenu('system', 'VDCs')
  cy.deleteVdc(vdc)
    .its('response.body.id')
    .should('eq', 200)
    .then(() => {
      cy.getVdcTable({ search: vdc.name }).within(() => {
        cy.get(`[role='row'][data-cy$='${vdc.id}']`).should('not.exist')
      })
    })
}

/**
 * @param {object} vdc - VDC template
 * @param {object} row - VDC element
 */
const vdcInfo = (vdc, row) => {
  if (row.id === undefined) return
  cy.navigateMenu('system', 'VDCs')
  cy.clickVdcRow(row).then(() => {
    cy.validateVdcInfo({ ...vdc, id: row.id })
  })
}

/**
 * @param {object} row - VDC element
 * @param {string} newName - new VDC name
 */
const renameVdc = (row, newName) => {
  if (row.id === undefined) return
  cy.navigateMenu('system', 'VDCs')
  cy.clickVdcRow(row)
    .then(() => cy.renameResource(newName))
    .then(() => (row.name = newName))
    .then(() => cy.getVdcRow(row).contains(newName))
}

module.exports = {
  vdcGUI,
  deleteVdc,
  vdcInfo,
  renameVdc,
}
