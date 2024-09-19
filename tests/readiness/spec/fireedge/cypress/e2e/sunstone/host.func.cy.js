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
import { Cluster, Host } from '@models'

const HOST = new Host('192.168.0.1')
const HOST2 = new Host('localhost')
const HOST_GUI = new Host('template_host')
const CLUSTER = new Cluster('new_cluster')

const DUMMY_MAD = { imMad: 'dummy', vmmMad: 'dummy' }
const HOST_PARAMS = { hostname: HOST.name, ...DUMMY_MAD }
const HOST2_PARAMS = { hostname: HOST2.name, ...DUMMY_MAD }
const OVERCOMMITMENT = {
  CPU: '900',
  MEMORY: '17703972', // 17GB
}

describe('Sunstone GUI in HOST tab', function () {
  before(function () {
    cy.fixture('auth')
      .then((auth) => cy.apiAuth(auth.admin))

      .then(() => HOST.allocate(HOST_PARAMS))
      .then(() => !HOST.isMonitored && HOST.enable())

      .then(() => HOST2.allocate(HOST2_PARAMS))
      .then(() => !HOST2.isMonitored && HOST2.enable())

      .then(() => CLUSTER.allocate({ name: CLUSTER.name }))
  })

  beforeEach(function () {
    cy.fixture('auth').then((auth) => {
      cy.visit(`${Cypress.config('baseUrl')}/sunstone`)
      cy.login(auth.admin)
    })
  })

  it('Create a new KVM host', function () {
    const host = {
      name: HOST_GUI.name,
      hypervisor: 'kvm',
      cluster: { id: '0', name: 'default' },
    }

    cy.navigateMenu('infrastructure', 'Hosts')

    cy.createHost(host)
      .its('response.body.id')
      .should('eq', 200)
      .then(() => HOST_GUI.info())
      .then(() => {
        expect(HOST_GUI.json).to.have.property('IM_MAD', host.hypervisor)
        expect(HOST_GUI.json).to.have.property('VM_MAD', host.hypervisor)
        expect(HOST_GUI.json).to.have.property('CLUSTER_ID', host.cluster.id)
        expect(HOST_GUI.json).to.have.property('CLUSTER', host.cluster.name)
      })
      .then(() => cy.getHostRow(HOST_GUI).contains(HOST_GUI.name))
  })

  it('Disable host', function () {
    cy.navigateMenu('infrastructure', 'Hosts')

    cy.disableHost(HOST)
      .its('response.body.id')
      .should('eq', 200)
      .then(() => cy.validateHostState('DISABLED'))
  })

  it('Enable host', function () {
    cy.navigateMenu('infrastructure', 'Hosts')

    cy.enableHost(HOST)
      .its('response.body.id')
      .should('eq', 200)
      .then(() => cy.validateHostState(/INIT|MONITORED/g))
  })

  it('Offline host', function () {
    cy.navigateMenu('infrastructure', 'Hosts')

    cy.offlineHost(HOST)
      .its('response.body.id')
      .should('eq', 200)
      .then(() => cy.validateHostState(/OFFLINE|DISABLED/g))
  })

  it('Rename host', function () {
    const newName = 'hostRenamed'

    cy.navigateMenu('infrastructure', 'Hosts')

    cy.clickHostRow(HOST)
      .then(() => cy.renameResource(newName))
      .then(() => (HOST.name = newName))
      .then(() => cy.getHostRow(HOST).contains(newName))
  })

  it('Change cluster host', function () {
    cy.navigateMenu('infrastructure', 'Hosts')

    cy.addHostCluster(HOST, CLUSTER)
      .its('response.body.id')
      .should('eq', 200)
      .then(() => HOST.info())
      .then(() => cy.validateHostInfo(HOST))
  })

  it('Validate numa host', function () {
    cy.navigateMenu('infrastructure', 'Hosts')

    cy.disableHost(HOST2)
      .then(() => cy.enableHost(HOST2))
      .then(() => HOST2.waitMonitored())
      .then(() => HOST2.info())
      .then(() => cy.clickHostRow(HOST2))
      .then(() => cy.validateNuma(HOST2))
  })

  it('Validate INFO host created by GUI', function () {
    cy.navigateMenu('infrastructure', 'Hosts')

    cy.clickHostRow(HOST)
      .then(() => HOST.info())
      .then(() => cy.validateHostInfo(HOST))
  })

  it('Validate Overcommitment', function () {
    cy.navigateMenu('infrastructure', 'Hosts')

    HOST.enable()
      .then(() => HOST.waitMonitored())
      .then(() => cy.clickHostRow(HOST))
      .then(() => cy.overcommitmentHost(OVERCOMMITMENT))
      .then(() => HOST.info())
      .then(() => cy.validateOvercommitmentHost(HOST, OVERCOMMITMENT))
  })

  it('Delete host created by GUI', function () {
    cy.navigateMenu('infrastructure', 'Hosts')

    HOST.info().then(() =>
      cy.deleteHost(HOST).its('response.body.id').should('eq', 200)
    )
  })
})
