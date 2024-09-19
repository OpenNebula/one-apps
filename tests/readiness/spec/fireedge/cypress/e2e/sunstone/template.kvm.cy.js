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
import { Datastore, Host, Image, VNet, VmTemplate } from '@models'
import { VmTemplate as vmTemplateDoc } from '@support/commands/template/jsdocs'
import { randomDate } from '@commands/helpers'

const date1 = randomDate()

const IMG_KERNEL_NAME = 'img_template_kernel'
const IMG_RAMDISK_NAME = 'img_template_ramdisk'
const IMG_CONTEXT_NAME = 'img_template_context'

const DS_DEFAULT = new Datastore('default')
const DS_IMG = new Datastore('files')
const IMG = new Image()
const VNET = new VNet()
const MAIN_TEMPLATE = new VmTemplate('template_created_GUI')
const VERIFY_TEMPLATE = new VmTemplate('verify_template')
const IMG_KERNEL = new Image(IMG_KERNEL_NAME)
const IMG_RAMDISK = new Image(IMG_RAMDISK_NAME)
const IMG_CONTEXT = new Image(IMG_CONTEXT_NAME)

// Need to be host 0 because the host it's in a different virtual machine, so localhost is not valid.
const HOST = new Host('0')

const IMAGE_XML = (options = {}) => {
  const {
    type = 'datablock',
    path = '',
    name = 'test_img_for_template',
  } = options
  const template = {
    NAME: name,
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

const baseTemplate = (name = '') => ({
  hypervisor: 'kvm',
  name,
  description: 'template description',
  memory: 248,
  cpu: 1,
  vcpu: 1,
})

/** @type {vmTemplateDoc} */
const TEMPLATE_GUI = {
  ...baseTemplate(MAIN_TEMPLATE.name),
  logo: 'images/logos/ubuntu.png',
  memoryHotResize: true,
  memoryMax: 528,
  memoryResizeMode: 'BALLOONING',
  vcpuHotResize: true,
  vcpuMax: 2,
  user: 'oneadmin',
  group: 'oneadmin',
  osCpu: {
    model: 'host-passthrough',
    feature: 'arch-capabilities',
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
    rawData:
      '<devices><serial type="pty"><source path="/dev/pts/5"/><target port="0"/></serial><console type="pty" tty="/dev/pts/5"><source path="/dev/pts/5"/><target port="0"/></console></devices>',
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
      action: 'poweroff',
      periodic: 'RELATIVE',
      time: 3,
      period: 'days',
    },
  ],
}

/**
 * Use to create a template to verify attributes
 */
const TEMPLATE_VERIFY = {
  ...baseTemplate(VERIFY_TEMPLATE.name),
  memory: 3,
  memoryunit: 'GB',
  storage: [
    {
      image: 'volatile',
      size: 2,
      sizeunit: 'GB',
      format: 'raw',
      type: 'fs',
    },
  ],
  osCpu: {
    model: 'host-passthrough',
    feature: 'arch-capabilities',
  },
  inputOutput: {
    video: {
      type: 'virtio',
      iommu: false,
      ats: true,
      vram: 1024,
      resolution: '1280x720',
    },
  },
}

// Modern cypress fails automatically on any exceptions
// should be removed once VM template async schema loading
// bug is resolved
Cypress.on('uncaught:exception', () => false)

describe('Sunstone GUI in VM Template tab', function () {
  // eslint-disable-next-line mocha/no-hooks-for-single-case
  before(function () {
    cy.fixture('auth')
      .then((auth) => cy.apiAuth(auth.admin))
      .then(() => cy.cleanup())
      .then(() => HOST.info())
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
  })

  // eslint-disable-next-line mocha/no-hooks-for-single-case
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

  // eslint-disable-next-line mocha/no-hooks-for-single-case
  after(function () {
    VERIFY_TEMPLATE && VERIFY_TEMPLATE.delete()
  })

  it('Should create Template by GUI', function () {
    cy.navigateMenu('templates', 'VM Templates')

    cy.createTemplateGUI({
      ...TEMPLATE_GUI,
      storage: [
        {
          image: IMG.id,
          size: 100,
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
        expect(CPU_MODEL.FEATURES).to.equal(TEMPLATE_GUI.osCpu.feature)
        expect(CPU_MODEL.MODEL).to.equal(TEMPLATE_GUI.osCpu.model)

        // Check the template has Ballooning as its memory resize mode
        expect(MEMORY_RESIZE_MODE).to.equal('BALLOONING')

        TEMPLATE_GUI.schedActions &&
          SCHED_ACTION.forEach(({ ACTION }, i) => {
            expect(ACTION).to.equal(TEMPLATE_GUI.schedActions[i].action)
          })
      })
  })

  /**
   * Create a verify template to validate attributes
   */
  it('Should create a verify Template and validate attributes', function () {
    // Navigate to templates menu
    cy.navigateMenu('templates', 'VM Templates')

    // Attributes to validate
    const validateList = [
      {
        field: 'MEMORY',
        value: '3072',
      },
      {
        field: 'DISK.SIZE',
        value: '2048',
      },
      {
        field: 'VIDEO.TYPE',
        value: 'virtio',
      },
      {
        field: 'VIDEO.IOMMU',
        value: 'NO',
      },
      {
        field: 'VIDEO.ATS',
        value: 'YES',
      },
      {
        field: 'VIDEO.RESOLUTION',
        value: '1280x720',
      },
      {
        field: 'VIDEO.VRAM',
        value: '1024',
      },
      {
        field: 'CPU_MODEL.MODEL',
        value: 'host-passthrough',
      },
      {
        field: 'CPU_MODEL.FEATURES',
        value: 'arch-capabilities',
      },
    ]

    // Create a template by GUI.
    // TEMPLATE_VERIFY it's the json with the data to fill on the GUI
    // VERIFY_TEMPLATE it's the VMTemplate object
    cy.createTemplateGUIAndValidate(
      TEMPLATE_VERIFY,
      validateList,
      VERIFY_TEMPLATE
    )
  })
})
