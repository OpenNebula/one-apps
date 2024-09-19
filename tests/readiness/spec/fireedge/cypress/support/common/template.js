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
import { transformAttributes, getDiff } from '@support/utils'
import { VmTemplate } from '@models'
import { fillGeneralStep } from '@support/commands/template/create'
import {
  updateGeneral,
  updateStorage,
  updateNetwork,
  updatePcidevices,
  updateBooting,
  updateInputOutput,
  updateContext,
  updateScheduleActions,
  updatePlacement,
  updateNuma,
  updateBackup,
} from '@support/commands/template/update'

const ignoreAttributes = []

/**
 * Create resources before execute the cases.
 *
 * @param {Array} MARKET_APPS - List of market apps
 * @param {object} DATASTORE - Datastore to store images
 * @param {object} DATASTORE_FILES - Datastore to store file images
 * @param {object} DATASTORE_BACKUPS - Backup datastores
 * @param {object} APP_IMAGES - Images that will be needed on the cases
 * @param {object} FILE_IMAGES - File images that will be needed on the cases
 * @param {object} NETWORKS - Networks that will be needed on the cases
 * @param {object} HOSTS - Hosts that will be needed on the cases
 * @param {object} USERS - Users that will be needed on the cases
 */
const beforeTemplateCases = (
  MARKET_APPS,
  DATASTORE,
  DATASTORE_FILES,
  DATASTORE_BACKUPS,
  APP_IMAGES,
  FILE_IMAGES,
  NETWORKS,
  HOSTS,
  USERS
) => {
  cy.fixture('auth')
    .then((auth) => cy.apiAuth(auth.admin))
    .then(() => cy.cleanup())
    .then(() => {
      cy.cleanup({
        templates: {
          NAMES: ['caseBasic'],
        },
      })
    })
    .then(() => DATASTORE.info())
    .then(() => DATASTORE_FILES.info())
    .then(() => {
      MARKET_APPS.forEach((marketapp) => {
        marketapp.info().then(() => {
          marketapp.exportApp({
            associated: true,
            datastore: DATASTORE.id,
            name: marketapp.name,
            vmname: marketapp.name,
          })
        })
      })
    })
    .then(() => {
      Object.entries(DATASTORE_BACKUPS).forEach(([key, value]) => {
        value.datastore.allocate({
          cluster: 0,
          template: value.template,
        })
      })
    })
    .then(() => {
      Object.entries(DATASTORE_BACKUPS).forEach(([key, value]) => {
        value.datastore.info()
      })
    })
    .then(() => {
      Object.entries(APP_IMAGES).forEach(([key, value]) => {
        value.info()
      })
    })
    .then(() => {
      Object.entries(FILE_IMAGES).forEach(([key, value]) => {
        value.image.info().then(() => {
          value.image.delete(true)
        })
      })
    })
    .then(() => {
      Object.entries(FILE_IMAGES).forEach(([key, value]) => {
        value.image.allocate({
          datastore: DATASTORE_FILES.id,
          template: value.template,
        })
      })
    })
    .then(() => {
      Object.entries(NETWORKS).forEach(([key, value]) => {
        value.allocate({
          template: { NAME: key, VN_MAD: 'dummy', BRIDGE: 'br0' },
        })
      })
    })
    .then(() => {
      Object.entries(NETWORKS).forEach(([key, value]) => {
        value.info()
      })
    })
    .then(() => {
      Object.entries(HOSTS).forEach(([key, value]) => {
        value.allocate({ hostname: key, imMad: key, vmmMad: key })
      })
    })
    .then(() => {
      Object.entries(HOSTS).forEach(([key, value]) => {
        value.waitMonitored()
      })
    })
    .then(() => {
      Object.entries(USERS).forEach(([key, value]) => {
        value.allocate({ username: key, password: 'opennebula', group: ['1'] })
      })
    })
}

/**
 * Check restricted attributes.
 *
 * @param {object} template - Template to check.
 * @param {boolean} admin - If the user belongs to oneadmin group.
 * @param {Array} restrictedAttributesException - List of attributes that won't be checked
 */
const checkRestrictedAttributes = (
  template,
  admin,
  restrictedAttributesException
) => {
  // Navigate to templates menu
  cy.navigateMenu('templates', 'VM Templates')

  // Get restricted attributes from OpenNebula config
  cy.getOneConf().then((config) => {
    // Virtual Machine restricted attributes
    const vmRestricteAttributes = transformAttributes(
      config.VM_RESTRICTED_ATTR,
      restrictedAttributesException
    )

    // Check VM restricted attributes
    cy.checkVMTemplateRestricteAttributes(
      vmRestricteAttributes,
      template,
      admin
    )
  })
}

/**
 * Execute a case creating and updatin a template.
 *
 * @param {object} templateCase - The definition of the case
 * @param {object} resources - . Resources to use in the cases
 * @param {object} resources.NETWORKS - Networks to use in the case
 * @param {object} resources.APP_IMAGES - Images to use in the case
 * @param {object} resources.FILE_IMAGES - File images to use in the case
 * @param {object} resources.DS_BACKUP - Backup datastores
 * @param {object} resources.USERS - Users to use in the case
 */
const executeCase = (
  templateCase,
  {
    APP_IMAGES = {},
    FILE_IMAGES = {},
    NETWORKS = {},
    DS_BACKUP = {},
    USERS = {},
  }
) => {
  // Prepare the template adding ids instead names of images, vnets...
  prepareTemplate(templateCase, APP_IMAGES, NETWORKS, DS_BACKUP)

  // Prepare expected templates adding ids instead names of images
  prepareExpectedTemplates(templateCase, { FILE_IMAGES, DS_BACKUP, USERS })

  // Create template object
  const template = new VmTemplate(templateCase.initialData.template.name)

  // Navigate to templates menu
  cy.navigateMenu('templates', 'VM Templates')

  // Create template with GUI
  cy.createTemplateGUI(templateCase.initialData.template)

  // Check creation template
  checkTemplates(template, templateCase.initialData.expectedTemplate)

  // Perform updates
  templateCase.updates.forEach((update, index) => {
    cy.log('Update number ' + index)

    // Navigate to templates menu
    cy.navigateMenu('templates', 'VM Templates')

    // Select template
    cy.clickTemplateRow(template, { noWait: true })

    // Click update button of the template
    cy.getBySel('action-update_dialog').click()

    // Fill general section
    if (update.general) {
      fillGeneralStep(update.general.template, true)
    }

    // Perform actions on the template advanced tabs
    update.actions.forEach((action) => {
      cy.getBySel(`step-${action.step}`).click()

      action.section === 'general' && updateGeneral(action.sectionActions)
      action.section === 'storage' &&
        updateStorage(action.sectionActions, APP_IMAGES)
      action.section === 'network' &&
        updateNetwork(action.sectionActions, NETWORKS)
      action.section === 'pci' && updatePcidevices(action.sectionActions)
      action.section === 'booting' && updateBooting(action.sectionActions)
      action.section === 'inputoutput' &&
        updateInputOutput(action.sectionActions)
      action.section === 'context' && updateContext(action.sectionActions)
      action.section === 'schedule' &&
        updateScheduleActions(action.sectionActions, DS_BACKUP)
      action.section === 'placement' && updatePlacement(action.sectionActions)
      action.section === 'numa' && updateNuma(action.sectionActions)
      action.section === 'backup' && updateBackup(action.sectionActions)
    })

    // Check in which step it is the form and click the next/finish button until the form is finished
    cy.get('body').then((body) => {
      const generalStep = body.find(`[data-cy="legend-general-information"]`)
      const extraStep = body.find(`[data-cy="tab-storage"]`)

      if (generalStep && generalStep.length > 0) {
        cy.getBySel('stepper-next-button').click()
        cy.getBySel('stepper-next-button').click()
        cy.getBySel('stepper-next-button').click()
      }

      if (extraStep && extraStep.length > 0) {
        cy.getBySel('stepper-next-button').click()
        cy.getBySel('stepper-next-button').click()
      }

      if (
        !(generalStep && generalStep.length > 0) &&
        !(extraStep && extraStep.length > 0)
      ) {
        cy.getBySel('stepper-next-button').click()
      }
    })

    // Check template after the update
    checkTemplates(template, update.expectedTemplate, index)
  })
}

/**
 * Check that the expected template is equal to the generated template.
 *
 * @param {object} template1 - Template created
 * @param {object} template2 - Template expected
 * @param {number} index - Index of the update
 */
const checkTemplates = (template1, template2, index) => {
  // Navigate to templates menu
  cy.navigateMenu('templates', 'VM Templates')

  // Get info of the created template
  template1.info()

  // Select the created template
  cy.clickTemplateRow(template1)

  // Navigate to info tab of the image
  cy.navigateTab('template').within(() => {
    // Get code element, which has the JSON template
    cy.get('code').then((data) => {
      // Get JSON and parse to object
      const templateJSON = JSON.parse(data.text())

      ignoreAttributesOnTemplate(templateJSON, template2)

      cy.log('Checking templates after update number ' + index)
      cy.log('Ignoring attributes: ', JSON.stringify(ignoreAttributes))
      cy.log('Template: ', JSON.stringify(templateJSON))
      cy.log('Expected template', JSON.stringify(template2))

      // Get difference to show on the log
      const differences = getDiff(templateJSON, template2)
      cy.log('Differences: ' + differences)

      // Check templates
      cy.wrap(templateJSON).should('deep.equal', template2)
    })
  })
}

const ignoreAttributesOnTemplate = (template1, template2) => {
  // Delete attributes that will be ignored in the templates
  ignoreAttributes.forEach((attribute) => {
    // ONE only has two levels on the templates
    if (attribute.includes('.')) {
      const parentAttribute = attribute.split('.')[0]
      const childAttribute = attribute.split('.')[1]

      if (parentAttribute in template1) {
        if (Array.isArray(template1[parentAttribute])) {
          template1[parentAttribute].forEach(
            (child) => delete child[childAttribute]
          )
        } else {
          parentAttribute in template1 &&
            delete template1[parentAttribute][childAttribute]
        }
      }

      if (parentAttribute in template2) {
        if (Array.isArray(template2[parentAttribute])) {
          template2[parentAttribute].forEach(
            (child) => delete child[childAttribute]
          )
        } else {
          parentAttribute in template2 &&
            delete template2[parentAttribute][childAttribute]
        }
      }
    } else {
      delete template1[attribute]
      delete template2[attribute]
    }
  })
}

const prepareTemplate = (templateCase, APP_IMAGES, NETWORKS, DS_BACKUP) => {
  // Add image ids in storage
  templateCase?.initialData?.template?.storage?.forEach((disk) => {
    if (disk.image) {
      disk.image = parseInt(APP_IMAGES[disk.image].json.ID)
    }
  })

  // Add vnet ids in networks
  templateCase?.initialData?.template?.networks?.forEach((vnet) => {
    if (vnet.name) vnet.id = parseInt(NETWORKS[vnet.name].json.ID)
  })

  // Add backup datastores on scheduled backup actions
  templateCase?.initialData?.template?.schedActions?.forEach((sched) => {
    if (sched.backupDs) {
      sched.action.backupDs =
        parseInt(DS_BACKUP[sched.action.backupDs].datastore.json.ID) +
        ': ' +
        sched.action.backupDs
    }
  })
}

const prepareExpectedTemplates = (
  templateCase,
  { FILE_IMAGES, DS_BACKUP, USERS }
) => {
  // DATA FOR INITIAL TEMPLATE

  // Replace INITRD_DS, KERNEL_DS and FILES_DS names by the id
  const regex = /#(.*?)#/g

  if (templateCase?.initialData?.expectedTemplate?.OS?.INITRD_DS) {
    templateCase.initialData.expectedTemplate.OS.INITRD_DS =
      templateCase?.initialData?.expectedTemplate?.OS?.INITRD_DS.replace(
        regex,
        (_, match) => {
          const idImage = FILE_IMAGES[match].image.id

          return idImage
        }
      )
  }

  if (templateCase?.initialData?.expectedTemplate?.OS?.KERNEL_DS) {
    templateCase.initialData.expectedTemplate.OS.KERNEL_DS =
      templateCase?.initialData?.expectedTemplate?.OS?.KERNEL_DS.replace(
        regex,
        (_, match) => {
          const idImage = FILE_IMAGES[match].image.id

          return idImage
        }
      )
  }

  if (templateCase?.initialData?.expectedTemplate?.CONTEXT?.FILES_DS) {
    templateCase.initialData.expectedTemplate.CONTEXT.FILES_DS =
      templateCase?.initialData?.expectedTemplate?.CONTEXT?.FILES_DS.replace(
        regex,
        (_, match) => {
          const idImage = FILE_IMAGES[match].image.id

          return idImage
        }
      )
  }

  // If exists backupDs on scheduled actions
  templateCase?.initialData?.expectedTemplate?.SCHED_ACTION?.forEach(
    (sched) => {
      if (sched.ACTION === 'backup' && sched.ARGS) {
        sched.ARGS = DS_BACKUP[sched.ARGS].datastore.json.ID
      }
    }
  )

  // User ownership
  if (templateCase?.initialData?.expectedTemplate?.AS_UID) {
    templateCase?.initialData?.expectedTemplate?.AS_UID !== '0' &&
      (templateCase.initialData.expectedTemplate.AS_UID =
        USERS[templateCase?.initialData?.expectedTemplate?.AS_UID].id)
  }

  // DATA ON UPDATES
  templateCase?.updates.forEach((update) => {
    // Replace INITRD_DS, KERNEL_DS and FILES_DS names by the id
    if (update?.expectedTemplate?.OS?.INITRD_DS) {
      update.expectedTemplate.OS.INITRD_DS =
        update?.expectedTemplate?.OS?.INITRD_DS.replace(regex, (_, match) => {
          const idImage = FILE_IMAGES[match].image.id

          return idImage
        })
    }

    if (update?.expectedTemplate?.OS?.KERNEL_DS) {
      update.expectedTemplate.OS.KERNEL_DS =
        update?.expectedTemplate?.OS?.KERNEL_DS.replace(regex, (_, match) => {
          const idImage = FILE_IMAGES[match].image.id

          return idImage
        })
    }

    if (update?.expectedTemplate?.CONTEXT?.FILES_DS) {
      update.expectedTemplate.CONTEXT.FILES_DS =
        update?.expectedTemplate?.CONTEXT?.FILES_DS.replace(
          regex,
          (_, match) => {
            const idImage = FILE_IMAGES[match].image.id

            return idImage
          }
        )
    }

    // If exists backupDs on scheduled actions
    update?.expectedTemplate?.SCHED_ACTION?.forEach((sched) => {
      if (sched.ACTION === 'backup' && sched.ARGS) {
        sched.ARGS = DS_BACKUP[sched.ARGS].datastore.json.ID
      }
    })

    // User ownership
    if (update?.expectedTemplate?.AS_UID) {
      update.expectedTemplate.AS_UID !== '0' &&
        (update.expectedTemplate.AS_UID =
          USERS[update?.expectedTemplate?.AS_UID].id)
    }
  })
}

export { checkRestrictedAttributes, executeCase, beforeTemplateCases }
