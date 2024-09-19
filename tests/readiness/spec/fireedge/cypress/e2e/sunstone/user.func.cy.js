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
import { User, Group } from '@models'

import {
  userGUI,
  userInfo,
  userTabs,
  userGroups,
  userQuota,
  userLock,
  userUnlock,
  userDelete,
  userAuthUpdate,
} from '@common/users'

const TESTUSER = new User('test_create_user')
const GROUP = new Group(0) // oneadmin group

const testUserTemplate = (name) => ({
  username: name,
  password: 'opennebula',
  driver: 'core',
  primaryGroup: GROUP,
  secondaryGroup: GROUP,
  state: 'Yes', // Enabled
})

const SubTabs = [
  'info',
  'group',
  'quota',
  'accounting',
  'showback',
  'authentication',
]

const quotaTypes = {
  datastore: {
    quotaResourceIds: [1, 2, 3],
    quotaIdentifiers: ['size'],
  },
  vm: {
    quotaIdentifiers: ['virtualmachines'],
  },
  network: { quotaResourceIds: [1, 2, 3], quotaIdentifiers: ['leases'] },
  image: { quotaResourceIds: [1, 2, 3], quotaIdentifiers: ['runningvms'] },
}

describe('Sunstone GUI in Users tab', function () {
  before(function () {
    cy.fixture('auth')
      .then((auth) => cy.apiAuth(auth.admin))
      .then(() => cy.cleanup())
  })

  beforeEach(function () {
    cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
      qs: { externalToken: Cypress.env('TOKEN') },
    })
  })

  it('Should Create a new USER via GUI', function () {
    userGUI(testUserTemplate(TESTUSER.name))
  })

  it('Should Validate User info after creation', function () {
    TESTUSER.info().then(() => {
      userInfo(testUserTemplate(TESTUSER.name), {
        id: TESTUSER.id,
        name: 'test_create_user',
      })
    })
  })

  it('Should Update auth driver and password', function () {
    userAuthUpdate(TESTUSER, 'public', 'Pennebula')
  })

  it('Should Lock/disable user', function () {
    userLock(TESTUSER)
  })

  it('Should Unlock/enable user', function () {
    userUnlock(TESTUSER)
  })

  it('Should Verify group memberships', function () {
    userGroups(TESTUSER)
  })

  it('Should Check all sub-tabs', function () {
    userTabs(TESTUSER, SubTabs)
  })

  // eslint-disable-next-line mocha/no-setup-in-describe
  Object.entries(quotaTypes).forEach(
    ([quotaType, { quotaResourceIds, quotaIdentifiers }]) => {
      it(`Should Set user quota for ${quotaType}`, function () {
        userQuota(TESTUSER, {
          quotaType,
          quotaValue: [10],
          quotaResourceIds: quotaResourceIds,
          quotaIdentifiers,
        })
      })
    }
  )

  it('Should Delete user', function () {
    userDelete(TESTUSER)
  })
})
