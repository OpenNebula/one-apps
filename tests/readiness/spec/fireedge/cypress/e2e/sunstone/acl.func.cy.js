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
import { adminContext } from '@utils/constants'
import {
  aclStringGUIAndValidate,
  aclGUIAndValidate,
  deleteGUI,
  validateViews,
} from '@common/acls'

// Rules to create with the create from from string
const stringRules = [
  {
    rule: '#0 VM+HOST/* USE+ADMIN',
    result: '#0 VM+HOST/* USE+ADMIN #0',
  },
  {
    rule: '#1 IMAGE/* USE',
    result: '#1 IMAGE/* USE #0',
  },
  {
    rule: '* MARKETPLACEAPP+BACKUPJOB/#1 USE+MANAGE #0',
    result: '* MARKETPLACEAPP+BACKUPJOB/#1 USE+MANAGE #0',
  },
  {
    rule: '@0 USER+GROUP+VDC/* CREATE+USE *',
    result: '@0 USER+GROUP+VDC/* USE+CREATE *',
  },
  {
    rule: '@1 NET/%0 USE',
    result: '@1 NET/%0 USE #0',
  },
]

// Rules to create with the wizard form
const rules = [
  {
    rule: {
      user: {
        type: 'INDIVIDUAL',
        id: '0',
      },
      resources: ['VM', 'USER'],
      resourcesIdentifier: {
        type: 'INDIVIDUAL',
        id: '5',
      },
      rights: ['USE', 'CREATE'],
      zone: {
        type: 'INDIVIDUAL',
        id: '0',
      },
    },
    summary: '#0 VM+USER/#5 USE+CREATE #0',
    result: '#0 VM+USER/#5 USE+CREATE #0',
  },
  {
    rule: {
      user: {
        type: 'INDIVIDUAL',
        id: '0',
      },
      resources: ['VM', 'USER', 'TEMPLATE'],
      resourcesIdentifier: {
        type: 'GROUP',
        id: '1',
      },
      rights: ['ADMIN', 'CREATE'],
      zone: {
        type: 'ALL',
      },
    },
    summary: '#0 VM+TEMPLATE+USER/@1 ADMIN+CREATE *',
    result: '#0 VM+USER+TEMPLATE/@1 ADMIN+CREATE *',
  },
  {
    rule: {
      user: {
        type: 'ALL',
      },
      resources: ['HOST'],
      resourcesIdentifier: {
        type: 'CLUSTER',
        id: '0',
      },
      rights: ['USE'],
    },
    summary: '* HOST/%0 USE',
    result: '* HOST/%0 USE #0',
  },
  {
    rule: {
      user: {
        type: 'GROUP',
        id: '1',
      },
      resources: ['TEMPLATE', 'VNTEMPLATE'],
      resourcesIdentifier: {
        type: 'ALL',
      },
      rights: ['CREATE', 'MANAGE'],
    },
    summary: '@1 TEMPLATE+VNTEMPLATE/* MANAGE+CREATE',
    result: '@1 TEMPLATE+VNTEMPLATE/* MANAGE+CREATE #0',
  },
]

// Rule to delete it
const deleteRule = {
  rule: '#0 BACKUPJOB/* USE+CREATE *',
}

// Rule to validate views
const validateRule = {
  rule: '#0 TEMPLATE+DATASTORE+VNTEMPLATE/#1 USE+CREATE #0',
  user: 'oneadmin',
  resources: ['TEMPLATE', 'VNTEMPLATE', 'DATASTORE'],
  resourcesIdentifier: 'Identifier #1',
  rights: ['USE', 'CREATE'],
  zone: 'OpenNebula',
  cli: {
    user: '#0',
    resources: '-----T-D---------t-',
    resourcesIdentifier: '#1',
    rights: 'u--c',
    zone: '#0',
  },
  readable:
    'Rule allow user with id 0 the right to perform USE and CREATE operations over all TEMPLATE and DATASTORE and VNTEMPLATE with identifier 1 in the zone 0',
}

describe('Sunstone GUI in ACLs tab', function () {
  context('Oneadmin', adminContext, function () {
    before(function () {
      cy.fixture('auth')
        .then((auth) => cy.apiAuth(auth.admin))
        .then(() => cy.cleanup())
    })

    beforeEach(function () {
      cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
        qs: { externalToken: Cypress.env('TOKEN') },
      })
    })

    // eslint-disable-next-line mocha/no-setup-in-describe
    stringRules.forEach((rule) =>
      it(`Should create acl: ${rule.rule} with STRING GUI and validate it`, function () {
        aclStringGUIAndValidate(rule)
      })
    )

    // eslint-disable-next-line mocha/no-setup-in-describe
    rules.forEach((rule) =>
      it(`Should create acl: ${rule.result} with GUI and validate it`, function () {
        aclGUIAndValidate(rule)
      })
    )

    it('Should delete an acl', function () {
      deleteGUI(deleteRule)
    })

    it('Should validate card views', function () {
      validateViews(validateRule)
    })
  })
})
