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

import { Backupjob, Group, User } from '@models'
import { fillBackupJobsGUI } from '@support/commands/backupsjobs/create'
import { FORCE } from '@support/commands/constants'
import { configSelectImage } from '@support/commands/image/jsdocs'
import { Intercepts, createIntercept } from '@support/utils'

/**
 * Changes Backup Job ownership: user or group.
 *
 * @param {Backupjob} backupjob - Backup Job to change owner
 * @param {object} options - Options to fill the form
 * @param {User} [options.user] - The new owner
 * @param {Group} [options.group] - The new group
 * @returns {Cypress.Chainable} Chainable command to change IMAGE owner
 */
const changeBackupJobOwnership = (backupjob, { user, group } = {}) =>
  cy.getBySelLike('modal-').within(() => {
    user && cy.getUserRow(user).click(FORCE)
    group && cy.getGroupRow(group).click(FORCE)
    cy.getBySel('dg-accept-button').click(FORCE)
  })

/**
 * Change Lock Backup Job.
 *
 * @param {string} action - action
 * @param {object} intercept - intercept
 * @returns {function(configSelectImage):Cypress.Chainable<Cypress.Response>} change image response
 */
const lockBackupJob =
  (action, intercept) =>
  (backupJob = {}) => {
    const getLockBackupJob = createIntercept(intercept)
    const getlockBackupJobInfo = createIntercept(Intercepts.SUNSTONE.BACKUPJOB)

    cy.clickBackupsJobsRow(backupJob)

    cy.getBySel('action-backupjob-lock').click(FORCE)
    cy.getBySel(`action-${action}`).click(FORCE)

    cy.getBySel(`modal-${action}`)
      .should('exist')
      .then(($dialog) => {
        cy.wrap($dialog).find(`[data-cy=dg-accept-button]`).click(FORCE)

        return cy.wait([getLockBackupJob, getlockBackupJobInfo])
      })
  }

/**
 * Performs an action on a Backup Job.
 *
 * @param {'ownership'} group - Group action name
 * @param {string} action - Action name to perform
 * @param {Function} form - Function to fill the form. By default is a confirmation dialog.
 * @returns {function(Backupjob, any):Cypress.Chainable}
 * Chainable command to perform an action on a Backupjob
 */
const groupAction = (group, action, form) => (backupjob, options) => {
  cy.clickBackupsJobsRow(backupjob)

  cy.getBySel(`action-backupjob-${group}`).click(FORCE)
  cy.getBySel(`action-${action}`).click(FORCE)

  if (form) return form(backupjob, options)

  return cy.getBySel(`modal-${action}`).within(() => {
    cy.getBySel('dg-accept-button').click(FORCE)
  })
}

/**
 * Create Backup Job via GUI.
 *
 * @param {Backupjob} backupjob - template
 * @returns {Cypress.Chainable<Cypress.Response>} create image response
 */
const createBackupJobGUI = (backupjob) => {
  const interceptBackupJobAllocate = createIntercept(
    Intercepts.SUNSTONE.BACKUPJOB_CREATE
  )
  cy.getBySel('action-backupjob_create_dialog').click()

  fillBackupJobsGUI(backupjob)

  cy.getBySel('stepper-next-button').click(FORCE)

  return cy.wait(interceptBackupJobAllocate)
}

/**
 * Delete Backup Job.
 *
 * @param {object} backupjob - config lock
 */
const deleteBackupJob = (backupjob = {}) => {
  const interceptDelete = createIntercept(Intercepts.SUNSTONE.BACKUPJOB_DELETE)

  cy.clickBackupsJobsRow(backupjob)
  cy.getBySel('action-backupjob_delete').click(FORCE)

  cy.getBySel(`modal-delete`)
    .should('exist')
    .then(($dialog) => {
      cy.wrap($dialog).find(`[data-cy=dg-accept-button]`).click(FORCE)

      return cy.wait(interceptDelete)
    })
}

Cypress.Commands.add(
  'lockBackupJob',
  lockBackupJob('lock', Intercepts.SUNSTONE.BACKUPJOB_LOCK)
)
Cypress.Commands.add(
  'unlockBackupJob',
  lockBackupJob('unlock', Intercepts.SUNSTONE.BACKUPJOB_UNLOCK)
)
Cypress.Commands.add(
  'changeBackupJobOwner',
  groupAction('ownership', 'chown', changeBackupJobOwnership)
)
Cypress.Commands.add(
  'changeBackupJobGroup',
  groupAction('ownership', 'chgrp', changeBackupJobOwnership)
)
Cypress.Commands.add('createBackupJobGUI', createBackupJobGUI)
Cypress.Commands.add('deleteBackupJob', deleteBackupJob)
