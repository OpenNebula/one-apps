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
import { Group, Image, User } from '@models'

import { FORCE } from '@support/commands/constants'
import { configSelectDatastore } from '@support/commands/datastore/jsdocs'
import { fillFileGUI, fillImageGUI } from '@support/commands/image/create'
import {
  Image as ImageDoc,
  configChangeOwnership,
  configSelectImage,
} from '@support/commands/image/jsdocs'
import { Intercepts, createIntercept } from '@support/utils'

/**
 * Change ownership image.
 *
 * @param {string} action - action
 * @returns {function(configChangeOwnership):Cypress.Chainable<Cypress.Response>} change host state response
 */
const changeOwnership =
  (action) =>
  ({ image = {}, resource = '' }) => {
    const getChangeOwn = createIntercept(Intercepts.SUNSTONE.IMAGE_CHANGE_OWN)
    const getTemplateInfo = createIntercept(Intercepts.SUNSTONE.IMAGE)
    const isChangeUser = action === 'chown'

    cy.clickImageRow(image)

    cy.getBySel('action-image-ownership').click(FORCE)
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
 * Change disable image.
 *
 * @param {string} action - action
 * @param {object} intercept - intercept
 * @returns {function(configSelectImage):Cypress.Chainable<Cypress.Response>} change image response
 */
const enableImage =
  (action, intercept) =>
  (image = {}) => {
    const getEnableImage = createIntercept(intercept)
    const getImageInfo = createIntercept(Intercepts.SUNSTONE.IMAGE)

    cy.clickImageRow(image)

    cy.getBySel('action-image-enable').click(FORCE)
    cy.getBySel(`action-${action}`).click(FORCE)

    cy.getBySel(`modal-${action}`)
      .should('exist')
      .then(($dialog) => {
        cy.wrap($dialog).find(`[data-cy=dg-accept-button]`).click(FORCE)

        return cy.wait([getEnableImage, getImageInfo])
      })
  }

/**
 * Change lock image.
 *
 * @param {string} action - action
 * @param {object} intercept - intercept
 * @returns {function(configSelectImage):Cypress.Chainable<Cypress.Response>} change image response
 */
const lockImage =
  (action, intercept) =>
  (image = {}) => {
    const getLockImage = createIntercept(intercept)
    const getImageInfo = createIntercept(Intercepts.SUNSTONE.IMAGE)

    cy.clickImageRow(image)

    cy.getBySel('action-image-lock').click(FORCE)
    cy.getBySel(`action-${action}`).click(FORCE)

    cy.getBySel(`modal-${action}`)
      .should('exist')
      .then(($dialog) => {
        cy.wrap($dialog).find(`[data-cy=dg-accept-button]`).click(FORCE)

        return cy.wait([getLockImage, getImageInfo])
      })
  }

/**
 * Delete image.
 *
 * @param {configSelectImage} image - config lock
 */
const deleteImage = (image = {}) => {
  const interceptDelete = createIntercept(Intercepts.SUNSTONE.IMAGE_DELETE)

  cy.clickImageRow(image)
  cy.getBySel('action-image_delete').click(FORCE)

  cy.getBySel(`modal-delete`)
    .should('exist')
    .then(($dialog) => {
      cy.wrap($dialog).find(`[data-cy=dg-accept-button]`).click(FORCE)

      return cy.wait(interceptDelete)
    })
}

/**
 * Performs an action on a IMAGE.
 *
 * @param {'ownership'} group - Group action name
 * @param {string} action - Action name to perform
 * @param {Function} form - Function to fill the form. By default is a confirmation dialog.
 * @returns {function(Image, any):Cypress.Chainable}
 * Chainable command to perform an action on a IMAGE
 */
const groupAction = (group, action, form) => (image, options) => {
  cy.clickImageRow(image)

  cy.getBySel(`action-image-${group}`).click(FORCE)
  cy.getBySel(`action-${action}`).click(FORCE)

  if (form) return form(image, options)

  return cy.getBySel(`modal-${action}`).within(() => {
    cy.getBySel('dg-accept-button').click(FORCE)
  })
}

/**
 * Changes Image ownership: user or group.
 *
 * @param {Image} image - VM to change owner
 * @param {object} options - Options to fill the form
 * @param {User} [options.user] - The new owner
 * @param {Group} [options.group] - The new group
 * @returns {Cypress.Chainable} Chainable command to change IMAGE owner
 */
const changeImageOwnership = (image, { user, group } = {}) =>
  cy.getBySelLike('modal-').within(() => {
    user && cy.getUserRow(user).click(FORCE)
    group && cy.getGroupRow(group).click(FORCE)
    cy.getBySel('dg-accept-button').click(FORCE)
  })

/**
 * Clone Image via GUI.
 *
 * @param {configSelectImage} image - image clone
 * @param {configSelectDatastore} datastore - datastore
 * @param {string} newname - new name
 */
const cloneImage = (image = {}, datastore = {}, newname = '') => {
  const getImageClone = createIntercept(Intercepts.SUNSTONE.IMAGE_CLONE)

  cy.clickImageRow(image)

  cy.getBySel('action-clone').click()

  cy.getBySel('modal-clone')
    .should('exist')
    .then(($dialog) => {
      cy.wrap($dialog)
        .find('[data-cy=clone-configuration-name]')
        .clear(FORCE)
        .type(newname)
      cy.wrap($dialog).find('[data-cy=stepper-next-button]').click(FORCE)
      cy.getDatastoreRow(datastore).click(FORCE)
      cy.wrap($dialog).find('[data-cy=stepper-next-button]').click(FORCE)

      return cy.wait(getImageClone)
    })
}

/**
 * Create Image via GUI.
 *
 * @param {ImageDoc} image - template
 * @returns {Cypress.Chainable<Cypress.Response>} create image response
 */
const createImageGUI = (image) => {
  const interceptImageAllocate = createIntercept(
    Intercepts.SUNSTONE.IMAGE_ALLOCATE
  )
  cy.getBySel('action-image_create_dialog').click()

  fillImageGUI(image)

  cy.getBySel('stepper-next-button').click(FORCE)

  return cy.wait(interceptImageAllocate)
}

/**
 * Create File via GUI.
 *
 * @param {ImageDoc} image - template
 * @returns {Cypress.Chainable<Cypress.Response>} create image response
 */
const createFileGUI = (image) => {
  const interceptImageAllocate = createIntercept(
    Intercepts.SUNSTONE.IMAGE_ALLOCATE
  )
  cy.getBySel('action-file_create_dialog').click()

  fillFileGUI(image)

  cy.getBySel('stepper-next-button').click(FORCE)

  return cy.wait(interceptImageAllocate)
}

Cypress.Commands.add('createFileGUI', createFileGUI)
Cypress.Commands.add('createImageGUI', createImageGUI)
Cypress.Commands.add('changeOwnerImage', changeOwnership('chown'))
Cypress.Commands.add('changeGroupImage', changeOwnership('chgrp'))
Cypress.Commands.add(
  'enableImage',
  enableImage('enable', Intercepts.SUNSTONE.IMAGE_ENABLE)
)
Cypress.Commands.add(
  'disableImage',
  enableImage('disable', Intercepts.SUNSTONE.IMAGE_ENABLE)
)
Cypress.Commands.add(
  'persistentImage',
  enableImage('persistent', Intercepts.SUNSTONE.IMAGE_PERSISTENT)
)
Cypress.Commands.add(
  'nonPersistentImage',
  enableImage('nonpersistent', Intercepts.SUNSTONE.IMAGE_PERSISTENT)
)
Cypress.Commands.add(
  'lockImage',
  lockImage('lock', Intercepts.SUNSTONE.IMAGE_LOCK)
)
Cypress.Commands.add(
  'unlockImage',
  lockImage('unlock', Intercepts.SUNSTONE.IMAGE_UNLOCK)
)
Cypress.Commands.add(
  'changeImageOwner',
  groupAction('ownership', 'chown', changeImageOwnership)
)
Cypress.Commands.add(
  'changeImageGroup',
  groupAction('ownership', 'chgrp', changeImageOwnership)
)
Cypress.Commands.add('deleteImage', deleteImage)
Cypress.Commands.add('cloneImage', cloneImage)
