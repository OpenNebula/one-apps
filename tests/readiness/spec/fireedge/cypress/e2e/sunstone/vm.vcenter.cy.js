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
import { VirtualMachine } from '@models'

let VM

describe('Sunstone GUI in VMs tab - VCENTER', function () {
  // eslint-disable-next-line mocha/no-hooks-for-single-case
  before(function () {
    let fixtureVcenter

    cy.fixture('auth').then((auth) => {
      this.auth = auth
    })

    cy.fixture('vcenter')
      .then((vcenter) => {
        fixtureVcenter = vcenter
        cy.apiAuth(this.auth.admin)
      })
      .then(() => cy.apiSunstoneConf())
      .then(() => cy.task('importVcenterHost', fixtureVcenter))
      .then(() =>
        cy.task('importVcenterDatastore', {
          datastoreRef: fixtureVcenter.datastoreRef,
          host: fixtureVcenter.clusterName,
        })
      )
      .then(() =>
        cy.task('importVM', {
          host: fixtureVcenter.clusterName,
          name: fixtureVcenter.wildVM,
        })
      )
      .then(() => (VM = new VirtualMachine(fixtureVcenter.wildVM)))
  })

  // eslint-disable-next-line mocha/no-hooks-for-single-case
  beforeEach(function () {
    cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
      qs: { externalToken: Cypress.env('TOKEN') },
    })
  })

  it('Open VMRC Console', function () {
    const baseURL = Cypress.config('baseUrl')

    VM.info()
      .then(() => cy.fixture('auth'))
      .then((auth) => {
        const id = VM?.id
        cy.task(
          'externalBrowserConsole',
          {
            auth,
            cypress: { ...Cypress.config(), endpoint: `${baseURL}/sunstone` },
            vm: {
              id,
              type: 'vmrc',
              waitURLConsole: `${baseURL}/api/vcenter/token/${id}`,
              waitURLListVms: `${baseURL}/api/vmpool/info/`,
            },
          },
          { timeout: 900000 /* 15 minutes */ }
        ).then(
          ({
            id: idConsole = '',
            name: nameConsole = '',
            ips = '',
            state = '',
            canvas = false,
            canvasPercent = 100,
            fullscreen = false,
            ctrlAltDel = false,
          }) => {
            /* eslint-disable no-unused-expressions */
            expect(canvas).to.be.true
            expect(canvasPercent).to.be.below(10)
            expect(fullscreen).to.be.true
            expect(ctrlAltDel).to.be.true
            /* eslint-enable no-unused-expressions */
            expect(state).to.include('Connected')
            expect(idConsole).to.include(id)
            expect(nameConsole).to.include(VM.name)
          }
        )
      })
  })
})
