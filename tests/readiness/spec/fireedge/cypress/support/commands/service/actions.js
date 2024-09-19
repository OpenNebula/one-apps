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

const serviceinstanceValidate = (service, maxAttempts = 30) => {
  cy.clickServiceRow({ id: service.id }).then(() => {
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
const changePermissionsService = (resource) => {
  const { ServiceInstance, NEW_PERMISSIONS } = resource

  cy.clickServiceRow({ id: ServiceInstance.id })
    .then(() =>
      cy.changePermissions(NEW_PERMISSIONS, Intercepts.SUNSTONE.SERVICE_CHMOD, {
        delay: true,
      })
    )
    .then(() => ServiceInstance.info())
    .then(() => cy.validatePermissions(NEW_PERMISSIONS))
}

/**
 * @param {object} service - OpenNebula resource to be updated
 * @param {string} newName - New name
 */
const renameService = (service, newName) => {
  cy.clickServiceRow({ id: service.id }).then(() => {
    cy.renameResource(newName, Intercepts.SUNSTONE.SERVICE)
      .then(() => (service.name = newName))
      .then(() => cy.getServiceRow(service).contains(newName))
  })
}

const deleteService = (service) => {
  const interceptDeleteService = createIntercept(
    Intercepts.SUNSTONE.SERVICE_RECOVER_DELETE
  )

  cy.clickServiceRow({ id: service.id }).then(() => {
    cy.getBySel('action-service-recover').click()

    cy.getBySel('action-recover').eq(1).click() // Second option
    cy.getBySel('dg-accept-button').click()
  })

  return cy
    .wait(interceptDeleteService)
    .its('response.statusCode')
    .should('eq', 200)
}

const addRole = (service, role) => {
  const interceptAddRole = createIntercept(Intercepts.SUNSTONE.SERVICE_ADD_ROLE)
  const { General, Extra, Elasticity } = role

  const { name, cardinality } = General
  const { vmTemplateId } = Extra
  const { minVms, maxVms, cooldown } = Elasticity

  cy.clickServiceRow({ id: service.id }).then(() => {
    cy.navigateTab('roles').within(() => {
      cy.getBySel('AddRole').click()
    })

    name && cy.getBySel('role-roleconfig-name').clear().type(name)
    cardinality &&
      cy.getBySel('role-roleconfig-cardinality').clear().type(cardinality)

    vmTemplateId && cy.getBySel(`role-vmtemplate-${vmTemplateId}`).click()
    minVms &&
      cy
        .getBySel(`elasticity-roleconfig-MINMAXVMS-0-min_vms`)
        .clear()

        .type(minVms)

    maxVms &&
      cy
        .getBySel(`elasticity-roleconfig-MINMAXVMS-0-max_vms`)
        .clear()
        .type(maxVms)

    cooldown &&
      cy
        .getBySel(`elasticity-roleconfig-MINMAXVMS-0-cooldown`)
        .clear()
        .type(cooldown)

    cy.getBySel('roleconfig-addrole').click()
  })

  return cy.wait(interceptAddRole).its('response.statusCode').should('eq', 200)
}

const servicePerformActionRole = (service, action, role) => {
  // Create interceptor for the perform action request
  const interceptPerformActionRole = createIntercept(
    Intercepts.SUNSTONE.SERVICE_PERFORM_ACTION_ROLE
  )

  // Select service
  cy.clickServiceRow({ id: service.id }).then(() => {
    cy.navigateTab('sched_actions').within(() => {
      cy.getBySel('perform_action').click()
    })

    // Select the type of action
    action &&
      cy.getBySelEndsWith('-ACTION').then(({ selector }) => {
        cy.get(selector)
          .click()
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    action?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    action === $el?.text()
                  ) {
                    cy.wrap($el).click()

                    return false // Break
                  }
                })
            })
          })
      })

    // Select the role
    role &&
      cy.getBySelEndsWith('-ROLE').then(({ selector }) => {
        cy.get(selector)
          .click()
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    role?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    role === $el?.text()
                  ) {
                    cy.wrap($el).click()

                    return false // Break
                  }
                })
            })
          })
      })

    cy.getBySel('dg-accept-button').click()
  })

  return cy
    .wait(interceptPerformActionRole)
    .its('response.statusCode')
    .should('eq', 200)
}

Cypress.Commands.add('validateServiceInstance', serviceinstanceValidate)
Cypress.Commands.add('changePermissionsService', changePermissionsService)
Cypress.Commands.add('renameService', renameService)
Cypress.Commands.add('serviceAddRole', addRole)
Cypress.Commands.add('deleteService', deleteService)
Cypress.Commands.add('servicePerformActionRole', servicePerformActionRole)
