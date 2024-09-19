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

const { Datastore, Marketplace } = require('@models')

const BASE_URL = Cypress.config('baseUrl')
const TASK_TIMEOUT = Cypress.config('taskTimeout')
const MARKET_XML = {
  NAME: 'test_market',
  MARKET_MAD: 'http',
  BASE_URL: 'http://localhost:8000',
  PUBLIC_DIR: '/var/tmp',
}
const IMAGE_TEMPLATE = {
  SIZE: '5',
  TYPE: 'DATABLOCK',
}

const MARKET = new Marketplace()
const DATASTORE = new Datastore('default')

/**
 * @param {object[]} appsToCreate - market apps
 * @param {boolean} createForUser - create for user
 */
const beforeAllMarketappTest = (appsToCreate, createForUser = false) => {
  cy.then(() => MARKET.allocate(MARKET_XML))
    .then(() => DATASTORE.info())
    .then(() => {
      const apps = Object.values(appsToCreate)
      const allocateFn =
        ({ app, image }) =>
        () =>
          image
            .allocate({
              template: {
                ...IMAGE_TEMPLATE,
                NAME: image.name,
              },
              datastore: DATASTORE.id,
            })
            .then(
              () =>
                createForUser &&
                image.chmod({
                  ownerUse: 1,
                  ownerManage: 1,
                  ownerAdmin: 0,
                  groupUse: 0,
                  groupManage: 0,
                  groupAdmin: 0,
                  otherUse: 1,
                  otherManage: 1,
                  otherAdmin: 0,
                })
            )
            .then(() =>
              app.allocate(MARKET.id, {
                template: {
                  ORIGIN_ID: image.id,
                  NAME: app.name,
                },
              })
            )
            .then(
              () =>
                createForUser &&
                app.chmod({
                  ownerUse: 1,
                  ownerManage: 1,
                  ownerAdmin: 0,
                  groupUse: 0,
                  groupManage: 0,
                  groupAdmin: 0,
                  otherUse: 1,
                  otherManage: 1,
                  otherAdmin: 0,
                })
            )

      return cy.all(...apps.map(allocateFn))
    })
}

/**
 * Function to be executed before each test.
 */
const beforeEachMarketappTest = () => {
  cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
    qs: { externalToken: Cypress.env('TOKEN') },
  })
}

/**
 * @param {object} marketapp - App to lock
 */
const lockMarketapp = (marketapp) => {
  cy.navigateMenu('storage', 'Apps')
  cy.lockMarketapp(marketapp).then(() => {
    cy.navigateTab('info').within(() => {
      cy.getBySel('locked').should('not.have.text', '-')
    })
  })
}

/**
 * @param {object} marketapp - App to unlock
 */
const unlockMarketapp = (marketapp) => {
  cy.navigateMenu('storage', 'Apps')
  cy.unlockMarketapp(marketapp).then(() => {
    cy.navigateTab('info').within(() => {
      cy.getBySel('locked').should('have.text', '-')
    })
  })
}

/**
 * @param {object} marketapp - App to disable
 */
const disableMarketapp = (marketapp) => {
  cy.navigateMenu('storage', 'Apps')
  cy.disableMarketapp(marketapp).then(() =>
    cy.validateMarketAppState('DISABLED')
  )
}

/**
 * @param {object} marketapp - App to enable
 */
const enableMarketapp = (marketapp) => {
  cy.navigateMenu('storage', 'Apps')
  cy.enableMarketapp(marketapp).then(() => cy.validateMarketAppState('READY'))
}

/**
 * @param {object} marketapp - App to change ownership
 * @param {object} newOwner - New owner
 */
const changeMarketappOwnership = (marketapp, newOwner) => {
  cy.navigateMenu('storage', 'Apps')

  newOwner
    .info()
    .then(() => {
      cy.changeOwnerMarketapp({
        marketapp,
        resource: newOwner,
      })
    })
    .then(() => cy.getBySel('owner').contains(newOwner.name))
}

/**
 * @param {object} marketapp - App to change group
 * @param {object} newGroup - New group
 */
const changeMarketappGroup = (marketapp, newGroup) => {
  cy.navigateMenu('storage', 'Apps')

  newGroup
    .info()
    .then(() =>
      cy.changeGroupMarketapp({
        marketapp,
        resource: newGroup,
      })
    )
    .then(() => cy.getBySel('group').contains(newGroup.name))
}

/**
 * @param {object} marketapp - App to delete
 */
const deleteMarketapp = (marketapp) => {
  cy.navigateMenu('storage', 'Apps')
  cy.deleteMarketapp(marketapp).its('response.body.id').should('eq', 200)
}

/**
 * @param {object} marketapp - App to download
 */
const downloadMarketapp = (marketapp) => {
  marketapp
    .info()
    .then(() => cy.fixture('auth'))
    .then((auth) =>
      cy.task(
        'externalBrowserDownloadMarketapp',
        {
          auth,
          cypress: {
            ...Cypress.config(),
            endpoint: BASE_URL,
          },
          app: {
            id: marketapp.id,
            name: marketapp.name,
            // Harcoding this in so that puppeteer finds the right url
            // old reference => Intercepts.SUNSTONE.MARKETAPPS.url
            waitURLList: `${BASE_URL}/api/marketapppool/info`,
          },
        },
        { timeout: TASK_TIMEOUT * 2 }
      )
    )
    .then((downloaded) => {
      expect(downloaded?.length).to.satisfy((num) => num > 0)
      expect(downloaded).to.include(marketapp.json.MD5)
    })
}

/**
 * Verify that when you export an app to a datastores you can only choose image datastores.
 *
 * @param {object} marketapp - App to export
 */
const verifyImageDatastoresToExport = (marketapp) => {
  // Navigate to Storage > Apps in Sunstone menu
  cy.navigateMenu('storage', 'Apps')

  // Verify datastores
  cy.verifyImageDatastoresToExport(marketapp)
}

module.exports = {
  lockMarketapp,
  unlockMarketapp,
  disableMarketapp,
  enableMarketapp,
  changeMarketappOwnership,
  changeMarketappGroup,
  deleteMarketapp,
  downloadMarketapp,
  beforeAllMarketappTest,
  beforeEachMarketappTest,
  verifyImageDatastoresToExport,
}
