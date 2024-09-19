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
let ldapUser = {}
let suffixLdap = '-bk'
const fileLdapConf = '/etc/one/auth/ldap_auth.conf'
const fileOnedConf = '/etc/one/oned.conf'
const fileLdapUser = '/tmp/test'

describe('Sunstone GUI LOGIN using LDAP', function () {
  // eslint-disable-next-line mocha/no-hooks-for-single-case
  before(function () {
    cy.fixture('ldap_user')
      .then(({ user, suffixLdapTemp } = {}) => {
        const [username, password] = user.split(':')
        ldapUser = {
          username,
          password,
        }
        suffixLdap = suffixLdapTemp

        return cy.writeFile(fileLdapUser, user)
      })
      .then(() =>
        cy.task('copy', {
          pathConfig: fileLdapConf,
          pathTemp: `${fileLdapConf}${suffixLdap}`,
        })
      )
      .then(() =>
        cy.task('copy', {
          pathConfig: fileOnedConf,
          pathTemp: `${fileOnedConf}${suffixLdap}`,
        })
      )
      .then(() => cy.task('changeDefaultAuth', 'ldap'))
      .then(() => cy.fixture('ldap_config.conf'))
      .then((dataLdapConfig) => cy.writeFile(fileLdapConf, dataLdapConfig))
      .then(() => cy.task('createOneAuthVar', fileLdapUser))
      .then(() => cy.restartOpennebulaService())
      .then(() => cy.apiAuth(ldapUser))
      .then(() => cy.apiSunstoneConf())
  })

  after(function () {
    cy.task('copy', {
      pathConfig: `${fileLdapConf}${suffixLdap}`,
      pathTemp: fileLdapConf,
    })
      .then(() =>
        cy.task('copy', {
          pathConfig: `${fileOnedConf}${suffixLdap}`,
          pathTemp: fileOnedConf,
        })
      )
      .then(() => cy.task('deleteOneAuthVar'))
  })

  beforeEach(function () {
    cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
      qs: { externalToken: Cypress.env('TOKEN') },
    })
  })

  it('Should check LDAP user connected in fireedge', function () {
    cy.get('[data-cy=header-user-button]').should(
      'have.text',
      ldapUser.username
    )
  })

  it('Should check that LDAP user cannot change password', function () {
    cy.changeUserPassword(undefined, undefined, true)
  })
})
