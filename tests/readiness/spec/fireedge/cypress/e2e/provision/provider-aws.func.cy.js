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
import * as ProviderActions from '@support/utils/actions/provider'

describe('Fireedge GUI in providers tab', function () {
  context('AWS', function () {
    beforeEach(function () {
      cy.fixture('auth').then((auth) => {
        this.auth = auth
        cy.login(auth.admin, '/provision')
      })

      cy.fixture('providers').then((providers) => {
        this.providers = providers
      })
    })

    it('create AWS provider', function () {
      const provider = this.providers.aws

      ProviderActions.create(provider).its('response.body.id').should('eq', 200)
    })

    it('check AWS provider exists in cards list', function () {
      const {
        overview: { name },
      } = this.providers.aws

      cy.contains('[data-cy=main-menu-item]', 'providers', {
        matchCase: false,
      }).click()

      cy.contains('[data-cy=provider-card-title]', name).should('exist')
    })

    it('check detail information about AWS provider', function () {
      const provider = this.providers.aws

      ProviderActions.checkDetail(provider)
    })

    it('update AWS provider', function () {
      const {
        overview: { name, ...overview },
        connection,
      } = this.providers.awsEdited

      ProviderActions.update(name, { overview, connection })
        .its('response.body.id')
        .should('eq', 200)
    })

    it('check detail information about AWS provider after update', function () {
      const providerEdited = this.providers.awsEdited

      ProviderActions.checkDetail(providerEdited)
    })

    it('delete AWS provider', function () {
      const {
        overview: { name },
      } = this.providers.aws

      ProviderActions.remove(name).its('response.body.id').should('eq', 200)

      cy.getBySel('providers').should('be.empty')
    })
  })
})
