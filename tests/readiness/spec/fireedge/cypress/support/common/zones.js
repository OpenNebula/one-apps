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

/**
 * Before test.
 *
 * @param {object} resources - resources
 * @param {object} resources.ZONE_SLAVE - zone slave
 * @param {object} resources.ZONE_MASTER - zone master
 * @param {object} resources.DATASTORE_IMG - datastore
 * @param {object} resources.MARKET_APP - market app
 * @param {Function} resources.nameMarketApp - market app name
 * @param {object} resources.VM_TEMPLATE_MASTER - vm template master
 * @param {object} resources.IMG - image
 * @param {object} resources.VM_TEMPLATE_SLAVE - vm template slave
 * @param {Function} resources.setZoneApi - set zone api
 */
const beforeAllZoneJobTest = ({
  ZONE_SLAVE,
  ZONE_MASTER,
  DATASTORE_IMG,
  MARKET_APP,
  nameMarketApp,
  VM_TEMPLATE_MASTER,
  IMG,
  VM_TEMPLATE_SLAVE,
  setZoneApi,
}) => {
  cy.fixture('auth')
    .then((auth) => cy.apiAuth(auth.admin))
    .then(() => setZoneApi(ZONE_SLAVE.ID))
    .then(() => ZONE_MASTER.info())
    .then(() => ZONE_SLAVE.info())
    // MASTER
    .then(() => DATASTORE_IMG.info())
    .then(() => MARKET_APP.info())
    .then(() => {
      const nameApp = nameMarketApp(ZONE_MASTER.id)

      return MARKET_APP.exportApp({
        associated: true,
        datastore: DATASTORE_IMG.id,
        name: nameApp,
        vmname: nameApp,
      })
    })
    .then(() => VM_TEMPLATE_MASTER.info())
    // SLAVE
    .then(() => setZoneApi(ZONE_SLAVE.id))
    .then(() => DATASTORE_IMG.info())
    .then(() =>
      IMG.allocate({
        template: {
          NAME: nameMarketApp(ZONE_SLAVE.id),
          SIZE: 100,
          TYPE: 'datablock',
        },
        datastore: DATASTORE_IMG.id,
      })
    )
    .then(() =>
      VM_TEMPLATE_SLAVE.allocate({
        NAME: nameMarketApp(ZONE_SLAVE.id),
        CPU: 1,
        MEMORY: 128,
      })
    )
}

/**
 * Validate Image.
 *
 * @param {object} resources - resources
 * @param {object} resources.imageName - image name
 * @param {object} resources.imageId - image id
 * @param {object} resources.zoneId - zone id
 * @param {string} resources.zoneName - zone name
 */
const validateImageZone = ({ imageName, imageId, zoneId, zoneName }) => {
  cy.changeZoneGUI(zoneId, zoneName)
    .then(() => cy.navigateMenu('storage', 'Images'))
    .then(() =>
      cy.getImageTable({ search: imageName }).within(() => {
        cy.get(`[role='row'][data-cy='image-${imageId}']`).should('exist')
      })
    )
}

/**
 * Validate Template.
 *
 * @param {object} resources - resources
 * @param {object} resources.templateName - image name
 * @param {object} resources.templateId - image id
 * @param {object} resources.zoneId - zone id
 * @param {string} resources.zoneName - zone name
 */
const validateTemplateZone = ({
  templateName,
  templateId,
  zoneId,
  zoneName,
}) => {
  cy.changeZoneGUI(zoneId, zoneName)
    .then(() => cy.navigateMenu('templates', 'VM Templates'))
    .then(() =>
      cy.getTemplateTable({ search: templateName }).within(() => {
        cy.get(`[role='row'][data-cy='template-${templateId}']`).should('exist')
      })
    )
}

/**
 * Validate Zone Info.
 *
 * @param {object} zone - zone
 */
const validateZoneInfo = (zone) => {
  cy.navigateMenu('infrastructure', 'Zones')

  cy.clickZoneRow(zone)
    .then(() => zone.info())
    .then(() => cy.validateZoneInfo(zone))
}

module.exports = {
  beforeAllZoneJobTest,
  validateImageZone,
  validateTemplateZone,
  validateZoneInfo,
}
