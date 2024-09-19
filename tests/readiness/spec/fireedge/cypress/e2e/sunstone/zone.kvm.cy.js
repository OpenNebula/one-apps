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
import { setZoneApi } from '@commands/helpers'
import {
  beforeAllZoneJobTest,
  validateImageZone,
  validateTemplateZone,
  validateZoneInfo,
} from '@common/zones'

import { Datastore, Image, MarketplaceApp, VmTemplate, Zone } from '@models'

const marketName = 'Ttylinux - KVM'
const SLAVE_ID = '100'
const SLAVE_NAME = 'Slave-3'
const MASTER_ID = '0'
const MASTER_NAME = 'OpenNebula'
const NAME_DATASTORE = 'default'

const nameMarketApp = (zoneName) => `${marketName}- (${zoneName})`

const ZONE_MASTER = new Zone(MASTER_ID)
const ZONE_SLAVE = new Zone(SLAVE_ID)
const MARKET_APP = new MarketplaceApp(marketName)
const DATASTORE_IMG = new Datastore(NAME_DATASTORE)
const VM_TEMPLATE_SLAVE = new VmTemplate(marketName)
const VM_TEMPLATE_MASTER = new VmTemplate(nameMarketApp(MASTER_ID))
const IMG = new Image()

describe('Sunstone GUI in Zone Tab', function () {
  before(function () {
    beforeAllZoneJobTest({
      ZONE_SLAVE,
      ZONE_MASTER,
      DATASTORE_IMG,
      MARKET_APP,
      nameMarketApp,
      VM_TEMPLATE_MASTER,
      IMG,
      VM_TEMPLATE_SLAVE,
      setZoneApi,
    })
  })

  beforeEach(function () {
    cy.fixture('auth').then((auth) => {
      cy.visit(`${Cypress.config('baseUrl')}/sunstone`)
      cy.login(auth.admin)
    })
  })

  it('Validate TEMPLATE in zone SLAVE', function () {
    validateTemplateZone({
      templateName: VM_TEMPLATE_SLAVE.name,
      templateId: VM_TEMPLATE_SLAVE.id,
      zoneId: SLAVE_ID,
      zoneName: SLAVE_NAME,
    })
  })

  it('Validate IMAGE in zone SLAVE', function () {
    validateImageZone({
      imageName: VM_TEMPLATE_SLAVE.name,
      imageId: IMG.id,
      zoneId: SLAVE_ID,
      zoneName: SLAVE_NAME,
    })
  })

  it('Validate TEMPLATE in zone MASTER', function () {
    validateTemplateZone({
      templateName: VM_TEMPLATE_MASTER.name,
      templateId: VM_TEMPLATE_MASTER.id,
      zoneId: MASTER_ID,
      zoneName: MASTER_NAME,
    })
  })

  it('Validate IMAGE in zone MASTER', function () {
    validateImageZone({
      imageName: VM_TEMPLATE_MASTER.name,
      imageId: VM_TEMPLATE_MASTER.id,
      zoneId: MASTER_ID,
      zoneName: MASTER_NAME,
    })
  })

  it('Validate INFO zone MASTER', function () {
    validateZoneInfo(ZONE_MASTER)
  })

  it('Validate INFO zone SLAVE', function () {
    validateZoneInfo(ZONE_SLAVE)
  })
})
