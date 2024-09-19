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

const casePcis = {
  initialData: {
    template: {
      name: 'casePcis',
      hypervisor: 'kvm',
      description: 'Create, delete and update pcis',
      memory: 248,
      cpu: 0.1,
      pcis: [
        {
          deviceName: 'MCP79 EHCI USB 2.0 Controller',
        },
        {
          specifyDevice: true,
          shortAddress: '02:00.0',
        },
      ],
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create, delete and update pcis',
        'kvm',
        '248'
      ),
      PCI: [
        {
          CLASS: '0c03',
          DEVICE: '0aa9',
          VENDOR: '10de',
        },
        {
          SHORT_ADDRESS: '02:00.0',
        },
      ],
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'pci',
          sectionActions: [
            {
              type: 'update',
              pci: 1,
              pciActions: [
                {
                  template: {
                    specifyDevice: false,
                    deviceName: 'MCP79 OHCI USB 1.1 Controller',
                  },
                },
              ],
            },
            {
              type: 'update',
              pci: 0,
              pciActions: [
                {
                  template: {
                    specifyDevice: true,
                    shortAddress: '06:01.0',
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
          'Create, delete and update pcis',
          'kvm',
          '248'
        ),
        PCI: [
          {
            SHORT_ADDRESS: '06:01.0',
          },
          {
            CLASS: '0c03',
            DEVICE: '0aa7',
            VENDOR: '10de',
          },
        ],
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'pci',
          sectionActions: [
            {
              type: 'delete',
              pci: 1,
            },
            {
              type: 'create',
              template: {
                specifyDevice: true,
                shortAddress: '00:00.0',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create, delete and update pcis',
          'kvm',
          '248'
        ),
        PCI: [
          {
            SHORT_ADDRESS: '06:01.0',
          },
          {
            SHORT_ADDRESS: '00:00.0',
          },
        ],
      },
    },
  ],
}

export const pciCases = [casePcis]
