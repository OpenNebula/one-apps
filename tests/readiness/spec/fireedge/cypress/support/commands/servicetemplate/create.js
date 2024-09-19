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

import { fillSchedActionForm } from '@support/commands/template/create'

/**
 * Fills in the general data for a service template.
 *
 * @param {object} GeneralData - General step configuration
 */
const fillGeneralStep = (GeneralData) => {
  const { name, description } = GeneralData

  name && cy.getBySel('general-NAME').clear().type(name)
  description && cy.getBySel('general-DESCRIPTION').clear().type(description)
}

/**
 * Fills in the role definitions for a service template.
 *
 * @param {object} ExtraData - Extra step configuration.
 */
const fillExtraStep = (ExtraData) => {
  const { Networks, UserInputs, AdvancedParams, ScheduledActions } = ExtraData

  const fillType = (inputType, data) => {
    let prefix = ''
    const { type, name, description } = data

    const fillCommonActions = (commonPrefix) => {
      type &&
        cy.getBySel(`${commonPrefix}-type`).then(({ selector }) => {
          cy.get(selector)
            .click()
            .then(() => {
              cy.document().then((doc) => {
                cy.wrap(doc?.body)
                  .find('.MuiAutocomplete-option')
                  .each(($el) => {
                    if (
                      type?.toLowerCase() ===
                        $el?.attr('data-value')?.toLowerCase() ||
                      type === $el?.text()
                    ) {
                      cy.wrap($el).click()

                      return false // Break
                    }
                  })
              })
            })
        })

      name && cy.getBySel(`${commonPrefix}-name`).clear().type(name)
      description &&
        cy.getBySel(`${commonPrefix}-description`).clear().type(description)
    }

    if (inputType === 'network') {
      prefix = 'extra-networking'
      fillCommonActions(prefix)
      const { network, extra } = data
      network &&
        cy.selectMUIDropdownOption(`${prefix}-network`, `network-${network}`)
      extra && cy.getBySel(`${prefix}-netextra`).clear().type(extra)
      cy.getBySel(prefix).click()
    } else if (inputType === 'userinput') {
      prefix = 'extra-customAttributes'
      fillCommonActions(prefix)
      const {
        defaultValue,
        mandatory,
        listOptions,
        range: { minRange = -1, maxRange = -1 } = {},
      } = data
      if (defaultValue) {
        type.toLowerCase() !== 'password' &&
          cy.getBySel(`${prefix}-defaultvalue`).clear().type(defaultValue)

        listOptions &&
          cy.getBySel(`${prefix}-defaultvaluelist`).clear().type(listOptions)

        minRange !== -1 &&
          cy.getBySel(`${prefix}-defaultvaluerangemin`).clear().type(minRange)

        maxRange !== -1 &&
          cy.getBySel(`${prefix}-defaultvaluerangemax`).clear().type(maxRange)
      }

      mandatory && cy.getBySel(`${prefix}-mandatory`).click()
      cy.getBySel(prefix).click()
    } else if (inputType === 'advanced') {
      prefix = 'extra-advancedparams'
      const { strategy, vmshutdown, waitVms, autoDeleteVms } = data

      strategy &&
        cy.selectMUIDropdownOption(`${prefix}-strategy`, `strategy-${strategy}`)
      vmshutdown &&
        cy.selectMUIDropdownOption(
          `${prefix}-shutdownoption`,
          `shutdown-${vmshutdown}`
        )
      waitVms && cy.getBySel(`${prefix}-waitVms`).click()
      autoDeleteVms && cy.getBySel(`${prefix}-autoDeleteVms`).click()
    } else if (inputType === 'scheduledaction') {
      fillSchedActionForm(data)
    }
  }

  Networks?.forEach((network) => fillType('network', network))
  UserInputs?.forEach((userInput) => fillType('userinput', userInput))
  AdvancedParams?.forEach((advancedparam) =>
    fillType('advancedparam', advancedparam)
  )
  ScheduledActions?.forEach((schedaction) => {
    cy.getBySel('sched-add').click()
    fillType('scheduledaction', schedaction)
  })
}

/**
 * Fills in the role definitions.
 *
 * @param {object} RoleDefinitionsData - Role definitions step configuration.
 */
const fillRoleDefinitionStep = (RoleDefinitionsData) => {
  const addRole = (name, cardinality, vmtemplateid, roleIndex) => {
    name && cy.getBySel(`role-name-${roleIndex}`).clear().type(name)
    cardinality &&
      cy
        .getBySel(`role-cardinality-${roleIndex}`)
        .type(`{selectall}${cardinality}`)

    vmtemplateid && cy.getBySel(`role-vmtemplate-${vmtemplateid}`).click()
  }

  if (RoleDefinitionsData !== undefined) {
    RoleDefinitionsData.forEach((role, roleIndex) => {
      !!RoleDefinitionsData.length - 1 - roleIndex &&
        cy.getBySel('add-role').click()
      addRole(role.name, role.cardinality, role.vmtemplateid, roleIndex)
    })
  }
}

const fillRoleConfigurationStep = (RoleConfigurationData) => {
  const prefix = 'role-config'

  RoleConfigurationData?.forEach((roleConfig, roleIndex) => {
    cy.getBySel(`role-column-${roleIndex}`).click()
    const { roleNetwork, roleElasticity } = roleConfig
    if (roleNetwork) {
      const { networkIndex, aliasToggle, aliasOption } = roleNetwork
      cy.getBySel(`${prefix}-network-${networkIndex}`).click()
      aliasToggle && cy.getBySel(`${prefix}-network-alias-${roleIndex}`).click()
      aliasOption &&
        cy.selectMUIDropdownOption(
          `${prefix}-network-aliasname-${roleIndex}`,
          `${prefix}-network-aliasname-option-${aliasOption}`
        )
    }
    if (roleElasticity) {
      const {
        minVms,
        maxVms,
        cooldown,
        elasticityPolicies,
        scheduledPolicies,
      } = roleElasticity
      minVms &&
        cy
          .getBySel(`elasticity-roleconfig-MINMAXVMS-${roleIndex}-min_vms`)
          .clear()
          .type(minVms)

      maxVms &&
        cy
          .getBySel(`elasticity-roleconfig-MINMAXVMS-${roleIndex}-max_vms`)
          .clear()
          .type(maxVms)

      cooldown &&
        cy
          .getBySel(`elasticity-roleconfig-MINMAXVMS-${roleIndex}-cooldown`)
          .clear()
          .type(cooldown)

      if (elasticityPolicies?.length) {
        const elaPrefix = prefix?.replace('-', '').concat('-elasticitypolicies')
        cy.getBySel(`${elaPrefix}-accordion`).click()

        elasticityPolicies?.forEach((policy) => {
          const {
            type,
            adjust,
            expression,
            period,
            periodNumber,
            policyCooldown,
          } = policy
          type &&
            cy.getBySel(`${elaPrefix}-TYPE`).then(({ selector }) => {
              cy.get(selector)
                .click()
                .then(() => {
                  cy.document().then((doc) => {
                    cy.wrap(doc?.body)
                      .find('.MuiAutocomplete-option')
                      .each(($el) => {
                        if (
                          type?.toLowerCase() ===
                            $el?.attr('data-value')?.toLowerCase() ||
                          type === $el?.text()
                        ) {
                          cy.wrap($el).click()

                          return false // Break
                        }
                      })
                  })
                })
            })

          adjust && cy.getBySel(`${elaPrefix}-ADJUST`).clear().type(adjust)
          expression &&
            cy.getBySel(`${elaPrefix}-EXPRESSION`).clear().type(expression)
          periodNumber &&
            cy.getBySel(`${elaPrefix}-PERIOD_NUMBER`).clear().type(periodNumber)
          period && cy.getBySel(`${elaPrefix}-PERIOD`).clear().type(period)
          policyCooldown &&
            cy.getBySel(`${elaPrefix}-COOLDOWN`).clear().type(policyCooldown)

          cy.getBySel(`${elaPrefix}`).click()
        })
      }

      if (scheduledPolicies?.length) {
        const schedPrefix = prefix
          ?.replace('-', '')
          .concat('-scheduledpolicies')
        cy.getBySel(`${schedPrefix}-accordion`).click()

        scheduledPolicies?.forEach((policy) => {
          const { type, adjust, min, timeFormat, timeExpression } = policy
          type &&
            cy.getBySel(`${schedPrefix}-SCHEDTYPE`).then(({ selector }) => {
              cy.get(selector)
                .click()
                .then(() => {
                  cy.document().then((doc) => {
                    cy.wrap(doc?.body)
                      .find('.MuiAutocomplete-option')
                      .each(($el) => {
                        if (
                          type?.toLowerCase() ===
                            $el?.attr('data-value')?.toLowerCase() ||
                          type === $el?.text()
                        ) {
                          cy.wrap($el).click()

                          return false // Break
                        }
                      })
                  })
                })
            })

          adjust && cy.getBySel(`${schedPrefix}-ADJUST`).clear().type(adjust)
          min && cy.getBySel(`${schedPrefix}-MIN`).clear().type(min)
          timeFormat &&
            cy.getBySel(`${schedPrefix}-TIMEFORMAT`).then(({ selector }) => {
              cy.get(selector)
                .click()
                .then(() => {
                  cy.document().then((doc) => {
                    cy.wrap(doc?.body)
                      .find('.MuiAutocomplete-option')
                      .each(($el) => {
                        if (
                          timeFormat?.toLowerCase() ===
                            $el?.attr('data-value')?.toLowerCase() ||
                          timeFormat === $el?.text()
                        ) {
                          cy.wrap($el).click()

                          return false // Break
                        }
                      })
                  })
                })
            })

          timeExpression &&
            cy
              .getBySel(`${schedPrefix}-TIMEEXPRESSION`)
              .clear()
              .type(timeExpression)

          cy.getBySel(`${schedPrefix}-TIMEEXPRESSION`)
            .clear()
            .type(timeExpression)

          cy.getBySel(`${schedPrefix}`).click()
        })
      }
    }
  })
}

/**
 * Fills in the general data for a service template when instantiating.
 *
 * @param {object} GeneralData - General step configuration
 */
const fillGeneralInstantiate = (GeneralData) => {
  const { name, instances } = GeneralData

  name && cy.getBySel('general-NAME').clear().type(name)
  instances && cy.getBySel('general-INSTANCES').clear().type(instances)
}

/**
 * Fills in the user inputs data for a service template when instantiating.
 *
 * @param {object} UserInputsData - General step configuration
 */
const fillUserInputsInstantiate = (UserInputsData) => {
  const prefix = 'custom_attrs_values'
  const fillUserInput = (input) => {
    const { name, type, value } = input
    if (type === 'boolean') {
      cy.getBySel(`${prefix}-${name.toLowerCase()}`).check()
    } else {
      cy.getBySel(`${prefix}-${name.toLowerCase()}`).click().clear().type(value)
    }
  }

  UserInputsData?.forEach((userInput) => fillUserInput(userInput))
}

/**
 * Fills in the networks inputs data for a service template when instantiating.
 *
 * @param {object} NetworksData - Networks data
 */
const fillNetworksInstantiate = (NetworksData) => {
  const tableName = {
    Create: 'vnet-templates',
    Existing: 'vnets',
    Reserve: 'vnets',
  }
  const fillNetworkInput = (network, index) => {
    const prefix = 'select-network'
    const { name, type, extra, nId } = network
    name && cy.getBySel(`${prefix}-id`).select(name)
    type && cy.getBySel(`${prefix}-type`).select(type)
    extra &&
      cy.getBySel(`network-network-NETWORKS-${index}-extra`).clear().type(extra)

    nId &&
      cy
        .getBySel(`${tableName?.[type]}`)
        .should('be.visible')
        .then(() => {
          cy.get(`[data-cy="${tableName?.[type]}"] div[role="row"]`)
            .contains(`#${nId}`)
            .click()
        })
  }

  NetworksData?.forEach((network, index) => fillNetworkInput(network, index))
}

/**
 * Fills in the GUI settings for a service template.
 *
 * @param {object} servicetemplate - Service template configuration
 */
const fillServiceTemplateGUI = (servicetemplate) => {
  const { General, Extra, RoleDefinitions, RoleConfiguration } = servicetemplate
  General && fillGeneralStep(General)
  cy.getBySel('stepper-next-button').click()
  // DEV MODE HACK TO AVOID REACT CRASH
  cy.getBySel('stepper-next-button').click()
  RoleDefinitions && fillRoleDefinitionStep(RoleDefinitions)
  cy.getBySel('stepper-back-button').click()
  Extra && fillExtraStep(Extra)
  cy.getBySel('stepper-next-button').click()
  cy.getBySel('stepper-next-button').click()
  RoleConfiguration && fillRoleConfigurationStep(RoleConfiguration)
  cy.getBySel('stepper-next-button').click()
}

/**
 * @param {object} servicetemplate - Service Template
 */
const fillServiceTemplateInstantiateGUI = (servicetemplate) => {
  const { General, UserInputs, Networks } = servicetemplate
  General && fillGeneralInstantiate(General)
  cy.getBySel('stepper-next-button').click()
  UserInputs && fillUserInputsInstantiate(UserInputs)
  cy.getBySel('stepper-next-button').click()
  Networks && fillNetworksInstantiate(Networks)
  cy.getBySel('stepper-next-button').click()
  cy.getBySel('stepper-next-button').click()
}

export {
  fillGeneralStep,
  fillExtraStep,
  fillServiceTemplateGUI,
  fillServiceTemplateInstantiateGUI,
}
