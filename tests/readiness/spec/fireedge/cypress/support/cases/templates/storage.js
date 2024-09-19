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

const caseVolatiles = {
  initialData: {
    template: {
      name: 'caseVolatiles',
      hypervisor: 'kvm',
      description: 'Create, delete and update volatile disks',
      memory: 248,
      cpu: 0.1,
      storage: [
        {
          diskType: 'volatile',
          size: 1,
          sizeunit: 'GB',
          format: 'raw',
          type: 'fs',
        },
        {
          diskType: 'volatile',
          size: 2,
          sizeunit: 'GB',
          format: 'raw',
          type: 'fs',
        },
      ],
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create, delete and update volatile disks',
        'kvm',
        '248'
      ),
      DISK: [
        {
          FORMAT: 'raw',
          SIZE: '1024',
          TYPE: 'fs',
        },
        {
          FORMAT: 'raw',
          SIZE: '2048',
          TYPE: 'fs',
        },
      ],
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'storage',
          sectionActions: [
            {
              type: 'update',
              disk: 1,
              diskType: 'volatile',
              storageActions: [
                {
                  step: 'configuration',
                  template: {
                    size: 256,
                  },
                },
              ],
            },
            {
              type: 'delete',
              disk: 0,
            },
            {
              type: 'create',
              template: {
                diskType: 'volatile',
                size: 128,
                sizeunit: 'MB',
                format: 'raw',
                type: 'fs',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create, delete and update volatile disks',
          'kvm',
          '248'
        ),
        DISK: [
          {
            FORMAT: 'raw',
            SIZE: '256',
            TYPE: 'fs',
          },
          {
            FORMAT: 'raw',
            SIZE: '128',
            TYPE: 'fs',
          },
        ],
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'storage',
          sectionActions: [
            {
              type: 'create',
              template: {
                diskType: 'volatile',
                size: 1,
                sizeunit: 'GB',
                type: 'swap',
                throttlingIOPS: {
                  writeValue: '100',
                },
                readOnly: 'YES',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create, delete and update volatile disks',
          'kvm',
          '248'
        ),
        DISK: [
          {
            FORMAT: 'raw',
            SIZE: '256',
            TYPE: 'fs',
          },
          {
            FORMAT: 'raw',
            SIZE: '128',
            TYPE: 'fs',
          },
          {
            SIZE: '1024',
            TYPE: 'swap',
            WRITE_IOPS_SEC: '100',
            READONLY: 'YES',
          },
        ],
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'storage',
          sectionActions: [
            {
              type: 'delete',
              disk: 1,
            },
            {
              type: 'delete',
              disk: 0,
            },
            {
              type: 'create',
              template: {
                diskType: 'volatile',
                size: 2,
                sizeunit: 'GB',
                type: 'swap',
              },
            },
            {
              type: 'update',
              disk: 0,
              diskType: 'volatile',
              storageActions: [
                {
                  step: 'advanced',
                  template: {
                    readOnly: 'NO',
                  },
                },
              ],
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create, delete and update volatile disks',
          'kvm',
          '248'
        ),
        DISK: [
          {
            SIZE: '1024',
            TYPE: 'swap',
            WRITE_IOPS_SEC: '100',
            READONLY: 'NO',
          },
          {
            SIZE: '2048',
            TYPE: 'swap',
          },
        ],
      },
    },
  ],
}

const caseImages = {
  initialData: {
    template: {
      name: 'caseImages',
      hypervisor: 'kvm',
      description: 'Create, delete and update image disks',
      memory: 248,
      cpu: 0.1,
      storage: [
        {
          diskType: 'image',
          image: 'Ubuntu 16.04',
        },
      ],
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create, delete and update image disks',
        'kvm',
        '248'
      ),
      DISK: {
        IMAGE: 'Ubuntu 16.04',
        IMAGE_UNAME: 'oneadmin',
      },
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'storage',
          sectionActions: [
            {
              type: 'update',
              disk: 0,
              diskType: 'image',
              storageActions: [
                {
                  step: 'advanced',
                  template: {
                    readOnly: 'YES',
                  },
                },
              ],
            },
            {
              type: 'create',
              template: {
                diskType: 'image',
                image: 'Ubuntu 18.04',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create, delete and update image disks',
          'kvm',
          '248'
        ),
        DISK: [
          {
            IMAGE: 'Ubuntu 16.04',
            IMAGE_UNAME: 'oneadmin',
            READONLY: 'YES',
          },
          {
            IMAGE: 'Ubuntu 18.04',
            IMAGE_UNAME: 'oneadmin',
          },
        ],
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'storage',
          sectionActions: [
            {
              type: 'create',
              template: {
                diskType: 'image',
                image: 'Ubuntu 20.04',
              },
            },
            {
              type: 'delete',
              disk: 0,
            },
            {
              type: 'update',
              disk: 0,
              diskType: 'image',
              storageActions: [
                {
                  step: 'image',
                  template: {
                    image: 'Ubuntu 16.04',
                  },
                },
                {
                  step: 'advanced',
                  template: {
                    size: 100,
                    iopsPerSecond: '2',
                  },
                },
              ],
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create, delete and update image disks',
          'kvm',
          '248'
        ),
        DISK: [
          {
            IMAGE: 'Ubuntu 16.04',
            IMAGE_UNAME: 'oneadmin',
            SIZE_IOPS_SEC: '2',
            SIZE: '100',
          },
          {
            IMAGE: 'Ubuntu 20.04',
            IMAGE_UNAME: 'oneadmin',
          },
        ],
      },
    },
  ],
}

const caseMix = {
  initialData: {
    template: {
      name: 'caseMix',
      hypervisor: 'kvm',
      description: 'Create, delete and update image and volatile disks',
      memory: 248,
      cpu: 0.1,
      storage: [
        {
          diskType: 'image',
          image: 'Ubuntu 16.04',
        },
        {
          diskType: 'volatile',
          type: 'swap',
          size: 128,
        },
      ],
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create, delete and update image and volatile disks',
        'kvm',
        '248'
      ),
      DISK: [
        {
          IMAGE: 'Ubuntu 16.04',
          IMAGE_UNAME: 'oneadmin',
        },
        {
          SIZE: '128',
          TYPE: 'swap',
        },
      ],
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'storage',
          sectionActions: [
            {
              type: 'update',
              disk: 0,
              diskType: 'image',
              storageActions: [
                {
                  step: 'advanced',
                  template: {
                    readOnly: 'YES',
                  },
                },
              ],
            },
            {
              type: 'create',
              template: {
                diskType: 'image',
                image: 'Ubuntu 18.04',
                size: 1024,
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create, delete and update image and volatile disks',
          'kvm',
          '248'
        ),
        DISK: [
          {
            IMAGE: 'Ubuntu 16.04',
            IMAGE_UNAME: 'oneadmin',
            READONLY: 'YES',
          },
          {
            SIZE: '128',
            TYPE: 'swap',
          },
          {
            IMAGE: 'Ubuntu 18.04',
            IMAGE_UNAME: 'oneadmin',
            SIZE: '1024',
          },
        ],
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'storage',
          sectionActions: [
            {
              type: 'create',
              template: {
                diskType: 'volatile',
                type: 'fs',
                format: 'raw',
                size: 1,
              },
            },
            {
              type: 'delete',
              disk: 0,
            },
            {
              type: 'update',
              disk: 1,
              diskType: 'image',
              storageActions: [
                {
                  step: 'image',
                  template: {
                    image: 'Ubuntu 16.04',
                  },
                },
                {
                  step: 'advanced',
                  template: {
                    iopsPerSecond: '2',
                    size: 1,
                  },
                },
              ],
            },
            {
              type: 'update',
              disk: 0,
              diskType: 'volatile',
              storageActions: [
                {
                  step: 'configuration',
                  template: {
                    sizeunit: 'GB',
                  },
                },
              ],
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create, delete and update image and volatile disks',
          'kvm',
          '248'
        ),
        DISK: [
          {
            TYPE: 'swap',
            SIZE: '131072',
          },
          {
            IMAGE: 'Ubuntu 16.04',
            IMAGE_UNAME: 'oneadmin',
            SIZE: '1',
            SIZE_IOPS_SEC: '2',
          },
          {
            SIZE: '1',
            TYPE: 'fs',
            FORMAT: 'raw',
          },
        ],
      },
    },
  ],
}

const caseVolatileConfiguration = {
  initialData: {
    template: {
      name: 'caseVolatileData',
      hypervisor: 'kvm',
      description: 'Create and update configuration step volatile fields',
      memory: 248,
      cpu: 0.1,
      storage: [
        {
          diskType: 'volatile',
          size: 1,
          sizeunit: 'GB',
          format: 'raw',
          type: 'fs',
          filesystem: 'ext3',
        },
      ],
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create and update configuration step volatile fields',
        'kvm',
        '248'
      ),
      DISK: {
        FORMAT: 'raw',
        SIZE: '1024',
        TYPE: 'fs',
        FS: 'ext3',
      },
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'storage',
          sectionActions: [
            {
              type: 'update',
              disk: 0,
              diskType: 'volatile',
              storageActions: [
                {
                  step: 'configuration',
                  template: {
                    type: 'swap',
                  },
                },
              ],
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create and update configuration step volatile fields',
          'kvm',
          '248'
        ),
        DISK: {
          SIZE: '1024',
          TYPE: 'swap',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'storage',
          sectionActions: [
            {
              type: 'update',
              disk: 0,
              diskType: 'volatile',
              storageActions: [
                {
                  step: 'configuration',
                  template: {
                    format: 'raw',
                    type: 'fs',
                    filesystem: 'ext3',
                  },
                },
                {
                  step: 'advanced',
                  template: {},
                },
                {
                  step: 'configuration',
                  template: {
                    type: 'swap',
                  },
                },
              ],
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create and update configuration step volatile fields',
          'kvm',
          '248'
        ),
        DISK: {
          SIZE: '1024',
          TYPE: 'swap',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'storage',
          sectionActions: [
            {
              type: 'update',
              disk: 0,
              diskType: 'volatile',
              storageActions: [
                {
                  step: 'configuration',
                  template: {
                    size: 2,
                    sizeunit: 'MB',
                  },
                },
                {
                  step: 'advanced',
                  template: {},
                },
                {
                  step: 'configuration',
                  template: {
                    size: 2,
                    sizeunit: 'GB',
                  },
                },
              ],
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create and update configuration step volatile fields',
          'kvm',
          '248'
        ),
        DISK: {
          SIZE: '2048',
          TYPE: 'swap',
        },
      },
    },
  ],
}

const caseVolatileAdvanced = {
  initialData: {
    template: {
      name: 'caseVolatileAdvanced',
      hypervisor: 'kvm',
      description: 'Create and update advanced step volatile fields',
      memory: 248,
      cpu: 0.1,
      storage: [
        {
          diskType: 'volatile',
          size: 1,
          sizeunit: 'GB',
          format: 'raw',
          type: 'fs',
          filesystem: 'ext3',
          target: 'ds',
          readOnly: 'yes',
          bus: 'Virtio',
          cache: 'Writethrough',
          io: 'Threads',
          discard: 'Unmap',
          iopsPerSecond: 10,
          ioThreadId: 2,
          throttlingBytes: {
            totalValue: 1,
            totalMaximum: 2,
            totalMaximumLength: 3,
            readValue: 4,
            readMaximum: 5,
            readMaximumLength: 6,
            writeValue: 7,
            writeMaximum: 8,
            writeMaximumLength: 9,
          },
          throttlingIOPS: {
            totalValue: 1,
            totalMaximum: 2,
            totalMaximumLength: 3,
            readValue: 4,
            readMaximum: 5,
            readMaximumLength: 6,
            writeValue: 7,
            writeMaximum: 8,
            writeMaximumLength: 9,
          },
          recoverySnapshotFreq: 15,
        },
      ],
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create and update advanced step volatile fields',
        'kvm',
        '248'
      ),
      DISK: {
        CACHE: 'writethrough',
        DEV_PREFIX: 'vd',
        DISCARD: 'unmap',
        FORMAT: 'raw',
        FS: 'ext3',
        IO: 'threads',
        READONLY: 'YES',
        SIZE: '1024',
        SIZE_IOPS_SEC: '10',
        TARGET: 'ds',
        TYPE: 'fs',
        IOTHREADS: '2',
        TOTAL_BYTES_SEC: '1',
        TOTAL_BYTES_SEC_MAX: '2',
        TOTAL_BYTES_SEC_MAX_LENGTH: '3',
        READ_BYTES_SEC: '4',
        READ_BYTES_SEC_MAX: '5',
        READ_BYTES_SEC_MAX_LENGTH: '6',
        WRITE_BYTES_SEC: '7',
        WRITE_BYTES_SEC_MAX: '8',
        WRITE_BYTES_SEC_MAX_LENGTH: '9',
        TOTAL_IOPS_SEC: '1',
        TOTAL_IOPS_SEC_MAX: '2',
        TOTAL_IOPS_SEC_MAX_LENGTH: '3',
        READ_IOPS_SEC: '4',
        READ_IOPS_SEC_MAX: '5',
        READ_IOPS_SEC_MAX_LENGTH: '6',
        WRITE_IOPS_SEC: '7',
        WRITE_IOPS_SEC_MAX: '8',
        WRITE_IOPS_SEC_MAX_LENGTH: '9',
        RECOVERY_SNAPSHOT_FREQ: '15',
      },
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'storage',
          sectionActions: [
            {
              type: 'update',
              disk: 0,
              diskType: 'volatile',
              storageActions: [
                {
                  step: 'advanced',
                  template: {
                    target: 'ds2',
                    readOnly: 'no',
                    bus: 'SCSI/SATA',
                    cache: 'Writeback',
                    io: 'Native',
                    discard: 'Ignore',
                    iopsPerSecond: 100,
                    ioThreadId: 20,
                    throttlingBytes: {
                      totalValue: 10,
                      totalMaximum: 20,
                      totalMaximumLength: 30,
                      readValue: 40,
                      readMaximum: 50,
                      readMaximumLength: 60,
                      writeValue: 70,
                      writeMaximum: 80,
                      writeMaximumLength: 90,
                    },
                    throttlingIOPS: {
                      totalValue: 10,
                      totalMaximum: 20,
                      totalMaximumLength: 30,
                      readValue: 40,
                      readMaximum: 50,
                      readMaximumLength: 60,
                      writeValue: 70,
                      writeMaximum: 80,
                      writeMaximumLength: 90,
                    },
                    recoverySnapshotFreq: 150,
                  },
                },
              ],
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create and update advanced step volatile fields',
          'kvm',
          '248'
        ),
        DISK: {
          CACHE: 'writeback',
          DEV_PREFIX: 'sd',
          DISCARD: 'ignore',
          FORMAT: 'raw',
          FS: 'ext3',
          IO: 'native',
          READONLY: 'NO',
          SIZE: '1024',
          SIZE_IOPS_SEC: '100',
          TARGET: 'ds2',
          TYPE: 'fs',
          IOTHREADS: '20',
          TOTAL_BYTES_SEC: '10',
          TOTAL_BYTES_SEC_MAX: '20',
          TOTAL_BYTES_SEC_MAX_LENGTH: '30',
          READ_BYTES_SEC: '40',
          READ_BYTES_SEC_MAX: '50',
          READ_BYTES_SEC_MAX_LENGTH: '60',
          WRITE_BYTES_SEC: '70',
          WRITE_BYTES_SEC_MAX: '80',
          WRITE_BYTES_SEC_MAX_LENGTH: '90',
          TOTAL_IOPS_SEC: '10',
          TOTAL_IOPS_SEC_MAX: '20',
          TOTAL_IOPS_SEC_MAX_LENGTH: '30',
          READ_IOPS_SEC: '40',
          READ_IOPS_SEC_MAX: '50',
          READ_IOPS_SEC_MAX_LENGTH: '60',
          WRITE_IOPS_SEC: '70',
          WRITE_IOPS_SEC_MAX: '80',
          WRITE_IOPS_SEC_MAX_LENGTH: '90',
          RECOVERY_SNAPSHOT_FREQ: '150',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'storage',
          sectionActions: [
            {
              type: 'update',
              disk: 0,
              diskType: 'volatile',
              storageActions: [
                {
                  step: 'advanced',
                  template: {
                    target: 'ds3',
                    cache: 'Unsafe',
                  },
                },
                {
                  step: 'configuration',
                  template: {},
                },
                {
                  step: 'advanced',
                  template: {
                    target: 'ds2',
                  },
                },
              ],
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create and update advanced step volatile fields',
          'kvm',
          '248'
        ),
        DISK: {
          CACHE: 'unsafe',
          DEV_PREFIX: 'sd',
          DISCARD: 'ignore',
          FORMAT: 'raw',
          FS: 'ext3',
          IO: 'native',
          READONLY: 'NO',
          SIZE: '1024',
          SIZE_IOPS_SEC: '100',
          TARGET: 'ds2',
          TYPE: 'fs',
          IOTHREADS: '20',
          TOTAL_BYTES_SEC: '10',
          TOTAL_BYTES_SEC_MAX: '20',
          TOTAL_BYTES_SEC_MAX_LENGTH: '30',
          READ_BYTES_SEC: '40',
          READ_BYTES_SEC_MAX: '50',
          READ_BYTES_SEC_MAX_LENGTH: '60',
          WRITE_BYTES_SEC: '70',
          WRITE_BYTES_SEC_MAX: '80',
          WRITE_BYTES_SEC_MAX_LENGTH: '90',
          TOTAL_IOPS_SEC: '10',
          TOTAL_IOPS_SEC_MAX: '20',
          TOTAL_IOPS_SEC_MAX_LENGTH: '30',
          READ_IOPS_SEC: '40',
          READ_IOPS_SEC_MAX: '50',
          READ_IOPS_SEC_MAX_LENGTH: '60',
          WRITE_IOPS_SEC: '70',
          WRITE_IOPS_SEC_MAX: '80',
          WRITE_IOPS_SEC_MAX_LENGTH: '90',
          RECOVERY_SNAPSHOT_FREQ: '150',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'storage',
          sectionActions: [
            {
              type: 'update',
              disk: 0,
              diskType: 'volatile',
              storageActions: [
                {
                  step: 'advanced',
                  template: {
                    target: '',
                    bus: '',
                    cache: '',
                    io: '',
                    discard: '',
                    iopsPerSecond: '',
                    ioThreadId: '',
                    throttlingBytes: {
                      totalValue: '',
                      totalMaximum: '',
                      totalMaximumLength: '',
                      readValue: '',
                      readMaximum: '',
                      readMaximumLength: '',
                      writeValue: '',
                      writeMaximum: '',
                      writeMaximumLength: '',
                    },
                    throttlingIOPS: {
                      totalValue: '',
                      totalMaximum: '',
                      totalMaximumLength: '',
                      readValue: '',
                      readMaximum: '',
                      readMaximumLength: '',
                      writeValue: '',
                      writeMaximum: '',
                      writeMaximumLength: '',
                    },
                    recoverySnapshotFreq: '',
                  },
                },
              ],
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create and update advanced step volatile fields',
          'kvm',
          '248'
        ),
        DISK: {
          READONLY: 'NO',
          SIZE: '1024',
          TYPE: 'fs',
          FORMAT: 'raw',
          FS: 'ext3',
        },
      },
    },
  ],
}

const caseImageAdvanced = {
  initialData: {
    template: {
      name: 'caseImageAdvanced',
      hypervisor: 'kvm',
      description: 'Create and update advanced step image fields',
      memory: 248,
      cpu: 0.1,
      storage: [
        {
          diskType: 'image',
          image: 'Ubuntu 16.04',
          target: 'ds',
          readOnly: 'yes',
          bus: 'Virtio',
          cache: 'Writethrough',
          io: 'Threads',
          discard: 'Unmap',
          iopsPerSecond: 10,
          ioThreadId: 2,
          throttlingBytes: {
            totalValue: 1,
            totalMaximum: 2,
            totalMaximumLength: 3,
            readValue: 4,
            readMaximum: 5,
            readMaximumLength: 6,
            writeValue: 7,
            writeMaximum: 8,
            writeMaximumLength: 9,
          },
          throttlingIOPS: {
            totalValue: 1,
            totalMaximum: 2,
            totalMaximumLength: 3,
            readValue: 4,
            readMaximum: 5,
            readMaximumLength: 6,
            writeValue: 7,
            writeMaximum: 8,
            writeMaximumLength: 9,
          },
          recoverySnapshotFreq: 15,
        },
      ],
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create and update advanced step image fields',
        'kvm',
        '248'
      ),
      DISK: {
        CACHE: 'writethrough',
        DEV_PREFIX: 'vd',
        DISCARD: 'unmap',
        IO: 'threads',
        IMAGE: 'Ubuntu 16.04',
        IMAGE_UNAME: 'oneadmin',
        READONLY: 'YES',
        SIZE_IOPS_SEC: '10',
        TARGET: 'ds',
        IOTHREADS: '2',
        TOTAL_BYTES_SEC: '1',
        TOTAL_BYTES_SEC_MAX: '2',
        TOTAL_BYTES_SEC_MAX_LENGTH: '3',
        READ_BYTES_SEC: '4',
        READ_BYTES_SEC_MAX: '5',
        READ_BYTES_SEC_MAX_LENGTH: '6',
        WRITE_BYTES_SEC: '7',
        WRITE_BYTES_SEC_MAX: '8',
        WRITE_BYTES_SEC_MAX_LENGTH: '9',
        TOTAL_IOPS_SEC: '1',
        TOTAL_IOPS_SEC_MAX: '2',
        TOTAL_IOPS_SEC_MAX_LENGTH: '3',
        READ_IOPS_SEC: '4',
        READ_IOPS_SEC_MAX: '5',
        READ_IOPS_SEC_MAX_LENGTH: '6',
        WRITE_IOPS_SEC: '7',
        WRITE_IOPS_SEC_MAX: '8',
        WRITE_IOPS_SEC_MAX_LENGTH: '9',
        RECOVERY_SNAPSHOT_FREQ: '15',
      },
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'storage',
          sectionActions: [
            {
              type: 'update',
              disk: 0,
              diskType: 'volatile',
              storageActions: [
                {
                  step: 'advanced',
                  template: {
                    target: 'ds2',
                    readOnly: 'no',
                    bus: 'SCSI/SATA',
                    cache: 'Writeback',
                    io: 'Native',
                    discard: 'Ignore',
                    iopsPerSecond: 100,
                    ioThreadId: 20,
                    throttlingBytes: {
                      totalValue: 10,
                      totalMaximum: 20,
                      totalMaximumLength: 30,
                      readValue: 40,
                      readMaximum: 50,
                      readMaximumLength: 60,
                      writeValue: 70,
                      writeMaximum: 80,
                      writeMaximumLength: 90,
                    },
                    throttlingIOPS: {
                      totalValue: 10,
                      totalMaximum: 20,
                      totalMaximumLength: 30,
                      readValue: 40,
                      readMaximum: 50,
                      readMaximumLength: 60,
                      writeValue: 70,
                      writeMaximum: 80,
                      writeMaximumLength: 90,
                    },
                    recoverySnapshotFreq: 150,
                  },
                },
              ],
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create and update advanced step image fields',
          'kvm',
          '248'
        ),
        DISK: {
          CACHE: 'writeback',
          DEV_PREFIX: 'sd',
          DISCARD: 'ignore',
          IO: 'native',
          IMAGE: 'Ubuntu 16.04',
          IMAGE_UNAME: 'oneadmin',
          READONLY: 'NO',
          SIZE_IOPS_SEC: '100',
          TARGET: 'ds2',
          IOTHREADS: '20',
          TOTAL_BYTES_SEC: '10',
          TOTAL_BYTES_SEC_MAX: '20',
          TOTAL_BYTES_SEC_MAX_LENGTH: '30',
          READ_BYTES_SEC: '40',
          READ_BYTES_SEC_MAX: '50',
          READ_BYTES_SEC_MAX_LENGTH: '60',
          WRITE_BYTES_SEC: '70',
          WRITE_BYTES_SEC_MAX: '80',
          WRITE_BYTES_SEC_MAX_LENGTH: '90',
          TOTAL_IOPS_SEC: '10',
          TOTAL_IOPS_SEC_MAX: '20',
          TOTAL_IOPS_SEC_MAX_LENGTH: '30',
          READ_IOPS_SEC: '40',
          READ_IOPS_SEC_MAX: '50',
          READ_IOPS_SEC_MAX_LENGTH: '60',
          WRITE_IOPS_SEC: '70',
          WRITE_IOPS_SEC_MAX: '80',
          WRITE_IOPS_SEC_MAX_LENGTH: '90',
          RECOVERY_SNAPSHOT_FREQ: '150',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'storage',
          sectionActions: [
            {
              type: 'update',
              disk: 0,
              diskType: 'volatile',
              storageActions: [
                {
                  step: 'advanced',
                  template: {
                    target: 'ds3',
                    cache: 'Unsafe',
                  },
                },
                {
                  step: 'image',
                  template: {},
                },
                {
                  step: 'advanced',
                  template: {
                    target: 'ds2',
                  },
                },
              ],
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create and update advanced step image fields',
          'kvm',
          '248'
        ),
        DISK: {
          CACHE: 'unsafe',
          DEV_PREFIX: 'sd',
          DISCARD: 'ignore',
          IO: 'native',
          IMAGE: 'Ubuntu 16.04',
          IMAGE_UNAME: 'oneadmin',
          READONLY: 'NO',
          SIZE_IOPS_SEC: '100',
          TARGET: 'ds2',
          IOTHREADS: '20',
          TOTAL_BYTES_SEC: '10',
          TOTAL_BYTES_SEC_MAX: '20',
          TOTAL_BYTES_SEC_MAX_LENGTH: '30',
          READ_BYTES_SEC: '40',
          READ_BYTES_SEC_MAX: '50',
          READ_BYTES_SEC_MAX_LENGTH: '60',
          WRITE_BYTES_SEC: '70',
          WRITE_BYTES_SEC_MAX: '80',
          WRITE_BYTES_SEC_MAX_LENGTH: '90',
          TOTAL_IOPS_SEC: '10',
          TOTAL_IOPS_SEC_MAX: '20',
          TOTAL_IOPS_SEC_MAX_LENGTH: '30',
          READ_IOPS_SEC: '40',
          READ_IOPS_SEC_MAX: '50',
          READ_IOPS_SEC_MAX_LENGTH: '60',
          WRITE_IOPS_SEC: '70',
          WRITE_IOPS_SEC_MAX: '80',
          WRITE_IOPS_SEC_MAX_LENGTH: '90',
          RECOVERY_SNAPSHOT_FREQ: '150',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'storage',
          sectionActions: [
            {
              type: 'update',
              disk: 0,
              diskType: 'volatile',
              storageActions: [
                {
                  step: 'advanced',
                  template: {
                    size: 3072,
                  },
                },
              ],
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create and update advanced step image fields',
          'kvm',
          '248'
        ),
        DISK: {
          CACHE: 'unsafe',
          DEV_PREFIX: 'sd',
          DISCARD: 'ignore',
          IO: 'native',
          IMAGE: 'Ubuntu 16.04',
          IMAGE_UNAME: 'oneadmin',
          READONLY: 'NO',
          SIZE_IOPS_SEC: '100',
          TARGET: 'ds2',
          IOTHREADS: '20',
          TOTAL_BYTES_SEC: '10',
          TOTAL_BYTES_SEC_MAX: '20',
          TOTAL_BYTES_SEC_MAX_LENGTH: '30',
          READ_BYTES_SEC: '40',
          READ_BYTES_SEC_MAX: '50',
          READ_BYTES_SEC_MAX_LENGTH: '60',
          WRITE_BYTES_SEC: '70',
          WRITE_BYTES_SEC_MAX: '80',
          WRITE_BYTES_SEC_MAX_LENGTH: '90',
          TOTAL_IOPS_SEC: '10',
          TOTAL_IOPS_SEC_MAX: '20',
          TOTAL_IOPS_SEC_MAX_LENGTH: '30',
          READ_IOPS_SEC: '40',
          READ_IOPS_SEC_MAX: '50',
          READ_IOPS_SEC_MAX_LENGTH: '60',
          WRITE_IOPS_SEC: '70',
          WRITE_IOPS_SEC_MAX: '80',
          WRITE_IOPS_SEC_MAX_LENGTH: '90',
          RECOVERY_SNAPSHOT_FREQ: '150',
          SIZE: '3072',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'storage',
          sectionActions: [
            {
              type: 'update',
              disk: 0,
              diskType: 'volatile',
              storageActions: [
                {
                  step: 'advanced',
                  template: {
                    size: '',
                    target: '',
                    bus: '',
                    cache: '',
                    io: '',
                    discard: '',
                    iopsPerSecond: '',
                    ioThreadId: '',
                    throttlingBytes: {
                      totalValue: '',
                      totalMaximum: '',
                      totalMaximumLength: '',
                      readValue: '',
                      readMaximum: '',
                      readMaximumLength: '',
                      writeValue: '',
                      writeMaximum: '',
                      writeMaximumLength: '',
                    },
                    throttlingIOPS: {
                      totalValue: '',
                      totalMaximum: '',
                      totalMaximumLength: '',
                      readValue: '',
                      readMaximum: '',
                      readMaximumLength: '',
                      writeValue: '',
                      writeMaximum: '',
                      writeMaximumLength: '',
                    },
                    recoverySnapshotFreq: '',
                  },
                },
              ],
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create and update advanced step image fields',
          'kvm',
          '248'
        ),
        DISK: {
          IMAGE: 'Ubuntu 16.04',
          IMAGE_UNAME: 'oneadmin',
          READONLY: 'NO',
        },
      },
    },
  ],
}

export const storageCases = [
  caseVolatiles,
  caseImages,
  caseMix,
  caseVolatileConfiguration,
  caseVolatileAdvanced,
  caseImageAdvanced,
]
