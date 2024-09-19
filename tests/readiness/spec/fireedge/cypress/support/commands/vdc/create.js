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

import { Vdc } from '@support/commands/vdc/jsdocs'

const noWait = { noWait: true }

const clickResources = (data, fn) => {
  const nameClickFn = `click${fn}`

  if (Array.isArray(data)) {
    data.forEach((resource, id) => {
      id === 0
        ? cy[nameClickFn](resource, { ...noWait, removeSelections: true })
        : cy[nameClickFn](resource, noWait)
    })
  } else {
    cy[nameClickFn](data, { ...noWait, removeSelections: true })
  }
}

/**
 * Fill configuration for vdc creation.
 *
 * @param {Vdc} vdc - template object
 */
const fillConfiguration = (vdc) => {
  const { name, description } = vdc

  name && cy.getBySel('general-NAME').clear().type(name)

  description && cy.getBySel('general-DESCRIPTION').clear().type(description)
}

/**
 * Fill groups for vdc.
 *
 * @param {Vdc} vdc - vdc object
 */
const fillGroups = (vdc) => {
  const { groups } = vdc

  groups && clickResources(groups, 'GroupRow')
}

/**
 * Fill resources for vdc.
 *
 * @param {Vdc} vdc - vdc object
 */
const fillResources = (vdc) => {
  const { clusters, datastores, hosts, networks } = vdc

  clusters && clickResources(clusters, 'ClusterRow')

  datastores && clickResources(datastores, 'DatastoreRow')

  hosts && clickResources(hosts, 'HostRow')

  networks && clickResources(networks, 'VNetRow')
}

/**
 * Fill custom attributes for vdc.
 *
 * @param {Vdc} vdc - vdc object
 */
const fillCustomAttributes = (vdc) => {
  const { customAttributes } = vdc

  Object.entries(customAttributes).forEach(([varName, varValue]) => {
    cy.getBySelLike('text-name-').clear().type(varName)
    cy.getBySelLike('text-value-').clear().type(`${varValue}{enter}`)
  })
}

/**
 * Fill forms vdc via GUI.
 *
 * @param {Vdc} vdc - vdc object
 */
const fillVdcGUI = (vdc) => {
  cy.getBySel('main-layout').click()

  fillConfiguration(vdc)
  cy.getBySel('stepper-next-button').click()
  fillGroups(vdc)
  cy.getBySel('stepper-next-button').click()
  fillResources(vdc)
  cy.getBySel('stepper-next-button').click()
  fillCustomAttributes(vdc)

  cy.getBySel('stepper-next-button').click()
}

export {
  fillConfiguration,
  fillCustomAttributes,
  fillGroups,
  fillResources,
  fillVdcGUI,
}
