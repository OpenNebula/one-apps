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

const caseNics = {
  initialData: {
    template: {
      name: 'caseNics',
      hypervisor: 'kvm',
      description: 'Create, delete and update nics',
      memory: 248,
      cpu: 0.1,
      networks: [
        {
          name: 'vnet1',
        },
        {
          auto: true,
          schedRank: 'schedRank',
          schedReqs: 'schedReqs',
        },
      ],
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create, delete and update nics',
        'kvm',
        '248'
      ),
      NIC: [
        {
          NETWORK: 'vnet1',
          NETWORK_UID: '0',
          NETWORK_UNAME: 'oneadmin',
        },
        {
          NETWORK_MODE: 'auto',
          SCHED_RANK: 'schedRank',
          SCHED_REQUIREMENTS: 'schedReqs',
        },
      ],
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'network',
          sectionActions: [
            {
              type: 'create',
              template: {
                name: 'vnet1',
              },
            },
            {
              type: 'update',
              nic: 0,
              networkActions: [
                {
                  step: 'advanced',
                  template: {
                    auto: true,
                  },
                },
              ],
            },
            {
              type: 'update',
              nic: 1,
              networkActions: [
                {
                  step: 'advanced',
                  template: {
                    auto: false,
                  },
                },
                {
                  step: 'network',
                  template: {
                    name: 'vnet3',
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
          'Create, delete and update nics',
          'kvm',
          '248'
        ),
        NIC: [
          {
            NETWORK_MODE: 'auto',
          },
          {
            NETWORK: 'vnet3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            NETWORK: 'vnet1',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
        ],
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'network',
          sectionActions: [
            {
              type: 'delete',
              nic: 1,
            },
            {
              type: 'create',
              template: {
                name: 'vnet2',
              },
            },
            {
              type: 'update',
              nic: 0,
              networkActions: [
                {
                  step: 'advanced',
                  template: {
                    auto: false,
                  },
                },
                {
                  step: 'network',
                  template: {
                    name: 'vnet4',
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
          'Create, delete and update nics',
          'kvm',
          '248'
        ),
        NIC: [
          {
            NETWORK: 'vnet4',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            NETWORK: 'vnet1',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            NETWORK: 'vnet2',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
        ],
      },
    },
  ],
}

const caseNicsAlias = {
  initialData: {
    template: {
      name: 'caseNicsAlias',
      hypervisor: 'kvm',
      description: 'Create, delete and update nics alias',
      memory: 248,
      cpu: 0.1,
      networks: [
        {
          name: 'vnet1',
        },
        {
          name: 'vnet2',
        },
        {
          name: 'vnet3',
        },
        {
          name: 'vnetAlias1',
          parent: '0',
        },
        {
          name: 'vnetAlias2',
          parent: '1',
        },
      ],
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create, delete and update nics alias',
        'kvm',
        '248'
      ),
      NIC: [
        {
          NETWORK: 'vnet1',
          NETWORK_UID: '0',
          NETWORK_UNAME: 'oneadmin',
        },
        {
          NETWORK: 'vnet2',
          NETWORK_UID: '0',
          NETWORK_UNAME: 'oneadmin',
        },
        {
          NETWORK: 'vnet3',
          NETWORK_UID: '0',
          NETWORK_UNAME: 'oneadmin',
        },
      ],
      NIC_ALIAS: [
        {
          NETWORK: 'vnetAlias1',
          NETWORK_UID: '0',
          NETWORK_UNAME: 'oneadmin',
          PARENT: 'NIC0',
        },
        {
          NETWORK: 'vnetAlias2',
          NETWORK_UID: '0',
          NETWORK_UNAME: 'oneadmin',
          PARENT: 'NIC1',
        },
      ],
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'network',
          sectionActions: [
            {
              type: 'create',
              template: {
                name: 'vnetAlias3',
                parent: '2',
              },
            },
            {
              type: 'delete',
              nic: '0',
              alias: '0',
            },
            {
              type: 'update',
              nic: '1',
              alias: '0',
              networkActions: [
                {
                  step: 'advanced',
                  template: {
                    ssh: true,
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
          'Create, delete and update nics alias',
          'kvm',
          '248'
        ),
        NIC: [
          {
            NETWORK: 'vnet1',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            NETWORK: 'vnet2',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            NETWORK: 'vnet3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
        ],
        NIC_ALIAS: [
          {
            NETWORK: 'vnetAlias2',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            PARENT: 'NIC1',
            SSH: 'YES',
          },
          {
            NETWORK: 'vnetAlias3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            PARENT: 'NIC2',
          },
        ],
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'network',
          sectionActions: [
            {
              type: 'update',
              nic: '1',
              alias: '0',
              networkActions: [
                {
                  step: 'advanced',
                  template: {
                    ssh: false,
                  },
                },
              ],
            },
            {
              type: 'create',
              template: {
                name: 'vnetAlias1',
                parent: '0',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create, delete and update nics alias',
          'kvm',
          '248'
        ),
        NIC: [
          {
            NETWORK: 'vnet1',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            NETWORK: 'vnet2',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            NETWORK: 'vnet3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
        ],
        NIC_ALIAS: [
          {
            NETWORK: 'vnetAlias2',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            PARENT: 'NIC1',
            SSH: 'NO',
          },
          {
            NETWORK: 'vnetAlias3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            PARENT: 'NIC2',
          },
          {
            NETWORK: 'vnetAlias1',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            PARENT: 'NIC0',
          },
        ],
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'network',
          sectionActions: [
            {
              type: 'delete',
              nic: '1',
              alias: '0',
            },
            {
              type: 'update',
              nic: '0',
              alias: '0',
              networkActions: [
                {
                  step: 'network',
                  template: {
                    name: 'vnetAlias2',
                  },
                },
              ],
            },
            {
              type: 'create',
              template: {
                name: 'vnetAlias1',
                parent: '1',
              },
            },
            {
              type: 'update',
              nic: '2',
              alias: '0',
              networkActions: [
                {
                  step: 'advanced',
                  template: {
                    skipContext: true,
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
          'Create, delete and update nics alias',
          'kvm',
          '248'
        ),
        NIC: [
          {
            NETWORK: 'vnet1',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            NETWORK: 'vnet2',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            NETWORK: 'vnet3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
        ],
        NIC_ALIAS: [
          {
            NETWORK: 'vnetAlias3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            PARENT: 'NIC2',
            EXTERNAL: 'YES',
          },
          {
            NETWORK: 'vnetAlias2',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            PARENT: 'NIC0',
          },
          {
            NETWORK: 'vnetAlias1',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            PARENT: 'NIC1',
          },
        ],
      },
    },
  ],
}

const caseNicsPcis = {
  initialData: {
    template: {
      name: 'caseNicsPcis',
      hypervisor: 'kvm',
      description: 'Create, delete and update nics pcis',
      memory: 248,
      cpu: 0.1,
      networks: [
        {
          name: 'vnetPci1',
          pci: {
            type: 'PCI Passthrough - Automatic',
            name: 'C79 [GeForce 9400M]',
          },
        },
        {
          name: 'vnetPci2',
          pci: {
            type: 'PCI Passthrough - Manual',
            shortAddress: '00:06.1',
          },
        },
      ],
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create, delete and update nics pcis',
        'kvm',
        '248'
      ),
      PCI: [
        {
          NETWORK: 'vnetPci1',
          NETWORK_UID: '0',
          NETWORK_UNAME: 'oneadmin',
          CLASS: '0300',
          DEVICE: '0863',
          VENDOR: '10de',
          TYPE: 'NIC',
        },
        {
          NETWORK: 'vnetPci2',
          NETWORK_UID: '0',
          NETWORK_UNAME: 'oneadmin',
          SHORT_ADDRESS: '00:06.1',
          TYPE: 'NIC',
        },
      ],
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'network',
          sectionActions: [
            {
              type: 'create',
              template: {
                name: 'vnetPci3',
                pci: {
                  type: 'PCI Passthrough - Automatic',
                  name: 'MCP79 OHCI USB 1.1 Controller',
                },
              },
            },
            {
              type: 'delete',
              nic: 0,
            },
            {
              type: 'update',
              nic: 0,
              networkActions: [
                {
                  step: 'advanced',
                  template: {
                    ssh: true,
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
          'Create, delete and update nics pcis',
          'kvm',
          '248'
        ),
        PCI: [
          {
            NETWORK: 'vnetPci2',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            SHORT_ADDRESS: '00:06.1',
            TYPE: 'NIC',
            SSH: 'YES',
          },
          {
            NETWORK: 'vnetPci3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            CLASS: '0c03',
            DEVICE: '0aa7',
            VENDOR: '10de',
            TYPE: 'NIC',
          },
        ],
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'network',
          sectionActions: [
            {
              type: 'update',
              nic: 0,
              networkActions: [
                {
                  step: 'advanced',
                  template: {
                    ssh: false,
                  },
                },
              ],
            },
            {
              type: 'create',
              template: {
                name: 'vnetPci1',
                pci: {
                  type: 'PCI Passthrough - Automatic',
                  name: 'MCP79 OHCI USB 1.1 Controller',
                },
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create, delete and update nics pcis',
          'kvm',
          '248'
        ),
        PCI: [
          {
            NETWORK: 'vnetPci2',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            SHORT_ADDRESS: '00:06.1',
            TYPE: 'NIC',
            SSH: 'NO',
          },
          {
            NETWORK: 'vnetPci3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            CLASS: '0c03',
            DEVICE: '0aa7',
            VENDOR: '10de',
            TYPE: 'NIC',
          },
          {
            NETWORK: 'vnetPci1',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            CLASS: '0c03',
            DEVICE: '0aa7',
            VENDOR: '10de',
            TYPE: 'NIC',
          },
        ],
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'network',
          sectionActions: [
            {
              type: 'update',
              nic: 1,
              networkActions: [
                {
                  step: 'advanced',
                  template: {
                    pci: {
                      type: 'PCI Passthrough - Manual',
                      shortAddress: '00:06.2',
                    },
                  },
                },
              ],
            },
            {
              type: 'delete',
              nic: 0,
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create, delete and update nics pcis',
          'kvm',
          '248'
        ),
        PCI: [
          {
            NETWORK: 'vnetPci3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            SHORT_ADDRESS: '00:06.2',
            TYPE: 'NIC',
          },
          {
            NETWORK: 'vnetPci1',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            CLASS: '0c03',
            DEVICE: '0aa7',
            VENDOR: '10de',
            TYPE: 'NIC',
          },
        ],
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'network',
          sectionActions: [
            {
              type: 'create',
              template: {
                name: 'vnetPci2',
                pci: {
                  type: 'PCI Passthrough - Automatic',
                  name: 'MCP79 OHCI USB 1.1 Controller',
                },
              },
            },
            {
              type: 'update',
              nic: 1,
              networkActions: [
                {
                  step: 'network',
                  template: {
                    name: 'vnetPci2',
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
          'Create, delete and update nics pcis',
          'kvm',
          '248'
        ),
        PCI: [
          {
            NETWORK: 'vnetPci3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            SHORT_ADDRESS: '00:06.2',
            TYPE: 'NIC',
          },
          {
            NETWORK: 'vnetPci2',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            CLASS: '0c03',
            DEVICE: '0aa7',
            VENDOR: '10de',
            TYPE: 'NIC',
          },
          {
            NETWORK: 'vnetPci2',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            CLASS: '0c03',
            DEVICE: '0aa7',
            VENDOR: '10de',
            TYPE: 'NIC',
          },
        ],
      },
    },
  ],
}

const caseNicsMix = {
  initialData: {
    template: {
      name: 'caseNicsMix',
      hypervisor: 'kvm',
      description:
        'Create, delete and update nics, alias and pcis at the same time',
      memory: 248,
      cpu: 0.1,
      networks: [
        {
          name: 'vnet1',
        },
        {
          name: 'vnet2',
        },
        {
          name: 'vnet3',
        },
        {
          name: 'vnet4',
        },
        {
          name: 'vnetAlias1',
          parent: '0',
        },
        {
          name: 'vnetAlias3',
          parent: '2',
        },
        {
          name: 'vnetPci1',
          pci: {
            type: 'PCI Passthrough - Manual',
            shortAddress: '00:06.1',
          },
        },
        {
          name: 'vnetPci2',
          pci: {
            type: 'PCI Passthrough - Manual',
            shortAddress: '00:06.2',
          },
        },
        {
          name: 'vnetPci3',
          pci: {
            type: 'PCI Passthrough - Manual',
            shortAddress: '00:06.3',
          },
        },
      ],
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create, delete and update nics, alias and pcis at the same time',
        'kvm',
        '248'
      ),
      NIC: [
        {
          NETWORK: 'vnet1',
          NETWORK_UID: '0',
          NETWORK_UNAME: 'oneadmin',
        },
        {
          NETWORK: 'vnet2',
          NETWORK_UID: '0',
          NETWORK_UNAME: 'oneadmin',
        },
        {
          NETWORK: 'vnet3',
          NETWORK_UID: '0',
          NETWORK_UNAME: 'oneadmin',
        },
        {
          NETWORK: 'vnet4',
          NETWORK_UID: '0',
          NETWORK_UNAME: 'oneadmin',
        },
      ],
      NIC_ALIAS: [
        {
          PARENT: 'NIC0',
          NETWORK: 'vnetAlias1',
          NETWORK_UID: '0',
          NETWORK_UNAME: 'oneadmin',
        },
        {
          PARENT: 'NIC2',
          NETWORK: 'vnetAlias3',
          NETWORK_UID: '0',
          NETWORK_UNAME: 'oneadmin',
        },
      ],
      PCI: [
        {
          NETWORK: 'vnetPci1',
          NETWORK_UID: '0',
          NETWORK_UNAME: 'oneadmin',
          SHORT_ADDRESS: '00:06.1',
          TYPE: 'NIC',
        },
        {
          NETWORK: 'vnetPci2',
          NETWORK_UID: '0',
          NETWORK_UNAME: 'oneadmin',
          SHORT_ADDRESS: '00:06.2',
          TYPE: 'NIC',
        },
        {
          NETWORK: 'vnetPci3',
          NETWORK_UID: '0',
          NETWORK_UNAME: 'oneadmin',
          SHORT_ADDRESS: '00:06.3',
          TYPE: 'NIC',
        },
      ],
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'network',
          sectionActions: [
            {
              type: 'update',
              nic: 4,
              networkActions: [
                {
                  step: 'advanced',
                  template: {
                    pci: {
                      type: 'Emulated',
                    },
                  },
                },
              ],
            },
            {
              type: 'update',
              nic: '2',
              alias: '0',
              networkActions: [
                {
                  step: 'advanced',
                  template: {
                    ssh: true,
                  },
                },
              ],
            },
            {
              type: 'create',
              template: {
                name: 'vnetAlias3',
                parent: '5',
              },
            },
            {
              type: 'update',
              nic: 3,
              networkActions: [
                {
                  step: 'advanced',
                  template: {
                    pci: {
                      type: 'PCI Passthrough - Manual',
                      shortAddress: '00:06.10',
                    },
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
          'Create, delete and update nics, alias and pcis at the same time',
          'kvm',
          '248'
        ),
        NIC: [
          {
            NETWORK: 'vnet1',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            NETWORK: 'vnet2',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            NETWORK: 'vnet3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            NETWORK: 'vnetPci1',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
        ],
        NIC_ALIAS: [
          {
            PARENT: 'NIC0',
            NETWORK: 'vnetAlias1',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            PARENT: 'NIC2',
            NETWORK: 'vnetAlias3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            SSH: 'YES',
          },
          {
            PARENT: 'PCI0',
            NETWORK: 'vnetAlias3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
        ],
        PCI: [
          {
            NETWORK: 'vnetPci2',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            SHORT_ADDRESS: '00:06.2',
            TYPE: 'NIC',
          },
          {
            NETWORK: 'vnetPci3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            SHORT_ADDRESS: '00:06.3',
            TYPE: 'NIC',
          },
          {
            NETWORK: 'vnet4',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            SHORT_ADDRESS: '00:06.10',
            TYPE: 'NIC',
          },
        ],
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'network',
          sectionActions: [
            {
              type: 'update',
              nic: 6,
              networkActions: [
                {
                  step: 'advanced',
                  template: {
                    pci: {
                      type: 'Emulated',
                    },
                  },
                },
              ],
            },
            {
              type: 'create',
              template: {
                name: 'vnetAlias3',
                parent: '2',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create, delete and update nics, alias and pcis at the same time',
          'kvm',
          '248'
        ),
        NIC: [
          {
            NETWORK: 'vnet1',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            NETWORK: 'vnet2',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            NETWORK: 'vnet3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            NETWORK: 'vnetPci1',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            NETWORK: 'vnet4',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
        ],
        NIC_ALIAS: [
          {
            PARENT: 'NIC0',
            NETWORK: 'vnetAlias1',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            PARENT: 'NIC2',
            NETWORK: 'vnetAlias3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            SSH: 'YES',
          },
          {
            PARENT: 'PCI0',
            NETWORK: 'vnetAlias3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            PARENT: 'NIC2',
            NETWORK: 'vnetAlias3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
        ],
        PCI: [
          {
            NETWORK: 'vnetPci2',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            SHORT_ADDRESS: '00:06.2',
            TYPE: 'NIC',
          },
          {
            NETWORK: 'vnetPci3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            SHORT_ADDRESS: '00:06.3',
            TYPE: 'NIC',
          },
        ],
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'network',
          sectionActions: [
            {
              type: 'update',
              nic: 1,
              networkActions: [
                {
                  step: 'advanced',
                  template: {
                    pci: {
                      type: 'PCI Passthrough - Manual',
                      shortAddress: '00:06.12',
                    },
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
          'Create, delete and update nics, alias and pcis at the same time',
          'kvm',
          '248'
        ),
        NIC: [
          {
            NETWORK: 'vnet1',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            NETWORK: 'vnet3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            NETWORK: 'vnetPci1',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            NETWORK: 'vnet4',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
        ],
        NIC_ALIAS: [
          {
            PARENT: 'NIC0',
            NETWORK: 'vnetAlias1',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            PARENT: 'NIC1',
            NETWORK: 'vnetAlias3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            SSH: 'YES',
          },
          {
            PARENT: 'PCI0',
            NETWORK: 'vnetAlias3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            PARENT: 'NIC1',
            NETWORK: 'vnetAlias3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
        ],
        PCI: [
          {
            NETWORK: 'vnetPci2',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            SHORT_ADDRESS: '00:06.2',
            TYPE: 'NIC',
          },
          {
            NETWORK: 'vnetPci3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            SHORT_ADDRESS: '00:06.3',
            TYPE: 'NIC',
          },
          {
            NETWORK: 'vnet2',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            SHORT_ADDRESS: '00:06.12',
            TYPE: 'NIC',
          },
        ],
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'network',
          sectionActions: [
            {
              type: 'delete',
              nic: 6,
            },
            {
              type: 'delete',
              nic: 2,
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create, delete and update nics, alias and pcis at the same time',
          'kvm',
          '248'
        ),
        NIC: [
          {
            NETWORK: 'vnet1',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            NETWORK: 'vnet3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            NETWORK: 'vnet4',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
        ],
        NIC_ALIAS: [
          {
            PARENT: 'NIC0',
            NETWORK: 'vnetAlias1',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            PARENT: 'NIC1',
            NETWORK: 'vnetAlias3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            SSH: 'YES',
          },
          {
            PARENT: 'PCI0',
            NETWORK: 'vnetAlias3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            PARENT: 'NIC1',
            NETWORK: 'vnetAlias3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
        ],
        PCI: [
          {
            NETWORK: 'vnetPci2',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            SHORT_ADDRESS: '00:06.2',
            TYPE: 'NIC',
          },
          {
            NETWORK: 'vnetPci3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            SHORT_ADDRESS: '00:06.3',
            TYPE: 'NIC',
          },
        ],
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'network',
          sectionActions: [
            {
              type: 'delete',
              nic: '1',
              alias: '1',
            },
            {
              type: 'delete',
              nic: '1',
              alias: '0',
            },
            {
              type: 'delete',
              nic: '1',
            },
            {
              type: 'create',
              template: {
                name: 'vnet2',
              },
            },
            {
              type: 'update',
              nic: 4,
              networkActions: [
                {
                  step: 'advanced',
                  template: {
                    ssh: true,
                  },
                },
              ],
            },
            {
              type: 'create',
              template: {
                name: 'vnetPci1',
                pci: {
                  type: 'PCI Passthrough - Manual',
                  shortAddress: '00:06.23',
                },
              },
            },
            {
              type: 'update',
              nic: 1,
              networkActions: [
                {
                  step: 'advanced',
                  template: {
                    ssh: true,
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
          'Create, delete and update nics, alias and pcis at the same time',
          'kvm',
          '248'
        ),
        NIC: [
          {
            NETWORK: 'vnet1',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            NETWORK: 'vnet4',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            SSH: 'YES',
          },
          {
            NETWORK: 'vnet2',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
        ],
        NIC_ALIAS: [
          {
            PARENT: 'NIC0',
            NETWORK: 'vnetAlias1',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            PARENT: 'PCI0',
            NETWORK: 'vnetAlias3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
        ],
        PCI: [
          {
            NETWORK: 'vnetPci2',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            SHORT_ADDRESS: '00:06.2',
            TYPE: 'NIC',
          },
          {
            NETWORK: 'vnetPci3',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            SHORT_ADDRESS: '00:06.3',
            TYPE: 'NIC',
            SSH: 'YES',
          },
          {
            NETWORK: 'vnetPci1',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
            SHORT_ADDRESS: '00:06.23',
            TYPE: 'NIC',
          },
        ],
      },
    },
  ],
}

const caseNicAllData = {
  initialData: {
    template: {
      name: 'caseNicAllData',
      hypervisor: 'kvm',
      description: 'Create, delete and update nic with all data',
      memory: 248,
      cpu: 0.1,
      networks: [
        {
          name: 'vnet1',
          rdp: true,
          rdpOptions: {
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
            resizeMethod: 'Reconnect',
            keyboardLayout: 'Spanish (Spain)',
          },
          ssh: true,
          ipv4: {
            ip: '127.0.0.1',
            mac: '02:42:ac:11:00:02',
            mask: '255.255.255.0',
            address: '192.168.1.0',
            gateway: 'gateway',
            domains: 'domains',
            method: 'DHCP (DHCPv4)',
          },
          ipv6: {
            v6Ip: '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
            v6Gateway: 'gatewayv6',
            v6Method: 'Auto (SLAAC)',
          },
          mtu: 10,
          inbound: {
            inboundAverage: 100,
            inboundPeak: 200,
            inboundPeakBurst: 300,
          },
          outbound: {
            outboundAverage: 400,
            outboundPeak: 500,
            outboundPeakBurst: 600,
          },
        },
      ],
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create, delete and update nic with all data',
        'kvm',
        '248'
      ),
      NIC: {
        NETWORK: 'vnet1',
        NETWORK_UID: '0',
        NETWORK_UNAME: 'oneadmin',
        RDP: 'YES',
        RDP_DISABLE_AUDIO: 'YES',
        RDP_DISABLE_BITMAP_CACHING: 'YES',
        RDP_DISABLE_GLYPH_CACHING: 'YES',
        RDP_DISABLE_OFFSCREEN_CACHING: 'YES',
        RDP_ENABLE_AUDIO_INPUT: 'YES',
        RDP_ENABLE_DESKTOP_COMPOSITION: 'YES',
        RDP_ENABLE_FONT_SMOOTHING: 'YES',
        RDP_ENABLE_FULL_WINDOW_DRAG: 'YES',
        RDP_ENABLE_MENU_ANIMATIONS: 'YES',
        RDP_ENABLE_THEMING: 'YES',
        RDP_ENABLE_WALLPAPER: 'YES',
        RDP_RESIZE_METHOD: 'reconnect',
        RDP_SERVER_LAYOUT: 'es-es-qwerty',
        SSH: 'YES',
        GATEWAY: 'gateway',
        GATEWAY6: 'gatewayv6',
        IP: '127.0.0.1',
        IP6: '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
        IP6_METHOD: 'auto',
        MAC: '02:42:ac:11:00:02',
        METHOD: 'dhcp',
        NETWORK_ADDRESS: '192.168.1.0',
        NETWORK_MASK: '255.255.255.0',
        SEARCH_DOMAIN: 'domains',
        GUEST_MTU: '10',
        INBOUND_AVG_BW: '100',
        INBOUND_PEAK_BW: '200',
        INBOUND_PEAK_KB: '300',
        OUTBOUND_AVG_BW: '400',
        OUTBOUND_PEAK_BW: '500',
        OUTBOUND_PEAK_KB: '600',
      },
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'network',
          sectionActions: [
            {
              type: 'update',
              nic: 0,
              networkActions: [
                {
                  step: 'advanced',
                  template: {
                    rdp: true,
                    rdpOptions: {
                      disableAudio: false,
                      disableBitmap: false,
                      disableGlyph: false,
                      disableOffscreen: false,
                      enableAudioInput: false,
                      enableDesktopComposition: false,
                      enableFontSmoothing: false,
                      enableWindowDrag: false,
                      enableMenuAnimations: false,
                      enableTheming: false,
                      enableWallpaper: false,
                      resizeMethod: 'Display update',
                      keyboardLayout: 'Japanese',
                    },
                    ssh: false,
                    ipv4: {
                      ip: '127.0.0.2',
                      mac: '02:42:ac:11:00:03',
                      mask: '255.255.255.1',
                      address: '192.168.1.1',
                      gateway: 'gateway2',
                      domains: 'domains2',
                      method: 'Skip (Do not configure IPv4)',
                    },
                    ipv6: {
                      v6Ip: '2001:0db8:85a3:0000:0000:8a2e:0370:7335',
                      v6Gateway: 'gatewayv62',
                      v6Method: 'Skip (Do not configure IPv4)',
                    },
                    mtu: 100,
                  },
                },
                {
                  step: 'network',
                },
                {
                  step: 'qos',
                  template: {
                    inbound: {
                      inboundAverage: 1000,
                      inboundPeak: 2000,
                      inboundPeakBurst: 3000,
                    },
                    outbound: {
                      outboundAverage: 4000,
                      outboundPeak: 5000,
                      outboundPeakBurst: 6000,
                    },
                  },
                },
                {
                  step: 'network',
                  template: {
                    name: 'vnet2',
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
          'Create, delete and update nic with all data',
          'kvm',
          '248'
        ),
        NIC: {
          NETWORK: 'vnet2',
          NETWORK_UNAME: 'oneadmin',
          NETWORK_UID: '0',
          RDP: 'YES',
          RDP_DISABLE_AUDIO: 'NO',
          RDP_DISABLE_BITMAP_CACHING: 'NO',
          RDP_DISABLE_GLYPH_CACHING: 'NO',
          RDP_DISABLE_OFFSCREEN_CACHING: 'NO',
          RDP_ENABLE_AUDIO_INPUT: 'NO',
          RDP_ENABLE_DESKTOP_COMPOSITION: 'NO',
          RDP_ENABLE_FONT_SMOOTHING: 'NO',
          RDP_ENABLE_FULL_WINDOW_DRAG: 'NO',
          RDP_ENABLE_MENU_ANIMATIONS: 'NO',
          RDP_ENABLE_THEMING: 'NO',
          RDP_ENABLE_WALLPAPER: 'NO',
          RDP_RESIZE_METHOD: 'display-update',
          RDP_SERVER_LAYOUT: 'ja-jp-qwerty',
          SSH: 'NO',
          GATEWAY: 'gateway2',
          GATEWAY6: 'gatewayv62',
          IP: '127.0.0.2',
          IP6: '2001:0db8:85a3:0000:0000:8a2e:0370:7335',
          IP6_METHOD: 'skip',
          MAC: '02:42:ac:11:00:03',
          METHOD: 'skip',
          NETWORK_ADDRESS: '192.168.1.1',
          NETWORK_MASK: '255.255.255.1',
          SEARCH_DOMAIN: 'domains2',
          GUEST_MTU: '100',
          INBOUND_AVG_BW: '1000',
          INBOUND_PEAK_BW: '2000',
          INBOUND_PEAK_KB: '3000',
          OUTBOUND_AVG_BW: '4000',
          OUTBOUND_PEAK_BW: '5000',
          OUTBOUND_PEAK_KB: '6000',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'network',
          sectionActions: [
            {
              type: 'update',
              nic: 0,
              networkActions: [
                {
                  step: 'advanced',
                  template: {
                    rdp: false,
                    ipv4: {
                      ip: '',
                      mac: '',
                      mask: '',
                      address: '',
                      gateway: '',
                      domains: '',
                      method: '-',
                    },
                    ipv6: {
                      v6Ip: '',
                      v6Gateway: '',
                      v6Method: '-',
                    },
                    mtu: '',
                  },
                },
                {
                  step: 'network',
                },
                {
                  step: 'qos',
                  template: {
                    inbound: {
                      inboundAverage: '',
                      inboundPeak: '',
                      inboundPeakBurst: '',
                    },
                    outbound: {
                      outboundAverage: '',
                      outboundPeak: '',
                      outboundPeakBurst: '',
                    },
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
          'Create, delete and update nic with all data',
          'kvm',
          '248'
        ),
        NIC: {
          NETWORK: 'vnet2',
          NETWORK_UNAME: 'oneadmin',
          NETWORK_UID: '0',
          RDP: 'NO',
          SSH: 'NO',
        },
      },
    },
  ],
}

const caseNicAliasAllData = {
  initialData: {
    template: {
      name: 'caseNicAliasAllData',
      hypervisor: 'kvm',
      description: 'Create, delete and update nic alias with all data',
      memory: 248,
      cpu: 0.1,
      networks: [
        {
          name: 'vnet1',
        },

        {
          name: 'vnet2',
        },
        {
          name: 'vnetAlias1',
          parent: '0',
          skipContext: true,
          rdp: true,
          rdpOptions: {
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
            resizeMethod: 'Reconnect',
            keyboardLayout: 'Spanish (Spain)',
          },
          ssh: true,
          ipv4: {
            ip: '127.0.0.1',
            mac: '02:42:ac:11:00:02',
            mask: '255.255.255.0',
            address: '192.168.1.0',
            gateway: 'gateway',
            domains: 'domains',
            method: 'DHCP (DHCPv4)',
          },
          ipv6: {
            v6Ip: '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
            v6Gateway: 'gatewayv6',
            v6Method: 'Auto (SLAAC)',
          },
          mtu: 10,
        },
      ],
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create, delete and update nic alias with all data',
        'kvm',
        '248'
      ),
      NIC: [
        {
          NETWORK: 'vnet1',
          NETWORK_UID: '0',
          NETWORK_UNAME: 'oneadmin',
        },
        {
          NETWORK: 'vnet2',
          NETWORK_UID: '0',
          NETWORK_UNAME: 'oneadmin',
        },
      ],
      NIC_ALIAS: {
        NETWORK: 'vnetAlias1',
        PARENT: 'NIC0',
        EXTERNAL: 'YES',
        NETWORK_UID: '0',
        NETWORK_UNAME: 'oneadmin',
        RDP: 'YES',
        RDP_DISABLE_AUDIO: 'YES',
        RDP_DISABLE_BITMAP_CACHING: 'YES',
        RDP_DISABLE_GLYPH_CACHING: 'YES',
        RDP_DISABLE_OFFSCREEN_CACHING: 'YES',
        RDP_ENABLE_AUDIO_INPUT: 'YES',
        RDP_ENABLE_DESKTOP_COMPOSITION: 'YES',
        RDP_ENABLE_FONT_SMOOTHING: 'YES',
        RDP_ENABLE_FULL_WINDOW_DRAG: 'YES',
        RDP_ENABLE_MENU_ANIMATIONS: 'YES',
        RDP_ENABLE_THEMING: 'YES',
        RDP_ENABLE_WALLPAPER: 'YES',
        RDP_RESIZE_METHOD: 'reconnect',
        RDP_SERVER_LAYOUT: 'es-es-qwerty',
        SSH: 'YES',
        GATEWAY: 'gateway',
        GATEWAY6: 'gatewayv6',
        IP: '127.0.0.1',
        IP6: '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
        IP6_METHOD: 'auto',
        MAC: '02:42:ac:11:00:02',
        METHOD: 'dhcp',
        NETWORK_ADDRESS: '192.168.1.0',
        NETWORK_MASK: '255.255.255.0',
        SEARCH_DOMAIN: 'domains',
        GUEST_MTU: '10',
      },
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'network',
          sectionActions: [
            {
              type: 'update',
              nic: '0',
              alias: '0',
              networkActions: [
                {
                  step: 'advanced',
                  template: {
                    skipContext: false,
                    rdp: true,
                    rdpOptions: {
                      disableAudio: false,
                      disableBitmap: false,
                      disableGlyph: false,
                      disableOffscreen: false,
                      enableAudioInput: false,
                      enableDesktopComposition: false,
                      enableFontSmoothing: false,
                      enableWindowDrag: false,
                      enableMenuAnimations: false,
                      enableTheming: false,
                      enableWallpaper: false,
                      resizeMethod: 'Display update',
                      keyboardLayout: 'Japanese',
                    },
                    ssh: false,
                    ipv4: {
                      ip: '127.0.0.2',
                      mac: '02:42:ac:11:00:03',
                      mask: '255.255.255.1',
                      address: '192.168.1.1',
                      gateway: 'gateway2',
                      domains: 'domains2',
                      method: 'Skip (Do not configure IPv4)',
                    },
                    ipv6: {
                      v6Ip: '2001:0db8:85a3:0000:0000:8a2e:0370:7335',
                      v6Gateway: 'gatewayv62',
                      v6Method: 'Skip (Do not configure IPv4)',
                    },
                    mtu: 100,
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
          'Create, delete and update nic alias with all data',
          'kvm',
          '248'
        ),
        NIC: [
          {
            NETWORK: 'vnet1',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            NETWORK: 'vnet2',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
        ],
        NIC_ALIAS: {
          NETWORK: 'vnetAlias1',
          PARENT: 'NIC0',
          EXTERNAL: 'NO',
          NETWORK_UID: '0',
          NETWORK_UNAME: 'oneadmin',
          RDP: 'YES',
          RDP_DISABLE_AUDIO: 'NO',
          RDP_DISABLE_BITMAP_CACHING: 'NO',
          RDP_DISABLE_GLYPH_CACHING: 'NO',
          RDP_DISABLE_OFFSCREEN_CACHING: 'NO',
          RDP_ENABLE_AUDIO_INPUT: 'NO',
          RDP_ENABLE_DESKTOP_COMPOSITION: 'NO',
          RDP_ENABLE_FONT_SMOOTHING: 'NO',
          RDP_ENABLE_FULL_WINDOW_DRAG: 'NO',
          RDP_ENABLE_MENU_ANIMATIONS: 'NO',
          RDP_ENABLE_THEMING: 'NO',
          RDP_ENABLE_WALLPAPER: 'NO',
          RDP_RESIZE_METHOD: 'display-update',
          RDP_SERVER_LAYOUT: 'ja-jp-qwerty',
          SSH: 'NO',
          GATEWAY: 'gateway2',
          GATEWAY6: 'gatewayv62',
          IP: '127.0.0.2',
          IP6: '2001:0db8:85a3:0000:0000:8a2e:0370:7335',
          IP6_METHOD: 'skip',
          MAC: '02:42:ac:11:00:03',
          METHOD: 'skip',
          NETWORK_ADDRESS: '192.168.1.1',
          NETWORK_MASK: '255.255.255.1',
          SEARCH_DOMAIN: 'domains2',
          GUEST_MTU: '100',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'network',
          sectionActions: [
            {
              type: 'update',
              nic: '0',
              alias: '0',
              networkActions: [
                {
                  step: 'network',
                  template: {
                    name: 'vnetAlias2',
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
          'Create, delete and update nic alias with all data',
          'kvm',
          '248'
        ),
        NIC: [
          {
            NETWORK: 'vnet1',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            NETWORK: 'vnet2',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
        ],
        NIC_ALIAS: {
          NETWORK: 'vnetAlias2',
          PARENT: 'NIC0',
          EXTERNAL: 'NO',
          NETWORK_UID: '0',
          NETWORK_UNAME: 'oneadmin',
          RDP: 'YES',
          RDP_DISABLE_AUDIO: 'NO',
          RDP_DISABLE_BITMAP_CACHING: 'NO',
          RDP_DISABLE_GLYPH_CACHING: 'NO',
          RDP_DISABLE_OFFSCREEN_CACHING: 'NO',
          RDP_ENABLE_AUDIO_INPUT: 'NO',
          RDP_ENABLE_DESKTOP_COMPOSITION: 'NO',
          RDP_ENABLE_FONT_SMOOTHING: 'NO',
          RDP_ENABLE_FULL_WINDOW_DRAG: 'NO',
          RDP_ENABLE_MENU_ANIMATIONS: 'NO',
          RDP_ENABLE_THEMING: 'NO',
          RDP_ENABLE_WALLPAPER: 'NO',
          RDP_RESIZE_METHOD: 'display-update',
          RDP_SERVER_LAYOUT: 'ja-jp-qwerty',
          SSH: 'NO',
          GATEWAY: 'gateway2',
          GATEWAY6: 'gatewayv62',
          IP: '127.0.0.2',
          IP6: '2001:0db8:85a3:0000:0000:8a2e:0370:7335',
          IP6_METHOD: 'skip',
          MAC: '02:42:ac:11:00:03',
          METHOD: 'skip',
          NETWORK_ADDRESS: '192.168.1.1',
          NETWORK_MASK: '255.255.255.1',
          SEARCH_DOMAIN: 'domains2',
          GUEST_MTU: '100',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'network',
          sectionActions: [
            {
              type: 'update',
              nic: '0',
              alias: '0',
              networkActions: [
                {
                  step: 'advanced',
                  template: {
                    rdp: false,
                    ipv4: {
                      ip: '',
                      mac: '',
                      mask: '',
                      address: '',
                      gateway: '',
                      domains: '',
                      method: '-',
                    },
                    ipv6: {
                      v6Ip: '',
                      v6Gateway: '',
                      v6Method: '-',
                    },
                    mtu: '',
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
          'Create, delete and update nic alias with all data',
          'kvm',
          '248'
        ),
        NIC: [
          {
            NETWORK: 'vnet1',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
          {
            NETWORK: 'vnet2',
            NETWORK_UID: '0',
            NETWORK_UNAME: 'oneadmin',
          },
        ],
        NIC_ALIAS: {
          NETWORK: 'vnetAlias2',
          NETWORK_UID: '0',
          NETWORK_UNAME: 'oneadmin',
          PARENT: 'NIC0',
          EXTERNAL: 'NO',
          RDP: 'NO',
          SSH: 'NO',
        },
      },
    },
  ],
}

// eslint-disable-next-line no-unused-vars
const caseNicPciAllData = {
  initialData: {
    template: {
      name: 'caseNicPciAllData',
      hypervisor: 'kvm',
      description: 'Create, delete and update nic pci with all data',
      memory: 248,
      cpu: 0.1,
      networks: [
        {
          name: 'vnetPci1',
          pci: {
            type: 'PCI Passthrough - Automatic',
            name: 'C79 [GeForce 9400M]',
          },
          rdp: true,
          rdpOptions: {
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
            resizeMethod: 'Reconnect',
            keyboardLayout: 'Spanish (Spain)',
          },
          ssh: true,
          ipv4: {
            ip: '127.0.0.1',
            mac: '02:42:ac:11:00:02',
            mask: '255.255.255.0',
            address: '192.168.1.0',
            gateway: 'gateway',
            domains: 'domains',
            method: 'DHCP (DHCPv4)',
          },
          ipv6: {
            v6Ip: '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
            v6Gateway: 'gatewayv6',
            v6Method: 'Auto (SLAAC)',
          },
          mtu: 10,
          inbound: {
            inboundAverage: 100,
            inboundPeak: 200,
            inboundPeakBurst: 300,
          },
          outbound: {
            outboundAverage: 400,
            outboundPeak: 500,
            outboundPeakBurst: 600,
          },
        },
      ],
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create, delete and update nic pci with all data',
        'kvm',
        '248'
      ),
      PCI: {
        CLASS: '0300',
        DEVICE: '0863',
        VENDOR: '10de',
        TYPE: 'NIC',
        NETWORK: 'vnetPci1',
        NETWORK_UID: '0',
        NETWORK_UNAME: 'oneadmin',
        RDP: 'YES',
        RDP_DISABLE_AUDIO: 'YES',
        RDP_DISABLE_BITMAP_CACHING: 'YES',
        RDP_DISABLE_GLYPH_CACHING: 'YES',
        RDP_DISABLE_OFFSCREEN_CACHING: 'YES',
        RDP_ENABLE_AUDIO_INPUT: 'YES',
        RDP_ENABLE_DESKTOP_COMPOSITION: 'YES',
        RDP_ENABLE_FONT_SMOOTHING: 'YES',
        RDP_ENABLE_FULL_WINDOW_DRAG: 'YES',
        RDP_ENABLE_MENU_ANIMATIONS: 'YES',
        RDP_ENABLE_THEMING: 'YES',
        RDP_ENABLE_WALLPAPER: 'YES',
        RDP_RESIZE_METHOD: 'reconnect',
        RDP_SERVER_LAYOUT: 'es-es-qwerty',
        SSH: 'YES',
        GATEWAY: 'gateway',
        GATEWAY6: 'gatewayv6',
        IP: '127.0.0.1',
        IP6: '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
        IP6_METHOD: 'auto',
        MAC: '02:42:ac:11:00:02',
        METHOD: 'dhcp',
        NETWORK_ADDRESS: '192.168.1.0',
        NETWORK_MASK: '255.255.255.0',
        SEARCH_DOMAIN: 'domains',
        GUEST_MTU: '10',
        INBOUND_AVG_BW: '100',
        INBOUND_PEAK_BW: '200',
        INBOUND_PEAK_KB: '300',
        OUTBOUND_AVG_BW: '400',
        OUTBOUND_PEAK_BW: '500',
        OUTBOUND_PEAK_KB: '600',
      },
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'network',
          sectionActions: [
            {
              type: 'update',
              nic: 0,
              networkActions: [
                {
                  step: 'advanced',
                  template: {
                    pci: {
                      name: 'MCP79 OHCI USB 1.1 Controller',
                    },
                    rdp: true,
                    rdpOptions: {
                      disableAudio: false,
                      disableBitmap: false,
                      disableGlyph: false,
                      disableOffscreen: false,
                      enableAudioInput: false,
                      enableDesktopComposition: false,
                      enableFontSmoothing: false,
                      enableWindowDrag: false,
                      enableMenuAnimations: false,
                      enableTheming: false,
                      enableWallpaper: false,
                      resizeMethod: 'Display update',
                      keyboardLayout: 'Japanese',
                    },
                    ssh: false,
                    ipv4: {
                      ip: '127.0.0.2',
                      mac: '02:42:ac:11:00:03',
                      mask: '255.255.255.1',
                      address: '192.168.1.1',
                      gateway: 'gateway2',
                      domains: 'domains2',
                      method: 'Skip (Do not configure IPv4)',
                    },
                    ipv6: {
                      v6Ip: '2001:0db8:85a3:0000:0000:8a2e:0370:7335',
                      v6Gateway: 'gatewayv62',
                      v6Method: 'Skip (Do not configure IPv4)',
                    },
                    mtu: 100,
                  },
                },
                {
                  step: 'network',
                },
                {
                  step: 'qos',
                  template: {
                    inbound: {
                      inboundAverage: 1000,
                      inboundPeak: 2000,
                      inboundPeakBurst: 3000,
                    },
                    outbound: {
                      outboundAverage: 4000,
                      outboundPeak: 5000,
                      outboundPeakBurst: 6000,
                    },
                  },
                },
                {
                  step: 'network',
                  template: {
                    name: 'vnetPci2',
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
          'Create, delete and update nic pci with all data',
          'kvm',
          '248'
        ),
        PCI: {
          CLASS: '0c03',
          DEVICE: '0aa7',
          VENDOR: '10de',
          TYPE: 'NIC',
          NETWORK: 'vnetPci2',
          NETWORK_UID: '0',
          NETWORK_UNAME: 'oneadmin',
          RDP: 'YES',
          RDP_DISABLE_AUDIO: 'NO',
          RDP_DISABLE_BITMAP_CACHING: 'NO',
          RDP_DISABLE_GLYPH_CACHING: 'NO',
          RDP_DISABLE_OFFSCREEN_CACHING: 'NO',
          RDP_ENABLE_AUDIO_INPUT: 'NO',
          RDP_ENABLE_DESKTOP_COMPOSITION: 'NO',
          RDP_ENABLE_FONT_SMOOTHING: 'NO',
          RDP_ENABLE_FULL_WINDOW_DRAG: 'NO',
          RDP_ENABLE_MENU_ANIMATIONS: 'NO',
          RDP_ENABLE_THEMING: 'NO',
          RDP_ENABLE_WALLPAPER: 'NO',
          RDP_RESIZE_METHOD: 'display-update',
          RDP_SERVER_LAYOUT: 'ja-jp-qwerty',
          SSH: 'NO',
          GATEWAY: 'gateway2',
          GATEWAY6: 'gatewayv62',
          IP: '127.0.0.2',
          IP6: '2001:0db8:85a3:0000:0000:8a2e:0370:7335',
          IP6_METHOD: 'skip',
          MAC: '02:42:ac:11:00:03',
          METHOD: 'skip',
          NETWORK_ADDRESS: '192.168.1.1',
          NETWORK_MASK: '255.255.255.1',
          SEARCH_DOMAIN: 'domains2',
          GUEST_MTU: '100',
          INBOUND_AVG_BW: '1000',
          INBOUND_PEAK_BW: '2000',
          INBOUND_PEAK_KB: '3000',
          OUTBOUND_AVG_BW: '4000',
          OUTBOUND_PEAK_BW: '5000',
          OUTBOUND_PEAK_KB: '6000',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'network',
          sectionActions: [
            {
              type: 'update',
              nic: 0,
              networkActions: [
                {
                  step: 'advanced',
                  template: {
                    pci: {
                      type: 'PCI Passthrough - Manual',
                      shortAddress: '00:06.1',
                    },
                    rdp: false,
                    ipv4: {
                      ip: '',
                      mac: '',
                      mask: '',
                      address: '',
                      gateway: '',
                      domains: '',
                      method: '-',
                    },
                    ipv6: {
                      v6Ip: '',
                      v6Gateway: '',
                      v6Method: '-',
                    },
                    mtu: '',
                  },
                },
                {
                  step: 'network',
                },
                {
                  step: 'qos',
                  template: {
                    inbound: {
                      inboundAverage: '',
                      inboundPeak: '',
                      inboundPeakBurst: '',
                    },
                    outbound: {
                      outboundAverage: '',
                      outboundPeak: '',
                      outboundPeakBurst: '',
                    },
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
          'Create, delete and update nic pci with all data',
          'kvm',
          '248'
        ),
        PCI: {
          NETWORK: 'vnetPci2',
          NETWORK_UID: '0',
          NETWORK_UNAME: 'oneadmin',
          TYPE: 'NIC',
          RDP: 'NO',
          SSH: 'NO',
          SHORT_ADDRESS: '00:06.1',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'network',
          sectionActions: [
            {
              type: 'update',
              nic: 0,
              networkActions: [
                {
                  step: 'advanced',
                  template: {
                    pci: {
                      type: 'Emulated',
                    },
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
          'Create, delete and update nic pci with all data',
          'kvm',
          '248'
        ),
        NIC: {
          NETWORK: 'vnetPci2',
          NETWORK_UID: '0',
          NETWORK_UNAME: 'oneadmin',
          RDP: 'NO',
          SSH: 'NO',
        },
      },
    },
  ],
}

export const networkCases = [
  caseNics,
  caseNicsAlias,
  caseNicsPcis,
  caseNicsMix,
  caseNicAllData,
  caseNicAliasAllData,
  // caseNicPciAllData,
]
