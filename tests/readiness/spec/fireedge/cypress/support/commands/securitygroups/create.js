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

import { SecurityGroup } from '@support/commands/template/jsdocs'

/**
 * Fill configuration for security group creation.
 *
 * @param {SecurityGroup} SecGroup - security group object
 */
const fillConfiguration = (SecGroup) => {
  const { NAME, DESCRIPTION } = SecGroup

  cy.getBySel('general-NAME').clear().type(NAME)

  DESCRIPTION && cy.getBySel('general-DESCRIPTION').clear().type(DESCRIPTION)
}

/**
 * Fill Rules for security group creation.
 *
 * @param {SecurityGroup} [SecGroup] - security group object
 */
const fillRules = (SecGroup) => {
  const { RULE: rules } = SecGroup
  rules.forEach((element) => {
    const { RULE_TYPE, PROTOCOL, RANGE_TYPE, TARGET } = element
    cy.getBySel('rules-rules-RULE_TYPE').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  RULE_TYPE?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  RULE_TYPE === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })

    cy.getBySel('rules-rules-PROTOCOL').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  PROTOCOL.value?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  PROTOCOL.value === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })

    switch (PROTOCOL.value) {
      case 'ICMP':
        cy.getBySel('rules-rules-ICMP_TYPE').then(({ selector }) => {
          cy.get(selector)
            .click()
            .then(() => {
              cy.document().then((doc) => {
                cy.wrap(doc?.body)
                  .find('.MuiAutocomplete-option')
                  .each(($el) => {
                    if (
                      PROTOCOL.ICMP?.toLowerCase() ===
                        $el?.attr('data-value')?.toLowerCase() ||
                      PROTOCOL.ICMP === $el?.text()
                    ) {
                      cy.wrap($el).click()

                      return false // Break
                    }
                  })
              })
            })
        })

        break
      case 'ICMPv6':
        cy.getBySel('rules-rules-ICMPv6_TYPE').then(({ selector }) => {
          cy.get(selector)
            .click()
            .then(() => {
              cy.document().then((doc) => {
                cy.wrap(doc?.body)
                  .find('.MuiAutocomplete-option')
                  .each(($el) => {
                    if (
                      PROTOCOL.ICMPv6?.toLowerCase() ===
                        $el?.attr('data-value')?.toLowerCase() ||
                      PROTOCOL.ICMPv6 === $el?.text()
                    ) {
                      cy.wrap($el).click()

                      return false // Break
                    }
                  })
              })
            })
        })

        break
      default:
        break
    }

    cy.getBySel('rules-rules-RANGE_TYPE').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  RANGE_TYPE.value?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  RANGE_TYPE.value === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })

    switch (RANGE_TYPE.value) {
      case 'Port Range':
        cy.getBySel('rules-rules-RANGE').clear().type(RANGE_TYPE.RANGE)
        break
      default:
        break
    }

    cy.getBySel('rules-rules-TARGET').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  TARGET.value?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  TARGET.value === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })

    switch (TARGET.value) {
      case 'Manual Network':
        cy.getBySel('rules-rules-IP').clear().type(TARGET.IP)
        cy.getBySel('rules-rules-SIZE').clear().type(TARGET.SIZE)
        break
      case 'OpenNebula Virtual Network':
        // select network on datatable
        break

      default:
        break
    }

    cy.getBySel('rules-add-rules').click()
  })
}

/**
 * Fill forms security group object via GUI.
 *
 * @param {SecurityGroup} SecGroup - security group object
 */
const fillSecurityGroupGUI = (SecGroup) => {
  cy.getBySel('main-layout').click()

  fillConfiguration(SecGroup)
  cy.getBySel('stepper-next-button').click()
  fillRules(SecGroup)
  cy.getBySel('stepper-next-button').click()
}

export { fillConfiguration, fillRules, fillSecurityGroupGUI }
