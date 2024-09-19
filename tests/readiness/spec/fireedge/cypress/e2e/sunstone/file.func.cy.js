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
import { adminContext, userContext } from '@utils/constants'

import {
  afterAllFileTest,
  beforeAllFileTest,
  beforeEachFileTest,
  changeFileGroup,
  changeFileOwnership,
  changeFilePermissions,
  createFile,
  deleteFile,
  disableFile,
  enableFile,
  renameFile,
} from '@common/files'
import { Group, Image, User } from '@models'
import { PermissionsGui } from '@support/commands/common'

const setFiles = (user = '') => {
  const userName = user ? `_${user}` : ''

  return [
    {
      enable: new Image(`file_enable${userName}`),
      disable: new Image(`file_disable${userName}`),
      changePermission: new Image(`file_changePermission${userName}`),
      delete: new Image(`file_delete`),
      ownership: new Image(`file_ownership${userName}`),
      rename: new Image(`file_rename${userName}`),
    },
    {
      PATH: `path_file${userName}`,
      UPLOAD: `upload_file${userName}`,
    },
  ]
}

const [FILES_ADMIN, FILES_GUI_ADMIN] = setFiles('admin')
const [FILES_USER, FILES_GUI_USER] = setFiles('user')

const SERVERADMIN_USER = new User('serveradmin')
const USERS_GROUP = new Group('users')

describe('Sunstone GUI in File tab', function () {
  context('User', userContext, function () {
    before(function () {
      beforeAllFileTest(FILES_USER, true)
    })

    beforeEach(function () {
      cy.fixture('auth')
        .then((auth) => cy.apiAuth(auth.user))
        .then(() => beforeEachFileTest())
    })

    it('Should DISABLE file', function () {
      disableFile(FILES_USER.disable)
    })

    it('Should ENABLE file', function () {
      enableFile(FILES_USER.enable)
    })

    it('Should DELETE file', function () {
      deleteFile(FILES_USER.delete)
    })

    it('Should CHANGE PERMISSIONS file', function () {
      /** @type {PermissionsGui} */
      const newPermissions = {
        ownerUse: '0',
        ownerManage: '0',
        ownerAdmin: '0',
        groupUse: '1',
        groupManage: '1',
        groupAdmin: '0',
        otherUse: '1',
        otherManage: '1',
        otherAdmin: '0',
      }

      changeFilePermissions(FILES_USER.changePermission, newPermissions)
    })

    it('should RENAME file', function () {
      const newName = FILES_USER.rename.name.replace('file_', 'file_renamed_')
      renameFile(FILES_USER.rename, newName)
    })

    it('Create File GUI (path)', function () {
      createFile(FILES_GUI_USER.PATH, true)
    })

    it('Create File GUI (upload)', function () {
      createFile(FILES_GUI_USER.UPLOAD)
    })

    after(function () {
      afterAllFileTest(FILES_USER, FILES_GUI_USER)
    })
  })

  context('Oneadmin', adminContext, function () {
    before(function () {
      beforeAllFileTest(FILES_ADMIN)
    })

    beforeEach(beforeEachFileTest)

    it('Should DISABLE file', function () {
      disableFile(FILES_ADMIN.disable)
    })

    it('Should ENABLE file', function () {
      enableFile(FILES_ADMIN.enable)
    })

    it('Should DELETE file', function () {
      deleteFile(FILES_ADMIN.delete)
    })

    it('Should CHANGE PERMISSIONS file', function () {
      /** @type {PermissionsGui} */
      const newPermissions = {
        ownerUse: '0',
        ownerManage: '0',
        ownerAdmin: '1',
        groupUse: '1',
        groupManage: '1',
        groupAdmin: '1',
        otherUse: '1',
        otherManage: '1',
        otherAdmin: '1',
      }

      changeFilePermissions(FILES_ADMIN.changePermission, newPermissions)
    })

    it('Should CHANGE-OWNERSHIP (user) file', function () {
      changeFileOwnership(FILES_ADMIN.ownership, SERVERADMIN_USER)
    })

    it('Should CHANGE-OWNERSHIP (group) file', function () {
      changeFileGroup(FILES_ADMIN.ownership, USERS_GROUP)
    })

    it('should RENAME file', function () {
      const newName = FILES_ADMIN.rename.name.replace('file_', 'file_renamed_')
      renameFile(FILES_ADMIN.rename, newName)
    })

    it('Create File GUI (path)', function () {
      createFile(FILES_GUI_ADMIN.PATH, true)
    })

    it('Create File GUI (upload)', function () {
      createFile(FILES_GUI_ADMIN.UPLOAD)
    })

    after(function () {
      afterAllFileTest(FILES_ADMIN, FILES_GUI_ADMIN)
    })
  })
})
