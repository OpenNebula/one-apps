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
import {
  Datastore,
  Group,
  Host,
  Image,
  Marketplace,
  MarketplaceApp,
  User,
  VNet,
  VmTemplate,
} from '@models'
import { PermissionsGui } from '@support/commands/common'
import { VmTemplate as vmTemplateDoc } from '@support/commands/template/jsdocs'
import { Intercepts } from '@support/utils'
import { adminContext, userContext } from '@utils/constants'
import { randomDate } from '@commands/helpers'
import { checkRestrictedAttributes } from '@common/template'

const date1 = randomDate()

const IMG_KERNEL_NAME = 'img_template_kernel'
const IMG_RAMDISK_NAME = 'img_template_ramdisk'
const IMG_CONTEXT_NAME = 'img_template_context'

const DS_DEFAULT = new Datastore('default')
const DS_IMG = new Datastore('files')
const IMG = new Image()
const IMG_USER = new Image()
const IMG_KERNEL = new Image(IMG_KERNEL_NAME)
const IMG_RAMDISK = new Image(IMG_RAMDISK_NAME)
const IMG_CONTEXT = new Image(IMG_CONTEXT_NAME)
const VNET = new VNet()
const MARKET = new Marketplace()
const MARKET_APP = new MarketplaceApp('app_from_template')
const MAIN_TEMPLATE = new VmTemplate('template_created_GUI')
const MAIN_TEMPLATE_USER = new VmTemplate('template_created_GUI_user')
const RC_TEMPLATE = new VmTemplate('template_remote_connection')
const PCI_TEMPLATE = new VmTemplate('template_PCI')
const NUMA_TEMPLATE = new VmTemplate('template_NUMA')
const HOTPLUG_TEMPLATE = new VmTemplate('template_hotplug')
const SERVERADMIN_USER = new User('serveradmin')
const USER = new User('user')
const USERS_GROUP = new Group('users')
const VERIFY_TEMPLATE = new VmTemplate('verify_template')
const VERIFY_TEMPLATE_USER = new VmTemplate('verify_template_user')
const HOST = new Host('localhost')

const IMAGE_XML = (options = {}) => {
  const {
    type = 'datablock',
    path = '',
    name = 'test_img_for_template',
  } = options
  const template = {
    NAME: name,
    HYPERVISOR: 'dummy',
    FORMAT: 'raw',
    SIZE: 100,
    TYPE: type,
  }
  if (path) {
    cy.writeFile(path, 'file for image fireedge')
    template.PATH = path
  }

  return template
}

const VNET_XML = {
  NAME: 'test_vnet_for_template',
  VN_MAD: 'dummy',
  BRIDGE: 'br0',
  AR: [{ TYPE: 'IP4', IP: '10.0.0.10', SIZE: 100 }],
  INBOUND_AVG_BW: '1500',
}

const MARKET_XML = {
  NAME: 'test_market',
  MARKET_MAD: 'http',
  BASE_URL: 'http://localhost:8000',
  PUBLIC_DIR: '/var/tmp',
}

const BASIC_TEMPLATE_XML = {
  MEMORY: 248,
  CPU: 1,
  VCPU: 1,
  CONTEXT: { NETWORK: true },
}

const TEMPLATES = {
  update: new VmTemplate('test_template_update'),
  clone: new VmTemplate('test_template_clone'),
  changeowner: new VmTemplate('test_template_changeowner'),
  changegroup: new VmTemplate('test_template_changegroup'),
  share: new VmTemplate('test_template_share'),
  unshare: new VmTemplate('test_template_unshare'),
  lock: new VmTemplate('test_template_lock'),
  unlock: new VmTemplate('test_template_unlock'),
  delete: new VmTemplate('test_template_delete'),
  rename: new VmTemplate('tests_template_rename'),
  changePermission: new VmTemplate('tests_template_changePermission'),
  createMarketApp: new VmTemplate('tests_template_createMarketApp'),
}

const baseTemplate = (name = '') => ({
  hypervisor: 'kvm',
  name,
  description: 'template description',
  memory: 248,
  cpu: 1,
  vcpu: 1,
})

/** @type {vmTemplateDoc} */
const UPDATE_TEMPLATE = {
  memory: 512,
  hypervisor: 'dummy',
  memoryHotResize: true,
  memoryMax: 1024,
  cpu: 2,
  vcpu: 2,
}

/** @type {vmTemplateDoc} */
const UPDATE_TEMPLATE_USER = {
  memory: 512,
  hypervisor: 'dummy',
  memoryHotResize: true,
  memoryMax: 1024,
  vcpu: 2,
}

/** @type {vmTemplateDoc} */
const TEMPLATE_GUI = {
  ...baseTemplate(MAIN_TEMPLATE.name),
  logo: 'images/logos/ubuntu.png',
  hypervisor: 'dummy',
  memoryHotResize: true,
  memoryMax: 528,
  memoryResizeMode: 'BALLOONING',
  vcpuHotResize: true,
  vcpuMax: 2,
  user: 'oneadmin',
  group: 'oneadmin',
  osCpu: {
    model: 'host-passthrough',
    arch: 'x86_64',
    bus: 'sata',
    os: 'host-passthrough',
    root: '',
    kernel: 'console=tt1',
    bootloader: '/c',
    uuid: '0',
    acpi: 'no',
    pae: 'no',
    apic: 'no',
    hyperV: 'no',
    localtime: 'no',
    guestAgent: 'no',
    virtioScsiQueues: '2',
    virtualBlkQueues: 'auto',
    ioThreads: '2',
    firmware: {
      enable: true,
      firmware: '',
      secure: true,
    },
    kernelOptions: {
      enable: true,
      os: 'KERNEL_PATH',
    },
    ramDisk: {
      enable: true,
      initrd: 'RAMDISK_PATH',
    },
    rawData: '<devices></devices>',
    validate: true,
  },
  inputOutput: {
    ip: '192.168.0.1',
    port: '2618',
    keymap: 'en-us',
    randomPassword: true,
    command: 'command',
    inputs: [{ type: 'tablet', bus: 'usb' }],
  },
  context: {
    network: true,
    token: true,
    report: true,
    autoAddSshKey: true,
    sshKey: '',
    startScript: '',
    encodeScript: true,
    files: [`${IMG_CONTEXT_NAME}`],
    initScripts: ['init_scripts'],
    userInputs: [
      {
        type: 'text',
        name: 'name',
        description: 'description',
        defaultValue: 'defaultValue',
        mandatory: true,
      },
    ],
    customVars: {
      CUSTOM_VAR: 'CUSTOM_VALUE',
    },
  },
  schedActions: [
    {
      action: 'hold',
      time: date1,
      periodic: 'ONETIME',
    },
    {
      action: 'terminate-hard',
      time: date1,
      periodic: 'PERIODIC',
      repeat: 'Monthly',
      repeatValue: '15',
      endType: 'Never',
    },
    {
      action: 'poweroff',
      periodic: 'RELATIVE',
      time: 3,
      period: 'days',
    },
  ],
  numa: {},
}

/** @type {vmTemplateDoc} */
const TEMPLATE_GUI_USER = {
  name: MAIN_TEMPLATE_USER.name,
  hypervisor: 'kvm',
  description: 'template description',
  memory: 248,
  vcpu: 1,
  logo: 'images/logos/ubuntu.png',
  memoryHotResize: true,
  memoryMax: 528,
  memoryResizeMode: 'BALLOONING',
  vcpuHotResize: true,
  vcpuMax: 2,
  osCpu: {
    arch: 'x86_64',
    bus: 'sata',
    os: 'host-passthrough',
    root: '',
    kernel: 'console=tt1',
    bootloader: '/c',
    uuid: '0',
    acpi: 'no',
    pae: 'no',
    apic: 'no',
    hyperV: 'no',
    localtime: 'no',
    guestAgent: 'no',
    virtioScsiQueues: '2',
    ioThreads: '2',
    firmware: {
      enable: true,
      firmware: '',
      secure: true,
    },
    kernelOptions: {
      enable: true,
      os: 'KERNEL_PATH',
    },
    ramDisk: {
      enable: true,
      initrd: 'RAMDISK_PATH',
    },
  },
  inputOutput: {
    ip: '192.168.0.1',
    port: '2618',
    keymap: 'en-us',
    randomPassword: true,
    command: 'command',
    inputs: [{ type: 'tablet', bus: 'usb' }],
  },
  context: {
    network: true,
    token: true,
    report: true,
    autoAddSshKey: true,
    sshKey: '',
    startScript: '',
    encodeScript: true,
    files: [`${IMG_CONTEXT_NAME}`],
    initScripts: ['init_scripts'],
    userInputs: [
      {
        type: 'text',
        name: 'name',
        description: 'description',
        defaultValue: 'defaultValue',
        mandatory: true,
      },
    ],
    customVars: {
      CUSTOM_VAR: 'CUSTOM_VALUE',
    },
  },
  schedActions: [
    {
      action: 'hold',
      time: date1,
      periodic: 'ONETIME',
    },
  ],
}

const DUMMY_MAD = { imMad: 'dummy', vmmMad: 'dummy' }
const HOST_PARAMS = { hostname: HOST.name, ...DUMMY_MAD }

/** @type {vmTemplateDoc} */
const TEMPLATE_REMOTE_CONNECTIONS = {
  ...baseTemplate(RC_TEMPLATE.name),
  memoryMax: 528,
  memoryHotResize: true,
  inputOutput: {
    ip: '192.168.0.1',
    port: '2618',
    keymap: 'custom',
    customKeymap: 'custom-keymap',
    randomPassword: true,
    command: 'command',
    inputs: [{ type: 'tablet', bus: 'usb' }],
  },
}

/** @type {vmTemplateDoc} */
const TEMPLATE_PCI = {
  ...baseTemplate(PCI_TEMPLATE.name),
  memoryHotResize: true,
  memoryMax: 528,
}

/** @type {vmTemplateDoc} */
const TEMPLATE_NUMA = {
  ...baseTemplate(NUMA_TEMPLATE.name),
  hypervisor: 'dummy',
  numa: {
    numaTopology: true,
    vcpu: '4',
    pinPolicy: 'NODE_AFFINITY',
    cores: '1',
    sockets: '1',
    threads: '2',
    numaAffinity: '2',
  },
}

/** @type {vmTemplateDoc} */
const TEMPLATE_HOTPLUG = {
  ...baseTemplate(HOTPLUG_TEMPLATE.name),
  memoryResizeMode: 'HOTPLUG',
  memorySlots: 1,
}

const restrictedAttributesException = {
  NIC: ['FILTER'],
}

// Modern cypress fails automatically on any exceptions
// should be removed once VM template async schema loading
// bug is resolved
Cypress.on('uncaught:exception', () => false)

describe('Sunstone GUI in VM Template tab', function () {
  context('Oneadmin', adminContext, function () {
    before(function () {
      cy.fixture('auth')
        .then((auth) => cy.apiAuth(auth.admin))
        .then(() => cy.cleanup())
        .then(() =>
          HOST.allocate({
            hostname: HOST.name,
            imMad: 'dummy',
            vmmMad: 'dummy',
          })
        )
        .then(() => !HOST.isMonitored && HOST.enable())
        .then((shouldWait) => shouldWait && HOST.waitMonitored())
        .then(() => VNET.allocate({ template: VNET_XML }))
        .then(() => DS_DEFAULT.info())
        .then(() => DS_IMG.info())
        .then(() =>
          IMG.allocate({ template: IMAGE_XML(), datastore: DS_DEFAULT.id })
        )
        .then(() =>
          IMG_KERNEL.allocate({
            template: IMAGE_XML({
              type: 'kernel',
              path: '/tmp/1',
              name: IMG_KERNEL_NAME,
            }),
            datastore: DS_IMG.id,
          })
        )
        .then(() =>
          IMG_RAMDISK.allocate({
            template: IMAGE_XML({
              type: 'ramdisk',
              path: '/tmp/2',
              name: IMG_KERNEL_NAME,
            }),
            datastore: DS_IMG.id,
          })
        )
        .then(() =>
          IMG_CONTEXT.allocate({
            template: {
              NAME: `${IMG_CONTEXT_NAME}`,
              TYPE: 'CONTEXT',
              SOURCE: '/tmp/3',
              SIZE: 1,
              FORMAT: 'qcow2',
            },
            datastore: DS_IMG.id,
          })
        )
        .then(() => IMG_KERNEL.info())
        .then(() => IMG_RAMDISK.info())
        .then(() => IMG_CONTEXT.info())
        .then(() => {
          IMG_CONTEXT.chmod({
            ownerUse: 1,
            ownerManage: 1,
            ownerAdmin: 0,
            groupUse: 0,
            groupManage: 0,
            groupAdmin: 0,
            otherUse: 1,
            otherManage: 0,
            otherAdmin: 0,
          })
        })
        .then(() => MARKET.allocate(MARKET_XML))
        .then(() => HOST.allocate(HOST_PARAMS))
        .then(() => !HOST.isMonitored && HOST.enable())
        .then(() => {
          const templates = Object.values(TEMPLATES)
          const allocateFn = (temp) => () =>
            temp.allocate({ NAME: temp.name, ...BASIC_TEMPLATE_XML })

          return cy.all(...templates.map(allocateFn))
        })
    })

    beforeEach(function () {
      cy.fixture('auth')
        .then((auth) => {
          cy.wrapperAuth(auth)
        })
        .then(() =>
          cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
            qs: { externalToken: Cypress.env('TOKEN') },
          })
        )
    })

    after(function () {
      TEMPLATES.changePermission && TEMPLATES.changePermission.delete()
      NUMA_TEMPLATE && NUMA_TEMPLATE.delete()
      VERIFY_TEMPLATE && VERIFY_TEMPLATE.delete()
      USER.info().then(() =>
        MAIN_TEMPLATE.info().then(() => MAIN_TEMPLATE.chown(USER.id))
      )
    })

    it('Should create Template with NUMA_AFFINITY', function () {
      cy.navigateMenu('templates', 'VM Templates')
      cy.createTemplateGUI(TEMPLATE_NUMA)
        .its('response.body.id')
        .should('eq', 200)
        .then(() => NUMA_TEMPLATE.info())
        .then((templateInfo) => {
          const { TOPOLOGY } = templateInfo.TEMPLATE || {}

          // Check Numa attributes
          expect(TOPOLOGY).to.not.have.property('PIN_POLICY')
          expect(TOPOLOGY.NODE_AFFINITY).to.equal(
            TEMPLATE_NUMA.numa.numaAffinity
          )
        })
    })

    it('Should update Template without NUMA_AFFINITY', function () {
      cy.navigateMenu('templates', 'VM Templates')
      const NUMA_UPDATE_TEMPLATE = {
        numa: {
          numaTopology: true,
          vcpu: '4',
          pinPolicy: 'SHARED',
          cores: '2',
          sockets: '2',
          threads: '2',
        },
      }

      NUMA_TEMPLATE.info().then(() => {
        cy.updateTemplateGUI(NUMA_TEMPLATE, NUMA_UPDATE_TEMPLATE)
          .its('response.body.id')
          .should('eq', 200)
          .then(() => NUMA_TEMPLATE.info())
          .then((templateInfo) => {
            const { TOPOLOGY } = templateInfo.TEMPLATE || {}

            // Check Numa attributes
            expect(TOPOLOGY).to.not.have.property('NODE_AFFINITY')
            expect(TOPOLOGY.PIN_POLICY).to.equal(
              NUMA_UPDATE_TEMPLATE.numa.pinPolicy
            )
          })
      })
    })

    it('Should create Template with PCI', function () {
      const PCI_ATTR = '0aa7;10de;0c03;'
      const [DEVICE, VENDOR, CLASS] = PCI_ATTR.split(';')

      cy.navigateMenu('templates', 'VM Templates')
      cy.createTemplateGUI({
        ...TEMPLATE_PCI,
        networks: [
          {
            id: VNET.id,
            name: VNET.name,
            rdp: true,
            pci: {
              type: 'PCI Passthrough - Automatic',
              name: 'MCP79 OHCI USB 1.1 Controller',
              VENDOR: VENDOR,
              DEVICE: DEVICE,
              CLASS: CLASS,
            },
          },
        ],
      })
        .its('response.body.id')
        .should('eq', 200)
        .then(() => PCI_TEMPLATE.info())
        .then(() => {
          const { PCI } = PCI_TEMPLATE.json?.TEMPLATE || {}

          // Check for the connection attributes
          expect(PCI.TYPE).to.equal('NIC')
          expect(PCI.NETWORK).to.equal(VNET.name)
          expect(PCI.DEVICE).to.equal(DEVICE)
          expect(PCI.VENDOR).to.equal(VENDOR)
          expect(PCI.CLASS).to.equal(CLASS)
        })
    })

    it('Should create Template by GUI', function () {
      cy.navigateMenu('templates', 'VM Templates')

      cy.createTemplateGUI({
        ...TEMPLATE_GUI,
        networks: [
          { id: VNET.id, name: VNET.name, ssh: true },
          { id: VNET.id, name: VNET.name, parent: '0' }, // NIC0 should be the previous nic
        ],
        storage: [
          {
            image: IMG.id,
            size: 100,
            target: 'ds',
            format: 'raw',
            type: 'fs',
            readOnly: 'YES',
            bus: 'vd',
            cache: 'default',
            io: 'native',
            discard: 'unmap',
            throttlingBytes: {
              totalValue: 10,
              totalMaximum: 10,
              totalMaximumLength: 10,
              readValue: 10,
              readMaximum: 10,
              readMaximumLength: 10,
              writeValue: 10,
              writeMaximum: 10,
              writeMaximumLength: 10,
            },
            throttlingIOPS: {
              totalValue: 10,
              totalMaximum: 10,
              totalMaximumLength: 10,
              readValue: 10,
              readMaximum: 10,
              readMaximumLength: 10,
              writeValue: 10,
              writeMaximum: 10,
              writeMaximumLength: 10,
            },
          },
        ],
      })
        .its('response.body.id')
        .should('eq', 200)
        .then(() => MAIN_TEMPLATE.info())
        .then(() => {
          const {
            CONTEXT,
            MEMORY_RESIZE_MODE,
            SCHED_ACTION,
            CPU_MODEL,
            FEATURES,
          } = MAIN_TEMPLATE.json?.TEMPLATE || {}

          // checks if custom variables are added to the new template
          Object.entries(TEMPLATE_GUI.context.customVars).forEach(
            ([key, value]) => {
              typeof value === 'object'
                ? expect(value).to.deep.equal(CONTEXT[key])
                : expect(value).to.equal(CONTEXT[key])
            }
          )

          // Check the virtio Queues
          expect(FEATURES.VIRTIO_BLK_QUEUES).to.equal(
            TEMPLATE_GUI.osCpu.virtualBlkQueues
          )
          expect(FEATURES.VIRTIO_SCSI_QUEUES).to.equal(
            TEMPLATE_GUI.osCpu.virtioScsiQueues
          )

          // Check the CPU_MODEL has MODEL and FEATURES
          expect(CPU_MODEL.MODEL).to.equal(TEMPLATE_GUI.osCpu.model)

          // Check the template has Ballooning as its memory resize mode
          expect(MEMORY_RESIZE_MODE).to.equal('BALLOONING')

          TEMPLATE_GUI.schedActions &&
            SCHED_ACTION.forEach(({ ACTION }, i) => {
              expect(ACTION).to.equal(TEMPLATE_GUI.schedActions[i].action)
            })
        })
    })

    it('Should check restricted attributes', function () {
      checkRestrictedAttributes(
        MAIN_TEMPLATE,
        true,
        restrictedAttributesException
      )
    })

    it('Should create Template with RDP and SSH', function () {
      cy.navigateMenu('templates', 'VM Templates')

      cy.createTemplateGUI({
        ...TEMPLATE_REMOTE_CONNECTIONS,
        networks: [
          {
            id: VNET.id,
            name: VNET.name,
            rdp: true,
            rdpOptions: {
              resizeMethod: 'display-update',
              disableAudio: true,
              disableBitmap: true,
              disableGlyph: true,
              disableOffscreen: true,
              enableAudioInput: true,
              enableDesktopComposition: true,
              enableFontSmoothing: true,
              enableWindowDrag: true,
              enableMenuAnimations: true,
              enableTheming: true,
              enableWallpaper: true,
            },
            ssh: true,
          },
        ],
      })
        .its('response.body.id')
        .should('eq', 200)
        .then(() => RC_TEMPLATE.info())
        .then(() => {
          const { NIC, GRAPHICS } = RC_TEMPLATE.json?.TEMPLATE || {}

          // Check for the connection attributes
          expect(GRAPHICS.KEYMAP).to.equal('custom-keymap')
          expect(NIC.RDP).to.equal('YES')
          expect(NIC.RDP_DISABLE_AUDIO).to.equal('YES')
          expect(NIC.RDP_DISABLE_BITMAP_CACHING).to.equal('YES')
          expect(NIC.RDP_DISABLE_GLYPH_CACHING).to.equal('YES')
          expect(NIC.RDP_DISABLE_OFFSCREEN_CACHING).to.equal('YES')
          expect(NIC.RDP_ENABLE_AUDIO_INPUT).to.equal('YES')
          expect(NIC.RDP_ENABLE_DESKTOP_COMPOSITION).to.equal('YES')
          expect(NIC.RDP_ENABLE_FONT_SMOOTHING).to.equal('YES')
          expect(NIC.RDP_ENABLE_FULL_WINDOW_DRAG).to.equal('YES')
          expect(NIC.RDP_ENABLE_MENU_ANIMATIONS).to.equal('YES')
          expect(NIC.RDP_ENABLE_THEMING).to.equal('YES')
          expect(NIC.RDP_ENABLE_WALLPAPER).to.equal('YES')
          expect(NIC.RDP_RESIZE_METHOD).to.equal('display-update')
          expect(NIC.SSH).to.equal('YES')
        })
    })

    it('Should create Template with hotplug as memory resize mode', function () {
      cy.navigateMenu('templates', 'VM Templates')

      cy.createTemplateGUI(TEMPLATE_HOTPLUG)
        .its('response.body.id')
        .should('eq', 200)
        .then(() => HOTPLUG_TEMPLATE.info())
        .then(() => {
          const { MEMORY_RESIZE_MODE, MEMORY_SLOTS } =
            HOTPLUG_TEMPLATE.json?.TEMPLATE || {}

          // Check for the resize mode to be changed and to have memory slots
          expect(MEMORY_RESIZE_MODE).to.equal('HOTPLUG')
          expect(MEMORY_SLOTS).to.equal('1')
        })
    })

    it('Should validate INFO TAB Template created by GUI', function () {
      cy.navigateMenu('templates', 'VM Templates')
      cy.validateVmTemplateInfo(MAIN_TEMPLATE)
    })

    it('Should update template', function () {
      if (!TEMPLATES.update) return

      cy.navigateMenu('templates', 'VM Templates')

      cy.updateTemplateGUI(TEMPLATES.update, UPDATE_TEMPLATE)
        .its('response.body.id')
        .should('eq', 200)
    })

    it('Should clone template', function () {
      if (!TEMPLATES.clone) return

      cy.navigateMenu('templates', 'VM Templates')

      cy.cloneTemplateGUI(TEMPLATES.clone, 'cloned_template')
        .its('response.body.id')
        .should('eq', 200)
    })

    it('Should change Owner', function () {
      if (!TEMPLATES.changeowner) return

      cy.navigateMenu('templates', 'VM Templates')

      SERVERADMIN_USER.info()
        .then(() => {
          cy.changeOwnerTemplate({
            templateInfo: TEMPLATES.changeowner,
            resource: SERVERADMIN_USER,
          })
        })
        .then(() => cy.getBySel('owner').contains(SERVERADMIN_USER.name))
    })

    it('Should change Group', function () {
      if (!TEMPLATES.changegroup) return

      cy.navigateMenu('templates', 'VM Templates')

      USERS_GROUP.info()
        .then(() => {
          cy.changeGroupTemplate({
            templateInfo: TEMPLATES.changegroup,
            resource: USERS_GROUP,
          })
        })
        .then(() => cy.getBySel('group').contains(USERS_GROUP.name))
    })

    it('Should share Template', function () {
      if (!TEMPLATES.share) return

      cy.navigateMenu('templates', 'VM Templates')

      cy.shareTemplate(TEMPLATES.share).then(() => {
        cy.getBySel('permission-groupUse')
          .invoke('attr', 'value')
          .should('contains', '1')
      })
    })

    it('Should unshare Template', function () {
      if (!TEMPLATES.unshare) return

      cy.navigateMenu('templates', 'VM Templates')

      cy.unshareTemplate(TEMPLATES.unshare).then(() => {
        cy.getBySel('permission-groupUse')
          .invoke('attr', 'value')
          .should('contains', '0')
      })
    })

    it('Should lock template', function () {
      if (!TEMPLATES.lock) return

      cy.navigateMenu('templates', 'VM Templates')

      cy.lockTemplate(TEMPLATES.lock).then(() => {
        cy.navigateTab('info').within(() => {
          cy.getBySel('locked').should('have.text', 'Use')
        })
      })
    })

    it('Should unlock template', function () {
      if (!TEMPLATES.unlock) return

      cy.navigateMenu('templates', 'VM Templates')

      cy.unlockTemplate(TEMPLATES.unlock).then(() => {
        cy.navigateTab('info').within(() => {
          cy.getBySel('locked').should('have.text', '-')
        })
      })
    })

    it('Should rename Template', function () {
      if (!TEMPLATES.rename) return

      const newName = 'templateRenamed'

      cy.navigateMenu('templates', 'VM Templates')

      cy.clickTemplateRow(TEMPLATES.rename)
        .then(() => cy.renameResource(newName))
        .then(() => (TEMPLATES.rename.name = newName))
        .then(() => cy.getTemplateRow(TEMPLATES.rename).contains(newName))
    })

    it('Should delete template', function () {
      if (!TEMPLATES.delete) return

      cy.navigateMenu('templates', 'VM Templates')

      cy.deleteTemplate(TEMPLATES.delete)
        .its('response.body.id')
        .should('eq', 200)
        .then(() => {
          cy.getTemplateTable({ search: TEMPLATES.delete.name }).within(() => {
            cy.get(`[role='row'][data-cy$='${TEMPLATES.delete.id}']`).should(
              'not.exist'
            )
          })
        })
    })

    it('Should change permissions Template', function () {
      if (!TEMPLATES.changePermission) return

      cy.navigateMenu('templates', 'VM Templates')

      /** @type {PermissionsGui} */
      const NEW_PERMISSIONS = {
        ownerUse: '0',
        ownerManage: '0',
        ownerAdmin: '1',
        groupUse: '1',
        groupManage: '1',
        groupAdmin: '1',
        otherUse: '1',
        otherManage: '1',
        otherAdmin: '1',
      }

      cy.clickTemplateRow(TEMPLATES.changePermission)
        .then(() =>
          cy.changePermissions(
            NEW_PERMISSIONS,
            Intercepts.SUNSTONE.TEMPLATE_CHANGE_MOD
          )
        )
        .then(() => cy.validatePermissions(NEW_PERMISSIONS))
    })

    it('Should create Marketplace App', function () {
      cy.navigateMenu('templates', 'VM Templates')

      cy.createAppFromTemplate(MARKET_APP.name, MAIN_TEMPLATE, MARKET)
        .its('response.body.id')
        .should('eq', 200)
        .then(() => MARKET_APP.info())
        .then(() => MARKET.info())
        .then(() => {
          expect(MARKET.apps).to.include(`${MARKET_APP.id}`)
        })
    })
  })

  context('User', userContext, function () {
    before(function () {
      cy.fixture('auth')
        .then((auth) => cy.apiAuth(auth.admin))
        .then(() => cy.cleanup())
        .then(() =>
          HOST.allocate({
            hostname: HOST.name,
            imMad: 'dummy',
            vmmMad: 'dummy',
          })
        )
        .then(() => !HOST.isMonitored && HOST.enable())
        .then((shouldWait) => shouldWait && HOST.waitMonitored())
        .then(() => VNET.allocate({ template: VNET_XML }))
        .then(() => DS_DEFAULT.info())
        .then(() => DS_IMG.info())
        .then(() => MARKET.allocate(MARKET_XML))
        .then(() => HOST.allocate(HOST_PARAMS))
        .then(() => !HOST.isMonitored && HOST.enable())
        .then(() => {
          const templates = Object.values(TEMPLATES)
          const allocateFn = (temp) => () =>
            temp.allocate({ NAME: temp.name, ...BASIC_TEMPLATE_XML })

          return cy.all(...templates.map(allocateFn))
        })
        .then(() => cy.fixture('auth'))
        .then((auth) => cy.apiAuth(auth.user))
        .then(() =>
          IMG_USER.allocate({
            template: IMAGE_XML({ name: 'image_user' }),
            datastore: DS_DEFAULT.id,
          })
        )
        .then(() => IMG_USER.info())
        .then(() => IMG_CONTEXT.info())
    })

    beforeEach(function () {
      cy.fixture('auth')
        .then((auth) => {
          cy.wrapperAuth(auth)
        })
        .then(() =>
          cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
            qs: { externalToken: Cypress.env('TOKEN') },
          })
        )
    })

    it('Should create Template by GUI', function () {
      cy.navigateMenu('templates', 'VM Templates')

      cy.createTemplateGUI({
        ...TEMPLATE_GUI_USER,
        networks: [
          { id: VNET.id, name: VNET.name, ssh: true },
          { id: VNET.id, name: VNET.name, parent: '0' }, // NIC0 should be the previous nic
        ],
        storage: [
          {
            image: IMG_USER.id,
            size: 100,
            format: 'raw',
            type: 'fs',
            target: 'ds',
            readOnly: 'YES',
            bus: 'vd',
            cache: 'default',
            io: 'native',
            discard: 'unmap',
          },
        ],
      })
        .its('response.body.id')
        .should('eq', 200)
        .then(() => MAIN_TEMPLATE_USER.info())
    })

    it('Should update template', function () {
      cy.navigateMenu('templates', 'VM Templates')

      const templateUser = new VmTemplate(TEMPLATE_GUI_USER.name)

      templateUser.info().then(() => {
        cy.updateTemplateGUI(templateUser, UPDATE_TEMPLATE_USER)
          .its('response.body.id')
          .should('eq', 200)
      })
    })

    it('Should check restricted attributes', function () {
      checkRestrictedAttributes(
        MAIN_TEMPLATE_USER,
        false,
        restrictedAttributesException
      )
    })

    after(function () {
      const userTemplate = new VmTemplate(TEMPLATE_GUI_USER.name)
      userTemplate.info().then(() => userTemplate.delete())
      VERIFY_TEMPLATE_USER && VERIFY_TEMPLATE_USER.delete()
    })
  })
})
