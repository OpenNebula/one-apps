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
import { Host, User } from '@models'
import { adminContext, userContext } from '@utils/constants'

const ONEADMIN_USER = new User('oneadmin')
const HOST = new Host('full-info-screen')
const DUMMY_MAD = { imMad: 'dummy', vmmMad: 'dummy' }
const HOST_PARAMS = { hostname: HOST.name, ...DUMMY_MAD }
const CUSTOM_LOGO = 'linux.png'
const NON_EXISTENT_LOGO = 'thislogodoesnotexist.png'
const REGULAR_USER = new User('regularUser', 'opennebula')

describe('Sunstone GUI in Settings Tab', function () {
  context('Oneadmin', adminContext, function () {
    before(function () {
      cy.fixture('auth')
        .then((auth) => cy.apiAuth(auth.admin))
        .then(() => cy.cleanup())
        .then(() => ONEADMIN_USER.info())
        .then(() => HOST.allocate(HOST_PARAMS))
    })

    beforeEach(function () {
      cy.fixture('auth').then((auth) => {
        cy.login(auth.admin)
      })

      cy.fixture('user_settings').then((userSettings) => {
        this.userSettings = userSettings
      })
    })

    it('Should change UI scheme to dark', function () {
      cy.changeSettingUISelector('SCHEME', this.userSettings.darkScheme)
        .its('response.body.id')
        .should('eq', 200)
        .then(() => ONEADMIN_USER.info())
        .then(() =>
          expect(ONEADMIN_USER.json).to.have.nested.property(
            'TEMPLATE.FIREEDGE.SCHEME',
            this.userSettings.darkScheme
          )
        )
    })

    it('Should change UI scheme to light', function () {
      cy.changeSettingUISelector('SCHEME', this.userSettings.lightScheme)
        .its('response.body.id')
        .should('eq', 200)
        .then(() => ONEADMIN_USER.info())
        .then(() =>
          expect(ONEADMIN_USER.json).to.have.nested.property(
            'TEMPLATE.FIREEDGE.SCHEME',
            this.userSettings.lightScheme
          )
        )
    })

    it('Should change UI language to Spanish', function () {
      cy.changeSettingUISelector('LANG', this.userSettings.langSpanish)
        .its('response.body.id')
        .should('eq', 200)
        .then(() => ONEADMIN_USER.info())
        .then(() =>
          expect(ONEADMIN_USER.json).to.have.nested.property(
            'TEMPLATE.FIREEDGE.LANG',
            this.userSettings.langSpanish
          )
        )
    })

    it('Should change UI language to English', function () {
      cy.changeSettingUISelector(
        'LANG',
        this.userSettings.langEnglish,
        'Ajustes'
      )
        .its('response.body.id')
        .should('eq', 200)
        .then(() => ONEADMIN_USER.info())
        .then(() =>
          expect(ONEADMIN_USER.json).to.have.nested.property(
            'TEMPLATE.FIREEDGE.LANG',
            this.userSettings.langEnglish
          )
        )
    })

    it('Should disable dashboard animations', function () {
      cy.toggleAnimations()
        .its('response.body.id')
        .should('eq', 200)
        .then(() => ONEADMIN_USER.info())
        .then(() =>
          expect(ONEADMIN_USER.json).to.have.nested.property(
            'TEMPLATE.FIREEDGE.DISABLE_ANIMATIONS',
            'true'
          )
        )
    })

    it('Should enable dashboard animations', function () {
      cy.toggleAnimations()
        .its('response.body.id')
        .should('eq', 200)
        .then(() => ONEADMIN_USER.info())
        .then(() =>
          expect(ONEADMIN_USER.json).to.have.nested.property(
            'TEMPLATE.FIREEDGE.DISABLE_ANIMATIONS',
            'false'
          )
        )
    })

    it('Should change view (User)', function () {
      cy.changeSettingUISelector('DEFAULT_VIEW', this.userSettings.viewUser)
        .its('response.body.id')
        .should('eq', 200)
        .then(() => ONEADMIN_USER.info())
        .then(() =>
          expect(ONEADMIN_USER.json).to.have.nested.property(
            'TEMPLATE.FIREEDGE.DEFAULT_VIEW',
            this.userSettings.viewUser
          )
        )
    })

    it('Should change view (Admin)', function () {
      cy.changeSettingUISelector('DEFAULT_VIEW', this.userSettings.viewAdmin)
        .its('response.body.id')
        .should('eq', 200)
        .then(() => ONEADMIN_USER.info())
        .then(() =>
          expect(ONEADMIN_USER.json).to.have.nested.property(
            'TEMPLATE.FIREEDGE.DEFAULT_VIEW',
            this.userSettings.viewAdmin
          )
        )
    })

    it('Should change default endpoint (Opennebula)', function () {
      cy.changeSettingUISelector(
        'DEFAULT_ZONE_ENDPOINT',
        this.userSettings.defaultEndpoint
      )
        .its('response.body.id')
        .should('eq', 200)
        .then(() => ONEADMIN_USER.info())
        .then(() =>
          expect(ONEADMIN_USER.json).to.have.nested.property(
            'TEMPLATE.FIREEDGE.DEFAULT_ZONE_ENDPOINT',
            this.userSettings.defaultEndpoint
          )
        )
    })

    it('Should clear default endpoint', function () {
      cy.changeSettingUISelector('DEFAULT_ZONE_ENDPOINT', '')
        .its('response.body.id')
        .should('eq', 200)
        .then(() => ONEADMIN_USER.info())
        .then(() =>
          expect(ONEADMIN_USER.json).to.not.have.nested.property(
            'TEMPLATE.FIREEDGE.DEFAULT_ZONE_ENDPOINT'
          )
        )
    })

    it('Should enable login token', function () {
      cy.changeLoginToken('3000', '0')
        .its('response.body.id')
        .should('eq', 200)
        .then(() => ONEADMIN_USER.info())
        .then(() =>
          expect(ONEADMIN_USER.json).to.have.nested.property('LOGIN_TOKEN')
        )
    })

    it('Should set the SSH public key by UI', function () {
      cy.changeSSHSettings('SSH_PUBLIC_KEY', this.userSettings.sshPublicKey)
        .its('response.body.id')
        .should('eq', 200)
        .then(() => ONEADMIN_USER.info())
        .then(() =>
          expect(ONEADMIN_USER.json).to.have.nested.property(
            'TEMPLATE.SSH_PUBLIC_KEY',
            this.userSettings.sshPublicKey
          )
        )
    })

    it('Should set the SSH private key by UI', function () {
      cy.changeSSHSettings('SSH_PRIVATE_KEY', this.userSettings.sshPrivateKey)
        .its('response.body.id')
        .should('eq', 200)
        .then(() => ONEADMIN_USER.info(true))
        .then(() =>
          expect(ONEADMIN_USER.json).to.have.nested.property(
            'TEMPLATE.SSH_PRIVATE_KEY',
            this.userSettings.sshPrivateKey
          )
        )
    })

    it('Should set the SSH private key passphrase by UI', function () {
      cy.changeSSHSettings('SSH_PASSPHRASE', this.userSettings.sshPassphrase)
        .its('response.body.id')
        .should('eq', 200)
        .then(() => ONEADMIN_USER.info(true))
        .then(() =>
          expect(ONEADMIN_USER.json).to.have.nested.property(
            'TEMPLATE.SSH_PASSPHRASE',
            this.userSettings.sshPassphrase
          )
        )
    })

    it('Should check that oneadmin cannot change password', function () {
      cy.changeUserPassword(undefined, undefined, true)
    })

    // Changing logo to the generic linux one
    it('Should change the FireEdge logo', function () {
      cy.getFSunstoneViewsConf().then((config) =>
        cy
          .updateFSunstoneViewsConf({
            ...config,
            logo: CUSTOM_LOGO,
          })
          .then(() => cy.validateLogoChange(CUSTOM_LOGO, { shouldFail: false }))
      )
    })

    it('Should try setting non-existing logo', function () {
      cy.getFSunstoneViewsConf().then((config) =>
        cy
          .updateFSunstoneViewsConf(
            {
              ...config,
              logo: NON_EXISTENT_LOGO,
            },
            false
          )
          .then(() =>
            cy.validateLogoChange(NON_EXISTENT_LOGO, { shouldFail: true })
          )
      )
    })

    it('Should revert back to default logo', function () {
      cy.restoreFSunstoneViewsConf().then(() =>
        cy.validateLogoChange('', { shouldFail: false })
      )
    })

    it('Should ENABLE the full-screen information', function () {
      cy.toggleInfoFullScreen()
        .its('response.body.id')
        .should('eq', 200)
        .then(() => ONEADMIN_USER.info())
        .then(() =>
          expect(ONEADMIN_USER.json).to.have.nested.property(
            'TEMPLATE.FIREEDGE.FULL_SCREEN_INFO',
            'true'
          )
        )
        .then(() => cy.navigateMenu('infrastructure', 'Hosts'))
        .then(() => cy.clickHostRow(HOST, { checkSelected: false }))
        .then(() => cy.getBySel('hosts').should('not.exist'))
    })

    it('Should DISABLE the full-screen information', function () {
      cy.toggleInfoFullScreen()
        .its('response.body.id')
        .should('eq', 200)
        .then(() => ONEADMIN_USER.info())
        .then(() =>
          expect(ONEADMIN_USER.json).to.have.nested.property(
            'TEMPLATE.FIREEDGE.FULL_SCREEN_INFO',
            'false'
          )
        )
        .then(() => cy.navigateMenu('infrastructure', 'Hosts'))
        .then(() => cy.clickHostRow(HOST))
        .then(() => cy.getBySel('hosts').should('exist'))
    })
  })

  context('User', userContext, function () {
    // eslint-disable-next-line mocha/no-hooks-for-single-case
    before(function () {
      cy.fixture('auth')
        .then((auth) => cy.apiAuth(auth.admin))
        .then(() => cy.cleanup())
        .then(() => REGULAR_USER.allocate())
    })

    // eslint-disable-next-line mocha/no-hooks-for-single-case
    beforeEach(function () {
      cy.fixture('auth').then(() => {
        cy.login(REGULAR_USER.credentials)
      })
    })

    it('Should check that regular user can change password', function () {
      cy.changeUserPassword(REGULAR_USER, 'opennebula2')
    })
  })
})
