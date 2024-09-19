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

const caseBasic = {
  initialData: {
    template: {
      name: 'caseBasic',
      hypervisor: 'kvm',
      description: 'Create and update basic fields',
      memory: 248,
      cpu: 0.1,
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create and update basic fields',
        'kvm',
        '248'
      ),
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                name: 'caseBasicUpdated',
                hypervisor: 'lxc',
                description: 'Create and update basic fields updated',
                memory: 512,
                cpu: 0.2,
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.2',
          'Create and update basic fields updated',
          'lxc',
          '512'
        ),
      },
    },
    {
      actions: [
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                name: 'caseBasicUpdated2',
                hypervisor: 'kvm',
                description: '',
                memory: 1024,
                cpu: 0.3,
              },
            },
          ],
        },
        {
          step: 'extra',
          section: 'network',
          sectionActions: [],
        },
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                name: 'caseBasicUpdated2',
                hypervisor: 'kvm',
                memory: 1024,
                cpu: 0.4,
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues('0.4', undefined, 'kvm', '1024'),
      },
    },
  ],
}

const caseInformation = {
  initialData: {
    template: {
      name: 'caseInformation',
      hypervisor: 'kvm',
      description: 'Create and update information fields',
      memory: 248,
      cpu: 0.1,
      logo: 'linux',
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create and update information fields',
        'kvm',
        '248'
      ),
      LOGO: 'images/logos/linux.png',
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                name: 'caseBasicUpdated',
                description: 'Create and update information fields updated',
                logo: 'debian',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create and update information fields updated',
          'kvm',
          '248'
        ),
        LOGO: 'images/logos/debian.png',
      },
    },
    {
      actions: [
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                name: 'caseBasicUpdated2',
                description: 'Create and update information fields updated2',
                logo: 'linux',
              },
            },
          ],
        },
        {
          step: 'extra',
          section: 'network',
          sectionActions: [],
        },
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                name: 'caseBasicUpdated3',
                description: '',
                logo: '-',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues('0.1', undefined, 'kvm', '248'),
        LOGO: 'images/logos/default.png',
      },
    },
  ],
}

const caseHypervisor = {
  initialData: {
    template: {
      name: 'caseHypervisor',
      hypervisor: 'kvm',
      description: 'Create and update hypervisor fields',
      memory: 248,
      cpu: 0.1,
      vrouter: true,
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create and update hypervisor fields',
        'kvm',
        '248'
      ),
      VROUTER: 'YES',
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                hypervisor: 'lxc',
                vrouter: false,
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create and update hypervisor fields',
          'lxc',
          '248'
        ),
        VROUTER: 'NO',
      },
    },
    {
      actions: [
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                hypervisor: 'kvm',
                vrouter: true,
              },
            },
          ],
        },
        {
          step: 'extra',
          section: 'network',
          sectionActions: [],
        },
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                hypervisor: 'dummy',
                vrouter: false,
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create and update hypervisor fields',
          'dummy',
          '248'
        ),
        VROUTER: 'NO',
      },
    },
  ],
}

const caseMemory = {
  initialData: {
    template: {
      name: 'caseMemory',
      hypervisor: 'kvm',
      description: 'Create and update memory fields',
      memory: 248,
      cpu: 0.1,
      memoryHotResize: true,
      memoryMax: 100,
      memoryResizeMode: 'Ballooning',
      memoryModificationType: 'Range',
      memoryModificationMin: '1',
      memoryModificationMax: '1024',
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create and update memory fields',
        'kvm',
        '248'
      ),
      HOT_RESIZE: {
        MEMORY_HOT_ADD_ENABLED: 'YES',
      },
      MEMORY_MAX: '100',
      MEMORY_RESIZE_MODE: 'BALLOONING',
      USER_INPUTS: {
        MEMORY: 'M|range||1..1024|248',
      },
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                memory: 1,
                memoryunit: 'GB',
                memoryMax: 200,
                memoryResizeMode: 'Hotplug',
                memorySlots: 2,
                memoryModificationType: 'Any value',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create and update memory fields',
          'kvm',
          '1024'
        ),
        HOT_RESIZE: {
          MEMORY_HOT_ADD_ENABLED: 'YES',
        },
        MEMORY_MAX: '200',
        MEMORY_RESIZE_MODE: 'HOTPLUG',
        MEMORY_SLOTS: '2',
      },
    },
    {
      actions: [
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                memory: 1,
                memoryunit: 'TB',
                memoryHotResize: false,
                memoryResizeMode: '-',
              },
            },
          ],
        },
        {
          step: 'extra',
          section: 'network',
          sectionActions: [],
        },
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                memoryunit: 'MB',
                memoryHotResize: true,
                memoryMax: 300,
                memoryResizeMode: 'Hotplug',
                memorySlots: 2,
                memoryModificationType: 'Fixed',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create and update memory fields',
          'kvm',
          '1'
        ),
        HOT_RESIZE: {
          MEMORY_HOT_ADD_ENABLED: 'YES',
        },
        MEMORY_MAX: '300',
        MEMORY_RESIZE_MODE: 'HOTPLUG',
        MEMORY_SLOTS: '2',
        USER_INPUTS: {
          MEMORY: 'M|fixed|| |1',
        },
      },
    },
    {
      actions: [
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                memoryHotResize: false,
                memoryResizeMode: '-',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create and update memory fields',
          'kvm',
          '1'
        ),
        HOT_RESIZE: {
          MEMORY_HOT_ADD_ENABLED: 'NO',
        },
        USER_INPUTS: {
          MEMORY: 'M|fixed|| |1',
        },
      },
    },
    {
      actions: [
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                memoryHotResize: true,
                memoryMax: 150,
                memoryModificationType: 'Fixed',
              },
            },
          ],
        },
        {
          step: 'extra',
          section: 'network',
          sectionActions: [],
        },
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                memoryHotResize: false,
                memoryModificationType: 'Any value',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create and update memory fields',
          'kvm',
          '1'
        ),
        HOT_RESIZE: {
          MEMORY_HOT_ADD_ENABLED: 'NO',
        },
      },
    },
  ],
}

const casePhysicalCpu = {
  initialData: {
    template: {
      name: 'casePhysicalCpu',
      hypervisor: 'kvm',
      description: 'Create and update physical cpu fields',
      memory: 248,
      cpu: 1.1,
      cpuModificationType: 'Range',
      cpuModificationMin: '1',
      cpuModificationMax: '4',
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '1.1',
        'Create and update physical cpu fields',
        'kvm',
        '248'
      ),
      USER_INPUTS: {
        CPU: 'M|range-float||1..4|1.1',
      },
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                cpu: 2,
                cpuModificationType: 'Any value',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '2',
          'Create and update physical cpu fields',
          'kvm',
          '248'
        ),
      },
    },
    {
      actions: [
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                cpuModificationType: 'Fixed',
              },
            },
          ],
        },
        {
          step: 'extra',
          section: 'network',
          sectionActions: [],
        },
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                cpuModificationType: 'Range',
                cpuModificationMin: '1',
                cpuModificationMax: '3',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '2',
          'Create and update physical cpu fields',
          'kvm',
          '248'
        ),
        USER_INPUTS: {
          CPU: 'M|range-float||1..3|2',
        },
      },
    },
    {
      actions: [
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                cpuModificationType: 'Any value',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '2',
          'Create and update physical cpu fields',
          'kvm',
          '248'
        ),
      },
    },
    {
      actions: [
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                cpuModificationType: 'Fixed',
              },
            },
          ],
        },
        {
          step: 'extra',
          section: 'network',
          sectionActions: [],
        },
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                cpuModificationType: 'Any value',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '2',
          'Create and update physical cpu fields',
          'kvm',
          '248'
        ),
      },
    },
  ],
}

const caseVirtualCpu = {
  initialData: {
    template: {
      name: 'caseVirtualCpu',
      hypervisor: 'kvm',
      description: 'Create and update virtual vcpu fields',
      memory: 248,
      cpu: 0.1,
      vcpu: 1,
      vcpuHotResize: true,
      vcpuMax: 3,
      vcpuResizeMode: 'Ballooning',
      vcpuModificationType: 'Range',
      vcpuModificationMin: '1',
      vcpuModificationMax: '4',
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create and update virtual vcpu fields',
        'kvm',
        '248'
      ),
      HOT_RESIZE: {
        CPU_HOT_ADD_ENABLED: 'YES',
      },
      VCPU: '1',
      VCPU_MAX: '3',
      USER_INPUTS: {
        VCPU: 'O|range-float||1..4|1',
      },
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                vcpu: 2,
                vcpuMax: 2,
                vcpuModificationType: 'Any value',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create and update virtual vcpu fields',
          'kvm',
          '248'
        ),
        HOT_RESIZE: {
          CPU_HOT_ADD_ENABLED: 'YES',
        },
        VCPU: '2',
        VCPU_MAX: '2',
      },
    },
    {
      actions: [
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                vcpuHotResize: false,
              },
            },
          ],
        },
        {
          step: 'extra',
          section: 'network',
          sectionActions: [],
        },
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                vcpuHotResize: true,
                vcpuMax: 3,
                vcpuModificationType: 'Fixed',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create and update virtual vcpu fields',
          'kvm',
          '248'
        ),
        HOT_RESIZE: {
          CPU_HOT_ADD_ENABLED: 'YES',
        },
        VCPU: '2',
        VCPU_MAX: '3',
        USER_INPUTS: {
          VCPU: 'O|fixed|| |2',
        },
      },
    },
    {
      actions: [
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                vcpuHotResize: false,
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create and update virtual vcpu fields',
          'kvm',
          '248'
        ),
        HOT_RESIZE: {
          CPU_HOT_ADD_ENABLED: 'NO',
        },
        VCPU: '2',
        USER_INPUTS: {
          VCPU: 'O|fixed|| |2',
        },
      },
    },
    {
      actions: [
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                vcpuHotResize: true,
                vcpuMax: 3,
                vcpuModificationType: 'Fixed',
              },
            },
          ],
        },
        {
          step: 'extra',
          section: 'network',
          sectionActions: [],
        },
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                vcpuHotResize: false,
                vcpuModificationType: 'Any value',
                vcpu: '',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create and update virtual vcpu fields',
          'kvm',
          '248'
        ),
        HOT_RESIZE: {
          CPU_HOT_ADD_ENABLED: 'NO',
        },
      },
    },
  ],
}

const caseCost = {
  initialData: {
    template: {
      name: 'caseCost',
      hypervisor: 'kvm',
      description: 'Create and update cost fields',
      memory: 248,
      cpu: 0.1,
      memoryCost: 1,
      cpuCost: 2,
      diskCost: 3,
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create and update cost fields',
        'kvm',
        '248'
      ),
      CPU_COST: '2',
      MEMORY_COST: '1',
      DISK_COST: '0.0029296875',
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                memoryCost: 3,
                cpuCost: 1,
                diskCost: 2,
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create and update cost fields',
          'kvm',
          '248'
        ),
        CPU_COST: '1',
        MEMORY_COST: '3',
        DISK_COST: '0.001953125',
      },
    },
    {
      actions: [
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                memoryCost: 4,
                cpuCost: 1,
                diskCost: 2,
              },
            },
          ],
        },
        {
          step: 'extra',
          section: 'network',
          sectionActions: [],
        },
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                memoryCost: '',
                cpuCost: '',
                diskCost: '',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create and update cost fields',
          'kvm',
          '248'
        ),
      },
    },
  ],
}

const caseOwnership = {
  initialData: {
    template: {
      name: 'caseOwnership',
      hypervisor: 'kvm',
      description: 'Create and update ownership fields',
      memory: 248,
      cpu: 0.1,
      user: 'user',
      group: 'users',
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create and update ownership fields',
        'kvm',
        '248'
      ),
      AS_GID: '1',
      AS_UID: 'user',
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                user: 'oneadmin',
                group: 'oneadmin',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create and update ownership fields',
          'kvm',
          '248'
        ),
        AS_GID: '0',
        AS_UID: '0',
      },
    },
    {
      actions: [
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                user: 'user',
                group: 'users',
              },
            },
          ],
        },
        {
          step: 'extra',
          section: 'network',
          sectionActions: [],
        },
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                user: '',
                group: '',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create and update ownership fields',
          'kvm',
          '248'
        ),
      },
    },
  ],
}

export const generalCases = [
  caseBasic,
  caseInformation,
  caseHypervisor,
  caseMemory,
  casePhysicalCpu,
  caseVirtualCpu,
  caseCost,
  caseOwnership,
]
