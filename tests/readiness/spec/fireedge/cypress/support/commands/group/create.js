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

import { Group as GroupDocs } from '@support/commands/group/jsdocs'
import { FORCE } from '@support/commands/constants'

/**
 * Fills in the GUI settings for a group.
 *
 * @param {GroupDocs} group - The group whose GUI settings are to be filled
 */
const fillGroupGUI = (group) => {
  // Start form
  cy.getBySel('main-layout').click()

  // Fill general data and continue
  if (group.name) {
    fillGeneral(group)
    cy.getBySel('stepper-next-button').click()
  }

  // Fill permissions data and continue
  if (group.permissions) {
    fillPermissions(group)
    cy.getBySel('stepper-next-button').click()
  }

  // Fill views data and continue
  fillViews(group)
  cy.getBySel('stepper-next-button').click()

  // Fill system data and continue
  fillsystem(group)
  cy.getBySel('stepper-next-button').click()
}

/**
 * Fills in the general settings for a group.
 *
 * @param {GroupDocs} group - The group whose general settings are to be filled
 */
const fillGeneral = (group) => {
  // Get group info
  const { name, admin } = group

  // Set name of the group
  name && cy.getBySel('general-name').clear().type(name)

  // Set admin inf
  if (admin) {
    cy.getBySel('general-adminUser').check()

    admin.username &&
      cy.getBySel('general-username').clear().type(admin.username)
    admin.authType &&
      cy.getBySel('general-authType').then(({ selector }) => {
        cy.get(selector)
          .click()
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    admin.authType?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    admin.authType === $el?.text()
                  ) {
                    cy.wrap($el).click()

                    return false // Break
                  }
                })
            })
          })
      })

    admin.password &&
      cy.getBySel('general-password').clear().type(admin.password)
    admin.password &&
      cy.getBySel('general-confirmPassword').clear().type(admin.password)
  }
}

/**
 * Fills in the permissions settings for a group.
 *
 * @param {GroupDocs} group - The group whose permissions settings are to be filled
 */
const fillPermissions = (group) => {
  // Get group info
  const { permissions } = group

  if (permissions) {
    // Set create permissions
    Object.entries(permissions?.create).forEach(([key, value]) => {
      value
        ? cy.getBySel('permissions-create-' + key).check()
        : cy.getBySel('permissions-create-' + key).uncheck()
    })

    // Set view permissions
    Object.entries(permissions?.view).forEach(([key, value]) => {
      value
        ? cy.getBySel('permissions-view-' + key).check()
        : cy.getBySel('permissions-view-' + key).uncheck()
    })
  }
}

/**
 * Fills in the views settings for a group.
 *
 * @param {GroupDocs} group - The group whose views settings are to be filled
 */
const fillViews = (group) => {
  // Get group info
  const { views } = group

  if (views) {
    // Set group views
    views?.groups?.defaultView &&
      cy.getBySel('views-DEFAULT_VIEW').then(({ selector }) => {
        cy.get(selector)
          .click()
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    views.groups.defaultView?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    views.groups.defaultView === $el?.text()
                  ) {
                    cy.wrap($el).click()

                    return false // Break
                  }
                })
            })
          })
      })

    views?.groups?.views &&
      Object.entries(views?.groups?.views).forEach(([key, value]) => {
        value
          ? cy.getBySel('views-VIEWS-' + key).check(FORCE)
          : cy.getBySel('views-VIEWS-' + key).uncheck(FORCE)
      })

    // Set admin views
    views?.admin?.defaultView &&
      cy
        .getBySel('views-GROUP_ADMIN_DEFAULT_VIEW')

        .then(({ selector }) => {
          cy.get(selector)
            .click()
            .then(() => {
              cy.document().then((doc) => {
                cy.wrap(doc?.body)
                  .find('.MuiAutocomplete-option')
                  .each(($el) => {
                    if (
                      views.admin.defaultView?.toLowerCase() ===
                        $el?.attr('data-value')?.toLowerCase() ||
                      views.admin.defaultView === $el?.text()
                    ) {
                      cy.wrap($el).click()

                      return false // Break
                    }
                  })
              })
            })
        })

    views?.admin?.views &&
      Object.entries(views?.admin?.views).forEach(([key, value]) => {
        value
          ? cy.getBySel('views-GROUP_ADMIN_VIEWS-' + key).check()
          : cy.getBySel('views-GROUP_ADMIN_VIEWS-' + key).uncheck()
      })
  }
}

/**
 * Fills in the system settings for a group.
 *
 * @param {GroupDocs} group - The group whose general system are to be filled
 */
const fillsystem = (group) => {
  // Get group info
  const { system } = group

  // Set system settings
  system?.DEFAULT_IMAGE_PERSISTENT_NEW
    ? cy.getBySel('system-OPENNEBULA-DEFAULT_IMAGE_PERSISTENT_NEW').check()
    : cy.getBySel('system-OPENNEBULA-DEFAULT_IMAGE_PERSISTENT_NEW').uncheck()
  system?.DEFAULT_IMAGE_PERSISTENT
    ? cy.getBySel('system-OPENNEBULA-DEFAULT_IMAGE_PERSISTENT').check()
    : cy.getBySel('system-OPENNEBULA-DEFAULT_IMAGE_PERSISTENT').uncheck()
}

export { fillGroupGUI }
