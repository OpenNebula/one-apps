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

import { VmGroup as VmGroupDocs } from '@support/commands/vmgroup/jsdocs'

/**
 * Fills in the configuration settings for a vmgroup.
 *
 * @param {VmGroupDocs} vmgroup - The vmgroup whose configuration settings are to be filled
 * @param {object} isUpdate - Update configuration
 */
const fillConfiguration = (vmgroup, isUpdate) => {
  const { NAME, DESCRIPTION } = vmgroup
  const { DISABLED_NAME = false } = isUpdate

  !DISABLED_NAME && NAME && cy.getBySel('general-NAME').clear().type(NAME)
  DESCRIPTION && cy.getBySel('general-DESCRIPTION').clear().type(DESCRIPTION)
}

/**
 * Fills in the role definitions for a vmgroup.
 *
 * @param {VmGroupDocs} vmgroup - The vmgroup whose configuration settings are to be filled
 */
const fillRoleDefinitions = (vmgroup) => {
  const addRole = (name, policy, roleIndex) => {
    name && cy.getBySel(`role-name-${roleIndex}`).clear().type(name)
    policy &&
      cy.selectMUIDropdownOption('policy-selector', `policy-${policy}`, {
        timeout: 200,
      })
  }
  const { ROLE } = vmgroup
  if (ROLE !== undefined) {
    ROLE.forEach((role, roleIndex) => {
      !!ROLE.length - 1 - roleIndex && cy.getBySel('add-role').click()
      addRole(role.NAME, role.POLICY, roleIndex)
    })
  }
}

/**
 * Fills in the role to role definitions for a vmgroup.
 *
 * @param {object} ROLEGROUPS - Role to role definitions object
 */
const fillRoleToRole = (ROLEGROUPS) => {
  const { ROLE } = ROLEGROUPS
  if (ROLE !== undefined) {
    ;['AFFINED', 'ANTI_AFFINED'].forEach((policy) => {
      cy.getBySel(`policy-${policy}`).click()
      ROLE?.[policy].forEach((group) => {
        group.split(',').forEach((role) => {
          cy.getBySel(`role-${role.trim()}`).click()
        })
        cy.getBySel('add-group').click()
      })
    })
  }
}

/**
 * Fills in the GUI settings for a vmgroup.
 *
 * @param {VmGroupDocs} vmgroup - The vmgroup whose GUI settings are to be filled
 * @param {object} isUpdate - Update configuration
 */
const fillVmGroupGUI = (vmgroup, isUpdate = {}) => {
  const { DEFINITIONS, GROUPS } = vmgroup
  fillConfiguration(DEFINITIONS, isUpdate)
  cy.getBySel('stepper-next-button').click()
  fillRoleDefinitions(DEFINITIONS, isUpdate)
  cy.getBySel('stepper-next-button').click()
  fillRoleToRole(GROUPS)
  cy.getBySel('stepper-next-button').click()
}

export {
  fillConfiguration,
  fillRoleDefinitions,
  fillRoleToRole,
  fillVmGroupGUI,
}
