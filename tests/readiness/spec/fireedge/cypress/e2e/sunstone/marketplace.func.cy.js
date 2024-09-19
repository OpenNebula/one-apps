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
import {
  beforeAllMarketplace,
  createMarketplace,
  updateMarketplace,
  deleteMarketplace,
  enabledDisabledMarketplace,
  changeOwnerGroupMarketplace,
  afterAllMarketplace,
} from '@common/marketplace'

import { adminContext } from '@utils/constants'
import { Group, User } from '@models'

const MARKETPLACE_CREATE = {
  data: {
    general: {
      name: 'marketplace ONE',
      description: 'description marketplace ONE',
      type: 'OpenNebula Systems',
    },
    configuration: {
      endpoint: 'http://opennebula.systems.tests',
    },
  },
  expectedTemplate: {
    NAME: 'marketplace ONE',
    MARKET_MAD: 'one',
    TEMPLATE: {
      ENDPOINT: 'http://opennebula.systems.tests',
      MARKET_MAD: 'one',
      DESCRIPTION: 'description marketplace ONE',
    },
  },
}

const MARKETPLACE_UPDATE = {
  initialData: {
    data: {
      general: {
        name: 'marketplace update',
        description: 'description marketplace update',
        type: 'OpenNebula Systems',
      },
      configuration: {
        endpoint: 'http://opennebula.systems.tests',
      },
    },
  },
  updates: [
    {
      data: {
        general: {
          name: 'marketplace01',
          type: 'HTTP',
          description: 'description marketplace01',
        },
        configuration: {
          baseUrl: 'http://marketplace.com',
          path: '/home/marketplace',
          bridgeList: ['serverOne', 'serverTwo', 'serverThree'],
        },
      },
      expectedTemplate: {
        NAME: 'marketplace01',
        MARKET_MAD: 'http',
        TEMPLATE: {
          MARKET_MAD: 'http',
          DESCRIPTION: 'description marketplace01',
          PUBLIC_DIR: '/home/marketplace',
          BASE_URL: 'http://marketplace.com',
          BRIDGE_LIST: 'serverOne serverTwo serverThree',
        },
      },
    },
    {
      data: {
        general: {
          type: 'Amazon S3',
        },
        configuration: {
          accessKey: 'accessKey',
          secretAccessKey: 'secretAccessKey',
          bucket: 'bucket',
          region: 'region',
        },
      },
      expectedTemplate: {
        NAME: 'marketplace01',
        MARKET_MAD: 's3',
        TEMPLATE: {
          MARKET_MAD: 's3',
          DESCRIPTION: 'description marketplace01',
          AWS: 'YES',
          ACCESS_KEY_ID: 'accessKey',
          SECRET_ACCESS_KEY: 'secretAccessKey',
          BUCKET: 'bucket',
          REGION: 'region',
        },
      },
    },
    {
      data: {
        general: {
          type: 'Amazon S3',
        },
        configuration: {
          size: 1024,
          length: 1,
          endpoint: 'http://s3.bucket.amazonaws.eu-west1.com',
        },
      },
      expectedTemplate: {
        NAME: 'marketplace01',
        MARKET_MAD: 's3',
        TEMPLATE: {
          MARKET_MAD: 's3',
          DESCRIPTION: 'description marketplace01',
          AWS: 'YES',
          ACCESS_KEY_ID: 'accessKey',
          SECRET_ACCESS_KEY: 'secretAccessKey',
          BUCKET: 'bucket',
          REGION: 'region',
          ENDPOINT: 'http://s3.bucket.amazonaws.eu-west1.com',
          TOTAL_MB: '1024',
          READ_LENGTH: '1',
        },
      },
    },
    {
      data: {
        general: {
          type: 'Amazon S3',
        },
        configuration: {
          accessKey: 'accessKey2',
          secretAccessKey: 'secretAccessKey2',
          bucket: 'bucket2',
          region: 'region2',
          size: 10242,
          length: 12,
          endpoint: 'http://s3.bucket.amazonaws.eu-west1.com2',
        },
      },
      expectedTemplate: {
        NAME: 'marketplace01',
        MARKET_MAD: 's3',
        TEMPLATE: {
          MARKET_MAD: 's3',
          DESCRIPTION: 'description marketplace01',
          AWS: 'YES',
          ACCESS_KEY_ID: 'accessKey2',
          SECRET_ACCESS_KEY: 'secretAccessKey2',
          BUCKET: 'bucket2',
          REGION: 'region2',
          ENDPOINT: 'http://s3.bucket.amazonaws.eu-west1.com2',
          TOTAL_MB: '10242',
          READ_LENGTH: '12',
        },
      },
    },
    {
      data: {
        general: {
          type: 'Amazon S3',
        },
        configuration: {
          aws: false,
        },
      },
      expectedTemplate: {
        NAME: 'marketplace01',
        MARKET_MAD: 's3',
        TEMPLATE: {
          MARKET_MAD: 's3',
          DESCRIPTION: 'description marketplace01',
          AWS: 'NO',
          ACCESS_KEY_ID: 'accessKey2',
          SECRET_ACCESS_KEY: 'secretAccessKey2',
          BUCKET: 'bucket2',
          REGION: 'region2',
          ENDPOINT: 'http://s3.bucket.amazonaws.eu-west1.com2',
          TOTAL_MB: '10242',
          READ_LENGTH: '12',
          SIGNATURE_VERSION: 's3',
          FORCE_PATH_STYLE: 'YES',
        },
      },
    },
    {
      data: {
        general: {
          type: 'Linux Containers',
        },
        configuration: {},
      },
      expectedTemplate: {
        NAME: 'marketplace01',
        MARKET_MAD: 'linuxcontainers',
        TEMPLATE: {
          MARKET_MAD: 'linuxcontainers',
          DESCRIPTION: 'description marketplace01',
          BASE_URL: 'https://images.linuxcontainers.org',
          PRIVILEGED: 'YES',
          SKIP_UNTESTED: 'YES',
        },
      },
    },
  ],
}

const MARKETPLACE_DELETE = {
  general: {
    name: 'marketplace delete',
  },
  configuration: {
    endpoint: 'http://opennebula.systems.tests',
  },
}

const MARKETPLACE_ENABLE_DISABLED = {
  general: {
    name: 'marketplace enabled disabled',
  },
  configuration: {
    endpoint: 'http://opennebula.systems.tests',
  },
}

const MARKETPLACE_CHANGE_OWNER_GROUP = {
  general: {
    name: 'marketplace change owner group',
  },
  configuration: {
    endpoint: 'http://opennebula.systems.tests',
  },
}

const GROUP = new Group('users')
const USER = new User('user')

describe('Sunstone GUI in MArketplace tab', function () {
  context('Oneadmin', adminContext, function () {
    before(function () {
      beforeAllMarketplace({
        marketplaces: [
          MARKETPLACE_UPDATE.initialData.data,
          MARKETPLACE_DELETE,
          MARKETPLACE_ENABLE_DISABLED,
          MARKETPLACE_CHANGE_OWNER_GROUP,
        ],
        group: GROUP,
        user: USER,
      })
    })

    beforeEach(function () {
      cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
        qs: { externalToken: Cypress.env('TOKEN') },
      })
    })

    it(`Should create marketplace and validate tabs`, function () {
      createMarketplace(MARKETPLACE_CREATE)
    })

    it(`Should update marketplace`, function () {
      updateMarketplace(MARKETPLACE_UPDATE)
    })

    it(`Should delete marketplace`, function () {
      deleteMarketplace(MARKETPLACE_DELETE)
    })

    it(`Should enable and disable marketplace and validate info tab`, function () {
      enabledDisabledMarketplace(MARKETPLACE_ENABLE_DISABLED)
    })

    it(`Should change owner and group marketplace and validate info tab`, function () {
      changeOwnerGroupMarketplace(MARKETPLACE_CHANGE_OWNER_GROUP, USER, GROUP)
    })

    after(function () {
      afterAllMarketplace()
    })
  })
})
