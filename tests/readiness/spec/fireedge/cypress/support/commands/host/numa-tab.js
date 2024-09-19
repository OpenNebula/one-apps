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
import { Host } from '@models'
import { getDataProgressBar, prettyBytes } from '@support/commands/helpers'

const CPU_STATUS = {
  '-1': 'FREE',
  '-2': 'ISOLATED',
}

const mergeNumaMonitoring = (host) => {
  const monitoring = host.MONITORING
  if (!monitoring) return []

  const numaNodes =
    host.HOST_SHARE?.NUMA_NODES?.NODE &&
    Array.isArray(host.HOST_SHARE.NUMA_NODES.NODE)
      ? host.HOST_SHARE.NUMA_NODES.NODE
      : [host.HOST_SHARE.NUMA_NODES.NODE]

  const monitoringNodes = Array.isArray(monitoring.NUMA_NODE)
    ? monitoring.NUMA_NODE
    : [monitoring.NUMA_NODE]

  numaNodes.map((node) => {
    const monitoringNode = monitoringNodes.find(
      (mNode) => mNode.NODE_ID === node.NODE_ID
    )
    node.MEMORY.FREE = monitoringNode.MEMORY.FREE
    node.MEMORY.USED = monitoringNode.MEMORY.USED

    node.HUGEPAGE.map((page) => {
      const monitoringPage = monitoringNode.HUGEPAGE.find(
        (mPage) => mPage.SIZE === page.SIZE
      )
      page.FREE = monitoringPage.FREE

      return page
    })

    return node
  })

  return numaNodes
}

/**
 * Validate host numa.
 *
 * @param {Host} host - host data
 */
const validateNuma = (host) => {
  const numaNodes = mergeNumaMonitoring(host.json || host)
  cy.navigateTab('numa').within(() => {
    numaNodes.forEach(({ CORE, HUGEPAGE, MEMORY }) => {
      CORE.forEach(({ ID: ID_NUMA, CPUS }) => {
        const cpus = CPUS.split(',').map((item) => item.split(':'))

        cy.getBySel(`numa-core-${ID_NUMA}`).within(() => {
          cpus.forEach(([key, value]) => {
            cy.getBySel(`cpu-${key}`).contains(CPU_STATUS[`${value}`])
          })
        })
      })

      HUGEPAGE.forEach(({ FREE, PAGES, SIZE, USAGE }, index) => {
        cy.getBySel(`hugepage-${index}`)
          .eq(index)
          .within(() => {
            cy.getBySel('size').contains(prettyBytes(SIZE))
            cy.getBySel('pages').contains(PAGES)
            cy.getBySel('free').contains(FREE)
            cy.getBySel('usage').contains(USAGE)
          })
      })

      const { TOTAL, USED } = MEMORY
      const dataMemory = getDataProgressBar({ total: TOTAL, used: USED })
      cy.getBySel('memory')
        .then(($memory) => {
          const regex = /(?<=\))/g
          const memoryLabels = $memory
            .text()
            .split(regex)
            .map((s) => s.trim())

          return memoryLabels.includes(dataMemory.percentMemLabel)
        })
        .should('equal', true)
    })
  })
}

Cypress.Commands.add('validateNuma', validateNuma)
