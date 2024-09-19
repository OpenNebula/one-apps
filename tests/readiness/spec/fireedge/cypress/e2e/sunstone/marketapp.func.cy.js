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
import { adminContext, userContext } from '@utils/constants'

import {
  beforeAllMarketappTest,
  beforeEachMarketappTest,
  deleteMarketapp,
  disableMarketapp,
  downloadMarketapp,
  enableMarketapp,
  lockMarketapp,
  unlockMarketapp,
  verifyImageDatastoresToExport,
} from '@common/apps'
import { Image, MarketplaceApp } from '@models'

const MARKETPLACE_APP = new MarketplaceApp('Ttylinux - KVM')

const setApps = (user = '') => {
  const userName = user ? `_${user}` : ''

  return {
    ownership: {
      image: new Image(`image-ownership${userName}`),
      app: new MarketplaceApp(`marketapp-ownership${userName}`),
    },
    delete: {
      image: new Image(`image-delete${userName}`),
      app: new MarketplaceApp(`marketapp-delete${userName}`),
    },
  }
}

const MARKETAPPS_ADMIN = setApps('admin')
const MARKETAPPS_USER = setApps('user')

describe('Sunstone GUI in Marketapp tab', function () {
  context('User', userContext, function () {
    before(function () {
      cy.fixture('auth')
        .then((auth) => cy.apiAuth(auth.admin))
        .then(() => MARKETPLACE_APP.info())
        .then(() => beforeAllMarketappTest(MARKETAPPS_USER, true))
    })

    beforeEach(function () {
      cy.fixture('auth')
        .then((auth) => cy.apiAuth(auth.user))
        .then(() => beforeEachMarketappTest())
    })

    it('Should delete Marketapp', function () {
      deleteMarketapp(MARKETAPPS_USER.delete.app)
    })

    it('Download marketapp', function () {
      downloadMarketapp(MARKETPLACE_APP)
    })

    // Verify that all datastores to export an app are image datastores
    it('Verify that all datastores to export an app are image datastores', function () {
      verifyImageDatastoresToExport(MARKETPLACE_APP)
    })
  })

  context('Admin', adminContext, function () {
    before(function () {
      cy.fixture('auth')
        .then((auth) => cy.apiAuth(auth.admin))
        .then(() => MARKETPLACE_APP.info())
        .then(() => beforeAllMarketappTest(MARKETAPPS_ADMIN))
    })

    beforeEach(function () {
      beforeEachMarketappTest()
    })

    it('Should lock marketapp', function () {
      lockMarketapp(MARKETPLACE_APP)
    })

    it('Should unlock marketapp', function () {
      unlockMarketapp(MARKETPLACE_APP)
    })

    it('Should disable marketapp', function () {
      disableMarketapp(MARKETPLACE_APP)
    })

    it('Should enable marketapp', function () {
      enableMarketapp(MARKETPLACE_APP)
    })

    it('Should delete Marketapp', function () {
      deleteMarketapp(MARKETAPPS_ADMIN.delete.app)
    })

    it('Download marketapp', function () {
      downloadMarketapp(MARKETPLACE_APP)
    })

    // Verify that all datastores to export an app are image datastores
    it('Verify that all datastores to export an app are image datastores', function () {
      verifyImageDatastoresToExport(MARKETPLACE_APP)
    })
  })
})
