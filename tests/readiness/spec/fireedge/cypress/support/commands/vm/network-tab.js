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

import { FORCE } from '@commands/constants'
import { fillNetworkSection } from '@commands/template/create'
import { VirtualMachine } from '@models'
import {
  Intercepts,
  createIntercept,
  checkForm,
  hasRestrictedAttributes,
} from '@support/utils'

const validateSecGroupRule = (rule, nicId) => {
  const {
    SECURITY_GROUP_NAME,
    SECURITY_GROUP_ID,
    PROTOCOL,
    RULE_TYPE,
    NETWORK_ID,
    RANGE,
    ICMP,
  } = rule

  const parentKey = `nic-${nicId}-secgroup-${SECURITY_GROUP_ID}`
  const titleKey = `${parentKey}-rule-name`.toLowerCase()
  const ruleKey = `${parentKey}-rule-${RULE_TYPE}`.toLowerCase()

  cy.getBySel(titleKey).contains(SECURITY_GROUP_ID, {
    matchCase: false,
  })

  cy.getBySel(titleKey).contains(SECURITY_GROUP_NAME, {
    matchCase: false,
  })

  cy.getBySel(`${ruleKey}-protocol`).contains(PROTOCOL, {
    matchCase: false,
  })

  cy.getBySel(`${ruleKey}-ruletype`).contains(RULE_TYPE, {
    matchCase: false,
  })

  cy.getBySel(`${ruleKey}-range`).contains(RANGE ?? 'All', {
    matchCase: false,
  })

  cy.getBySel(`${ruleKey}-networkid`).contains(
    NETWORK_ID ? `${NETWORK_ID}` : 'Any',
    { matchCase: false }
  )

  if (ICMP) {
    cy.getBySel(`${ruleKey}-icmp-type`).contains(ICMP, {
      matchCase: false,
    })
  }
}

/*
 * Add NIC with PCI.
 *
 * @param {VirtualMachine} vm - VM info object
 * @param {object} nic - network
 */
const addNicToVm = (vm, nic) => {
  cy.clickVmRow(vm)
  fillNetworkSection({ networks: nic })
}

/*
 * update NIC.
 *
 * @param {VirtualMachine} vm - VM info object
 * @param {object} nic - network
 */
const updateNicVM = (vm, qos) => {
  const { NIC = [] } = vm.json.TEMPLATE || {}
  const {
    INBOUND_AVG_BW = '',
    INBOUND_PEAK_BW = '',
    INBOUND_PEAK_KB = '',
    OUTBOUND_AVG_BW = '',
    OUTBOUND_PEAK_BW = '',
    OUTBOUND_PEAK_KB = '',
  } = qos

  const ensuredNics = Array.isArray(NIC) ? NIC : [NIC]

  cy.getBySel('unselect').click()
  cy.clickVmRow(vm)
  const updateNetwork = createIntercept(Intercepts.SUNSTONE.VM_UPDATENIC)
  cy.navigateTab('network').within(() => {
    ensuredNics.forEach((nic) => {
      const { NIC_ID } = nic

      cy.getBySel(`nic-${NIC_ID}`).within(() => {
        cy.getBySel(`update-nic-${NIC_ID}`).click()
      })
    })
  })

  cy.getBySel('modal-update-nic').within(() => {
    cy.getBySel('override-in-qos-INBOUND_AVG_BW')
      .clear(FORCE)
      .type(INBOUND_AVG_BW)
    cy.getBySel('override-in-qos-INBOUND_PEAK_BW')
      .clear(FORCE)
      .type(INBOUND_PEAK_BW)
    cy.getBySel('override-in-qos-INBOUND_PEAK_KB')
      .clear(FORCE)
      .type(INBOUND_PEAK_KB)
    cy.getBySel('override-out-qos-OUTBOUND_AVG_BW')
      .clear(FORCE)
      .type(OUTBOUND_AVG_BW)
    cy.getBySel('override-out-qos-OUTBOUND_PEAK_BW')
      .clear(FORCE)
      .type(OUTBOUND_PEAK_BW)
    cy.getBySel('override-out-qos-OUTBOUND_PEAK_KB')
      .clear(FORCE)
      .type(OUTBOUND_PEAK_KB)
    cy.getBySel('stepper-next-button').click(FORCE)
  })

  return cy.wait(updateNetwork)
}

/**
 * Validate VM networks tab.
 *
 * @param {VirtualMachine} vm - VM info object
 */
const validateVmNetworks = (vm) => {
  const {
    NIC = [],
    NIC_ALIAS = [],
    SECURITY_GROUP_RULE: rules = [],
  } = vm.json.TEMPLATE || {}

  const ensuredNics = Array.isArray(NIC) ? NIC : [NIC]
  const ensuredAlias = Array.isArray(NIC_ALIAS) ? NIC_ALIAS : [NIC_ALIAS]
  const ensuredRules = Array.isArray(rules) ? rules : [rules]

  if (
    ensuredNics.length === 0 &&
    ensuredAlias.length === 0 &&
    ensuredRules.length === 0
  )
    return

  cy.clickVmRow(vm)

  cy.navigateTab('network').within(() => {
    ensuredNics.forEach((nic) => {
      const { NETWORK, IP, MAC, NIC_ID } = nic

      cy.getBySel(`nic-${NIC_ID}`).within(() => {
        cy.getBySel('nic-name').contains(NETWORK)
        cy.getBySel('nic-ip').contains(IP)
        cy.getBySel('nic-mac').contains(MAC)

        // ALIAS
        ensuredAlias
          .filter(({ PARENT_ID }) => PARENT_ID === NIC_ID)
          // reformat NIC ID => parent ID + (index + 1)
          // => eg: 0.1, 0.2 ...
          .map((nicAlias, aliasIndex) => ({
            ...nicAlias,
            NIC_ID: `${NIC_ID}.${aliasIndex + 1}`,
          }))
          .forEach((nicAlias) => {
            cy.getBySel(`alias-${nicAlias.NIC_ID}`).within(() => {
              cy.getBySel('alias-name').contains(nicAlias.NETWORK)
              cy.getBySel('alias-ip').contains(nicAlias.IP)
              cy.getBySel('alias-mac').contains(nicAlias.MAC)
              cy.getBySel('alias-bridge').contains(nicAlias.BRIDGE)
            })
          })

        // SECURITY GROUPS
        ensuredRules.forEach((rule) => {
          cy.getBySel('security-groups')
            .invoke('attr', 'aria-expanded')
            .then((isExpanded) => {
              !isExpanded && cy.getBySel('security-groups').click()
            })

          validateSecGroupRule(rule, NIC_ID)
        })
      })
    })
  })
}

/**
 * Validate restricted attributes in VM network tab.
 *
 * @param {object} restrictedAttributes - Map of restricted attributes
 * @param {object} vm - VM to check
 * @param {string} check - Condition to check
 */
const validateRestrictedAttributesVmNetwork = (
  restrictedAttributes,
  vm,
  check
) => {
  const { NIC = [] } = vm.json.TEMPLATE || {}

  const ensuredNics = Array.isArray(NIC) ? NIC : [NIC]

  if (ensuredNics.length === 0) return

  cy.navigateTab('network')

  ensuredNics.forEach(({ NIC_ID, ...nic }) => {
    cy.getBySel(`nic-${NIC_ID}`).within(() => {
      // If exists a Vnet attribute and it's not admin, delete button has to be disabled
      hasRestrictedAttributes(nic, 'NIC', restrictedAttributes) &&
        cy.getBySelLike(`detach-nic-${NIC_ID}`).should(check)
    })

    // Click on update button
    cy.getBySel(`update-nic-${NIC_ID}`).click()

    // Check QoS step
    cy.get('[role="presentation"]').then(() =>
      checkForm(restrictedAttributes.NIC, check)
    )
    cy.getBySel('dg-cancel-button').click()
  })
}

Cypress.Commands.add('validateVmNetworks', validateVmNetworks)
Cypress.Commands.add('addNicToVM', addNicToVm)
Cypress.Commands.add('updateNicVM', updateNicVM)
Cypress.Commands.add(
  'validateRestrictedAttributesVmNetwork',
  validateRestrictedAttributesVmNetwork
)
