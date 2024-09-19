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
 * Deletes a vmgroup.
 *
 * @param {object} vmgroup - VM Group template.
 */
const vmgroupDelete = (vmgroup) => {
  if (vmgroup.id === undefined) return
  cy.navigateMenu('templates', 'VM Groups')
  cy.clickVmGroupRow({ id: vmgroup.id }).then(() => {
    cy.deleteVmGroup().then(() => {
      cy.getVmGroupTable({ search: vmgroup.name }).within(() => {
        cy.get(`[role='row'][data-cy$='${vmgroup.id}']`).should('not.exist')
      })
    })
  })
}

/**
 * Validates vmgroup information.
 *
 * @param {object} vmgroup - VmGroup template.
 * @param {object} row - Holds vmgroup ID property.
 */
const vmgroupInfo = (vmgroup, row) => {
  if (row.id === undefined) return
  cy.navigateMenu('system', 'VmGroups')
  cy.clickVmGroupRow(row).then(() => {
    cy.validateVmGroupInfo({ ...vmgroup, id: row.id })
  })
}

/**
 * Creates a new vmgroup via GUI.
 *
 * @param {object} vmgroup - VM Group template.
 */
const vmgroupGUI = (vmgroup) => {
  cy.navigateMenu('templates', 'VM Groups')
  cy.vmgroupGUI(vmgroup)
}

/**
 * @param {object} vmgroup - VM Group template.
 */
const vmgroupUpdate = (vmgroup) => {
  cy.navigateMenu('templates', 'VM Groups')
  cy.vmgroupUpdate(vmgroup)
}

/**
 * Change vmgroup permissions.
 *
 * @param {object} resource - Permissions definition
 */
const vmgroupPermissions = (resource) => {
  cy.changePermissionsVmGroup(resource)
}

/**
 * Locks a vmgroup.
 *
 * @param {object} vmgroup - VM Group template.
 */
const vmgroupLock = (vmgroup) => {
  cy.navigateMenu('templates', 'VM Groups')
  cy.clickVmGroupRow({ id: vmgroup.id }).then(() => {
    cy.lockVmGroup(vmgroup)
  })
}

/**
 * Unlocks a vmgroup.
 *
 * @param {object} vmgroup - VM Group template.
 */
const vmgroupUnlock = (vmgroup) => {
  cy.navigateMenu('templates', 'VM Groups')
  cy.clickVmGroupRow({ id: vmgroup.id }).then(() => {
    cy.unlockVmGroup(vmgroup)
  })
}

/**
 * Verifies VM group Vm monitoring.
 *
 * @param {object} vmgroup - Vm group
 * @param {string|number} vmname - VM id
 */
const vmgroupMonitoring = (vmgroup, vmname) => {
  cy.navigateMenu('templates', 'VM Groups')
  cy.clickVmGroupRow({ id: vmgroup.id }).then(() => {
    cy.validateVmGroupMonitoring(vmname)
  })
}

module.exports = {
  vmgroupGUI,
  vmgroupUpdate,
  vmgroupDelete,
  vmgroupMonitoring,
  vmgroupInfo,
  vmgroupPermissions,
  vmgroupLock,
  vmgroupUnlock,
}
