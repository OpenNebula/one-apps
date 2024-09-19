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
import { createIntercept, Intercepts } from '@support/utils/index'

/** @type {User} */
let ONEADMIN_USER = null
const USER_NOT_ONEADMIN = new User('im_not_oneadmin', 'opennebula')
const USER_IN_ONEADMIN_GROUP = new User('im_in_oneadmin_group', 'opennebula')
const ONEADMIN_GROUP = new Group('oneadmin')
const USERS_GROUP = new Group('users')

describe('Fireedge GUI in dashboard tab', function () {
  before(function () {
    cy.fixture('auth')
      .then((auth) => cy.apiAuth(auth.admin))
      .then(() => ONEADMIN_GROUP.info())
      .then(() => USERS_GROUP.info())
      .then(() => USER_NOT_ONEADMIN.allocate())
      .then(() =>
        USER_IN_ONEADMIN_GROUP.allocate({
          group: [ONEADMIN_GROUP.id, USERS_GROUP.id],
        })
      )
  })

  beforeEach(function () {
    cy.fixture('auth').then((auth) => {
      this.auth = auth
    })
  })

  it('should throw the user out when do not belong to the oneadmin group', function () {
    const { jwtName } = this.auth

    cy.login(USER_NOT_ONEADMIN.credentials, '/provision')
    cy.getBySel('login-user-error').should('exist')
    cy.window().its(`localStorage.${jwtName}`).should('not.exist')
  })

  it('should login by oneadmin’s group user', function () {
    const { jwtName } = this.auth

    cy.login(USER_IN_ONEADMIN_GROUP.credentials, '/provision')
    cy.getBySel('login-user-error').should('not.exist')
    cy.getBySel('login-group').should('not.exist')
    cy.window().its(`localStorage.${jwtName}`).should('exist')

    cy.logout()
  })

  it('check widgets after login', function () {
    const { username, password } = this.auth.admin
    ONEADMIN_USER ||= new User(username, password)

    const getClusters = createIntercept(Intercepts.PROVISION.CLUSTER_LIST)
    const getHosts = createIntercept(Intercepts.PROVISION.HOST_LIST)
    const getDatastores = createIntercept(Intercepts.PROVISION.DATASTORE_LIST)
    const getNetworks = createIntercept(Intercepts.PROVISION.NETWORK_LIST)

    cy.login(ONEADMIN_USER.credentials, '/provision')

    cy.wait([getClusters, getHosts, getDatastores, getNetworks])

    cy.getBySel('widget-total-cluster').should('be.visible')
    cy.getBySel('widget-total-host').should('be.visible')
    cy.getBySel('widget-total-datastore').should('be.visible')
    cy.getBySel('widget-total-network').should('be.visible')

    cy.getBySel('dashboard-widget-total-providers-by-type').should('be.visible')
    cy.getBySel('dashboard-widget-provisions-by-states').should('be.visible')
  })

  it('check JWT in session storage', function () {
    const { jwtName } = this.auth

    cy.login(ONEADMIN_USER.credentials, '/provision')
    cy.window().its(`localStorage.${jwtName}`).should('exist')
  })

  it('has username on header', function () {
    const { username } = this.auth.admin

    cy.login(ONEADMIN_USER.credentials, '/provision')
    cy.get('[data-cy=header-user-button]').should('have.text', username)
  })
})
