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
import * as ProvisionActions from '@support/utils/actions/provision'

describe('Fireedge GUI in provisions tab', function () {
  context('AWS', function () {
    beforeEach(function () {
      cy.fixture('auth').then((auth) => {
        this.auth = auth
        cy.login(auth.admin, '/provision')
      })

      cy.fixture('providers').then((providers) => {
        this.providers = providers
      })

      cy.fixture('provisions').then((provisions) => {
        this.provisions = provisions
      })
    })

    it('create AWS provider', function () {
      const provider = this.providers.aws

      ProviderActions.create(provider).its('response.body.id').should('eq', 200)
    })

    it('create AWS provision', function () {
      const {
        overview: { name: providerName },
      } = this.providers.aws
      const provision = this.provisions.aws

      ProvisionActions.create(provision, providerName)
        .its('response.body.id')
        .should('eq', 202)

      // check provision is created, the log should contain the message 'ID: <id>'
      cy.getBySel('auto-scroll').contains('[data-cy=message]', /ID: \d+/g)
    })

    it('check detail information about AWS provision', function () {
      const {
        overview: { name: providerName },
      } = this.providers.aws
      const provision = this.provisions.aws

      ProvisionActions.checkDetail(provision, providerName)
    })

    it('configure AWS provision', function () {
      const {
        overview: { name: provisionName },
      } = this.provisions.aws

      ProvisionActions.configure(provisionName)
        .its('response.body.id')
        .should('eq', 202)
    })

    it('delete AWS provision', function () {
      const {
        overview: { name: provisionName },
      } = this.provisions.aws
      const formData = this.provisions.awsDeleteForm

      ProvisionActions.remove(provisionName, formData).then((interception) => {
        expect(interception.response.body.id).eq(202)
        expect(interception.request.body.cleanup).eq(formData.cleanup)
      })
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
