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
import { VNetTemplate } from '@models'

import {
  beforeEachVNTemplateTest,
  changePermissionsVnTemplateGUI,
  createVNTemplate,
  deleteResources,
  deleteVNTemplateAndValidate,
  lockVNTemplate,
  renameVNTemplate,
  unlockVNTemplate,
  updateVNTemplate,
} from '@common/vnTemplate'

const VN_TEMPLATE_GUI = (customValues = {}) => ({
  description: 'VN_TEMPLATE GENERATED FOR TESTING UPDATED',
  vnMad: 'bridge',
  bridge: 'br0',
  phydev: 'eth0',
  clusters: { id: '0', name: 'default' },
  context: { dns: '8.8.8.8', gateway: '1.1.1.1' },
  ...customValues,
})

const VN_TEMPLATE = (name = 'TEST_VN_TEMPLATE') => ({
  NAME: name,
  VN_MAD: 'BRIDGE',
  DESCRIPTION: 'VN_TEMPLATE GENERATED FOR TESTING',
})

const VN_TEMPLATE_NAMES = {
  testLock: 'TEST_LOCK',
  testPermissions: 'TEST_PERMISSIONS',
  testRename: 'TEST_RENAME',
  testDelete: 'TEST_DELETE',
  testUpdate: 'TEST_UPDATE',
  testCreate: 'TEST_CREATE_GUI',
}

const VN_TEMPLATES = {
  testLock: new VNetTemplate(VN_TEMPLATE_NAMES.testLock),
  testPermissions: new VNetTemplate(VN_TEMPLATE_NAMES.testPermissions),
  testRename: new VNetTemplate(VN_TEMPLATE_NAMES.testRename),
  testDelete: new VNetTemplate(VN_TEMPLATE_NAMES.testRename),
  testUpdate: new VNetTemplate(VN_TEMPLATE_NAMES.testUpdate),
}

const NEW_PERMISSIONS = {
  ownerUse: '1',
  ownerManage: '1',
  groupUse: '1',
  groupManage: '1',
  otherUse: '1',
  otherManage: '1',
}

describe('Sunstone GUI in Virtual Network Template tab', function () {
  before(function () {
    cy.fixture('auth')
      .then((auth) => cy.apiAuth(auth.admin))
      .then(() => cy.cleanup())
      .then(() => {
        Object.entries(VN_TEMPLATES).forEach(([key, vnTemplate]) => {
          vnTemplate.allocate(VN_TEMPLATE(VN_TEMPLATE_NAMES[key]))
        })
      })
  })

  beforeEach(beforeEachVNTemplateTest)

  after(function () {
    deleteResources(VN_TEMPLATES)
  })

  it('should RENAME virtual network template', function () {
    const newName = VN_TEMPLATES.testRename.name.replace(
      'rename_',
      'rename_update_'
    )
    renameVNTemplate(VN_TEMPLATES.testRename, newName)
  })

  it('should LOCK virtual network template', function () {
    lockVNTemplate(VN_TEMPLATES.testLock)
  })

  it('should UNLOCK virtual network template', function () {
    unlockVNTemplate(VN_TEMPLATES.testLock)
  })

  it('should DELETE a virtual network template', function () {
    deleteVNTemplateAndValidate(VN_TEMPLATES.testRename)
  })

  it('Should CHANGE PERMISSIONS virtual network template', function () {
    changePermissionsVnTemplateGUI({
      VN_TEMPLATE: VN_TEMPLATES.testPermissions,
      NEW_PERMISSIONS,
    })
  })

  it('Should UPDATE virtual network template', function () {
    updateVNTemplate({
      VN_TEMPLATE: VN_TEMPLATES.testUpdate,
      TEMPLATE: VN_TEMPLATE_GUI(),
    })
  })

  it('Should CREATE a virtual network template (GUI)', function () {
    createVNTemplate(
      VN_TEMPLATE_GUI({
        name: VN_TEMPLATE_NAMES.testCreate,
        description: 'VN_TEMPLATE GENERATED FOR TESTING UPDATED GUI',
      })
    )
  })
})
