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

/**
 * Fill configuration for Backup Job creation.
 *
 * @param {object} backupjob - template object
 */
const fillConfiguration = (backupjob) => {
  const { NAME, PRIORITY, BACKUP_VOLATILE, KEEP_LAST, FS_FREEZE, MODE } =
    backupjob

  NAME && cy.getBySel('general-NAME').clear().type(NAME)

  PRIORITY &&
    cy.getBySel('general-PRIORITY-input').type('{selectAll}').type(PRIORITY)

  FS_FREEZE &&
    cy.getBySel('general-FS_FREEZE').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  FS_FREEZE?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  FS_FREEZE === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })

  MODE &&
    cy.getBySel('general-MODE').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  MODE?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  MODE === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })

  KEEP_LAST && cy.getBySel('general-KEEP_LAST').clear().type(KEEP_LAST)
  BACKUP_VOLATILE === 'YES' &&
    cy.getBySel('general-BACKUP_VOLATILE').click(FORCE)
}

/**
 * Fill datastore for Backup Job creation.
 *
 * @param {object} backupjob - backupjob object
 */
const fillDatastore = (backupjob) => {
  const { DATASTORE_ID } = backupjob

  cy.getDatastoreRow(DATASTORE_ID).click(FORCE)
}

/**
 * Fill vms for Backup Job creation.
 *
 * @param {object} backupjob - backupjob object
 */
const fillVms = (backupjob) => {
  const { BACKUP_VMS } = backupjob

  cy.getVmRow(BACKUP_VMS).click(FORCE)
}

/**
 * Fill schedule actions for Backup Job creation.
 *
 * @param {object} backupjob - backupjob object
 */
const fillSchedActions = (backupjob) => {
  const { schedActions } = backupjob

  if (!schedActions) return

  const ensuredActions = Array.isArray(schedActions)
    ? schedActions
    : [schedActions]

  cy.wrap(ensuredActions).each(
    ({ time, periodic, period, endType, repeat, endValue }) => {
      cy.getBySel('sched-add').click(FORCE)

      cy.getBySel('modal-sched-actions')
      if (periodic) {
        cy.getBySel('form-dg-PERIODIC')
          .find(`button[aria-pressed="false"]`)
          .each(($button) => {
            cy.wrap($button)
              .invoke('attr', 'value')
              .then(($value) => $value === periodic && cy.wrap($button).click())
          })
      }
      if (periodic === 'RELATIVE') {
        time && cy.getBySelEndsWith('-RELATIVE_TIME').type(time, FORCE)
        period &&
          cy.getBySelEndsWith('-PERIOD').then(({ selector }) => {
            cy.get(selector)
              .click()
              .then(() => {
                cy.document().then((doc) => {
                  cy.wrap(doc?.body)
                    .find('.MuiAutocomplete-option')
                    .each(($el) => {
                      if (
                        period?.toLowerCase() ===
                          $el?.attr('data-value')?.toLowerCase() ||
                        period === $el?.text()
                      ) {
                        cy.wrap($el).click()

                        return false // Break
                      }
                    })
                })
              })
          })
      } else {
        // One time and periodic have time field
        time && cy.fillDatetimePicker('form-dg-TIME', time)

        // Periodic also has to fill other fields
        if (periodic === 'PERIODIC') {
          if (repeat) {
            cy.getBySelEndsWith('-REPEAT').then(({ selector }) => {
              cy.get(selector)
                .click(FORCE)
                .then(() => {
                  cy.document().then((doc) => {
                    cy.wrap(doc?.body)
                      .find('.MuiAutocomplete-option')
                      .each(($el) => {
                        if (
                          repeat?.toLowerCase() ===
                            $el?.attr('data-value')?.toLowerCase() ||
                          repeat === $el?.text()
                        ) {
                          cy.wrap($el).click()

                          return false // Break
                        }
                      })
                  })
                })
            })

            const upperRepeat = repeat.toUpperCase()
            const input = upperRepeat === 'WEEKLY' ? 'select' : 'type'

            cy.getBySelEndsWith(`-${upperRepeat}`)[input](endValue, FORCE)
          }
          endType &&
            cy.getBySelEndsWith('-END_TYPE').then(({ selector }) => {
              cy.get(selector)
                .click()
                .then(() => {
                  cy.document().then((doc) => {
                    cy.wrap(doc?.body)
                      .find('.MuiAutocomplete-option')
                      .each(($el) => {
                        if (
                          endType?.toLowerCase() ===
                            $el?.attr('data-value')?.toLowerCase() ||
                          endType === $el?.text()
                        ) {
                          cy.wrap($el).click()

                          return false // Break
                        }
                      })
                  })
                })
            })
        }
      }

      // FINISH DIALOG
      cy.getBySel('dg-accept-button').click(FORCE).should('not.exist')
    }
  )
}

/**
 * Fill forms Backup Job via GUI.
 *
 * @param {object} backupjob - backup job
 */
const fillBackupJobsGUI = (backupjob) => {
  cy.getBySel('main-layout').click()

  fillConfiguration(backupjob)
  cy.getBySel('stepper-next-button').click()
  fillVms(backupjob)
  cy.getBySel('stepper-next-button').click()
  fillDatastore(backupjob)
  cy.getBySel('stepper-next-button').click()
  fillSchedActions(backupjob)

  cy.getBySel('stepper-next-button').click()
}

export {
  fillBackupJobsGUI,
  fillConfiguration,
  fillDatastore,
  fillSchedActions,
  fillVms,
}
