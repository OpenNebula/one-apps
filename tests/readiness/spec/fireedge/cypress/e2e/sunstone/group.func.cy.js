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

import { Group, User, VmTemplate } from '@models'

import {
  groupGUIAndValidate,
  groupInfoTab,
  updateGroupGUIAndValidate,
  validateAdminGroupViews,
  validateUserViews,
  groupTabs,
  groupQuota,
  deleteAdminsGroupGUIAndValidate,
  addAdminsGroupGUIAndValidate,
  groupDelete,
  beforeAllSwitchGroupTests,
  beforeEachSwitchGroupTest,
  switchGroup,
  afterSwitchGroupTests,
  verifySwitchGroupsList,
  beforeAllSwitchViewTests,
  beforeEachSwitchViewTest,
  afterSwitchViewTests,
  verifySwitchViewsList,
  switchView,
} from '@common/groups'

import { adminContext, userContext } from '@utils/constants'

const TESTGROUP = new Group('test_create_group')

const SubTabs = ['info', 'user', 'quota', 'accounting', 'showback']

const quotaTypes = {
  datastore: {
    quotaResourceIds: [1],
    quotaIdentifiers: ['size'],
  },
  vm: {
    quotaIdentifiers: ['virtualmachines'],
  },
  network: { quotaResourceIds: [1], quotaIdentifiers: ['leases'] },
  image: { quotaResourceIds: [1], quotaIdentifiers: ['runningvms'] },
}

const testGroupTemplate = (name) => ({
  name,
  admin: {
    username: name + '-admin',
    authType: 'core',
    password: 'opennebula',
  },
  permissions: {
    create: {
      NET: true,
    },
    view: {
      VM: true,
      DOCUMENT: true,
    },
  },
  views: {
    groups: {
      defaultView: 'User view',
    },
    admin: {
      defaultView: 'Admin group view',
      views: {
        admin: true,
      },
    },
  },
  system: {
    DEFAULT_IMAGE_PERSISTENT_NEW: true,
    DEFAULT_IMAGE_PERSISTENT: true,
  },
})

const testUpdateGroupTemplate = {
  views: {
    groups: {
      defaultView: 'Admin group view',
      views: {
        admin: true,
      },
    },
    admin: {
      defaultView: 'Admin view',
    },
  },
  system: {
    DEFAULT_IMAGE_PERSISTENT_NEW: false,
    DEFAULT_IMAGE_PERSISTENT: false,
  },
}

// Admin group user info
const adminGroupUser = {
  username: 'test_create_group-admin',
  password: 'opennebula',
}

// Group user info
const groupUser = {
  username: 'test_create_group-user',
  password: 'opennebula',
}

// Resources to use in switch group tests
const infoSwitchGroupTests = {
  groups: {
    group1: {
      template: {
        name: 'group1',
      },
      group: new Group(),
    },
    group2: {
      template: {
        name: 'group2',
      },
      group: new Group(),
    },
    group3: {
      template: {
        name: 'group2',
      },
      group: new Group(),
    },
  },
  users: {
    user1: {
      template: {
        username: 'test_switch_group-user',
        password: 'opennebula',
        driver: 'core',
      },
      user: new User(),
    },
  },
  templates: {
    template1: {
      template: {
        hypervisor: 'kvm',
        name: 'template1',
        description: 'template description',
        memory: 248,
        cpu: 1,
        vcpu: 1,
      },
      item: new VmTemplate(),
    },
    template2: {
      template: {
        hypervisor: 'kvm',
        name: 'template2',
        description: 'template description',
        memory: 248,
        cpu: 1,
        vcpu: 1,
      },
      item: new VmTemplate(),
    },
    template3: {
      template: {
        hypervisor: 'kvm',
        name: 'template3',
        description: 'template description',
        memory: 248,
        cpu: 1,
        vcpu: 1,
      },
      item: new VmTemplate(),
    },
  },
}

// Resources to use in switch view tests
const infoSwitchViewTests = {
  groupView: {
    template: {
      name: 'groupViews1',
      views: ['admin', 'user'],
    },
    group: new Group(),
  },
  userView: {
    template: {
      username: 'test_switch_view-user',
      password: 'opennebula',
      driver: 'core',
    },
    user: new User(),
  },
}

describe('Sunstone GUI in Groups tab', function () {
  context('Oneadmin - Create', adminContext, function () {
    before(function () {
      cy.fixture('auth')
        .then((auth) => cy.apiAuth(auth.admin))
        .then(() =>
          cy.cleanup({
            users: {
              USERS: ['test_create_group-admin'],
            },
            groups: {
              NAMES: ['test_create_group'],
            },
          })
        )
    })

    beforeEach(function () {
      cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
        qs: { externalToken: Cypress.env('TOKEN') },
      })
    })

    it('Should create a new group via GUI and validate it', function () {
      // Attributes to validate
      const validateList = [
        {
          field: 'NAME',
          value: 'test_create_group',
        },
        {
          field: 'TEMPLATE.FIREEDGE.DEFAULT_VIEW',
          value: 'user',
        },
        {
          field: 'TEMPLATE.FIREEDGE.GROUP_ADMIN_DEFAULT_VIEW',
          value: 'groupadmin',
        },
        {
          field: 'TEMPLATE.FIREEDGE.VIEWS',
          value: 'cloud,user',
        },
        {
          field: 'TEMPLATE.FIREEDGE.GROUP_ADMIN_VIEWS',
          value: 'admin,groupadmin',
        },
        {
          field: 'TEMPLATE.OPENNEBULA.DEFAULT_IMAGE_PERSISTENT',
          value: 'YES',
        },
        {
          field: 'TEMPLATE.OPENNEBULA.DEFAULT_IMAGE_PERSISTENT_NEW',
          value: 'YES',
        },
      ]

      // Test
      groupGUIAndValidate(testGroupTemplate(TESTGROUP.name), validateList)
    })

    it('Should validate info tab after creation', function () {
      TESTGROUP.info().then(() => {
        groupInfoTab(testGroupTemplate(TESTGROUP.name), {
          id: TESTGROUP.id,
          name: 'test_create_group',
        })
      })
    })

    // eslint-disable-next-line mocha/no-setup-in-describe
    Object.entries(quotaTypes).forEach(
      ([quotaType, { quotaResourceIds, quotaIdentifiers }]) => {
        it(`Should Set group quota for ${quotaType}`, function () {
          groupQuota(TESTGROUP, {
            quotaType,
            quotaValue: 10,
            quotaResourceIds,
            quotaIdentifiers,
          })
        })
      }
    )
  })

  context(
    'Operations with the admin user of a group',
    userContext,
    function () {
      before(function () {
        cy.fixture('auth').then((auth) => {
          auth.user.username = adminGroupUser.username
          auth.user.password = adminGroupUser.password
          cy.wrapperAuth(auth)
        })
      })

      beforeEach(function () {
        cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
          qs: { externalToken: Cypress.env('TOKEN') },
        })
      })

      it('Should Check all sub-tabs', function () {
        groupTabs(TESTGROUP, SubTabs)
      })

      it('Should verify admin views', function () {
        validateAdminGroupViews(adminGroupUser, ['groupadmin', 'admin'])
      })

      it('Should verify user views', function () {
        validateUserViews(groupUser, ['user'])
      })
    }
  )

  context('Oneadmin - Modify & Delete', adminContext, function () {
    before(function () {
      cy.fixture('auth').then((auth) => cy.apiAuth(auth.admin))
    })

    beforeEach(function () {
      cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
        qs: { externalToken: Cypress.env('TOKEN') },
      })
    })

    it('Should update a group via GUI and validate it', function () {
      // Attributes to validate
      const validateList = [
        {
          field: 'TEMPLATE.FIREEDGE.DEFAULT_VIEW',
          value: 'groupadmin',
        },
        {
          field: 'TEMPLATE.FIREEDGE.GROUP_ADMIN_DEFAULT_VIEW',
          value: 'admin',
        },
        {
          field: 'TEMPLATE.FIREEDGE.VIEWS',
          value: 'cloud,user,admin,groupadmin',
        },
        {
          field: 'TEMPLATE.FIREEDGE.GROUP_ADMIN_VIEWS',
          value: 'admin,groupadmin',
        },
        {
          field: 'TEMPLATE.OPENNEBULA.DEFAULT_IMAGE_PERSISTENT',
          value: 'NO',
        },
        {
          field: 'TEMPLATE.OPENNEBULA.DEFAULT_IMAGE_PERSISTENT_NEW',
          value: 'NO',
        },
      ]

      // Test
      updateGroupGUIAndValidate(
        TESTGROUP,
        testUpdateGroupTemplate,
        validateList
      )
    })

    it('Should delete group administrators', function () {
      deleteAdminsGroupGUIAndValidate(TESTGROUP, TESTGROUP.name + '-admin')
    })

    it('Should add group administrators', function () {
      addAdminsGroupGUIAndValidate(TESTGROUP, TESTGROUP.name + '-admin')
    })

    it('Should delete group', function () {
      groupDelete(TESTGROUP, adminGroupUser, groupUser)
    })
  })

  context('Switch groups functionality', userContext, function () {
    before(function () {
      beforeAllSwitchGroupTests(infoSwitchGroupTests)
    })

    beforeEach(function () {
      beforeEachSwitchGroupTest(infoSwitchGroupTests.users.user1.template)
    })

    it('Should verify groups switch', function () {
      verifySwitchGroupsList(infoSwitchGroupTests.groups)
    })

    it('Should switch to group1', function () {
      switchGroup(
        infoSwitchGroupTests.users.user1.user,
        infoSwitchGroupTests.groups.group1.group,
        [infoSwitchGroupTests.templates.template1.item],
        [
          infoSwitchGroupTests.templates.template2.item,
          infoSwitchGroupTests.templates.template3.item,
        ]
      )
    })

    it('Should switch to group2', function () {
      switchGroup(
        infoSwitchGroupTests.users.user1.user,
        infoSwitchGroupTests.groups.group2.group,
        [infoSwitchGroupTests.templates.template2.item],
        [
          infoSwitchGroupTests.templates.template1.item,
          infoSwitchGroupTests.templates.template3.item,
        ]
      )
    })

    it('Should switch to Show all', function () {
      switchGroup(
        infoSwitchGroupTests.users.user1.user,
        undefined,
        [
          infoSwitchGroupTests.templates.template2.item,
          infoSwitchGroupTests.templates.template3.item,
        ],
        [infoSwitchGroupTests.templates.template1.item]
      )
    })

    it('Should switch to Show all owned by the user or his groups', function () {
      switchGroup(
        infoSwitchGroupTests.users.user1.user,
        undefined,
        [
          infoSwitchGroupTests.templates.template2.item,
          infoSwitchGroupTests.templates.template3.item,
        ],
        [infoSwitchGroupTests.templates.template1.item]
      )
    })

    it('Should switch to Show all owned by the user', function () {
      switchGroup(
        infoSwitchGroupTests.users.user1.user,
        undefined,
        [infoSwitchGroupTests.templates.template2.item],
        [
          infoSwitchGroupTests.templates.template1.item,
          infoSwitchGroupTests.templates.template3.item,
        ]
      )
    })

    after(function () {
      afterSwitchGroupTests(infoSwitchGroupTests)
    })
  })

  context('Switch views functionality', userContext, function () {
    before(function () {
      beforeAllSwitchViewTests(infoSwitchViewTests)
    })

    beforeEach(function () {
      beforeEachSwitchViewTest(infoSwitchViewTests.userView)
    })

    it('Should verify views switch', function () {
      verifySwitchViewsList(infoSwitchViewTests.groupView.template.views)
    })

    it('Should switch to view admin', function () {
      switchView(
        'admin',
        [
          { parent: 'system', item: 'groups' },
          { parent: 'infrastructure', item: 'hosts' },
        ],
        undefined
      )
    })

    it('Should switch to group2', function () {
      switchView(
        'user',
        [
          { parent: 'templates', item: 'VM Templates' },
          { parent: 'instances', item: 'VMs' },
        ],
        [
          { parent: 'system', item: 'groups' },
          { parent: 'infrastructure', item: 'hosts' },
        ]
      )
    })

    after(function () {
      afterSwitchViewTests(infoSwitchViewTests)
    })
  })
})
