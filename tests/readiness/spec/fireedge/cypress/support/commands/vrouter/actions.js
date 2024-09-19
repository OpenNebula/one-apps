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

import { Intercepts, createIntercept } from '@support/utils'

const vrouterinstanceValidate = (vrouter, maxAttempts = 30) => {
  cy.clickVRouterRow({ id: vrouter.id }).then(() => {
    const checkState = (attempt = 0) => {
      cy.getBySel('detail-refresh').click()
      cy.getBySel('state').then(($state) => {
        if ($state.text() !== 'RUNNING' && attempt < maxAttempts) {
          cy.wait(1000) // eslint-disable-line cypress/no-unnecessary-waiting
          checkState(attempt + 1)
        }
      })
    }

    checkState()
  })
}

/**
 * @param {object} resource - OpenNebula resource to be updated
 */
const changePermissionsVRouter = (resource) => {
  const { VRouterInstance, NEW_PERMISSIONS } = resource

  cy.clickVRouterRow({ id: VRouterInstance.id })
    .then(() =>
      cy.changePermissions(NEW_PERMISSIONS, Intercepts.SUNSTONE.VROUTER_CHMOD, {
        delay: true,
      })
    )
    .then(() => VRouterInstance.info())
    .then(() => cy.validatePermissions(NEW_PERMISSIONS))
}

/**
 * @param {object} vrouter - OpenNebula resource to be updated
 * @param {string} newName - New name
 */
const renameVRouter = (vrouter, newName) => {
  cy.clickVRouterRow({ id: vrouter.id }).then(() => {
    cy.renameResource(newName, Intercepts.SUNSTONE.VROUTER)
      .then(() => (vrouter.name = newName))
      .then(() => cy.getVRouterRow(vrouter).contains(newName))
  })
}

const deleteVRouter = (vrouter) => {
  const interceptDeleteVRouter = createIntercept(
    Intercepts.SUNSTONE.VROUTER_DELETE
  )

  cy.clickVRouterRow({ id: vrouter.id }).then(() => {
    cy.getBySel('action-delete').click()

    cy.getBySel(`modal-delete`)
      .should('exist')
      .then(($dialog) => {
        cy.wrap($dialog).find(`[data-cy=dg-accept-button]`).click()

        return cy
          .wait(interceptDeleteVRouter)
          .its('response.statusCode')
          .should(
            'satisfy',
            (statusCode) => statusCode === 200 || statusCode === 304
          )
      })
  })
}

Cypress.Commands.add('validateVRouterInstance', vrouterinstanceValidate)
Cypress.Commands.add('changePermissionsVRouter', changePermissionsVRouter)
Cypress.Commands.add('renameVRouter', renameVRouter)
Cypress.Commands.add('deleteVRouter', deleteVRouter)
