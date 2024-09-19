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
 * Fills in the general data for a vr template.
 *
 * @param {object} GeneralData - General step configuration
 */
const fillGeneralStep = (GeneralData) => {
  const { name, description } = GeneralData

  name && cy.getBySel('general-NAME').clear().type(name)
  description && cy.getBySel('general-DESCRIPTION').clear().type(description)
}

/**
 * Fills in the role definitions for a vr template.
 *
 * @param {object} ExtraData - Extra step configuration.
 */
const fillExtraStep = (ExtraData) => {
  const { Networks, UserInputs, AdvancedParams, ScheduledActions } = ExtraData

  const fillScheduledActionTime = (schedTime, prefix) => {
    const { timeString, granularity, endType, periodTime, periodType } =
      schedTime
    granularity &&
      cy.selectMUIDropdownOption(
        `${prefix}-REPEAT`,
        `${prefix}-REPEAT-${granularity}`
      )
    timeString && cy.getBySel(`${prefix}-TIME`).clear().type(timeString)
    endType &&
      cy.selectMUIDropdownOption(
        `${prefix}-END_TYPE`,
        `${prefix}-END_TYPE-${endType}`
      )
    periodTime &&
      cy.getBySel(`${prefix}-RELATIVE_TIME`).clear().type(periodTime)
    periodType &&
      cy.selectMUIDropdownOption(
        `${prefix}-PERIOD`,
        `${prefix}-PERIOD-${periodType}`
      )
  }

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
        if (type.toLowerCase() === 'boolean') {
          cy.getBySel(`${prefix}-defaultvalue`).check()
        } else {
          type.toLowerCase() !== 'password' &&
            cy.getBySel(`${prefix}-defaultvalue`).clear().type(defaultValue)
        }

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
      prefix = `form-dg`
      const { action, actionOptional, actionTimeType, actionTime } = data
      action &&
        cy.selectMUIDropdownOption(`${prefix}-ACTION`, `${prefix}-${action}`)
      actionOptional &&
        cy.selectMUIDropdownOption(
          `${prefix}-ARGS-${
            action === 'Backup'
              ? 'DS_ID'
              : action === 'Snapshot create'
              ? 'NAME'
              : ['Snapshot revert', 'Snapshot delete'].includes(action)
              ? 'SNAPSHOT_ID'
              : ''
          }`,
          `${prefix}-ARGS-${action}`
        )
      actionTimeType && cy.getBySel(`${prefix}-${actionTimeType}`).click()
      actionTime && fillScheduledActionTime(actionTime, prefix)
    }
  }

  Networks?.forEach((network) => fillType('network', network))
  UserInputs?.forEach((userInput) => fillType('userinput', userInput))
  AdvancedParams?.forEach((advancedparam) =>
    fillType('advancedparam', advancedparam)
  )
  ScheduledActions?.forEach((schedaction) =>
    fillType('scheduledaction', schedaction)
  )
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
      cy.getBySel(`role-cardinality-${roleIndex}`).clear().type(cardinality)
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
 * Fills in the general data for a vr template when instantiating.
 *
 * @param {object} GeneralData - General step configuration
 */
const fillGeneralInstantiate = (GeneralData) => {
  const {
    name,
    description,
    keepaliveid,
    keepalivepassword,
    vmname,
    numberofinstances,
    startonhold,
    instantiateaspersistent,
  } = GeneralData

  name && cy.getBySel('general-name').clear().type(name)
  description && cy.getBySel('general-description').clear().type(description)
  keepaliveid && cy.getBySel('general-keepaliveid').clear().type(keepaliveid)
  keepalivepassword &&
    cy.getBySel('general-keepalivepass').clear().type(keepalivepassword)

  vmname && cy.getBySel('general-vmname').clear().type(vmname)
  numberofinstances &&
    cy.getBySel('general-instances').clear().type(numberofinstances)

  startonhold && cy.getBySel(`general-hold`).check()
  instantiateaspersistent && cy.getBySel(`general-persistent`).check()
}

/**
 * Fills in the user inputs data for a vr template when instantiating.
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
 * Fills in the networks inputs data for a vr template when instantiating.
 *
 * @param {object} NetworksData - Networks data
 */
const fillNetworksInstantiate = (NetworksData) => {
  const fillNetworkInput = (network) => {
    cy.getBySel('add-nic').click()
    const { rdp, ssh, vnet, secgroup } = network

    rdp && cy.getBySel('networking-RDP').check()
    ssh && cy.getBySel('networking-SSH').check()

    vnet &&
      cy
        .getBySel(`vnets`)
        .should('be.visible')
        .then(() => {
          cy.get(`[data-cy="vnets"] div[role="row"]`)
            .contains(`#${vnet?.id}`)
            .click()
        })

    secgroup !== undefined &&
      cy
        .getBySel(`secgroup`)
        .should('be.visible')
        .then(() => {
          cy.get(`[data-cy="secgroup"] div[role="row"]`)
            .contains(`#${secgroup}`)
            .click()
        })
  }

  NetworksData?.forEach((network, index) => fillNetworkInput(network, index))
}

/**
 * Fills in the GUI settings for a vr template.
 *
 * @param {object} vrtemplate - VR template configuration
 */
const fillVrTemplateGUI = (vrtemplate) => {
  const { General, Extra, RoleDefinitions, RoleConfiguration } = vrtemplate
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
 * @param {object} vrtemplate - VR Template
 */
const fillVrTemplateInstantiateGUI = (vrtemplate) => {
  const { general, networking, userInputs } = vrtemplate
  general && fillGeneralInstantiate(general)
  cy.getBySel('stepper-next-button').click()
  networking && fillNetworksInstantiate(networking)
  cy.getBySel('stepper-next-button').click()
  userInputs && fillUserInputsInstantiate(userInputs)
  cy.getBySel('stepper-next-button').click()
}

export {
  fillGeneralStep,
  fillExtraStep,
  fillVrTemplateGUI,
  fillVrTemplateInstantiateGUI,
}
