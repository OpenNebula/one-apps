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

const caseNuma = {
  initialData: {
    template: {
      name: 'caseNuma',
      hypervisor: 'kvm',
      description: 'Create a template with numa',
      memory: 248,
      cpu: 0.1,
      numa: {
        numaTopology: true,
        pinPolicy: 'Node affinity',
        numaAffinity: '1',
        cores: '3',
        sockets: '2',
        threads: '4',
        memoryAccess: 'Private',
        hugepages: '2 MB',
      },
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create a template with numa',
        'kvm',
        '248'
      ),
      TOPOLOGY: {
        NODE_AFFINITY: '1',
        CORES: '3',
        SOCKETS: '2',
        THREADS: '4',
        MEMORY_ACCESS: 'private',
        HUGEPAGE_SIZE: '2',
      },
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'numa',
          sectionActions: [
            {
              type: 'update',
              template: {
                pinPolicy: 'Core',
                cores: '2',
                sockets: '3',
                threads: '5',
                memoryAccess: 'Shared',
                hugepages: '1 GB',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with numa',
          'kvm',
          '248'
        ),
        TOPOLOGY: {
          CORES: '2',
          SOCKETS: '3',
          THREADS: '5',
          MEMORY_ACCESS: 'shared',
          PIN_POLICY: 'CORE',
          HUGEPAGE_SIZE: '1024',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'numa',
          sectionActions: [
            {
              type: 'update',
              template: {
                numaTopology: false,
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with numa',
          'kvm',
          '248'
        ),
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'numa',
          sectionActions: [
            {
              type: 'update',
              template: {
                numaTopology: true,
                pinPolicy: 'Core',
                cores: '2',
                sockets: '3',
                threads: '5',
                memoryAccess: 'Shared',
                hugepages: '1 GB',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with numa',
          'kvm',
          '248'
        ),
        TOPOLOGY: {
          CORES: '2',
          SOCKETS: '3',
          THREADS: '5',
          MEMORY_ACCESS: 'shared',
          PIN_POLICY: 'CORE',
          HUGEPAGE_SIZE: '1024',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'numa',
          sectionActions: [
            {
              type: 'update',
              template: {
                pinPolicy: 'Core',
                cores: '',
                threads: '',
                memoryAccess: '-',
                hugepages: '-',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with numa',
          'kvm',
          '248'
        ),
        TOPOLOGY: {
          SOCKETS: '3',
          PIN_POLICY: 'CORE',
        },
      },
    },
  ],
}

const caseNumaVcpu = {
  initialData: {
    template: {
      name: 'caseNumaVcpu',
      hypervisor: 'kvm',
      description: 'Create a template with vpcu in numa',
      memory: 248,
      cpu: 0.1,
      vcpu: 1.1,
      vcpuModificationType: 'Range',
      vcpuModificationMin: '1',
      vcpuModificationMax: '4',
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create a template with vpcu in numa',
        'kvm',
        '248'
      ),
      VCPU: '1.1',
      USER_INPUTS: {
        VCPU: 'O|range-float||1..4|1.1',
      },
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'numa',
          sectionActions: [
            {
              type: 'update',
              template: {
                vcpu: 2.2,
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with vpcu in numa',
          'kvm',
          '248'
        ),
        VCPU: '2.2',
        USER_INPUTS: {
          VCPU: 'O|range-float||1..4|2.2',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'numa',
          sectionActions: [
            {
              type: 'update',
              template: {
                vcpu: 3.2,
              },
            },
          ],
        },
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                vcpu: 2,
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with vpcu in numa',
          'kvm',
          '248'
        ),
        VCPU: '2',
        USER_INPUTS: {
          VCPU: 'O|range-float||1..4|2',
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
                vcpuModificationType: 'Any value',
              },
            },
          ],
        },
        {
          step: 'extra',
          section: 'numa',
          sectionActions: [
            {
              type: 'update',
              template: {
                vcpu: '',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with vpcu in numa',
          'kvm',
          '248'
        ),
      },
    },
  ],
}

export const numaCases = [caseNuma, caseNumaVcpu]
