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
import { hasRestrictedAttributes, checkForm } from '@support/utils'

/**
 * Validate restricted attributes in VM storage tab.
 *
 * @param {object} restrictedAttributes - Map of restricted attributes
 * @param {object} vm - VM to check
 * @param {string} check - Condition to check
 */
const validateRestrictedAttributesVmScheduleActions = (
  restrictedAttributes,
  vm,
  check
) => {
  const { SCHED_ACTION = [] } = vm.json.TEMPLATE
  const ensuredSchedActions = Array.isArray(SCHED_ACTION)
    ? SCHED_ACTION
    : [SCHED_ACTION]

  if (ensuredSchedActions.length === 0) return

  cy.navigateTab('sched_actions')

  ensuredSchedActions.forEach(({ ID, ...sched }) => {
    // If exists a SCHED_ACTION restricted attribute in the sched action and it's not admin, delete button has to be disabled
    hasRestrictedAttributes(sched, 'SCHED_ACTION', restrictedAttributes) &&
      cy.getBySelLike(`sched-delete-${ID}`).should(check)

    // Click on update button
    cy.getBySel(`sched-update-${ID}`).click()

    // Check update step
    cy.get('[role="presentation"]').then(() =>
      checkForm(restrictedAttributes.SCHED_ACTION, check)
    )
    cy.getBySel('dg-cancel-button').click()
  })
}

Cypress.Commands.add(
  'validateRestrictedAttributesVmScheduleActions',
  validateRestrictedAttributesVmScheduleActions
)
