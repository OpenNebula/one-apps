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

import { OpenNebulaResource } from '@models'

const VM_STATES = [
  'INIT',
  'PENDING',
  'HOLD',
  'ACTIVE',
  'STOPPED',
  'SUSPENDED',
  'DONE',
  'FAILED',
  'POWEROFF',
  'UNDEPLOYED',
  'CLONING',
  'CLONING_FAILURE',
]

const VM_LCM_STATES = [
  'LCM_INIT',
  'PROLOG',
  'BOOT',
  'RUNNING',
  'MIGRATE',
  'SAVE_STOP',
  'SAVE_SUSPEND',
  'SAVE_MIGRATE',
  'PROLOG_MIGRATE',
  'PROLOG_RESUME',
  'EPILOG_STOP',
  'EPILOG',
  'SHUTDOWN',
  'CANCEL',
  'FAILURE',
  'CLEANUP_RESUBMIT',
  'UNKNOWN',
  'HOTPLUG',
  'SHUTDOWN_POWEROFF',
  'BOOT_UNKNOWN',
  'BOOT_POWEROFF',
  'BOOT_SUSPENDED',
  'BOOT_STOPPED',
  'CLEANUP_DELETE',
  'HOTPLUG_SNAPSHOT',
  'HOTPLUG_NIC',
  'HOTPLUG_SAVEAS',
  'HOTPLUG_SAVEAS_POWEROFF',
  'HOTPLUG_SAVEAS_SUSPENDED',
  'SHUTDOWN_UNDEPLOY',
  'EPILOG_UNDEPLOY',
  'PROLOG_UNDEPLOY',
  'BOOT_UNDEPLOY',
  'HOTPLUG_PROLOG_POWEROFF',
  'HOTPLUG_EPILOG_POWEROFF',
  'BOOT_MIGRATE',
  'BOOT_FAILURE',
  'BOOT_MIGRATE_FAILURE',
  'PROLOG_MIGRATE_FAILURE',
  'PROLOG_FAILURE',
  'EPILOG_FAILURE',
  'EPILOG_STOP_FAILURE',
  'EPILOG_UNDEPLOY_FAILURE',
  'PROLOG_MIGRATE_POWEROFF',
  'PROLOG_MIGRATE_POWEROFF_FAILURE',
  'PROLOG_MIGRATE_SUSPEND',
  'PROLOG_MIGRATE_SUSPEND_FAILURE',
  'BOOT_UNDEPLOY_FAILURE',
  'BOOT_STOPPED_FAILURE',
  'PROLOG_RESUME_FAILURE',
  'PROLOG_UNDEPLOY_FAILURE',
  'DISK_SNAPSHOT_POWEROFF',
  'DISK_SNAPSHOT_REVERT_POWEROFF',
  'DISK_SNAPSHOT_DELETE_POWEROFF',
  'DISK_SNAPSHOT_SUSPENDED',
  'DISK_SNAPSHOT_REVERT_SUSPENDED',
  'DISK_SNAPSHOT_DELETE_SUSPENDED',
  'DISK_SNAPSHOT',
  'DISK_SNAPSHOT_REVERT',
  'DISK_SNAPSHOT_DELETE',
  'PROLOG_MIGRATE_UNKNOWN',
  'PROLOG_MIGRATE_UNKNOWN_FAILURE',
  'DISK_RESIZE',
  'DISK_RESIZE_POWEROFF',
  'DISK_RESIZE_UNDEPLOYED',
  'HOTPLUG_NIC_POWEROFF',
  'HOTPLUG_RESIZE',
  'HOTPLUG_SAVEAS_UNDEPLOYED',
  'HOTPLUG_SAVEAS_STOPPED',
]

const NIC_IP_ATTRS = [
  'EXTERNAL_IP', // external IP must be first
  'IP',
  'IP6',
  ['IP6_ULA', 'IP6_GLOBAL'],
  'MAC',
]

const EXTERNAL_IP_ATTRS = ['GUEST_IP', 'GUEST_IP_ADDRESSES']

class VirtualMachine extends OpenNebulaResource {
  /** @returns {boolean} Whether the VM is public */
  isPublic() {
    return (
      this.json?.PERMISSIONS?.GROUP_U === '1' ||
      this.json?.PERMISSIONS?.OTHER_U === '1'
    )
  }

  /** @returns {boolean} Last history record  */
  lastHistory() {
    const records = this.json?.HISTORY_RECORDS?.HISTORY
    const ensured = Array.isArray(records) ? records : [records]

    return ensured.length > 0 ? ensured[ensured.length - 1] : null
  }

  /** @returns {boolean} Hostname where VM is located */
  hostname() {
    return this.lastHistory?.HOSTNAME
  }

  /** @returns {boolean} Host ID where VM is located */
  hostId() {
    return this.lastHistory?.HID
  }

  /** @returns {string} The VM state */
  get state() {
    const state = VM_STATES[this.json.STATE]
    const lcmState = VM_LCM_STATES[this.json.LCM_STATE]

    return state === 'ACTIVE' ? lcmState : state
  }

  /** @returns {string} The nics */
  nics() {
    const { TEMPLATE = {}, MONITORING = {} } = this.json || {}
    const { NIC = [], NIC_ALIAS = [], PCI = [] } = TEMPLATE

    const pciNics = PCI.filter(({ NIC_ID } = {}) => NIC_ID !== undefined)
    const nics = [NIC, NIC_ALIAS, pciNics].flat().filter(Boolean)

    // MONITORING data is not always available
    if (Object.keys(MONITORING).length > 0) {
      const externalIps = EXTERNAL_IP_ATTRS.map((externalAttribute) =>
        MONITORING[externalAttribute]?.split(',')
      )

      const ensuredExternalIps = [...externalIps].flat().filter(Boolean)
      const externalNics = ensuredExternalIps.map((externalIp) => ({
        NIC_ID: '_',
        IP: externalIp,
        NETWORK: 'Additional IP',
      }))

      nics.concat(externalNics)
    }

    return nics
  }

  /** @returns {string} The all IPs from nics */
  get ips() {
    return this.nics().map(this.#getIpsFromNic).filter(Boolean).flat()
  }

  /** @returns {string[]} - Labels */
  get labels() {
    const labels = this.json.USER_TEMPLATE?.LABELS?.split(',') ?? []

    return labels.filter(Boolean).map((label) => label.toUpperCase())
  }

  /** @returns {string[]} - Backup ids */
  get backupIds() {
    return [].concat(this.json?.BACKUPS?.BACKUP_IDS?.ID ?? [])
  }

  /** @returns {object} - Backup config */
  get backupConfig() {
    return this.json?.BACKUPS?.BACKUP_CONFIG ?? {}
  }

  /**
   * @param {object} nic - The nic to get the IP from
   * @returns {string} The IPs from a NIC
   */
  #getIpsFromNic(nic) {
    const attributeIp = NIC_IP_ATTRS.find((attr) =>
      [attr].flat().every((flatted) => nic[flatted] !== undefined)
    )

    if (attributeIp) {
      return [attributeIp]
        .flat()
        .map((attribute) => nic[attribute])
        .join(' ')
    }
  }

  /**
   * @param {string} state - The state to wait for
   * @param {object} config - waitUntil Config
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves when the VM reaches the state
   */
  waitState(state, config) {
    return cy.waitUntil(
      () =>
        this.info().then(() =>
          Array.isArray(state)
            ? state.includes(this.state)
            : this.state === state
        ),
      config
    )
  }

  /**
   * @param {object} config - waitUntil Config
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves when the VM is running
   */
  waitRunning(config = {}) {
    return this.waitState('RUNNING', config)
  }

  /**
   * @param {object} config - waitUntil Config
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves when the VM is hold
   */
  waitHold(config = {}) {
    return this.waitState('HOLD', config)
  }

  /**
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves when the VM is stopped
   */
  waitStop() {
    return this.waitState(['STOPPED', 'POWEROFF'])
  }

  /**
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves when the VM is failed
   */
  waitFailed() {
    return this.waitState('FAILED')
  }

  /**
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves when the VM is undeployed
   */
  waitUndeployed() {
    return this.waitState('UNDEPLOYED')
  }

  /**
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves when the VM is done
   */
  waitDone() {
    return this.waitState('DONE')
  }

  /**
   * Retrieves information for the vm.
   *
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves to the vm information
   */
  info() {
    const id = this.id ?? this.name

    return cy.apiGetVm(id).then((vm) => {
      this.json = vm

      return vm
    })
  }

  /**
   * @param {boolean} hard - If `true`, the VM will be hard deleted
   * @returns {Cypress.Chainable<string>}
   * A promise that resolves to the vm id
   */
  terminate(hard = false) {
    return cy.apiActionVm(this.id, hard ? 'terminate-hard' : 'terminate')
  }

  /**
   * @param {boolean} hard - If `true`, the VM will be hard rebooted
   * @returns {Cypress.Chainable<string>}
   * A promise that resolves to the vm id
   */
  reboot(hard = false) {
    return cy.apiActionVm(this.id, hard ? 'reboot-hard' : 'reboot')
  }

  /**
   * @param {boolean} hard - If `true`, the VM will be hard power off
   * @returns {Cypress.Chainable<string>}
   * A promise that resolves to the vm id
   */
  poweroff(hard = false) {
    return cy.apiActionVm(this.id, hard ? 'poweroff-hard' : 'poweroff')
  }

  /**
   * @param {boolean} hard - If `true`, the VM will be hard undeployed
   * @returns {Cypress.Chainable<string>}
   * A promise that resolves to the vm id
   */
  undeploy(hard = false) {
    return cy.apiActionVm(this.id, hard ? 'undeploy-hard' : 'undeploy')
  }

  /**
   * @param {string} host - The target host id
   * @param {boolean} enforce
   * - If `true`, will enforce the Host capacity isn't over committed
   * @param {string} datastore - The target datastore id
   * @returns {Cypress.Chainable<Cypress.Response>}
   * A promise that resolves to the vm id
   */
  deploy(host = false, enforce = false, datastore = -1) {
    return cy.apiDeployVm(this.id, { host, enforce, datastore })
  }

  /**
   * @param {object} permissions - permissions
   * @returns {Cypress.Chainable<Cypress.Response>}
   * A promise that resolves to the vm id
   */
  chmod(permissions) {
    return cy.apiChmodVm(this.id, permissions)
  }

  /**
   * @param {number} user - user ID
   * @returns {Cypress.Chainable<Cypress.Response>}
   * A promise that resolves to the vm id
   */
  chown(user) {
    return cy.apiChownVm(this.id, user)
  }

  /**
   * Create a snapshot of the vm.
   *
   * @param {string} name - Snapshot name
   * @returns {Cypress.Chainable<Cypress.Response>}
   * A promise that resolves to the vm id
   */
  snapshot(name) {
    return cy.snapshot(this.id, name)
  }
}

export default VirtualMachine
