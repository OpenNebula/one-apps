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
import { VmGroup, Host, VmTemplate } from '@models'

import {
  vmgroupGUI,
  vmgroupLock,
  vmgroupUnlock,
  vmgroupPermissions,
  vmgroupUpdate,
  vmgroupMonitoring,
  vmgroupDelete,
} from '@common/vmgroups'

const TEST_HOST = new Host('0')
const TEST_VMTEMPLATE = new VmTemplate()
const TESTVMGROUP = new VmGroup('TEST_VMGROUP')
let VMID = ''

const TEMPLATE_XML = (VMGROUP_ID = 0) => ({
  NAME: 'test_template',
  PERSISTENT: false,
  MEMORY: 248,
  CPU: 1,
  VCPU: 1,
  CONTEXT: { NETWORK: true },
  VMGROUP: { VMGROUP_ID: VMGROUP_ID, ROLE: 'TESTVMROLE' },
})

const ALLOCATE_HOST_PARAMS = {
  hostname: 'localhost',
  imMad: 'dummy',
  vmmMad: 'dummy',
}

const VMGROUP_TEMPLATE = {
  NAME: 'TEST_VMGROUP',
  DESCRIPTION: 'VMGROUP GENERATED FOR TESTING',
  ROLE: [{ NAME: 'TESTVMROLE', POLICY: 'None' }],
}

const VMGROUP_ROLE_GROUPS = {
  ROLE: {
    AFFINED: ['affinedRole1,affinedRole2'],
    ANTI_AFFINED: [
      'antiAffinedRole1,antiAffinedRole2,noneRole1',
      'antiAffinedRole2,noneRole1',
      'antiAffinedRole1,antiAffinedRole2',
      'antiAffinedRole1,noneRole1',
    ],
  },
}

const NEW_PERMISSIONS = {
  ownerUse: '1',
  ownerManage: '1',
  groupUse: '1',
  groupManage: '1',
  otherUse: '1',
  otherManage: '1',
}

const NEW_TEMPLATE = {
  DESCRIPTION: 'UPDATED_VMGROUP',
  ROLE: [
    {
      NAME: 'affinedRole1',
      POLICY: 'AFFINED',
    },
    {
      NAME: 'affinedRole2',
      POLICY: 'AFFINED',
    },
    {
      NAME: 'antiAffinedRole1',
      POLICY: 'ANTI_AFFINED',
    },
    {
      NAME: 'antiAffinedRole2',
      POLICY: 'ANTI_AFFINED',
    },
    {
      NAME: 'noneRole1',
      POLICY: 'None',
    },
  ],
}

describe('Sunstone GUI in VmGroups tab', function () {
  before(function () {
    cy.fixture('auth')
      .then((auth) => cy.apiAuth(auth.admin))
      .then(() => cy.cleanup())
      .then(() => TESTVMGROUP.allocate(VMGROUP_TEMPLATE))
      .then(() => TEST_VMTEMPLATE.allocate(TEMPLATE_XML(TESTVMGROUP.json.ID)))
      .then(() => TEST_HOST.allocate(ALLOCATE_HOST_PARAMS))
      .then(() => {
        TEST_VMTEMPLATE.instantiate({
          name: 'TEST_VM',
          template: TEMPLATE_XML(TESTVMGROUP.json.ID),
        }).then((VmID) => (VMID = VmID))
      })
  })

  beforeEach(function () {
    cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
      qs: { externalToken: Cypress.env('TOKEN') },
    })
  })

  it('Should check VM monitoring', function () {
    vmgroupMonitoring(TESTVMGROUP, 'TEST_VM')
    cy.apiRecoverDeleteVm(VMID)
  })

  it('Should update VM group', function () {
    vmgroupUpdate({
      VmGrp: TESTVMGROUP,
      TEMPLATE: { DEFINITIONS: NEW_TEMPLATE, GROUPS: VMGROUP_ROLE_GROUPS },
      DISABLED_NAME: true,
    })
  })

  it('Should lock VM group', function () {
    vmgroupLock(TESTVMGROUP)
  })

  it('Should unlock VM group', function () {
    vmgroupUnlock(TESTVMGROUP)
  })

  it('Should change VM group permissions', function () {
    vmgroupPermissions({
      VmGrp: TESTVMGROUP,
      NEW_PERMISSIONS: NEW_PERMISSIONS,
    })
  })

  it('Should delete a VM group', function () {
    vmgroupDelete(TESTVMGROUP)
  })

  it('Should Create a new VM group (GUI)', function () {
    vmgroupGUI({
      DEFINITIONS: { ...VMGROUP_TEMPLATE, ...NEW_TEMPLATE },
      GROUPS: VMGROUP_ROLE_GROUPS,
    })
  })

  it('Should cleanup allocated resources...', function () {
    cy.cleanup()
  })
})
