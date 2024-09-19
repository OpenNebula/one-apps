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
const { Datastore, Image } = require('@models')
const { PermissionsGui } = require('@support/commands/common')
const { Intercepts } = require('@support/utils')

const DATASTORE = new Datastore('default')

const BASIC_IMAGE_XML = {
  SIZE: 10,
  PERSISTENT: 'NO',
  TYPE: 'OS',
  DESCRIPTION: 'Image for tests',
}

const DEV_PREFIXES = {
  vd: 'Virtio',
  sd: 'SCSI/SATA',
  hd: 'Parallel ATA (IDE)',
  custom: 'Custom',
}

const IMAGE_GUI = {
  description: 'description',
  type: 'OS',
  persistent: 'YES',
  customAttributes: {
    custom1: 'valueCustom1',
  },
  bus: DEV_PREFIXES.CUSTOM,
  device: 'device',
}

/**
 * @param {object} imagesToCreate - Images to create
 * @param {boolean} createForUser - True if the image is created for a user
 */
const beforeAllImageTest = (imagesToCreate, createForUser = false) => {
  cy.fixture('auth')
    .then((auth) => cy.apiAuth(auth.admin))
    .then(() => DATASTORE.info())
    .then(() => {
      const images = Object.values(imagesToCreate)
      const allocateFn = (image) => () => {
        const DEV_PREFIX = image.name.split('__').pop()

        return image
          .allocate({
            template: {
              ...BASIC_IMAGE_XML,
              NAME: image.name,
              bus: DEV_PREFIXES[DEV_PREFIX] || DEV_PREFIXES.custom,
              DEV_PREFIX:
                DEV_PREFIX in DEV_PREFIXES ? DEV_PREFIX : DEV_PREFIXES.custom,
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
      }

      return cy.all(...images.map(allocateFn))
    })
}

/**
 * @param {object} images - Images to delete
 * @param {object} imagesGui - Images names to delete
 */
const afterAllImageTest = (images, imagesGui) => {
  cy.then(() =>
    Object.values(images).forEach((image) => image?.delete?.())
  ).then(() => {
    const deleteFn = (img) => () => {
      const image = new Image(img)

      return image.info().then(() => image.delete())
    }

    return cy.all(...Object.values(imagesGui).map(deleteFn))
  })
}

/**
 * Function to be executed before each Virtual Network test.
 */
const beforeEachImageTest = () => {
  cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
    qs: { externalToken: Cypress.env('TOKEN') },
  })
}

/**
 * @param {object} image - Image to lock
 */
const lockImage = (image) => {
  if (image.id === undefined) return
  cy.navigateMenu('storage', 'Images')
  cy.lockImage(image).then(() =>
    cy
      .navigateTab('info')
      .within(() => cy.getBySel('locked').should('not.have.text', '-'))
  )
}

/**
 * @param {object} image - Image to lock
 */
const unlockImage = (image) => {
  if (image.id === undefined) return
  cy.navigateMenu('storage', 'Images')
  cy.unlockImage(image).then(() =>
    cy
      .navigateTab('info')
      .within(() => cy.getBySel('locked').should('have.text', '-'))
  )
}

/**
 * @param {object} image - Image to enable
 */
const enableImage = (image) => {
  if (image.id === undefined) return
  cy.navigateMenu('storage', 'Images')
  cy.enableImage(image).then(() => cy.validateImageState('READY'))
}

/**
 * @param {object} image - Image to disable
 */
const disableImage = (image) => {
  if (image.id === undefined) return
  cy.navigateMenu('storage', 'Images')
  cy.disableImage(image).then(() => cy.validateImageState('DISABLED'))
}

/**
 * @param {object} image - Image to make persistent
 */
const makePersistentImage = (image) => {
  if (image.id === undefined) return
  cy.navigateMenu('storage', 'Images')
  cy.persistentImage(image).then(() =>
    cy
      .navigateTab('info')
      .within(() => cy.getBySel('persistent').should('have.text', 'Yes'))
  )

  // Get image id
  image.info()

  // Select row of the created image
  cy.getImageRow(image).then((row) =>
    cy.wrap(row).should('contain', 'Persistent')
  )
}

/**
 * @param {object} image - Image to make non persistent
 */
const makeNonPersistentImage = (image) => {
  if (image.id === undefined) return
  cy.navigateMenu('storage', 'Images')
  cy.nonPersistentImage(image).then(() =>
    cy
      .navigateTab('info')
      .within(() => cy.getBySel('persistent').should('have.text', 'No'))
  )

  // Get image id
  image.info()

  // Select row of the created image
  cy.getImageRow(image).then((row) =>
    cy.wrap(row).should('contain', 'Non Persistent')
  )
}

/**
 * @param {object} image - Image to make non persistent
 */
const deleteImage = (image) => {
  if (image.id === undefined) return
  cy.navigateMenu('storage', 'Images')
  cy.deleteImage(image)
    .its('response.body.id')
    .should('eq', 200)
    .then(() => {
      cy.getImageTable({ search: image.name }).within(() => {
        cy.get(`[role='row'][data-cy$='${image.id}']`).should('not.exist')
      })
    })
}

/**
 * @param {object} image - Image to make non persistent
 * @param {PermissionsGui} permissions - Permissions to change
 */
const changeImagePermissions = (image, permissions) => {
  if (image.id === undefined) return
  cy.navigateMenu('storage', 'Images')
  cy.clickImageRow(image)
    .then(() =>
      cy.changePermissions(permissions, Intercepts.SUNSTONE.IMAGE_CHANGE_MOD)
    )
    .then(() => cy.validatePermissions(permissions))
}

/**
 * @param {object} image - Image to change ownership
 * @param {object} newOwner - New owner
 */
const changeImageOwnership = (image, newOwner) => {
  if (image.id === undefined) return
  cy.navigateMenu('storage', 'Images')
  cy.all(() => newOwner.info())
    .then(() => cy.changeImageOwner(image, { user: newOwner }))
    .then(() => {
      cy.navigateTab('info').within(() => {
        cy.getBySel('owner').should('have.text', newOwner.name)
      })
    })
}

/**
 * @param {object} image - Image to change ownership
 * @param {object} newGroup - New group
 */
const changeImageGroup = (image, newGroup) => {
  if (image.id === undefined) return
  cy.navigateMenu('storage', 'Images')
  cy.all(() => newGroup.info())
    .then(() => cy.changeImageGroup(image, { group: newGroup }))
    .then(() => {
      cy.navigateTab('info').within(() => {
        cy.getBySel('group').should('have.text', newGroup.name)
      })
    })
}

/**
 * @param {object} image - Image to rename
 * @param {string} newName - New name
 */
const renameImage = (image, newName) => {
  if (image.id === undefined) return

  cy.navigateMenu('storage', 'Images')
  cy.clickImageRow(image)
    .then(() => cy.renameResource(newName))
    .then(() => (image.name = newName))
    .then(() => cy.getImageRow(image).contains(newName))
}

/**
 * @param {object} image - Image to clone
 * @param {string} cloneName - Clone name
 */
const cloneImage = (image, cloneName) => {
  if (image.id === undefined) return
  cy.navigateMenu('storage', 'Images')
  cy.cloneImage(image, DATASTORE, cloneName)
    .its('response.body.id')
    .should('eq', 200)
}

/**
 * @param {object} imageName - Image to create (GUI)
 * @param {object} customAttributes - Custom attributes to add
 */
const createImage = (imageName, customAttributes = {}) => {
  cy.navigateMenu('storage', 'Images')
  cy.createImageGUI({
    ...IMAGE_GUI,
    ...customAttributes,
    name: imageName,
    datastore: { id: DATASTORE.id },
  })
    .its('response.body.id')
    .should('eq', 200)
}

/**
 * Create an image and validate that image attributes were created with the right values.
 *
 * @param {object} imageName - Image to create (GUI)
 * @param {object} customAttributes - Custom attributes to add
 * @param {object} fieldsToValidate - Array of objects with field and value to validate after create the image
 */
const createImageAndValidate = (
  imageName,
  customAttributes = {},
  fieldsToValidate = []
) => {
  // Create image
  const image = new Image(imageName)

  // Navigate to Images menu
  cy.navigateMenu('storage', 'Images')

  // Create Image
  cy.createImageGUI({
    ...IMAGE_GUI,
    ...customAttributes,
    name: imageName,
    datastore: { id: DATASTORE.id },
  })

  // Get image id
  image.info()

  // Select row of the created image
  cy.clickImageRow(image)

  // Navigate to info tab of the image
  cy.navigateTab('info').within(() => {
    // Validate each field of fieldsToValidte array
    fieldsToValidate.forEach((element) => {
      // Validate one field
      cy.getBySel(element.field).should('have.text', element.value)
    })
  })
}

/**
 * Create and image and validate his card.
 *
 * @param {string} imageName - The name of the image
 * @param {object} customAttributes - Attributes of the image
 * @param {Array} fieldsToValidate - String array with values to check inside the card
 */
const createImageAndValidateCard = (
  imageName,
  customAttributes = {},
  fieldsToValidate = []
) => {
  // Create image
  const image = new Image(imageName)

  // Navigate to Images menu
  cy.navigateMenu('storage', 'Images')

  // Create Image
  cy.createImageGUI({
    ...IMAGE_GUI,
    ...customAttributes,
    name: imageName,
    datastore: { id: DATASTORE.id },
  })

  // Get image id
  image.info()

  // Select row of the created image
  cy.getImageRow(image).then((row) => {
    fieldsToValidate.forEach((field) => cy.wrap(row).should('contain', field))
  })
}

/**
 * @param {object }image - Image to verify DEV_PREFIX for
 */
const validateDevPrefix = (image) => {
  if (image.id === undefined) return
  cy.navigateMenu('storage', 'Images')
  cy.clickImageRow(image)
  cy.navigateTab('info').within(() => {
    cy.getBySel('edit-devPrefix').click({ force: true })
    cy.getBySel('text-devPrefix').should(
      'have.value',
      image.name.split('__').pop()
    )
  })
}

module.exports = {
  beforeAllImageTest,
  beforeEachImageTest,
  lockImage,
  unlockImage,
  enableImage,
  disableImage,
  makePersistentImage,
  makeNonPersistentImage,
  deleteImage,
  changeImagePermissions,
  changeImageOwnership,
  changeImageGroup,
  renameImage,
  cloneImage,
  createImage,
  afterAllImageTest,
  validateDevPrefix,
  createImageAndValidate,
  createImageAndValidateCard,
}
