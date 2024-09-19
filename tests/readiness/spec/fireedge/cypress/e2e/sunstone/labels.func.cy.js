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
import { MarketplaceApp, User } from '@models'

/** @type {User} */
let AUTH_USER = null
/** @type {MarketplaceApp[]} */
const MARKETPLACE_APPS = []

const LABEL1 = 'LABEL1'
const LABEL2 = 'LABEL2'
const LABEL3 = 'LABEL3'
const USER_LABELS = [LABEL1, LABEL2, LABEL3]

describe('Sunstone GUI is testing labels manipulation', function () {
  before(function () {
    cy.fixture('auth')
      .then((auth) => {
        const { username, password } = auth.admin
        AUTH_USER ||= new User(username, password)

        return cy.apiAuth(auth.admin)
      })
      .then(() => cy.apiSunstoneConf())
  })

  beforeEach(function () {
    cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
      qs: { externalToken: Cypress.env('TOKEN') },
    })
  })

  it("Should add labels to user's labels", function () {
    cy.navigateMenu(null, 'settings')

    cy.then(() => cy.addUserLabels(USER_LABELS))
      .then(() => AUTH_USER.info())
      .then(() => {
        USER_LABELS.forEach((label) => {
          // checks if the label is created on the resource
          expect(AUTH_USER.labels).to.include(label)
        })
      })
  })

  it("Should delete labels from user's labels", function () {
    cy.navigateMenu(null, 'settings')

    cy.deleteUserLabel(LABEL2)
      .its('response.body.id')
      .should('eq', 200)
      .then(() => AUTH_USER.info())
      .then(() => {
        // checks if the label is deleted from the UI
        cy.getBySel(LABEL2).should('not.exist')
        // checks if the label is deleted from the resource
        cy.wrap(AUTH_USER.labels).should('not.include', LABEL2)
      })
  })

  it('Should add label to Marketplace Apps', function () {
    cy.navigateMenu('storage', 'apps')

    cy.applyLabelsToMarketAppRows([0, 1, 2], [LABEL1])
      .then((ids) => {
        ids.forEach((id) => MARKETPLACE_APPS.push(new MarketplaceApp(id)))
      })
      .then(() => cy.all(...MARKETPLACE_APPS.map((app) => () => app.info())))
      .then(() => {
        MARKETPLACE_APPS.forEach((app) => {
          // exists in the resource
          cy.wrap(app.labels).should('contain', LABEL1)
          // exist on the UI
          cy.getMarketAppRow(app).contains(LABEL1)
        })
      })
  })

  it('Should filter Marketplace Apps by selected label', function () {
    cy.navigateMenu('storage', 'apps')

    cy.filterByLabels([LABEL1])

    cy.getMarketAppTable()
      .find("[role='row']")
      .each(($row) => {
        cy.wrap($row).should('contain.text', LABEL1)
      })
  })

  it('Should delete label from Marketplace Apps', function () {
    cy.navigateMenu('storage', 'apps')

    cy.applyLabelsToMarketAppRows(MARKETPLACE_APPS, [LABEL1], true)
      .then(() => cy.all(...MARKETPLACE_APPS.map((app) => () => app.info())))
      .then(() => {
        MARKETPLACE_APPS.forEach((app) => {
          // not exists in the resource
          cy.wrap(app.labels).should('not.include', LABEL1)
          // not exist on the UI
          cy.getMarketAppRow(app, { clearSearch: true })
            .find(`[data-cy='label-${LABEL1}']`)
            .should('not.exist')
        })
      })
  })

  it('Should RESET ALL DB', function () {
    // reset all resources after tests
    // comment these lines if you want to keep the test result
    cy.all(
      ...MARKETPLACE_APPS.map((app) => () => app.update({ LABELS: '' }, 1))
    ).then(() => {
      const templateUser = AUTH_USER.json.TEMPLATE
      const { LABELS: _, ...templateUserWithoutLabels } = templateUser

      return AUTH_USER.update(templateUserWithoutLabels, 0)
    })
  })
})
