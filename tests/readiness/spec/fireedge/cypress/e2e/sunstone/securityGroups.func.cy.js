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
import { SecurityGroup } from '@models'
import { PermissionsGui } from '@support/commands/common'

import { adminContext, userContext } from '@utils/constants'

import {
  afterAllSecGroupsTest,
  beforeAllSecGroupTest,
  beforeEachSecGroupTest,
  changeOwnershipGUI,
  changePermissionsSecGroupGUI,
  cloneSecGroupGUI,
  commitSecGroupGUI,
  createSecGroupGUI,
  deleteSecGroupGUI,
  renameSecGroupGUI,
  updateSecGroupGUI,
} from '@common/secGroups'

const BASIC_SECGROUP_XML = {
  NAME: 'CONTEXT',
  DESCRIPTION: 'File for tests',
  RULE: [
    { PROTOCOL: 'ALL', RULE_TYPE: 'inbound' },
    { PROTOCOL: 'UDP', RULE_TYPE: 'outbound' },
  ],
}

/** @type {PermissionsGui} */
const NEW_PERMISSIONS = {
  ownerUse: '1',
  ownerManage: '1',
  groupUse: '1',
  groupManage: '1',
  otherUse: '1',
  otherManage: '1',
}

const SECGROUP_TEMPLATE_GUI = {
  RULE: [
    {
      RULE_TYPE: 'Outbound',
      PROTOCOL: {
        value: 'TCP',
      },
      RANGE_TYPE: {
        value: 'Port Range',
        RANGE: 3001,
      },
      TARGET: {
        value: 'Manual Network',
        IP: '127.0.0.1',
        SIZE: 255,
      },
    },
  ],
}

const secGroups = (user = '') => {
  const userName = user ? `_${user}` : ''

  return {
    changePermission: new SecurityGroup(`sec_changePermission${userName}`),
    update: new SecurityGroup(`sec_update${userName}`),
    clone: new SecurityGroup(`sec_clone${userName}`),
    commit: new SecurityGroup(`sec_commit${userName}`),
    delete: new SecurityGroup(`sec_delete${userName}`),
    ownership: new SecurityGroup(`sec_ownership${userName}`),
    rename: new SecurityGroup(`sec_rename${userName}`),
  }
}

const secGroupsGUI = (user = '') => {
  const userName = user ? `_${user}` : ''

  return {
    CREATE_GUI: `created_via_GUI${userName}`,
    CLONE: `clone_security_group${userName}`,
  }
}

const SECGROUPS_USER = secGroups('user')
const SECGROUPS_ADMIN = secGroups('admin')
const SECGROUPS_GUI_USER = secGroupsGUI('user')
const SECGROUPS_GUI_ADMIN = secGroupsGUI('admin')

describe('Sunstone GUI in Security Groups tab', function () {
  context('User', userContext, function () {
    before(function () {
      beforeAllSecGroupTest({
        SECGROUPS: SECGROUPS_USER,
        BASIC_SECGROUP_XML,
      })
    })

    beforeEach(function () {
      cy.fixture('auth')
        .then((auth) => cy.apiAuth(auth.user))
        .then(() => beforeEachSecGroupTest())
    })

    it('Create Security Group GUI as USER', function () {
      createSecGroupGUI({
        SECGROUP_TEMPLATE_GUI,
        SECGROUPS_GUI: SECGROUPS_GUI_USER,
      })
    })
    it('Update Security Group GUI as USER', function () {
      updateSecGroupGUI({
        SECGROUP_TEMPLATE_GUI,
        SECGROUPS_GUI: SECGROUPS_GUI_USER,
        SECGROUPS: SECGROUPS_USER,
      })
    })
    it('should COMMIT Security Group as USER', function () {
      commitSecGroupGUI(SECGROUPS_USER)
    })
    it('should CLONE Security Group as USER', function () {
      cloneSecGroupGUI({
        SECGROUPS: SECGROUPS_USER,
        SECGROUPS_GUI: SECGROUPS_GUI_USER,
      })
    })
    it('Should DELETE Security Group as USER', function () {
      deleteSecGroupGUI(SECGROUPS_USER)
    })
    it('Should CHANGE PERMISSIONS Security Group as USER', function () {
      changePermissionsSecGroupGUI({
        SECGROUPS: SECGROUPS_USER,
        NEW_PERMISSIONS,
      })
    })
    it('Should RENAME Security Group as USER', function () {
      renameSecGroupGUI(SECGROUPS_USER)
    })
    after(function () {
      afterAllSecGroupsTest({
        SECGROUPS: SECGROUPS_USER,
        SECGROUPS_GUI: SECGROUPS_GUI_USER,
      })
    })
  })

  context('Oneadmin', adminContext, function () {
    before(function () {
      beforeAllSecGroupTest({
        SECGROUPS: SECGROUPS_ADMIN,
        BASIC_SECGROUP_XML,
      })
    })

    beforeEach(beforeEachSecGroupTest)

    it('Create Security Group GUI as ADMIN', function () {
      createSecGroupGUI({
        SECGROUP_TEMPLATE_GUI,
        SECGROUPS_GUI: SECGROUPS_GUI_ADMIN,
      })
    })
    it('Update Security Group GUI as ADMIN', function () {
      updateSecGroupGUI({
        SECGROUP_TEMPLATE_GUI,
        SECGROUPS_GUI: SECGROUPS_GUI_ADMIN,
        SECGROUPS: SECGROUPS_ADMIN,
      })
    })
    it('should COMMIT Security Group as ADMIN', function () {
      commitSecGroupGUI(SECGROUPS_ADMIN)
    })
    it('should CLONE Security Group as ADMIN', function () {
      cloneSecGroupGUI({
        SECGROUPS: SECGROUPS_ADMIN,
        SECGROUPS_GUI: SECGROUPS_GUI_ADMIN,
      })
    })
    it('Should DELETE Security Group as ADMIN', function () {
      deleteSecGroupGUI(SECGROUPS_ADMIN)
    })
    it('Should CHANGE PERMISSIONS Security Group as ADMIN', function () {
      changePermissionsSecGroupGUI({
        SECGROUPS: SECGROUPS_ADMIN,
        NEW_PERMISSIONS,
      })
    })
    it('Should RENAME Security Group as ADMIN', function () {
      renameSecGroupGUI(SECGROUPS_ADMIN)
    })
    it('Should CHANGE-OWNERSHIP (user & group) Security Group as ADMIN', function () {
      changeOwnershipGUI(SECGROUPS_ADMIN)
    })

    after(function () {
      afterAllSecGroupsTest({
        SECGROUPS: SECGROUPS_ADMIN,
        SECGROUPS_GUI: SECGROUPS_GUI_ADMIN,
      })
    })
  })
})
