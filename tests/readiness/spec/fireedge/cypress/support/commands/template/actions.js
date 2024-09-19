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
  VmTemplate as VmTemplateDoc,
  configSelectTemplate,
  configChangeOwnership,
} from '@support/commands/template/jsdocs'
import { createIntercept, Intercepts, accessAttribute } from '@support/utils'
import { FORCE } from '@support/commands/constants'
import { fillTemplateGUI } from '@support/commands/template/create'
import { checkTemplateGUI } from '@support/commands/template/attributes'
import { VmTemplate, Marketplace } from '@models'

/**
 * Create Template via GUI.
 *
 * @param {VmTemplateDoc} templateTest - template
 * @returns {Cypress.Chainable<Cypress.Response>} create template response
 */
const createTemplate = (templateTest) => {
  const interceptTemplateAllocate = createIntercept(
    Intercepts.SUNSTONE.TEMPLATE_ALLOCATE
  )
  cy.getBySel('action-create_dialog').click()

  fillTemplateGUI(templateTest)

  cy.getBySel('stepper-next-button').click(FORCE)

  return cy.wait(interceptTemplateAllocate)
}

/**
 * Create Template via GUI.
 *
 * @param {object} templateTest - template
 * @param {Array} validateList - List of attributes to validate
 * @param {object} template - Template object
 */
const createTemplateAndValidate = (templateTest, validateList, template) => {
  // Start create dialog
  cy.getBySel('action-create_dialog').click()

  // Fill template info
  fillTemplateGUI(templateTest)

  // Click next button to create template
  cy.getBySel('stepper-next-button').click(FORCE)

  // Navigate to templates menu
  cy.navigateMenu('templates', 'VM Templates')

  // Get info of the created template
  template.info()

  // Select the created template
  cy.clickTemplateRow(template)

  // Navigate to info tab of the image
  cy.navigateTab('template').within(() => {
    // Get code element, which has the JSON template
    cy.get('code').then((data) => {
      // Get JSON and parse to object
      const templateJSON = JSON.parse(data.text())

      // Validate each field of validateList array
      validateList.forEach((element) => {
        // Validate each field
        expect(accessAttribute(templateJSON, element.field)).eq(element.value)
      })
    })
  })
}

/**
 * Update Template via GUI.
 *
 * @param {configSelectTemplate} templateInfo - template Info
 * @param {VmTemplateDoc} templateTest - template
 * @returns {Cypress.Chainable<Cypress.Response>} A promise that resolves to template update
 */
const updateTemplate = (templateInfo = {}, templateTest = {}) => {
  const interceptTemplateUpdate = createIntercept(
    Intercepts.SUNSTONE.TEMPLATE_UPDATE
  )
  cy.clickTemplateRow(templateInfo)

  cy.getBySel('action-update_dialog').click()

  fillTemplateGUI(templateTest, true)
  cy.getBySel('stepper-next-button').click(FORCE)

  return cy.wait(interceptTemplateUpdate)
}

/**
 * Validate clone template.
 *
 * @param {configSelectTemplate} templateInfo - template info
 * @param {string} newname - new name
 */
const cloneTemplate = (templateInfo = {}, newname = '') => {
  const getTemplateClone = createIntercept(Intercepts.SUNSTONE.TEMPLATE_CLONE)

  cy.clickTemplateRow(templateInfo)

  cy.getBySel('action-clone').click()

  cy.getBySel('modal-clone')
    .should('exist')
    .then(($dialog) => {
      cy.wrap($dialog).find('[data-cy=form-dg-name]').clear(FORCE).type(newname)
      cy.wrap($dialog).find('[data-cy=dg-accept-button]').click(FORCE)

      return cy.wait(getTemplateClone)
    })
}

/**
 * Change ownership template.
 *
 * @param {string} action - action
 * @returns {function(configChangeOwnership):Cypress.Chainable<Cypress.Response>} change host state response
 */
const changeOwnership =
  (action) =>
  ({ templateInfo = {}, resource = '' }) => {
    const getChangeOwn = createIntercept(
      Intercepts.SUNSTONE.TEMPLATE_CHANGE_OWN
    )
    const getTemplateInfo = createIntercept(Intercepts.SUNSTONE.TEMPLATE)
    const isChangeUser = action === 'chown'

    cy.clickTemplateRow(templateInfo)

    cy.getBySel('action-template-ownership').click(FORCE)
    cy.getBySel(`action-${action}`).click(FORCE)

    cy.getBySel(`modal-${action}`)
      .should('exist')
      .then(($dialog) => {
        if (isChangeUser) {
          cy.getUserRow(resource).click(FORCE)
        } else {
          cy.getGroupRow(resource).click(FORCE)
        }

        cy.wrap($dialog).find(`[data-cy=dg-accept-button]`).click(FORCE)

        return cy.wait([getChangeOwn, getTemplateInfo])
      })
  }

/**
 * Change share template.
 *
 * @param {boolean} share - share
 * @returns {function(configSelectTemplate):Cypress.Chainable<Cypress.Response>} change host state response
 */
const shareTemplate =
  (share) =>
  (templateInfo = {}) => {
    const getChangeMod = createIntercept(
      Intercepts.SUNSTONE.TEMPLATE_CHANGE_MOD
    )
    const getTemplateInfo = createIntercept(Intercepts.SUNSTONE.TEMPLATE)

    const action = share ? 'share' : 'unshare'

    cy.clickTemplateRow(templateInfo)

    cy.getBySel('action-template-ownership').click(FORCE)
    cy.getBySel(`action-${action}`).click(FORCE)
    cy.getBySel(`modal-${action}`)
      .should('exist')
      .then(($dialog) => {
        cy.wrap($dialog).find(`[data-cy=dg-accept-button]`).click(FORCE)

        return cy.wait([getChangeMod, getTemplateInfo])
      })
  }

/**
 * Change lock template.
 *
 * @param {boolean} lock - lock
 * @returns {function(configSelectTemplate):Cypress.Chainable<Cypress.Response>} change host state response
 */
const lockTemplate =
  (lock) =>
  (templateInfo = {}) => {
    const getLockTemplate = createIntercept(
      lock
        ? Intercepts.SUNSTONE.TEMPLATE_LOCK
        : Intercepts.SUNSTONE.TEMPLATE_UNLOCK
    )
    const getTemplateInfo = createIntercept(Intercepts.SUNSTONE.TEMPLATE)

    const action = lock ? 'lock' : 'unlock'
    cy.clickTemplateRow(templateInfo)

    cy.getBySel('action-template-lock').click(FORCE)
    cy.getBySel(`action-${action}`).click(FORCE)

    cy.getBySel(`modal-${action}`)
      .should('exist')
      .then(($dialog) => {
        cy.wrap($dialog).find(`[data-cy=dg-accept-button]`).click(FORCE)

        return cy.wait([getLockTemplate, getTemplateInfo])
      })
  }

/**
 * Delete template.
 *
 * @param {configSelectTemplate} templateInfo - config lock
 */
const deleteTemplate = (templateInfo = {}) => {
  const interceptDelete = createIntercept(Intercepts.SUNSTONE.TEMPLATE_DELETE)

  cy.clickTemplateRow(templateInfo)
  cy.getBySel('action-delete').click(FORCE)

  cy.getBySel(`modal-delete`)
    .should('exist')
    .then(($dialog) => {
      cy.wrap($dialog).find(`[data-cy=form-dg-image]`).click(FORCE)
      cy.wrap($dialog).find(`[data-cy=dg-accept-button]`).click(FORCE)

      return cy.wait(interceptDelete)
    })
}

/**
 * Create Marketplace App from VM Template.
 *
 * @param {string} name - Name of the new Marketplace App
 * @param {VmTemplate} vmTemplate - Vm Template
 * @param {Marketplace} marketplace - Marketplace
 * @returns {Cypress.Chainable<Cypress.Response>} A promise that resolves to marketapp import
 */
const createAppFromTemplate = (name, vmTemplate, marketplace) => {
  const interceptImport = createIntercept(
    Intercepts.SUNSTONE.MARKETAPP_VMIMPORT
  )

  cy.clickTemplateRow(vmTemplate)
  cy.getBySel('action-create_app_dialog').click(FORCE)
  cy.getBySel('configuration-vmname').clear().type(name)

  cy.clickTemplateRow(vmTemplate, { noWait: true })
  cy.getBySel('stepper-next-button').click(FORCE)

  cy.clickMarketplaceRow(marketplace, { noWait: true })
  cy.getBySel('stepper-next-button').click()

  return cy.wait(interceptImport)
}

/**
 * Check the vm restricted attributes on a template.
 *
 * @param {object} restrictedAttributes - Map of restricted attributes
 * @param {object} templateInfo - Template to check
 * @param {boolean} admin - If the user belongs to oneadmin group.
 */
const checkVMTemplateRestricteAttributes = (
  restrictedAttributes,
  templateInfo,
  admin
) => {
  // Check disabled or not depending if the user is an admin
  const check = admin ? 'not.be.disabled' : 'be.disabled'

  // Get info template
  templateInfo.info().then(() => {
    // Click on the template
    cy.clickTemplateRow(templateInfo)

    // Click on update button
    cy.getBySel('action-update_dialog').click()

    // Ensure that the form is loaded before checking the fields
    cy.getBySel('legend-general-information').then(() => {
      // Check the template
      checkTemplateGUI(restrictedAttributes, check, templateInfo)
    })
  })
}

Cypress.Commands.add('createTemplateGUI', createTemplate)
Cypress.Commands.add('createTemplateGUIAndValidate', createTemplateAndValidate)
Cypress.Commands.add('updateTemplateGUI', updateTemplate)
Cypress.Commands.add('cloneTemplateGUI', cloneTemplate)
Cypress.Commands.add('changeOwnerTemplate', changeOwnership('chown'))
Cypress.Commands.add('changeGroupTemplate', changeOwnership('chgrp'))
Cypress.Commands.add('shareTemplate', shareTemplate(true))
Cypress.Commands.add('unshareTemplate', shareTemplate(false))
Cypress.Commands.add('lockTemplate', lockTemplate(true))
Cypress.Commands.add('unlockTemplate', lockTemplate(false))
Cypress.Commands.add('deleteTemplate', deleteTemplate)
Cypress.Commands.add('createAppFromTemplate', createAppFromTemplate)
Cypress.Commands.add(
  'checkVMTemplateRestricteAttributes',
  checkVMTemplateRestricteAttributes
)
