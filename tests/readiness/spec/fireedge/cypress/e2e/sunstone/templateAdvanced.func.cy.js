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
import { executeCase, beforeTemplateCases } from '@common/template'
import { generalCases } from '@cases/templates/general'
import { storageCases } from '@cases/templates/storage'
import { networkCases } from '@cases/templates/network'
import { pciCases } from '@cases/templates/pci'
import { osAndCpuCases } from '@cases/templates/osandcpu'
import { inputOutputCases } from '@cases/templates/inputoutput'
import { contextCases } from '@cases/templates/context'
import { scheduleActionCases } from '@cases/templates/schedule'
import { placementCases } from '@cases/templates/placement'
import { numaCases } from '@cases/templates/numa'
import { backupCases } from '@cases/templates/backup'
import { adminContext } from '@utils/constants'
import { Datastore, MarketplaceApp, Image, VNet, Host, User } from '@models'

const DS_IMG = new Datastore('default')
const DS_FILES = new Datastore('files')
const DS_BACKUP = {
  dsBackup1: {
    datastore: new Datastore('dsBackup1'),
    template: {
      NAME: 'dsBackup1',
      TYPE: 'BACKUP_DS',
      DS_MAD: 'fs',
      TM_MAD: 'shared',
    },
  },
  dsBackup2: {
    datastore: new Datastore('dsBackup2'),
    template: {
      NAME: 'dsBackup2',
      TYPE: 'BACKUP_DS',
      DS_MAD: 'fs',
      TM_MAD: 'shared',
    },
  },
}

const MARKET_APPS = [
  new MarketplaceApp('Ubuntu 16.04'),
  new MarketplaceApp('Ubuntu 18.04'),
  new MarketplaceApp('Ubuntu 20.04'),
]

const APP_IMAGES = {
  'Ubuntu 16.04': new Image('Ubuntu 16.04'),
  'Ubuntu 18.04': new Image('Ubuntu 18.04'),
  'Ubuntu 20.04': new Image('Ubuntu 20.04'),
}

const FILE_IMAGES = {
  ramimage1: {
    image: new Image('ramimage1'),
    template: {
      NAME: 'ramimage1',
      TYPE: 'RAMDISK',
      SOURCE: '/home/oneadmin/ramimage1',
      SIZE: 1,
      FORMAT: 'qcow2',
    },
  },
  ramimage2: {
    image: new Image('ramimage2'),
    template: {
      NAME: 'ramimage2',
      TYPE: 'RAMDISK',
      SOURCE: '/home/oneadmin/ramimage2',
      SIZE: 1,
      FORMAT: 'qcow2',
    },
  },
  kernelimage1: {
    image: new Image('kernelimage1'),
    template: {
      NAME: 'kernelimage1',
      TYPE: 'KERNEL',
      SOURCE: '/home/oneadmin/kernelimage1',
      SIZE: 1,
      FORMAT: 'qcow2',
    },
  },
  kernelimage2: {
    image: new Image('kernelimage2'),
    template: {
      NAME: 'kernelimage2',
      TYPE: 'KERNEL',
      SOURCE: '/home/oneadmin/kernelimage2',
      SIZE: 1,
      FORMAT: 'qcow2',
    },
  },
  contextimage1: {
    image: new Image('contextimage1'),
    template: {
      NAME: 'contextimage1',
      TYPE: 'CONTEXT',
      SOURCE: '/home/oneadmin/contextimage1',
      SIZE: 1,
      FORMAT: 'qcow2',
    },
  },
  contextimage2: {
    image: new Image('contextimage2'),
    template: {
      NAME: 'contextimage2',
      TYPE: 'CONTEXT',
      SOURCE: '/home/oneadmin/contextimage2',
      SIZE: 1,
      FORMAT: 'qcow2',
    },
  },
}

const NETWORKS = {
  vnet1: new VNet('vnet1'),
  vnet2: new VNet('vnet2'),
  vnet3: new VNet('vnet3'),
  vnet4: new VNet('vnet4'),
  vnetAlias1: new VNet('vnetAlias1'),
  vnetAlias2: new VNet('vnetAlias2'),
  vnetAlias3: new VNet('vnetAlias3'),
  vnetPci1: new VNet('vnetPci1'),
  vnetPci2: new VNet('vnetPci2'),
  vnetPci3: new VNet('vnetPci3'),
  vnetPci4: new VNet('vnetPci4'),
}

const HOSTS = {
  dummy: new Host('dummy'),
}

const USERS = {
  user: new User('user'),
}

// Modern cypress fails automatically on any exceptions
// should be removed once VM template async schema loading
// bug is resolved
Cypress.on('uncaught:exception', () => false)

describe('Sunstone GUI in VM Template tab', function () {
  context('Oneadmin', adminContext, function () {
    before(function () {
      beforeTemplateCases(
        MARKET_APPS,
        DS_IMG,
        DS_FILES,
        DS_BACKUP,
        APP_IMAGES,
        FILE_IMAGES,
        NETWORKS,
        HOSTS,
        USERS
      )
    })

    beforeEach(function () {
      cy.fixture('auth')
        .then((auth) => {
          cy.wrapperAuth(auth)
        })
        .then(() =>
          cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
            qs: { externalToken: Cypress.env('TOKEN') },
          })
        )
    })

    // eslint-disable-next-line mocha/no-setup-in-describe
    generalCases.forEach((caseItem) => {
      it(`General: ${caseItem.initialData.template.name} - ${caseItem.initialData.template.description}`, function () {
        executeCase(caseItem, { APP_IMAGES, USERS })
      })
    })

    // eslint-disable-next-line mocha/no-setup-in-describe
    storageCases.forEach((caseItem) => {
      it(`Storage: ${caseItem.initialData.template.name} - ${caseItem.initialData.template.description}`, function () {
        executeCase(caseItem, { APP_IMAGES })
      })
    })

    // eslint-disable-next-line mocha/no-setup-in-describe
    networkCases.forEach((caseItem) => {
      it(`Network: ${caseItem.initialData.template.name} - ${caseItem.initialData.template.description}`, function () {
        executeCase(caseItem, { NETWORKS })
      })
    })

    // eslint-disable-next-line mocha/no-setup-in-describe
    pciCases.forEach((caseItem) => {
      it(`PCI devices: ${caseItem.initialData.template.name} - ${caseItem.initialData.template.description}`, function () {
        executeCase(caseItem, {})
      })
    })

    // eslint-disable-next-line mocha/no-setup-in-describe
    osAndCpuCases.forEach((caseItem) => {
      it(`OS&CPU: ${caseItem.initialData.template.name} - ${caseItem.initialData.template.description}`, function () {
        executeCase(caseItem, { FILE_IMAGES, APP_IMAGES, NETWORKS })
      })
    })

    // eslint-disable-next-line mocha/no-setup-in-describe
    inputOutputCases.forEach((caseItem) => {
      it(`Input/Output: ${caseItem.initialData.template.name} - ${caseItem.initialData.template.description}`, function () {
        executeCase(caseItem, { NETWORKS })
      })
    })

    // eslint-disable-next-line mocha/no-setup-in-describe
    contextCases.forEach((caseItem) => {
      it(`Context: ${caseItem.initialData.template.name} - ${caseItem.initialData.template.description}`, function () {
        executeCase(caseItem, { FILE_IMAGES })
      })
    })

    // eslint-disable-next-line mocha/no-setup-in-describe
    scheduleActionCases.forEach((caseItem) => {
      it(`Scheduled actions: ${caseItem.initialData.template.name} - ${caseItem.initialData.template.description}`, function () {
        executeCase(caseItem, { DS_BACKUP })
      })
    })

    // eslint-disable-next-line mocha/no-setup-in-describe
    placementCases.forEach((caseItem) => {
      it(`Placement: ${caseItem.initialData.template.name} - ${caseItem.initialData.template.description}`, function () {
        executeCase(caseItem, {})
      })
    })

    // eslint-disable-next-line mocha/no-setup-in-describe
    numaCases.forEach((caseItem) => {
      it(`Numa: ${caseItem.initialData.template.name} - ${caseItem.initialData.template.description}`, function () {
        executeCase(caseItem, {})
      })
    })

    // eslint-disable-next-line mocha/no-setup-in-describe
    backupCases.forEach((caseItem) => {
      it(`Backup: ${caseItem.initialData.template.name} - ${caseItem.initialData.template.description}`, function () {
        executeCase(caseItem, {})
      })
    })
  })
})
