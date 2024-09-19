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

import { FORCE } from '@support/commands/constants'
import { fillVdcGUI } from '@support/commands/vdc/create'
import { Vdc as VdcDoc, configSelectVdc } from '@support/commands/vdc/jsdocs'
import { Intercepts, createIntercept } from '@support/utils'

/**
 * Delete VDC.
 *
 * @param {configSelectVdc} vdc - config lock
 */
const deleteVdc = (vdc = {}) => {
  const interceptDelete = createIntercept(Intercepts.SUNSTONE.VDC_DELETE)

  cy.clickVdcRow(vdc)
  cy.getBySel('action-vdc_delete').click(FORCE)

  cy.getBySel(`modal-delete`)
    .should('exist')
    .then(($dialog) => {
      cy.wrap($dialog).find(`[data-cy=dg-accept-button]`).click(FORCE)

      return cy.wait(interceptDelete)
    })
}

/**
 * Create or Update VDC via GUI.
 *
 * @param {VdcDoc} vdc - template
 * @param {VdcDoc} row - row
 * @returns {Cypress.Chainable<Cypress.Response>} create vdc response
 */
const vdcGUI = (vdc, row) => {
  let interceptVdcAllocate = createIntercept(Intercepts.SUNSTONE.VDC_CREATE)

  if (row) {
    interceptVdcAllocate = createIntercept(Intercepts.SUNSTONE.VDC_UPDATE)
    cy.clickVdcRow(row)
    cy.getBySel('action-vdc_update_dialog').click()
  } else {
    cy.getBySel('action-create_dialog').click()
  }

  fillVdcGUI(vdc)

  cy.getBySel('stepper-next-button').click(FORCE)

  return cy.wait(interceptVdcAllocate)
}

const validateInfoTab = ({ id, name }) => {
  cy.navigateTab('info').within(() => {
    // INFORMATION
    cy.getBySel('id').should('have.text', id)
    cy.getBySel('name').should('have.text', name)
  })
}

const findResource = (id, table) => {
  const nameFnTable = `get${table}Table`

  cy[nameFnTable]({ search: id }).within(() => {
    cy.get(`[role='row'][data-cy$='${id}']`).should('exist')
  })
}

const validateResourceTab = (dataCyTab, table, resource) => {
  cy.navigateTab(dataCyTab).within(() => {
    if (Array.isArray(resource)) {
      resource.forEach((res) => {
        findResource(res.id, table)
      })
    } else {
      findResource(resource.id, table)
    }
  })
}

/**
 * Validate info VDC via GUI.
 *
 * @param {VdcDoc} vdc - template
 */
const validateVdcInfo = (vdc) => {
  validateInfoTab(vdc)
  validateResourceTab('groups', 'Group', vdc.groups)
  validateResourceTab('clusters', 'Cluster', vdc.clusters)
  validateResourceTab('datastores', 'Datastore', vdc.datastores)
  validateResourceTab('hosts', 'Host', vdc.hosts)
  validateResourceTab('vnets', 'VNet', vdc.networks)
}

Cypress.Commands.add('vdcGUI', vdcGUI)
Cypress.Commands.add('deleteVdc', deleteVdc)
Cypress.Commands.add('validateVdcInfo', validateVdcInfo)
