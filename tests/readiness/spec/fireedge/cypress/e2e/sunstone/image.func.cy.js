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
  afterAllImageTest,
  beforeAllImageTest,
  beforeEachImageTest,
  changeImageGroup,
  changeImageOwnership,
  changeImagePermissions,
  cloneImage,
  createImage,
  deleteImage,
  disableImage,
  enableImage,
  lockImage,
  makeNonPersistentImage,
  makePersistentImage,
  renameImage,
  unlockImage,
  validateDevPrefix,
  createImageAndValidate,
  createImageAndValidateCard,
} from '@common/images'
import { Group, Image, User } from '@models'
import { PermissionsGui } from '@support/commands/common'
import { adminContext, userContext } from '@utils/constants'

const setImages = (user = '') => {
  const userName = user ? `_${user}` : ''

  return [
    {
      clone: new Image(`image_clone${userName}`),
      lock: new Image(`image_lock${userName}`),
      unlock: new Image(`image_unlock${userName}`),
      enable: new Image(`image_enable${userName}`),
      disable: new Image(`image_disable${userName}`),
      persistent: new Image(`image_persistent${userName}`),
      nonPersistent: new Image(`image_nonPersistent${userName}`),
      changePermission: new Image(`image_changePermission${userName}`),
      delete: new Image(`image_delete${userName}`),
      ownership: new Image(`image_ownership${userName}`),
      rename: new Image(`image_rename${userName}`),
      prefix_sd: new Image(`image_prefix${userName}__sd`),
      prefix_vd: new Image(`image_prefix${userName}__vd`),
      prefix_hd: new Image(`image_prefix${userName}__hd`),
      prefix_custom: new Image(`image_prefix${userName}__custom`),
    },
    {
      clone: `clone_image${userName}`,
      path: `path_image${userName}`,
      empty: `empty_disk_image${userName}`,
      emptysize: `empty_size_disk_image${userName}`,
      upload: `upload_image${userName}`,
      os: `os_image${userName}`,
      datablock: `datablock_image${userName}`,
      cdrom: `cdrom_image${userName}`,
    },
  ]
}

const [IMAGES_ADMIN, IMAGES_GUI_ADMIN] = setImages('admin')
const [IMAGES_USER, IMAGES_GUI_USER] = setImages('user')

const SERVERADMIN_USER = new User('serveradmin')
const NON_ONEADMIN_USER = new User('user')
const USERS_GROUP = new Group('users')

describe('Sunstone GUI in Image tab', function () {
  context('User', userContext, function () {
    before(function () {
      beforeAllImageTest(IMAGES_USER, true)
    })

    beforeEach(function () {
      cy.fixture('auth')
        .then((auth) => cy.apiAuth(auth.user))
        .then(() => beforeEachImageTest())
    })

    it('Should LOCK image', function () {
      lockImage(IMAGES_USER.lock)
    })

    it('Should UNLOCK image', function () {
      unlockImage(IMAGES_USER.unlock)
    })

    it('Should DISABLE image', function () {
      disableImage(IMAGES_USER.disable)
    })

    it('Should ENABLE image', function () {
      enableImage(IMAGES_USER.enable)
    })

    it('Should PERSISTENT image', function () {
      makePersistentImage(IMAGES_USER.persistent)
    })

    it('Should NON PERSISTENT image', function () {
      makeNonPersistentImage(IMAGES_USER.nonPersistent)
    })

    it('Should DELETE image', function () {
      deleteImage(IMAGES_USER.delete)
    })

    it('Should CHANGE PERMISSIONS image', function () {
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

      changeImagePermissions(IMAGES_USER.changePermission, newPermissions)
    })

    it('Should CHANGE-OWNERSHIP (user) image', function () {
      changeImageOwnership(IMAGES_USER.ownership, NON_ONEADMIN_USER)
    })

    it('Should CHANGE-OWNERSHIP (group) image', function () {
      changeImageGroup(IMAGES_USER.ownership, USERS_GROUP)
    })

    it('should RENAME image', function () {
      const newName = IMAGES_USER.rename.name.replace(
        'image_',
        'image_renamed_'
      )

      renameImage(IMAGES_USER.rename, newName)
    })

    it('should CLONE image', function () {
      cloneImage(IMAGES_USER.clone, IMAGES_GUI_USER.clone)
    })

    it('Create Image GUI (path)', function () {
      createImage(IMAGES_GUI_USER.path, {
        path: '/var/lib/one/one.db',
      })
    })

    it('Create Image GUI (size)', function () {
      createImage(IMAGES_GUI_USER.empty, {
        size: '20',
        format: 'qcow2',
        fs: 'ext3',
      })
    })

    /**
     * Create an image and verify that size is ok.
     */
    it('Create Image GUI (size) and validate size', function () {
      createImageAndValidate(
        IMAGES_GUI_USER.emptysize,
        {
          size: '2',
          format: 'qcow2',
          fs: 'ext3',
          sizeunit: 'GB',
        },
        [
          {
            field: 'size',
            value: '2 GB',
          },
        ]
      )
    })

    it('Create Image GUI (upload)', function () {
      createImage(IMAGES_GUI_USER.upload, {
        upload: 'upload_file.png',
      })
    })

    it('Create Image GUI (DATABLOCK type) and validate card', function () {
      createImageAndValidateCard(
        IMAGES_GUI_USER.datablock,
        {
          type: 'DATABLOCK',
          size: '128',
          format: 'qcow2',
          fs: 'ext3',
          sizeunit: 'MB',
          name: 'image_validate_card',
        },
        ['DATABLOCK']
      )
    })

    it('Create Image GUI (OS type) and validate card', function () {
      createImageAndValidateCard(
        IMAGES_GUI_USER.os,
        {
          type: 'OS',
          size: '128',
          format: 'qcow2',
          fs: 'ext3',
          sizeunit: 'MB',
          name: 'image_validate_card',
        },
        ['OS']
      )
    })

    it('Create Image GUI (CDROM type) and validate card', function () {
      createImageAndValidateCard(
        IMAGES_GUI_USER.cdrom,
        {
          type: 'CDROM',
          name: 'image_validate_card',
          upload: 'upload_file.png',
        },
        ['CDROM']
      )
    })

    // eslint-disable-next-line mocha/no-setup-in-describe
    Object.keys(IMAGES_USER)
      .filter((key) => key.startsWith('prefix_'))
      .forEach((imageKey) => {
        it(`user (GUI) DEV_PREFIX should be ${imageKey
          .split('_')
          .pop()} for image: ${IMAGES_USER[imageKey].name}`, function () {
          validateDevPrefix(IMAGES_USER[imageKey])
        })
      })

    after(function () {
      afterAllImageTest(IMAGES_USER, IMAGES_GUI_USER)
    })
  })

  context('Oneadmin', adminContext, function () {
    before(function () {
      beforeAllImageTest(IMAGES_ADMIN)
    })

    beforeEach(function () {
      beforeEachImageTest()
    })

    it('Should LOCK image', function () {
      lockImage(IMAGES_ADMIN.lock)
    })

    it('Should UNLOCK image', function () {
      unlockImage(IMAGES_ADMIN.unlock)
    })

    it('Should DISABLE image', function () {
      disableImage(IMAGES_ADMIN.disable)
    })

    it('Should ENABLE image', function () {
      enableImage(IMAGES_ADMIN.enable)
    })

    it('Should PERSISTENT image', function () {
      makePersistentImage(IMAGES_ADMIN.persistent)
    })

    it('Should NON PERSISTENT image', function () {
      makeNonPersistentImage(IMAGES_ADMIN.nonPersistent)
    })

    it('Should DELETE image', function () {
      deleteImage(IMAGES_ADMIN.delete)
    })

    it('Should CHANGE PERMISSIONS image', function () {
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

      changeImagePermissions(IMAGES_ADMIN.changePermission, newPermissions)
    })

    it('Should CHANGE-OWNERSHIP (user) image', function () {
      changeImageOwnership(IMAGES_ADMIN.ownership, SERVERADMIN_USER)
    })

    it('Should CHANGE-OWNERSHIP (group) image', function () {
      changeImageGroup(IMAGES_ADMIN.ownership, USERS_GROUP)
    })

    it('should RENAME image', function () {
      const newName = IMAGES_ADMIN.rename.name.replace(
        'image_',
        'image_renamed_'
      )

      renameImage(IMAGES_ADMIN.rename, newName)
    })

    it('should CLONE image', function () {
      cloneImage(IMAGES_ADMIN.clone, IMAGES_GUI_ADMIN.clone)
    })

    it('Create Image GUI (path)', function () {
      createImage(IMAGES_GUI_ADMIN.path, {
        path: '/var/lib/one/one.db',
      })
    })

    it('Create Image GUI (size)', function () {
      createImage(IMAGES_GUI_ADMIN.empty, {
        size: '20',
        format: 'qcow2',
        fs: 'ext3',
      })
    })

    /**
     * Create an image and verify that size is ok.
     */
    it('Create Image GUI (size) and validate size', function () {
      createImageAndValidate(
        IMAGES_GUI_ADMIN.emptysize,
        {
          size: '2',
          format: 'qcow2',
          fs: 'ext3',
          sizeunit: 'GB',
        },
        [
          {
            field: 'size',
            value: '2 GB',
          },
        ]
      )
    })

    it('Create Image GUI (upload)', function () {
      createImage(IMAGES_GUI_ADMIN.upload, {
        upload: 'upload_file.png',
      })
    })

    it('Create Image GUI (DATABLOCK type) and validate card', function () {
      createImageAndValidateCard(
        IMAGES_GUI_ADMIN.datablock,
        {
          type: 'DATABLOCK',
          size: '128',
          format: 'qcow2',
          fs: 'ext3',
          sizeunit: 'MB',
          name: 'image_validate_card',
        },
        ['DATABLOCK']
      )
    })

    it('Create Image GUI (OS type) and validate card', function () {
      createImageAndValidateCard(
        IMAGES_GUI_ADMIN.os,
        {
          type: 'OS',
          size: '128',
          format: 'qcow2',
          fs: 'ext3',
          sizeunit: 'MB',
          name: 'image_validate_card',
        },
        ['OS']
      )
    })

    it('Create Image GUI (CDROM type) and validate card', function () {
      createImageAndValidateCard(
        IMAGES_GUI_ADMIN.cdrom,
        {
          type: 'CDROM',
          name: 'image_validate_card',
          upload: 'upload_file.png',
        },
        ['CDROM']
      )
    })

    // eslint-disable-next-line mocha/no-setup-in-describe
    Object.keys(IMAGES_ADMIN)
      .filter((key) => key.startsWith('prefix_'))
      .forEach((imageKey) => {
        it(`admin (GUI) DEV_PREFIX should be ${imageKey
          .split('_')
          .pop()} for image: ${IMAGES_ADMIN[imageKey].name}`, function () {
          validateDevPrefix(IMAGES_ADMIN[imageKey])
        })
      })

    after(function () {
      afterAllImageTest(IMAGES_ADMIN, IMAGES_GUI_ADMIN)
    })
  })
})
