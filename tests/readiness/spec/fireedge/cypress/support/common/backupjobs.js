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
const { VirtualMachine, VmTemplate } = require('@models')
const { PermissionsGui } = require('@support/commands/common')
const { Intercepts } = require('@support/utils')

const navigateMenu = () => cy.navigateMenu('storage', 'BackupJobs')

/**
 * @param {object} resources - resources to delete
 * @param {object[]} resources.VMS - vms
 * @param {string} resources.VM_NAME - VmTemplate name
 * @param {object} resources.HOST - host
 * @param {object} resources.BACKUPJOB_GUI - backup job created by GUI
 */
const afterAllBackupJobsTest = ({ VMS, VM_NAME, HOST, BACKUPJOB_GUI } = {}) => {
  VMS.forEach(({ data }) => data?.terminate(true))
  const template = new VmTemplate(VM_NAME)
  template
    .info()
    .then(() => template.delete(true))
    .then(() => HOST.delete())
    .then(() => BACKUPJOB_GUI.info())
    .then(() => BACKUPJOB_GUI.delete())
}

/**
 * @param {object} backupjob - Backup Job to lock
 */
const lockBackupJob = (backupjob) => {
  if (backupjob.id === undefined) return
  navigateMenu()
  cy.lockBackupJob(backupjob).then(() =>
    cy
      .navigateTab('info')
      .within(() => cy.getBySel('locked').should('not.have.text', '-'))
  )
}

/**
 * @param {object} backupjob - Backup Job to lock
 */
const unlockBackupJob = (backupjob) => {
  if (backupjob.id === undefined) return
  navigateMenu()
  cy.unlockBackupJob(backupjob).then(() =>
    cy
      .navigateTab('info')
      .within(() => cy.getBySel('locked').should('have.text', '-'))
  )
}

/**
 * @param {object} backupjob - Backup Job to make non persistent
 * @param {PermissionsGui} permissions - Permissions to change
 */
const changeBackupJobsPermissions = (backupjob, permissions) => {
  if (backupjob.id === undefined) return
  navigateMenu()
  cy.clickBackupsJobsRow(backupjob)
    .then(() =>
      cy.changePermissions(
        permissions,
        Intercepts.SUNSTONE.BACKUPJOB_CHANGE_MOD
      )
    )
    .then(() => cy.validatePermissions(permissions))
}

/**
 * @param {object} backupjob - Backup Job to change ownership
 * @param {object} newOwner - New owner
 */
const changeBackupJobsOwnership = (backupjob, newOwner) => {
  if (backupjob.id === undefined) return
  navigateMenu()
  cy.all(() => newOwner.info())
    .then(() => cy.changeBackupJobOwner(backupjob, { user: newOwner }))
    .then(() => {
      cy.navigateTab('info').within(() => {
        cy.getBySel('owner').should('have.text', newOwner.name)
      })
    })
}

/**
 * @param {object} backupjob - Backup Job to change ownership
 * @param {object} newGroup - New group
 */
const changeBackupJobsGroup = (backupjob, newGroup) => {
  if (backupjob.id === undefined) return
  navigateMenu()
  cy.all(() => newGroup.info())
    .then(() => cy.changeBackupJobGroup(backupjob, { group: newGroup }))
    .then(() => {
      cy.navigateTab('info').within(() => {
        cy.getBySel('group').should('have.text', newGroup.name)
      })
    })
}

/**
 * Before test.
 *
 * @param {object} resources - resources
 * @param {object} resources.DATASTORE_BK - DS BACKUP
 * @param {object} resources.DATASTORE_IMG - DS IMG
 * @param {object} resources.DS_TEMPLATE - TEMPLATE DS
 * @param {object} resources.CLUSTER - CLUSTER
 * @param {object} resources.HOST - HOST
 * @param {object} resources.TEMPLATE_HOST -HOST template
 * @param {object} resources.MARKET_APP - market app
 * @param {string} resources.VM_NAME - VM name
 * @param {object[]} resources.VMS - VMs
 * @param {object} resources.BACKUPJOB_ACTION - action
 * @param {string} resources.BACKUPJOB_NAME_ACTION - name bj
 * @param {Function} resources.BACKUPJOB_TEMPLATE - template
 */
const beforeAllBackupJobTest = ({
  DATASTORE_BK,
  DATASTORE_IMG,
  DS_TEMPLATE,
  CLUSTER,
  HOST,
  TEMPLATE_HOST,
  MARKET_APP,
  VM_NAME,
  VMS,
  BACKUPJOB_ACTION,
  BACKUPJOB_NAME_ACTION,
  BACKUPJOB_TEMPLATE,
} = {}) => {
  cy.fixture('auth')
    .then((auth) => cy.apiAuth(auth.admin))
    .then(() => CLUSTER.info())
    .then(() =>
      DATASTORE_BK.allocate({
        template: { ...DS_TEMPLATE, NAME: DATASTORE_BK.name },
        cluster: CLUSTER.id,
      })
    )
    .then(() => DATASTORE_BK.info())
    .then(() => DATASTORE_IMG.info())
    .then(() => HOST.allocate(TEMPLATE_HOST))
    .then(() => MARKET_APP.info())
    .then(() =>
      MARKET_APP.exportApp({
        associated: true,
        datastore: DATASTORE_IMG.id,
        name: VM_NAME,
        vmname: VM_NAME,
      })
    )
    .then(({ template } = {}) => new VmTemplate(template ?? VM_NAME))
    .then((template) => {
      template.info().then(() => {
        VMS.forEach(({ name }, i) => {
          template.instantiate({ name }).then((vmID) => {
            VMS[i].data = new VirtualMachine(vmID)
          })
        })
      })
    })
    .then(() => {
      BACKUPJOB_ACTION.allocate(
        BACKUPJOB_TEMPLATE({
          name: BACKUPJOB_NAME_ACTION,
          vms: VMS[2].data.id,
        })
      )
    })
}

/**
 * Backup Job Rename.
 *
 * @param {object} backupjob - Backup Job to rename
 * @param {string} newName - New name
 */
const renameBackupJob = (backupjob, newName) => {
  if (backupjob.id === undefined) return
  navigateMenu()
  cy.clickBackupsJobsRow(backupjob)
    .then(() => cy.renameResource(newName))
    .then(() => (backupjob.name = newName))
    .then(() => cy.getBackupsJobsRow(backupjob).contains(newName))
}

/**
 * Backup Job to create.
 *
 * @param {object} template - Backup Job template
 */
const createBackupJobGUI = (template) => {
  navigateMenu()
  cy.createBackupJobGUI(template).its('response.body.id').should('eq', 200)
}

/**
 * @param {object} backupjob - Bakup job for delete
 */
const deleteBackupJob = (backupjob) => {
  if (backupjob.id === undefined) return
  navigateMenu()
  cy.deleteBackupJob(backupjob)
    .its('response.body.id')
    .should('eq', 200)
    .then(() => {
      cy.getBackupsJobsTable({ search: backupjob.name }).within(() => {
        cy.get(`[role='row'][data-cy$='${backupjob.id}']`).should('not.exist')
      })
    })
}

module.exports = {
  lockBackupJob,
  unlockBackupJob,
  changeBackupJobsPermissions,
  changeBackupJobsOwnership,
  changeBackupJobsGroup,
  afterAllBackupJobsTest,
  beforeAllBackupJobTest,
  renameBackupJob,
  createBackupJobGUI,
  deleteBackupJob,
}
