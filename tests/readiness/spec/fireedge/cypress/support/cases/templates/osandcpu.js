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
import { expectedTemplateMandatoryValues } from './utils'

const caseCPUModel = {
  initialData: {
    template: {
      name: 'caseCPUModel',
      hypervisor: 'kvm',
      description: 'Create a template with cpu model and update it',
      memory: 248,
      cpu: 0.1,
      osCpu: {
        model: 'host-passthrough',
        feature: 'abm',
      },
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create a template with cpu model and update it',
        'kvm',
        '248'
      ),
      CPU_MODEL: {
        FEATURES: 'abm',
        MODEL: 'host-passthrough',
      },
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'booting',
          sectionActions: [
            {
              type: 'update',
              template: {
                model: '-',
                feature: 'acpi',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with cpu model and update it',
          'kvm',
          '248'
        ),
        CPU_MODEL: {
          FEATURES: 'acpi',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'booting',
          sectionActions: [
            {
              type: 'update',
              template: {
                model: '-',
                feature: '-',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with cpu model and update it',
          'kvm',
          '248'
        ),
      },
    },
  ],
}

const caseFeatures = {
  initialData: {
    template: {
      name: 'caseFeatures',
      hypervisor: 'kvm',
      description: 'Create a template with features and update it',
      memory: 248,
      cpu: 0.1,
      osCpu: {
        acpi: 'YES',
        pae: 'YES',
        apic: 'YES',
        hyperV: 'YES',
        localtime: 'YES',
        guestAgent: 'YES',
        virtioScsiQueues: '2',
        virtualBlkQueues: '1',
        ioThreads: 1,
      },
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create a template with features and update it',
        'kvm',
        '248'
      ),
      FEATURES: {
        ACPI: 'yes',
        APIC: 'yes',
        GUEST_AGENT: 'yes',
        HYPERV: 'yes',
        IOTHREADS: '1',
        LOCALTIME: 'yes',
        PAE: 'yes',
        VIRTIO_BLK_QUEUES: '1',
        VIRTIO_SCSI_QUEUES: '2',
      },
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'booting',
          sectionActions: [
            {
              type: 'update',
              template: {
                acpi: 'NO',
                pae: 'NO',
                apic: 'NO',
                hyperV: 'NO',
                localtime: 'NO',
                guestAgent: 'NO',
                virtioScsiQueues: '3',
                virtualBlkQueues: '3',
                ioThreads: 20,
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with features and update it',
          'kvm',
          '248'
        ),
        FEATURES: {
          ACPI: 'no',
          APIC: 'no',
          GUEST_AGENT: 'no',
          HYPERV: 'no',
          IOTHREADS: '20',
          LOCALTIME: 'no',
          PAE: 'no',
          VIRTIO_BLK_QUEUES: '3',
          VIRTIO_SCSI_QUEUES: '3',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'booting',
          sectionActions: [
            {
              type: 'update',
              template: {
                acpi: '-',
                pae: '-',
                apic: '-',
                hyperV: '-',
                localtime: '-',
                guestAgent: '-',
                virtioScsiQueues: '-',
                virtualBlkQueues: '-',
                ioThreads: '',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with features and update it',
          'kvm',
          '248'
        ),
      },
    },
  ],
}

const caseKernelRamdisk = {
  initialData: {
    template: {
      name: 'caseKernelRamdisk',
      hypervisor: 'kvm',
      description: 'Create a template with kernal and ramdisk',
      memory: 248,
      cpu: 0.1,
      osCpu: {
        kernelOptions: {
          enable: true,
          os: '/path/to/kernel',
        },
        ramDisk: {
          enable: true,
          initrd: '/path/to/ramdisk',
        },
      },
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create a template with kernal and ramdisk',
        'kvm',
        '248'
      ),
      OS: {
        INITRD: '/path/to/ramdisk',
        KERNEL: '/path/to/kernel',
      },
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'booting',
          sectionActions: [
            {
              type: 'update',
              template: {
                kernelOptions: {
                  enable: true,
                  os: '/path/to/kernel2',
                },
                ramDisk: {
                  enable: true,
                  initrd: '/path/to/ramdisk2',
                },
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with kernal and ramdisk',
          'kvm',
          '248'
        ),
        OS: {
          INITRD: '/path/to/ramdisk2',
          KERNEL: '/path/to/kernel2',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'booting',
          sectionActions: [
            {
              type: 'update',
              template: {
                kernelOptions: {
                  enable: false,
                  os: 'kernelimage1',
                },
                ramDisk: {
                  enable: false,
                  initrd: 'ramimage1',
                },
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with kernal and ramdisk',
          'kvm',
          '248'
        ),
        OS: {
          INITRD_DS: '$FILE[IMAGE_ID=#ramimage1#]',
          KERNEL_DS: '$FILE[IMAGE_ID=#kernelimage1#]',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'booting',
          sectionActions: [
            {
              type: 'update',
              template: {
                kernelOptions: {
                  enable: true,
                  os: '/path/to/kernel',
                },
                ramDisk: {
                  enable: false,
                  initrd: 'ramimage1',
                },
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with kernal and ramdisk',
          'kvm',
          '248'
        ),
        OS: {
          INITRD_DS: '$FILE[IMAGE_ID=#ramimage1#]',
          KERNEL: '/path/to/kernel',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'booting',
          sectionActions: [
            {
              type: 'update',
              template: {
                kernelOptions: {
                  enable: false,
                  os: 'kernelimage1',
                },
                ramDisk: {
                  enable: false,
                  initrd: 'ramimage1',
                },
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with kernal and ramdisk',
          'kvm',
          '248'
        ),
        OS: {
          INITRD_DS: '$FILE[IMAGE_ID=#ramimage1#]',
          KERNEL_DS: '$FILE[IMAGE_ID=#kernelimage1#]',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'booting',
          sectionActions: [
            {
              type: 'update',
              template: {
                kernelOptions: {
                  enable: false,
                  os: 'kernelimage2',
                },
                ramDisk: {
                  enable: false,
                  initrd: 'ramimage2',
                },
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with kernal and ramdisk',
          'kvm',
          '248'
        ),
        OS: {
          INITRD_DS: '$FILE[IMAGE_ID=#ramimage2#]',
          KERNEL_DS: '$FILE[IMAGE_ID=#kernelimage2#]',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'booting',
          sectionActions: [
            {
              type: 'update',
              template: {
                kernelOptions: {
                  enable: false,
                  os: '',
                },
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with kernal and ramdisk',
          'kvm',
          '248'
        ),
      },
    },
  ],
}

const caseBoot = {
  initialData: {
    template: {
      name: 'caseBoot',
      hypervisor: 'kvm',
      description: 'Create a template with data on boot section',
      memory: 248,
      cpu: 0.1,
      osCpu: {
        arch: 'i686',
        bus: 'SATA',
        os: 'host-passthrough',
        root: 'rootdevice',
        kernel: 'parameter1=value1',
        bootloader: '/path/bootloader',
        uuid: '1',
        firmware: {
          firmware: '/path/firmware',
          secure: true,
        },
      },
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create a template with data on boot section',
        'kvm',
        '248'
      ),
      OS: {
        ARCH: 'i686',
        BOOTLOADER: '/path/bootloader',
        FIRMWARE: '/path/firmware',
        FIRMWARE_SECURE: 'YES',
        KERNEL_CMD: 'parameter1=value1',
        MACHINE: 'host-passthrough',
        ROOT: 'rootdevice',
        SD_DISK_BUS: 'sata',
        UUID: '1',
      },
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'booting',
          sectionActions: [
            {
              type: 'update',
              template: {
                arch: 'x86_64',
                bus: 'SCSI',
                os: '-',
                root: 'rootdevice2',
                kernel: 'parameter2=value2',
                bootloader: '/path/bootloader2',
                uuid: '2',
                firmware: {
                  firmware: '/path/firmware2',
                  secure: false,
                },
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with data on boot section',
          'kvm',
          '248'
        ),
        OS: {
          ARCH: 'x86_64',
          BOOTLOADER: '/path/bootloader2',
          FIRMWARE: '/path/firmware2',
          FIRMWARE_SECURE: 'NO',
          KERNEL_CMD: 'parameter2=value2',
          ROOT: 'rootdevice2',
          SD_DISK_BUS: 'scsi',
          UUID: '2',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'booting',
          sectionActions: [
            {
              type: 'update',
              template: {
                arch: '-',
                bus: '-',
                os: '-',
                root: '',
                kernel: '',
                bootloader: '',
                uuid: '',
                firmware: {
                  firmware: 'BIOS',
                },
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with data on boot section',
          'kvm',
          '248'
        ),
        OS: {
          FIRMWARE: 'BIOS',
          FIRMWARE_SECURE: 'NO',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'booting',
          sectionActions: [
            {
              type: 'update',
              template: {
                firmware: {
                  firmware: 'BIOS',
                  secure: false,
                },
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with data on boot section',
          'kvm',
          '248'
        ),
        OS: {
          FIRMWARE: 'BIOS',
          FIRMWARE_SECURE: 'NO',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'booting',
          sectionActions: [
            {
              type: 'update',
              template: {
                firmware: {
                  firmware: '/path/firmware3',
                  secure: false,
                },
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with data on boot section',
          'kvm',
          '248'
        ),
        OS: {
          FIRMWARE: '/path/firmware3',
          FIRMWARE_SECURE: 'NO',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'booting',
          sectionActions: [
            {
              type: 'update',
              template: {
                firmware: {
                  firmware: '-',
                  secure: false,
                },
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with data on boot section',
          'kvm',
          '248'
        ),
        OS: {
          FIRMWARE: '-',
          FIRMWARE_SECURE: 'NO',
        },
      },
    },
  ],
}

const caseRawData = {
  initialData: {
    template: {
      name: 'caseRawData',
      hypervisor: 'kvm',
      description: 'Create a template with raw data',
      memory: 248,
      cpu: 0.1,
      osCpu: {
        rawData: '<label1></label1>',
      },
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create a template with raw data',
        'kvm',
        '248'
      ),
      RAW: {
        TYPE: 'kvm',
        VALIDATE: 'NO',
        DATA: '<label1></label1>',
      },
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'booting',
          sectionActions: [
            {
              type: 'update',
              template: {
                rawData: '<label2></label2>',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with raw data',
          'kvm',
          '248'
        ),
        RAW: {
          TYPE: 'kvm',
          VALIDATE: 'NO',
          DATA: '<label2></label2>',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'booting',
          sectionActions: [
            {
              type: 'update',
              template: {
                rawData: '',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with raw data',
          'kvm',
          '248'
        ),
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'booting',
          sectionActions: [
            {
              type: 'update',
              template: {
                rawData:
                  '<devices><serial type="pty"><source path="/dev/pts/5"/><target port="0"/></serial><console type="pty" tty="/dev/pts/5"><source path="/dev/pts/5"/><target port="0"/></console></devices>',
                validate: true,
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with raw data',
          'kvm',
          '248'
        ),
        RAW: {
          DATA: '<devices><serial type="pty"><source path="/dev/pts/5"/><target port="0"/></serial><console type="pty" tty="/dev/pts/5"><source path="/dev/pts/5"/><target port="0"/></console></devices>',
          VALIDATE: 'YES',
          TYPE: 'kvm',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'booting',
          sectionActions: [
            {
              type: 'update',
              template: {
                validate: false,
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with raw data',
          'kvm',
          '248'
        ),
        RAW: {
          DATA: '<devices><serial type="pty"><source path="/dev/pts/5"/><target port="0"/></serial><console type="pty" tty="/dev/pts/5"><source path="/dev/pts/5"/><target port="0"/></console></devices>',
          TYPE: 'kvm',
          VALIDATE: 'NO',
        },
      },
    },
  ],
}

const caseBootOrder = {
  initialData: {
    template: {
      name: 'caseBootOrder',
      hypervisor: 'kvm',
      description: 'Create a template with boot order',
      memory: 248,
      cpu: 0.1,
      storage: [
        {
          diskType: 'image',
          image: 'Ubuntu 16.04',
        },
        {
          diskType: 'image',
          image: 'Ubuntu 18.04',
        },
      ],
      networks: [
        {
          name: 'vnet1',
        },
        {
          name: 'vnet2',
        },
      ],
      osCpu: {
        bootOrder: {
          check: ['disk0', 'disk1', 'nic0'],
        },
      },
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create a template with boot order',
        'kvm',
        '248'
      ),
      DISK: [
        {
          IMAGE: 'Ubuntu 16.04',
          IMAGE_UNAME: 'oneadmin',
        },
        {
          IMAGE: 'Ubuntu 18.04',
          IMAGE_UNAME: 'oneadmin',
        },
      ],
      NIC: [
        {
          NETWORK: 'vnet1',
          NETWORK_UNAME: 'oneadmin',
          NETWORK_UID: '0',
        },
        {
          NETWORK: 'vnet2',
          NETWORK_UNAME: 'oneadmin',
          NETWORK_UID: '0',
        },
      ],
      OS: {
        BOOT: 'disk0,disk1,nic0',
      },
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'booting',
          sectionActions: [
            {
              type: 'update',
              template: {
                bootOrder: {
                  uncheck: ['disk0'],
                },
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with boot order',
          'kvm',
          '248'
        ),
        DISK: [
          {
            IMAGE: 'Ubuntu 16.04',
            IMAGE_UNAME: 'oneadmin',
          },
          {
            IMAGE: 'Ubuntu 18.04',
            IMAGE_UNAME: 'oneadmin',
          },
        ],
        NIC: [
          {
            NETWORK: 'vnet1',
            NETWORK_UNAME: 'oneadmin',
            NETWORK_UID: '0',
          },
          {
            NETWORK: 'vnet2',
            NETWORK_UNAME: 'oneadmin',
            NETWORK_UID: '0',
          },
        ],
        OS: {
          BOOT: 'disk1,nic0',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'booting',
          sectionActions: [
            {
              type: 'update',
              template: {
                bootOrder: {
                  check: ['disk0'],
                },
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with boot order',
          'kvm',
          '248'
        ),
        DISK: [
          {
            IMAGE: 'Ubuntu 16.04',
            IMAGE_UNAME: 'oneadmin',
          },
          {
            IMAGE: 'Ubuntu 18.04',
            IMAGE_UNAME: 'oneadmin',
          },
        ],
        NIC: [
          {
            NETWORK: 'vnet1',
            NETWORK_UNAME: 'oneadmin',
            NETWORK_UID: '0',
          },
          {
            NETWORK: 'vnet2',
            NETWORK_UNAME: 'oneadmin',
            NETWORK_UID: '0',
          },
        ],
        OS: {
          BOOT: 'disk1,nic0,disk0',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'booting',
          sectionActions: [
            {
              type: 'update',
              template: {
                bootOrder: {
                  uncheck: ['disk0', 'disk1', 'nic0'],
                },
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with boot order',
          'kvm',
          '248'
        ),
        DISK: [
          {
            IMAGE: 'Ubuntu 16.04',
            IMAGE_UNAME: 'oneadmin',
          },
          {
            IMAGE: 'Ubuntu 18.04',
            IMAGE_UNAME: 'oneadmin',
          },
        ],
        NIC: [
          {
            NETWORK: 'vnet1',
            NETWORK_UNAME: 'oneadmin',
            NETWORK_UID: '0',
          },
          {
            NETWORK: 'vnet2',
            NETWORK_UNAME: 'oneadmin',
            NETWORK_UID: '0',
          },
        ],
      },
    },
  ],
}

export const osAndCpuCases = [
  caseCPUModel,
  caseFeatures,
  caseKernelRamdisk,
  caseBoot,
  caseRawData,
  caseBootOrder,
]
