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
  expectedTemplateMandatoryValues,
  expectedTemplateAllValues,
} from './utils'

const caseGraphics = {
  initialData: {
    template: {
      name: 'caseGraphics',
      hypervisor: 'kvm',
      description: 'Create a template with graphics',
      memory: 248,
      cpu: 0.1,
      inputOutput: {
        graphics: true,
      },
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create a template with graphics',
        'kvm',
        '248'
      ),
      GRAPHICS: {
        TYPE: 'VNC',
        LISTEN: '0.0.0.0',
      },
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'inputoutput',
          sectionActions: [
            {
              type: 'update',
              template: {
                ip: '127.0.0.2',
                port: '2000',
                keymap: 'Finnish',
                password: 'opennebula2',
                command: 'command2',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with graphics',
          'kvm',
          '248'
        ),
        GRAPHICS: {
          TYPE: 'VNC',
          LISTEN: '127.0.0.2',
          PORT: '2000',
          KEYMAP: 'fi',
          PASSWD: 'opennebula2',
          COMMAND: 'command2',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'inputoutput',
          sectionActions: [
            {
              type: 'update',
              template: {
                randomPassword: true,
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with graphics',
          'kvm',
          '248'
        ),
        GRAPHICS: {
          TYPE: 'VNC',
          LISTEN: '127.0.0.2',
          PORT: '2000',
          KEYMAP: 'fi',
          RANDOM_PASSWD: 'YES',
          COMMAND: 'command2',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'inputoutput',
          sectionActions: [
            {
              type: 'update',
              template: {
                graphics: false,
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateAllValues(
          '0.1',
          'Create a template with graphics',
          'kvm',
          '248',
          {
            graphicsType: false,
            graphicsListen: false,
          }
        ),
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'inputoutput',
          sectionActions: [
            {
              type: 'update',
              template: {
                graphics: true,
                ip: '',
                port: '',
                keymap: '',
                password: '',
                command: '',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with graphics',
          'kvm',
          '248'
        ),
        GRAPHICS: {
          TYPE: 'VNC',
          RANDOM_PASSWD: 'NO',
        },
      },
    },
  ],
}

const caseInputs = {
  initialData: {
    template: {
      name: 'caseInputs',
      hypervisor: 'kvm',
      description: 'Create a template with inputs',
      memory: 248,
      cpu: 0.1,
      inputOutput: {
        inputs: [
          {
            type: 'mouse',
            bus: 'ps2',
          },
          {
            type: 'tablet',
            bus: 'usb',
          },
        ],
      },
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create a template with inputs',
        'kvm',
        '248'
      ),
      INPUT: [
        {
          TYPE: 'mouse',
          BUS: 'ps2',
        },
        {
          TYPE: 'tablet',
          BUS: 'usb',
        },
      ],
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'inputoutput',
          sectionActions: [
            {
              type: 'create',
              template: {
                inputs: {
                  type: 'mouse',
                  bus: 'usb',
                },
              },
            },
            {
              type: 'create',
              template: {
                inputs: {
                  type: 'tablet',
                  bus: 'ps2',
                },
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with inputs',
          'kvm',
          '248'
        ),
        INPUT: [
          {
            TYPE: 'mouse',
            BUS: 'ps2',
          },
          {
            TYPE: 'tablet',
            BUS: 'usb',
          },
          {
            TYPE: 'mouse',
            BUS: 'usb',
          },
          {
            TYPE: 'tablet',
            BUS: 'ps2',
          },
        ],
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'inputoutput',
          sectionActions: [
            {
              type: 'delete',
              subSection: 'input',
              id: 1,
            },
            {
              type: 'delete',
              subSection: 'input',
              id: 2,
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with inputs',
          'kvm',
          '248'
        ),
        INPUT: [
          {
            TYPE: 'mouse',
            BUS: 'ps2',
          },
          {
            TYPE: 'mouse',
            BUS: 'usb',
          },
        ],
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'inputoutput',
          sectionActions: [
            {
              type: 'create',
              template: {
                inputs: {
                  type: 'mouse',
                  bus: 'ps2',
                },
              },
            },
            {
              type: 'delete',
              subSection: 'input',
              id: 0,
            },
            {
              type: 'create',
              template: {
                inputs: {
                  type: 'tablet',
                  bus: 'usb',
                },
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with inputs',
          'kvm',
          '248'
        ),
        INPUT: [
          {
            TYPE: 'mouse',
            BUS: 'usb',
          },
          {
            TYPE: 'mouse',
            BUS: 'ps2',
          },
          {
            TYPE: 'tablet',
            BUS: 'usb',
          },
        ],
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'inputoutput',
          sectionActions: [
            {
              type: 'delete',
              subSection: 'input',
              id: 2,
            },
            {
              type: 'delete',
              subSection: 'input',
              id: 0,
            },
            {
              type: 'delete',
              subSection: 'input',
              id: 0,
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with inputs',
          'kvm',
          '248'
        ),
      },
    },
  ],
}

const caseVideo = {
  initialData: {
    template: {
      name: 'caseVideo',
      hypervisor: 'kvm',
      description: 'Create a template with video',
      memory: 248,
      cpu: 0.1,
      inputOutput: {
        video: {
          type: 'virtio',
          vram: '1024',
          resolution: '1280x720',
          ats: true,
          iommu: true,
        },
      },
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create a template with video',
        'kvm',
        '248'
      ),
      VIDEO: {
        TYPE: 'virtio',
        VRAM: '1024',
        RESOLUTION: '1280x720',
        ATS: 'YES',
        IOMMU: 'YES',
      },
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'inputoutput',
          sectionActions: [
            {
              type: 'update',
              template: {
                video: {
                  type: 'virtio',
                  vram: '2048',
                  resolution: '1366x768',
                  ats: false,
                  iommu: false,
                },
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with video',
          'kvm',
          '248'
        ),
        VIDEO: {
          TYPE: 'virtio',
          VRAM: '2048',
          RESOLUTION: '1366x768',
          ATS: 'NO',
          IOMMU: 'NO',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'inputoutput',
          sectionActions: [
            {
              type: 'update',
              template: {
                video: {
                  type: 'cirrus',
                  vram: '3072',
                },
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with video',
          'kvm',
          '248'
        ),
        VIDEO: {
          TYPE: 'cirrus',
          VRAM: '3072',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'inputoutput',
          sectionActions: [
            {
              type: 'update',
              template: {
                video: {
                  type: 'none',
                },
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with video',
          'kvm',
          '248'
        ),
        VIDEO: {
          TYPE: 'none',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'inputoutput',
          sectionActions: [
            {
              type: 'update',
              template: {
                video: {
                  type: 'vga',
                  vram: '1024',
                },
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with video',
          'kvm',
          '248'
        ),
        VIDEO: {
          TYPE: 'vga',
          VRAM: '1024',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'inputoutput',
          sectionActions: [
            {
              type: 'update',
              template: {
                video: {
                  type: 'virtio',
                  vram: '2048',
                  resolution: 'custom',
                  resolutionWidth: '1000',
                  resolutionHeight: '500',
                },
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with video',
          'kvm',
          '248'
        ),
        VIDEO: {
          TYPE: 'virtio',
          VRAM: '2048',
          RESOLUTION: '1000x500',
          IOMMU: 'NO',
          ATS: 'NO',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'inputoutput',
          sectionActions: [
            {
              type: 'update',
              template: {
                video: {
                  type: 'auto',
                },
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with video',
          'kvm',
          '248'
        ),
      },
    },
  ],
}

export const inputOutputCases = [caseGraphics, caseInputs, caseVideo]
