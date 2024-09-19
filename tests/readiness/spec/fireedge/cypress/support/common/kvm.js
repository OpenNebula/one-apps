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

const {
  Datastore,
  VirtualMachine,
  VmTemplate,
  User,
  Image,
} = require('@models')

const { performBackupActionToVM } = require('@common/vms')

/**
 * Before cypress for backup tests.
 *
 * @param {object} resources - resources
 */
const beforeBackupTest = (resources = {}) => {
  const {
    VNET,
    VNET_XML,
    DS_IMG,
    HOST,
    MARKET_APP,
    MARKET_APP_BKS,
    DATASTORES,
    TEMPLATE_NAME,
    VMS,
    USER,
    TEMPLATES,
  } = resources

  cy.fixture('auth')
    .then((auth) => cy.apiAuth(auth.admin))
    .then(() => cy.apiSunstoneConf())
    .then(() => cy.cleanup())
    .then(() => VNET.allocate({ template: VNET_XML }))
    .then(() => DS_IMG.info())
    .then(() => HOST.info())
    .then(() => !HOST.isMonitored && HOST.enable())
    .then((shouldWait) => shouldWait && HOST.waitMonitored())
    .then(() => MARKET_APP.info())
    .then(() => MARKET_APP_BKS.info())
    .then(() => {
      Object.entries(DATASTORES).forEach(([key, value]) => {
        const DS = new Datastore(value)
        DS.info().then(() => (DATASTORES[key] = DS))
      })
    })
    .then(() =>
      MARKET_APP_BKS.exportApp({
        associated: true,
        datastore: DS_IMG.id,
        name: TEMPLATE_NAME,
        vmname: TEMPLATE_NAME,
      })
    )
    .then((market) => {
      const user = new User(USER)
      const { template } = market
      user.allocate({ username: USER, password: 'opennebula' }).then(() => {
        Object.entries(VMS).forEach(([key, { deploy, ...vmData }]) => {
          const TEMPLATE = new VmTemplate(template)
          TEMPLATE.instantiate(vmData).then((vmId) => {
            VMS[key] = new VirtualMachine(vmId)
            // deploy if needed
            deploy &&
              VMS[key]
                .deploy(HOST.id)
                .then(() =>
                  VMS[key].waitRunning({
                    errorMsg: 'Timeout when waiting for RUNNING state on VM',
                    timeout: 60000,
                  })
                )
                .then(() => VMS[key].chmod({ ownerAdmin: '1' }))
                .then(() => VMS[key].chown(user.id))
          })
        })
      })
    })
    .then(() => {
      TEMPLATES.forEach((template) => {
        const templateModel = new VmTemplate(template.name)
        templateModel.allocate(template)

        const user = new User(USER)
        user.info().then(() => {
          templateModel.chown(user.id)
        })
      })
    })
}

/**
 * After cypress for backup tests.
 *
 * @param {object} resources - resources
 */
const afterBackupTest = (resources = {}) => {
  const { VMS, TEMPLATE_NAME } = resources
  Object.values(VMS).forEach((vm) => vm?.terminate?.(true))
  cy.fixture('auth')
    .then((auth) => cy.apiAuth(auth.admin))
    .then(() => {
      const TEMPLATE = new VmTemplate(TEMPLATE_NAME)
      TEMPLATE.info().then(() => TEMPLATE.delete(true))
    })
}

/**
 * Before each cypress for backup tests.
 */
const beforeEachTest = () => {
  cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
    qs: { externalToken: Cypress.env('TOKEN') },
  })
}

/**
 * Import Market app.
 *
 * @param {object} resources - resources
 */
const importMarketplaceApp = (resources = {}) => {
  const { MARKET_APP, DS_IMG } = resources

  cy.navigateMenu('storage', 'Apps')

  cy.importMarketApp(MARKET_APP, DS_IMG)
    .its('response.body.id')
    .should('eq', 200)
}

/**
 * Check Imported vm template.
 *
 * @param {object} resources - resources
 */
const checkImportedVMTemplate = (resources = {}) => {
  const { APP_TEMPLATE, MARKET_APP } = resources
  APP_TEMPLATE.info().then(() => {
    expect(APP_TEMPLATE.name).to.eq(MARKET_APP.name)
  })
}

/**
 * Instantiate VM.
 *
 * @param {object} resources - resources
 */
const instantiateVM = (resources = {}) => {
  const { APP_TEMPLATE, VNET, VM } = resources

  cy.navigateMenu('instances', 'VMs')

  APP_TEMPLATE.info().then(() => {
    cy.instantiateVM({
      templateId: APP_TEMPLATE.id,
      vmTemplate: {
        name: VM.name,
        networks: [{ id: VNET.id, name: VNET.name }],
      },
    })
  })
}

/**
 * Instantiate VM and validte template.
 *
 * @param {object} resources - resources
 * @param {Array} validateList - List of attributes to validate
 */
const instantiateVMandValidate = (resources = {}, validateList) => {
  const { APP_TEMPLATE, VM } = resources

  cy.navigateMenu('instances', 'VMs')

  APP_TEMPLATE.info().then(() => {
    cy.instantiateVMandValidate(
      {
        templateId: APP_TEMPLATE.id,
        vmTemplate: {
          name: VM.name,
        },
      },
      validateList
    )
  })
}

/**
 * Deploy VM.
 *
 * @param {object} resources - resources
 */
const deployVM = (resources = {}) => {
  const { VM, HOST, DS_SYSTEM } = resources
  DS_SYSTEM.info()
  cy.navigateMenu('instances', 'VMs')
  VM.info()
    .then(() => cy.deployVm(VM, { host: HOST, ds: DS_SYSTEM }))
    .then(() => {
      cy.navigateTab('info').within(() => {
        cy.getBySel('state').should('have.text', 'RUNNING')
      })
    })
}

/**
 * Check IPS in VM.
 *
 * @param {object} VM - Virtual machine
 */
const checkTheIPsFromVM = (VM) => {
  cy.navigateMenu('instances', 'VMs')
  VM.info().then(() => cy.validateVmIps(VM))
}

/**
 * Check Guacamole VNC.
 *
 * @param {object} VM - Virtual machine
 */
const openGuacamoleVNC = (VM) => {
  const baseUrl = Cypress.config('baseUrl')
  VM.waitRunning({
    errorMsg: 'Timeout when waiting for RUNNING state on VM',
    timeout: 60000,
  })
    .then(() => cy.fixture('auth'))
    .then((auth) =>
      cy.task(
        'externalBrowserConsole',
        {
          auth,
          cypress: { ...Cypress.config(), endpoint: `${baseUrl}/sunstone` },
          vm: {
            id: VM.id,
            type: VM.json?.TEMPLATE?.GRAPHICS?.TYPE,
            waitURLConsole: `${baseUrl}/api/vm/${VM.id}/guacamole/vnc`,
            waitURLListVms: `${baseUrl}/api/vmpool/info/`,
          },
        },
        { timeout: 900000 /* 15 minutes */ }
      )
    )
    .then(
      ({
        id: idConsole = '',
        name: nameConsole = '',
        ips = '',
        state = '',
        canvas = false,
        canvasPercent = 100,
        fullscreen = false,
        ctrlAltDel = false,
        reconnect = false,
        screenshot = false,
      }) => {
        // eslint-disable-next-line no-unused-expressions
        expect(canvas).to.be.true
        // eslint-disable-next-line no-unused-expressions
        expect(canvasPercent).to.be.below(10)
        // eslint-disable-next-line no-unused-expressions
        expect(fullscreen).to.be.true
        // eslint-disable-next-line no-unused-expressions
        expect(ctrlAltDel).to.be.true
        // eslint-disable-next-line no-unused-expressions
        expect(reconnect).to.be.true
        // eslint-disable-next-line no-unused-expressions
        expect(screenshot).to.be.true
        expect(state).to.include('Connected')
        expect(idConsole).to.include(VM.id)
        expect(nameConsole).to.include(VM.name)

        for (const ip of VM.ips) {
          expect(ips).to.include(ip)
        }
      }
    )
}

/**
 * Create VM Backup.
 *
 * @param {object} resources - resources
 */
const performBackup = (resources = {}) => {
  const { VM, DATASTORE } = resources

  let BACKUP
  performBackupActionToVM(VM, { ds: DATASTORE, reset: false }).then(
    (backupID) => {
      BACKUP = new Image(backupID)
      BACKUP.info().then(() => {
        cy.validateBackupInfo(BACKUP)
      })
    }
  )
}

module.exports = {
  beforeBackupTest,
  afterBackupTest,
  beforeEachTest,
  importMarketplaceApp,
  checkImportedVMTemplate,
  instantiateVM,
  instantiateVMandValidate,
  deployVM,
  checkTheIPsFromVM,
  openGuacamoleVNC,
  performBackup,
}
