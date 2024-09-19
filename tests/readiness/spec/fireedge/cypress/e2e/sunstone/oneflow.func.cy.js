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
import { VmTemplate, Service, ServiceTemplate, User, VNet, Host } from '@models'

import {
  servicetemplateGUI,
  servicetemplateUpdate,
  servicetemplateDelete,
  servicetemplatePermissions,
  servicetemplateRename,
  servicetemplateChown,
  servicetemplateInstantiate,
} from '@common/serviceTemplate'

import {
  serviceinstanceValidate,
  serviceinstancePermissions,
  serviceRename,
  serviceAddRole,
  serviceDelete,
  servicePerformActionRole,
} from '@common/service'

import { randomDate } from '@commands/helpers'

const date1 = randomDate()

const TEST_VMTEMPLATE = new VmTemplate('TEMP_VmTemplate')
const TESTSERVICETEMPLATE = new ServiceTemplate('TestServiceTemplate')
const TESTSERVICE = new Service()
const TESTVNET = new VNet('TestVNetTemplate')
const TESTHOST = new Host('localhost')
const DUMMY_MAD = { imMad: 'dummy', vmmMad: 'dummy' }
const HOST_PARAMS = { hostname: TESTHOST.name, ...DUMMY_MAD }
const NEWOWNER = new User('NewServiceTemplateOwner', 'opennebula')

const VNET_TEMPLATE = (VNET_TEMPLATE_NAME, CLUSTER_ID) => ({
  template: {
    NAME: VNET_TEMPLATE_NAME,
    VN_MAD: 'bridge',
    CLUSTER_IDS: CLUSTER_ID,
    AR: [
      {
        IP: '10.0.0.1',
        SIZE: '100',
        TYPE: 'IP4',
      },
    ],
  },
})

const VM_TEMPLATE_JSON = () => ({
  NAME: 'TEMP_VmTemplate',
  CPU: 1,
  MEMORY: 24,
})

const SERVICE_TEMPLATE_JSON = (VM_TEMPLATE_ID) => ({
  name: 'ServiceTemplateTesting',
  description: 'TestingTemplate',
  roles: [
    {
      cardinality: 2,
      name: 'role1',
      vm_template: +VM_TEMPLATE_ID,
      min_vms: 1,
      max_vms: 5,
      cooldown: 3,
      elasticity_policies: [
        {
          cooldown: 5,
          period: 5,
          period_number: 5,
          expression: 'A=2',
          adjust: +'2',
          type: 'CHANGE',
        },
      ],
    },
  ],
  deployment: 'straight',
  ready_status_gate: false,
  automatic_deletion: false,
})

const NEW_ROLE = (VM_TEMPLATE_ID) => ({
  General: {
    name: 'AddedNewRole',
    cardinality: 1,
  },
  Extra: {
    vmTemplateId: +VM_TEMPLATE_ID,
  },
  Elasticity: {
    minVms: 1,
    maxVms: 3,
    cooldown: 5,
  },
})

const SERVICE_TEMPLATE_GUI = (VM_TEMPLATE_ID) => ({
  General: {
    name: 'GUI_ServiceTemplateTest',
    description: 'GUI Service Template test description',
  },
  Extra: {
    Networks: [
      {
        type: 'Create',
        name: 'TestNetwork1',
        description: 'TestNetwork1Description',
        network: undefined,
        extra: 'TestNetwork1Extra',
      },
      {
        type: 'Create',
        name: 'TestNetwork2',
        description: 'TestNetwork2Description',
        network: undefined,
        extra: 'TestNetwork2Extra',
      },
    ],
    UserInputs: [
      {
        type: 'text',
        name: 'UserTextInput1',
        description: 'UserTextDescription1',
        defaultValue: 'UserTextDefaultValue1',
        mandatory: true,
      },
      {
        type: 'boolean',
        name: 'UserBooleanInput2',
        description: 'UserBooleanInput2',
        defaultValue: 'YES',
        mandatory: true,
      },
      {
        type: 'range',
        name: 'UserRangeInput3',
        description: 'UserRangeInput3',
        defaultValue: 3,
        mandatory: true,
        range: {
          minRange: 0,
          maxRange: 10,
        },
      },
    ],
    ScheduledActions: [
      {
        action: 'hold',
        time: date1,
        periodic: 'ONETIME',
      },
    ],
  },
  RoleDefinitions: [
    {
      name: 'Role1',
      cardinality: 1,
      vmtemplateid: VM_TEMPLATE_ID,
    },
    {
      name: 'Role2',
      cardinality: 1,
      vmtemplateid: VM_TEMPLATE_ID,
    },
  ],
  RoleConfiguration: [
    {
      roleNetwork: {
        networkIndex: 0,
        aliasToggle: false,
        aliasOption: undefined,
      },
      roleElasticity: {
        minVms: 1,
        maxVms: 4,
        cooldown: 0,
        elasticityPolicies: [
          {
            type: 'Change',
            adjust: 3,
            expression: 'A=2',
            period: 5,
            periodNumber: 3,
            policyCooldown: 10,
          },
        ],
        scheduledPolicies: [
          {
            type: 'Change',
            adjust: 3,
            min: 1,
            timeFormat: 'Recurrence',
            // CRON expression
            timeExpression: '0 0 12 * *',
          },
          {
            type: 'Change',
            adjust: 5,
            min: 1,
            timeFormat: 'Start time',
            timeExpression: '2024-07-24',
          },
        ],
      },
    },
    {
      roleNetwork: {
        networkIndex: 1,
        aliasToggle: true,
        aliasOption: 0,
      },
      roleElasticity: {
        minVms: 1,
        maxVms: 4,
        cooldown: 0,
      },
    },
  ],
})

const SERVICE_TEMPLATE_INSTANTIATE_GUI = (VNET_TEMPLATE_ID) => ({
  General: {
    name: 'TestInstantiateServiceTemplate',
    instances: 1,
  },

  UserInputs: [
    {
      type: 'text',
      name: 'UserTextInput1',
      value: 'TextValue1',
    },
    {
      type: 'boolean',
      name: 'UserBooleanInput2',
    },
    {
      type: 'range',
      name: 'UserRangeInput3',
      value: '123',
    },
  ],

  Networks: [
    {
      type: 'Existing',
      name: 'TestNetwork1',
      nId: VNET_TEMPLATE_ID,
      extra: '',
    },
    {
      type: 'Existing',
      name: 'TestNetwork2',
      nId: VNET_TEMPLATE_ID,
      extra: '',
    },
  ],
})

const NEW_PERMISSIONS = {
  ownerUse: '1',
  ownerManage: '1',
  groupUse: '1',
  groupManage: '1',
  otherUse: '1',
  otherManage: '1',
}

describe('Sunstone GUI in Service Templates tab', function () {
  before(function () {
    cy.fixture('auth')
      .then((auth) => cy.apiAuth(auth.admin))
      .then(() => cy.cleanup())
      .then(() => TEST_VMTEMPLATE.allocate(VM_TEMPLATE_JSON()))
      .then(() =>
        TESTSERVICETEMPLATE.allocate(SERVICE_TEMPLATE_JSON(TEST_VMTEMPLATE.id))
      )
      .then(() => NEWOWNER.allocate())
      .then(() => TESTHOST.allocate(HOST_PARAMS))
      .then(() => !TESTHOST.isMonitored && TESTHOST.enable())
      .then(
        () => TESTVNET.allocate(VNET_TEMPLATE('TestVNet', 0)) // Use default cluster
      )
  })

  beforeEach(function () {
    cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
      qs: { externalToken: Cypress.env('TOKEN') },
    })
  })

  it('Should change owner Service Template', function () {
    servicetemplateChown(TESTSERVICETEMPLATE, NEWOWNER)
  })

  it('Should change permissions Service Template', function () {
    servicetemplatePermissions({
      ServiceTemplate: TESTSERVICETEMPLATE,
      NEW_PERMISSIONS: NEW_PERMISSIONS,
    })
  })

  it('Should rename Service Template', function () {
    servicetemplateRename(TESTSERVICETEMPLATE, 'RenamedServiceTemplateTest')
  })

  it('Should update Service Template', function () {
    servicetemplateUpdate({
      existingId: TESTSERVICETEMPLATE.id,
      template: SERVICE_TEMPLATE_GUI(TEST_VMTEMPLATE.id),
    })
  })

  it('Should instantiate Service Template', function () {
    servicetemplateInstantiate({
      existingId: TESTSERVICETEMPLATE.id,
      template: SERVICE_TEMPLATE_INSTANTIATE_GUI(TESTVNET.id),
    }).then((id) => {
      TESTSERVICE.id = id
    })
  })

  it('Should delete Service Template', function () {
    servicetemplateDelete(TESTSERVICETEMPLATE)
  })

  it('Should create a Service Template  (GUI)', function () {
    servicetemplateGUI(SERVICE_TEMPLATE_GUI(TEST_VMTEMPLATE.id))
  })

  it('Should verify that service is running ', function () {
    serviceinstanceValidate(TESTSERVICE)
  })

  it('Should change service permissions', function () {
    serviceinstancePermissions({
      ServiceInstance: TESTSERVICE,
      NEW_PERMISSIONS: NEW_PERMISSIONS,
    })
  })

  it('Should rename a service', function () {
    serviceRename(TESTSERVICE, 'RenamedServiceInstanceTest')
  })

  it('Should add a role to a service', function () {
    serviceAddRole(TESTSERVICE, NEW_ROLE(TEST_VMTEMPLATE.id))
  })

  it('Should perform an action on a role', function () {
    servicePerformActionRole(TESTSERVICE, 'poweroff', 'role1')
  })

  it('Should delete a service', function () {
    serviceDelete(TESTSERVICE)
  })

  it('Should cleanup allocated resources...', function () {
    cy.cleanup()
  })
})
