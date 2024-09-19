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
const { Intercepts } = require('@support/utils/index')

const FILE_GUI = {
  description: 'description file created by GUI',
  type: 'KERNEL',
}

const DATASTORE = new Datastore('files')

const PATH_FILE = '/var/tmp/fileTest'

const BASIC_FILE_XML = {
  TYPE: 'CONTEXT',
  DESCRIPTION: 'File for tests',
}

/**
 * @param {object} filesToCreate - Files to create
 * @param {boolean} createForUser - True if the file is created for a user
 */
const beforeAllFileTest = (filesToCreate, createForUser = false) => {
  cy.fixture('auth')
    .then((auth) => cy.apiAuth(auth.admin))
    .then(() => DATASTORE.info())
    .then(() => {
      cy.writeFile(PATH_FILE, 'file for tests fireedge')
      BASIC_FILE_XML.PATH = PATH_FILE
    })
    .then(() => {
      const files = Object.values(filesToCreate)
      const allocateFn = (file) => () =>
        file
          .allocate({
            template: { ...BASIC_FILE_XML, NAME: file.name },
            datastore: DATASTORE.id,
          })
          .then(
            () =>
              createForUser &&
              file.chmod({
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

      return cy.all(...files.map(allocateFn))
    })
}

/**
 * Function to be executed before each Virtual Network test.
 */
const beforeEachFileTest = () => {
  cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
    qs: { externalToken: Cypress.env('TOKEN') },
  })
}

/**
 * @param {object} files - Files to delete
 * @param {object} filesGui - File names to delete
 */
const afterAllFileTest = (files, filesGui) => {
  // comment theses lines if you want to keep the Images after the test
  cy.then(() =>
    Object.values(files).forEach((image) => image?.delete?.())
  ).then(() => {
    const deleteFn = (img) => () => {
      const image = new Image(img)

      return image.info().then(() => image.delete())
    }

    return cy.all(...Object.values(filesGui).map(deleteFn))
  })
}

/**
 * Disable a file.
 *
 * @param {object} file - File to disable
 */
const disableFile = (file) => {
  if (file.id === undefined) throw new Error('File was not created')
  cy.navigateMenu('storage', 'Files')
  cy.disableImage(file).then(() => cy.validateImageState('DISABLED'))
}

/**
 * Enable a file.
 *
 * @param {object} file - File to disable
 */
const enableFile = (file) => {
  if (file.id === undefined) throw Error('File was not created')
  cy.navigateMenu('storage', 'Files')
  cy.enableImage(file).then(() => cy.validateImageState('READY'))
}

/**
 * @param {object} file - File to delete
 */
const deleteFile = (file) => {
  if (file.id === undefined) throw Error('File was not created')
  cy.navigateMenu('storage', 'Files')
  cy.deleteImage(file)
    .its('response.body.id')
    .should('eq', 200)
    .then(() => {
      cy.getImageTable({ search: file.name }).within(() => {
        cy.get(`[role='row'][data-cy$='${file.id}']`).should('not.exist')
      })
    })
}

/**
 * @param {object} file - File to change permissions
 * @param {PermissionsGui} permissions - Permissions to change
 */
const changeFilePermissions = (file, permissions) => {
  if (file.id === undefined) throw Error('File was not created')
  cy.navigateMenu('storage', 'Files')
  cy.clickImageRow(file)
    .then(() =>
      cy.changePermissions(permissions, Intercepts.SUNSTONE.IMAGE_CHANGE_MOD)
    )
    .then(() => cy.validatePermissions(permissions))
}

/**
 * @param {object} file - File to change ownership
 * @param {object} newOwner - New owner
 */
const changeFileOwnership = (file, newOwner) => {
  if (file.id === undefined) return
  cy.navigateMenu('storage', 'Files')
  cy.all(() => newOwner.info())
    .then(() => cy.changeImageOwner(file, { user: newOwner }))
    .then(() => {
      cy.navigateTab('info').within(() => {
        cy.getBySel('owner').should('have.text', newOwner.name)
      })
    })
}

/**
 * @param {object} file - File to change ownership
 * @param {object} newGroup -  New group
 */
const changeFileGroup = (file, newGroup) => {
  if (file.id === undefined) return
  cy.navigateMenu('storage', 'Files')
  cy.all(() => newGroup.info())
    .then(() => cy.changeImageGroup(file, { group: newGroup }))
    .then(() => {
      cy.navigateTab('info').within(() => {
        cy.getBySel('group').should('have.text', newGroup.name)
      })
    })
}

/**
 * @param {object} file - File to rename
 * @param {string} newName - New name
 */
const renameFile = (file, newName) => {
  if (file.id === undefined) return

  cy.navigateMenu('storage', 'Files')
  cy.clickImageRow(file)
    .then(() => cy.renameResource(newName))
    .then(() => (file.name = newName))
    .then(() => cy.getImageRow(file).contains(newName))
}

/**
 * @param {string} fileName - Name of the file
 * @param {boolean} path - Use path instead of upload
 */
const createFile = (fileName, path = false) => {
  cy.navigateMenu('storage', 'Files')

  const fileType = path
    ? { path: '/var/lib/one/one.db' }
    : { upload: 'upload_file.png' }

  cy.createFileGUI({
    ...FILE_GUI,
    ...fileType,
    name: fileName,
    datastore: { id: DATASTORE.id },
  })
    .its('response.body.id')
    .should('eq', 200)
}

module.exports = {
  beforeAllFileTest,
  beforeEachFileTest,
  disableFile,
  enableFile,
  deleteFile,
  changeFilePermissions,
  changeFileOwnership,
  changeFileGroup,
  renameFile,
  createFile,
  afterAllFileTest,
}
