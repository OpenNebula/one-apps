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
import {
  checkSunstoneHeaderHasUsername,
  goFromSunstoneToOneProvision,
  loginBySingleSignOnMethod,
  loginWith2FA,
  multipleLoginWithTheSameUser,
} from '@support/common/dashboard'
import { adminContext, userContext } from '@utils/constants'

describe('Sunstone GUI in dashboard tab', function () {
  beforeEach(function () {
    cy.fixture('auth').then((auth) => {
      cy.wrapperAuth(auth)
      this.auth = auth
    })
  })

  it('Should login with 2FA', function () {
    cy.fixture('auth')
      .then((auth) => cy.apiAuth(auth.admin, auth.tfa))
      .then(() => {
        loginWith2FA(this.auth.tfa)
      })
  })

  context('User', userContext, function () {
    it(
      'Should go from Sunstone to OneProvision and come back',
      goFromSunstoneToOneProvision
    )

    it('Should login by Single-Sign-On method', function () {
      loginBySingleSignOnMethod(this.auth)
    })

    it('Should perform multiple logins with the same user', function () {
      multipleLoginWithTheSameUser(this.auth)
    })

    it('Should check Sunstone header has username', function () {
      checkSunstoneHeaderHasUsername(this.auth)
    })
  })

  context('Oneadmin', adminContext, function () {
    it(
      'Should go from Sunstone to OneProvision and come back',
      goFromSunstoneToOneProvision
    )

    it('Should login by Single-Sign-On method', function () {
      loginBySingleSignOnMethod(this.auth)
    })

    it('Should perform multiple logins with the same user', function () {
      multipleLoginWithTheSameUser(this.auth)
    })

    it('Should check Sunstone header has username', function () {
      checkSunstoneHeaderHasUsername(this.auth)
    })
  })
})
