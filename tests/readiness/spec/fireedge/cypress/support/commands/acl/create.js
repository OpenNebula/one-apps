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
 * Fills in the String GUI settings for an ACL.
 *
 * @param {string} rule - The string rule whose GUI settings are to be filled
 */
const fillAclStringGUI = (rule) => {
  // Start form
  cy.getBySel('main-layout').click()

  // Fill string acl data and continue
  cy.getBySel('stringEditor-RULE').clear().type(rule)

  // Click finish button
  cy.getBySel('stepper-next-button').click()
}

/**
 * Fills in the GUI settings for an ACL.
 *
 * @param {object} acl - The acl rule whose GUI settings are to be filled
 */
const fillAclGUI = (acl) => {
  const { rule, summary } = acl

  // Start form
  cy.getBySel('main-layout').click()

  // Fill user data
  fillUser(rule?.user)
  cy.getBySel('stepper-next-button').click()

  // Fill resources data and continue
  fillResources(rule?.resources)
  cy.getBySel('stepper-next-button').click()

  // Fill resources identifier data
  fillResourcesIdentifier(rule?.resourcesIdentifier)
  cy.getBySel('stepper-next-button').click()

  // Fill rights data
  fillRights(rule?.rights)
  cy.getBySel('stepper-next-button').click()

  // Fill zone data
  rule?.zone && fillZone(rule?.zone)
  cy.getBySel('stepper-next-button').click()

  // Summary - Check that the rule it's ok
  cy.getBySel('ruleString').should('have.text', summary)

  // Click finish button
  cy.getBySel('stepper-next-button').click()
}

/**
 * Fills in the user settings for an ACL.
 *
 * @param {object} user - The acl user settings to be filled
 */
const fillUser = (user) => {
  // Get user info
  const { type, id } = user

  // Set type
  if (type) {
    cy.getBySel('user-TYPE')
      .find(`button[aria-pressed="false"]`)
      .each(($button) => {
        cy.wrap($button)
          .invoke('attr', 'value')
          .then(($value) => $value === type && cy.wrap($button).click())
      })
  }

  // Set user
  if (type === 'INDIVIDUAL') {
    id && cy.clickUserRow({ id: id }, { noWait: true })
  } else if (type === 'GROUP') {
    id && cy.clickGroupRow({ id: id }, { noWait: true })
  }
}

/**
 * Fills in the resources settings for an ACL.
 *
 * @param {Array} resources - The acl resources settings to be filled
 */
const fillResources = (resources) => {
  // Set type
  if (resources) {
    resources.forEach((resource) =>
      cy.getBySel('resources-' + resource).check()
    )
  }
}

/**
 * Fills in the user settings for an ACL.
 *
 * @param {object} resourcesIdentifier - The acl resourcesIdentifier settings to be filled
 */
const fillResourcesIdentifier = (resourcesIdentifier) => {
  // Get resourcesIdentifier info
  const { type, id } = resourcesIdentifier

  // Set type
  if (type) {
    cy.getBySel('resourcesIdentifier-TYPE')
      .find(`button[aria-pressed="false"]`)
      .each(($button) => {
        cy.wrap($button)
          .invoke('attr', 'value')
          .then(($value) => $value === type && cy.wrap($button).click())
      })
  }

  // Set resources identifier
  if (type === 'INDIVIDUAL') {
    id && cy.getBySel('resourcesIdentifier-INDIVIDUAL').clear().type(id)
  } else if (type === 'CLUSTER') {
    id && cy.clickClusterRow({ id: id }, { noWait: true })
  } else if (type === 'GROUP') {
    id && cy.clickGroupRow({ id: id }, { noWait: true })
  }
}

/**
 * Fills in the rights settings for an ACL.
 *
 * @param {Array} rights - The acl rights settings to be filled
 */
const fillRights = (rights) => {
  // Set type
  if (rights) {
    rights.forEach((resource) => cy.getBySel('rights-' + resource).check())
  }
}

/**
 * Fills in the zone settings for an ACL.
 *
 * @param {object} zone - The acl zone settings to be filled
 */
const fillZone = (zone) => {
  // Get zone info
  const { type, id } = zone

  // Set type
  if (type) {
    cy.getBySel('zone-TYPE')
      .find(`button[aria-pressed="false"]`)
      .each(($button) => {
        cy.wrap($button)
          .invoke('attr', 'value')
          .then(($value) => $value === type && cy.wrap($button).click())
      })
  }

  // Set zone
  if (type === 'INDIVIDUAL') {
    id && cy.clickZoneRow({ id: id }, { noWait: true })
  }
}

export { fillAclStringGUI, fillAclGUI }
