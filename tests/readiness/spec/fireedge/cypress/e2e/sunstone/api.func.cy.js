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
import { Datastore, Host, Image, User, VNet } from '@models'

describe('FireEdge API', function () {
  before(function () {
    cy.fixture('auth').then((auth) => cy.apiAuth(auth.admin))
  })

  it('Authentication by defaults credentials', function () {
    // eslint-disable-next-line no-unused-expressions
    expect(Cypress.env('TOKEN')).to.exist
  })

  it('sunstone-server.conf as ENV variable', function () {
    cy.apiSunstoneConf().then(() => {
      expect(Cypress.env('SUNSTONE_CONF')).to.have.property('currency')
    })
  })

  it('Host manipulation', function () {
    const host = new Host()

    host
      .allocate({ hostname: '9.9.9.9', imMad: 'dummy', vmmMad: 'dummy' })
      .then(() => host.disable())
      .then(() => host.waitDisabled())
      .then(() => host.enable())
      .then(() => host.waitMonitored())
      .then(() => host.delete())
      .then((response) => {
        expect(response.body).to.have.property('id', 200)
        expect(response.body).to.have.property('data', +host.id)
      })
  })

  it('Virtual Network manipulation', function () {
    const vnet = new VNet()

    const VNET_TEMPLATE = {
      NAME: 'api-testing-vnet',
      VN_MAD: 'dummy',
      BRIDGE: 'br0',
      AR: [{ TYPE: 'IP4', IP: '10.0.0.10', SIZE: '100' }],
    }

    vnet
      .allocate({ template: VNET_TEMPLATE })
      .then(() => {
        const [{ TYPE, IP, SIZE }] = VNET_TEMPLATE.AR

        expect(vnet.json).to.have.property('NAME', VNET_TEMPLATE.NAME)
        expect(vnet.json).to.have.property('BRIDGE', VNET_TEMPLATE.BRIDGE)
        expect(vnet.json).to.have.property('VN_MAD', VNET_TEMPLATE.VN_MAD)
        expect(vnet.json).to.have.nested.property('AR_POOL.AR.TYPE', TYPE)
        expect(vnet.json).to.have.nested.property('AR_POOL.AR.IP', IP)
        expect(vnet.json).to.have.nested.property('AR_POOL.AR.SIZE', SIZE)
      })
      .then(() => vnet.waitReady())
      .then(() => vnet.delete())
      .then(() => vnet.waitDone())
  })

  it('Datastore manipulation', function () {
    const datastore = new Datastore('default')

    datastore.info().then(() => {
      expect(datastore.name).to.equal('default')
      expect(datastore.type).to.equal('IMAGE')
      // eslint-disable-next-line no-unused-expressions
      expect(datastore.isReady).to.be.true
    })
  })

  it('Image manipulation', function () {
    const img = new Image()
    const datastore = new Datastore('default')

    const IMAGE_TEMPLATE = {
      NAME: 'api-testing-image',
      SIZE: '5',
      TYPE: 'DATABLOCK',
    }

    datastore
      .info()
      .then(() =>
        img.allocate({ template: IMAGE_TEMPLATE, datastore: datastore.id })
      )
      .then(() => {
        expect(img.name).to.equal(IMAGE_TEMPLATE.NAME)
        expect(img.type).to.equal(IMAGE_TEMPLATE.TYPE)
        expect(img.json).to.have.property('DATASTORE_ID', datastore.id)
        expect(img.json).to.have.property('SIZE', IMAGE_TEMPLATE.SIZE)
      })
      .then(() => img.isReady)
      .then(() => img.delete())
      .then((response) => {
        expect(response.body).to.have.property('id', 200)
        expect(response.body).to.have.property('data', +img.id)
      })
  })

  it('User (not oneadmin) manipulation', function () {
    const user = new User()
    const data = { username: 'user1', password: 'user1', group: ['0', '1'] }

    user
      .allocate(data)
      .then(() => {
        expect(user.name).to.equal(data.username)
        expect(user.driver).to.equal('core') // driver core is the default
        expect(user.json.GROUPS.ID).to.include.members(data.group)
      })
      .then(() => user.delete())
      .then((response) => {
        expect(response.body).to.have.property('id', 200)
        expect(response.body).to.have.property('data', +user.id)
      })
  })

  it('User 2fa manipulation', function () {
    const user = new User('oneadmin')

    user
      .getqr()
      .then((image) => {
        // eslint-disable-next-line no-unused-expressions
        expect(image).to.exist
      })
      .then(() => user.decodeqr())
      .then((qr) => {
        expect(qr).to.match(/^otpauth:\/\/totp\/fireedge-UI\?secret=/)
      })
      .then(() => user.getAuthCode())
      .then((secretKey) => user.set2fa(secretKey))
      .then((data) => {
        expect(data?.id).to.eq(200)
        expect(data?.message).to.eq('OK')
      })
      .then(() => user.info())
      .then((userInfo) => {
        // eslint-disable-next-line no-unused-expressions
        expect(userInfo?.TEMPLATE?.FIREEDGE?.TWO_FACTOR_AUTH_SECRET).to.exist
      })
      .then(() => user.delete2fa())
      .then((data) => {
        expect(data?.id).to.eq(200)
        expect(data?.message).to.eq('OK')
      })
      .then(() => user.info())
      .then((userInfo) => {
        // eslint-disable-next-line no-unused-expressions
        expect(userInfo?.TEMPLATE?.FIREEDGE?.TWO_FACTOR_AUTH_SECRET).to.not
          .exist
      })
  })
})
