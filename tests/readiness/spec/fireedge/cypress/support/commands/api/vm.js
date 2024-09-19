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

import { ENV } from '@commands/api'

const XML_ROOT = 'VM'
const XML_POOL_ROOT = 'VM_POOL'
const REG_ID_FROM_ERROR = new RegExp(`${XML_ROOT} (\\d+)`)

/**
 * Retrieves information for all or part of the VMs in the pool.
 *
 * @param {object} qs - Query parameters
 * @param {boolean} [qs.extended] - Retrieves information for all or part
 * @param {number} [qs.filter] - Filter flag
 * @param {number} [qs.start] - Range start ID
 * @param {number} [qs.end] - Range end ID
 * @param {number} [qs.state] - VM state to filter by
 * - `-2`: Any state, including DONE
 * - `-1`: Any state, except DONE
 * - `0`:  INIT
 * - `1`:  PENDING
 * - `2`:  HOLD
 * - `3`:  ACTIVE
 * - `4`:  STOPPED
 * - `5`:  SUSPENDED
 * - `6`:  DONE
 * - `8`:  POWEROFF
 * - `9`:  UNDEPLOYED
 * - `10`: CLONING
 * - `11`: CLONING_FAILURE
 * @returns {Cypress.Chainable<object[]>}
 * A promise that resolves to the VMs information
 */
const getVms = (qs) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/vmpool/info/`

  return cy
    .request({ url, auth: { bearer: jwt }, qs })
    .its(`body.data.${XML_POOL_ROOT}`)
    .then((pool) => pool?.[XML_ROOT] || [])
    .then((pool) => (Array.isArray(pool) ? pool : [pool]))
}

/**
 * Retrieves information for the virtual machine.
 *
 * @param {string} id - Template id
 * @returns {Cypress.Chainable<object>}
 * A promise that resolves to the VM information
 */
const getVm = (id) => {
  if (typeof id === 'string' && isNaN(+id)) {
    // find VM by name from pool if id is a string and not a number
    return getVms().then((pool) => pool.find((vm) => vm.NAME === id))
  }

  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/vm/info/${id}`

  return cy.request({ url, auth: { bearer: jwt } }).its(`body.data.${XML_ROOT}`)
}

/**
 * Initiates the instance of the given VM id on the target host.
 *
 * @param {string} id - Virtual machine id
 * @param {object} body - Request body for the POST request
 * @param {string} body.host - The target host id
 * @param {string} [body.datastore] - The target datastore id.
 * It is optional, and can be set to -1 to let OpenNebula choose the datastore
 * @param {boolean} [body.enforce] - If `true`, will enforce the Host capacity isn't over committed.
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to the deployed VM id
 */
const deployVm = (id, body) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/vm/deploy/${id}`

  return cy
    .request({
      method: 'PUT',
      url,
      auth: { bearer: jwt },
      body,
      failOnStatusCode: false,
    })
    .then(({ isOkStatusCode, body: { data } }) =>
      isOkStatusCode ? data : data.match(REG_ID_FROM_ERROR)?.[1]
    )
}

/**
 * Submits an action to be performed on a virtual machine.
 *
 * @param {string} id - Virtual machine id
 * @param {(
 * 'terminate-hard'|'terminate'|'undeploy-hard'|'undeploy'|
 * 'poweroff-hard'|'poweroff'|'reboot-hard'|'reboot'|
 * 'hold'|'release'|'stop'|'suspend'|'resume'|'resched'|'unresched'
 * )} action - Action to perform
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to the deployed VM id
 */
const actionVm = (id, action) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/vm/action/${id}`

  return cy
    .request({
      method: 'PUT',
      url,
      auth: { bearer: jwt },
      body: { action },
      failOnStatusCode: false,
    })
    .then(({ isOkStatusCode, body: { data } }) =>
      isOkStatusCode ? data : data.match(REG_ID_FROM_ERROR)?.[1]
    )
}

/**
 * Submits a recover action to be performed on a virtual machine.
 *
 * @param {string} id - Virtual machine id
 * @param {(
 * '0'|'1'|'2'|'3'|'4'|'5'
 * )} operation - Recovery operation to perform
 * 0 => Failure
 * 1 => Success
 * 2 => Retry
 * 3 => Delete
 * 4 => Recreate
 * 5 => Delete database
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to the deployed VM id
 */
const recoverVm = (id, operation) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/vm/recover/${id}`

  return cy
    .request({
      method: 'PUT',
      url,
      auth: { bearer: jwt },
      body: { operation },
      failOnStatusCode: false,
    })
    .then(({ isOkStatusCode, body: { data } }) =>
      isOkStatusCode ? data : data.match(REG_ID_FROM_ERROR)?.[1]
    )
}

const recoverDeleteVm = (id) => recoverVm(id, '3')

/**
 * Submits permissions on a virtual machine.
 *
 * @param {string} id - Virtual machine id
 * @param {object} permissions - Permissions to perform
 * @returns {Cypress.Chainable<string>}
 * A promise that resolves to the deployed VM id
 */
const chmodVm = (id, permissions = {}) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/vm/chmod/${id}`

  return cy
    .request({
      method: 'PUT',
      url,
      auth: { bearer: jwt },
      body: permissions,
      failOnStatusCode: false,
    })
    .then(({ isOkStatusCode, body: { data } }) =>
      isOkStatusCode ? data : data.match(REG_ID_FROM_ERROR)?.[1]
    )
}

const chownVm = (id, user) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/vm/chown/${id}`

  return cy
    .request({
      method: 'PUT',
      url,
      auth: { bearer: jwt },
      body: { user },
      failOnStatusCode: false,
    })
    .then(({ body: { data } }) => data)
}

const snapshot = (id, name) => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const url = `${baseUrl}/api/vm/snapshotcreate/${id}`

  return cy
    .request({
      method: 'POST',
      url,
      auth: { bearer: jwt },
      body: { name },
      failOnStatusCode: false,
    })
    .then(({ body: { data } }) => data)
}

Cypress.Commands.add('apiGetVms', getVms)
Cypress.Commands.add('apiGetVm', getVm)
Cypress.Commands.add('apiDeployVm', deployVm)
Cypress.Commands.add('apiActionVm', actionVm)
Cypress.Commands.add('apiRecoverVm', recoverVm)
Cypress.Commands.add('apiChmodVm', chmodVm)
Cypress.Commands.add('apiChownVm', chownVm)
Cypress.Commands.add('apiRecoverDeleteVm', recoverDeleteVm)
Cypress.Commands.add('snapshot', snapshot)
