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
  // addLabelToDatastore,
  appendClusterToDatastore,
  beforeAllDatastoreTest,
  changeDatastoreCluster,
  changeDatastoreGroup,
  changeDatastoreOwnership,
  changeDatastorePermissions,
  deleteDatastore,
  // deleteLabelfromDatastore,
  disableDatastore,
  disableDatastoreFail,
  enableDatastore,
  IMAGE_DS_XML,
  // LABEL,
  renameDatastore,
  SYSTEM_DS_XML_WITH_LABELS,
  SYSTEM_DS_XML,
  createDatastore,
} from '@common/datastores'
import { Datastore, Group, User } from '@models'
import { PermissionsGui } from '@support/commands/common'

const setDatastores = (user = '') => {
  const userName = user ? `_${user}` : ''

  return [
    {
      enable: [new Datastore(`ds_enable${userName}`), SYSTEM_DS_XML],
      disable: [new Datastore(`ds_disable${userName}`), SYSTEM_DS_XML],
      disableFail: [new Datastore(`ds_disable_fail${userName}`), IMAGE_DS_XML],
      changePermission: [
        new Datastore(`ds_changePermission${userName}`),
        SYSTEM_DS_XML,
      ],
      delete: [new Datastore(`ds_delete`), SYSTEM_DS_XML],
      ownership: [new Datastore(`ds_ownership${userName}`), SYSTEM_DS_XML],
      rename: [new Datastore(`ds_rename${userName}`), SYSTEM_DS_XML],
      appendCluster: [
        new Datastore(`ds_append_cluster${userName}`),
        SYSTEM_DS_XML,
      ],
      changeCluster: [
        new Datastore(`ds_change_cluster${userName}`),
        SYSTEM_DS_XML,
      ],
      addlabel: [new Datastore(`ds_add_label${userName}`), SYSTEM_DS_XML],
      deletelabel: [
        new Datastore(`ds_remove_label${userName}`),
        SYSTEM_DS_XML_WITH_LABELS,
      ],
    },
    {
      BACKUP_RESTIC_GUI: `backup_restic_gui${userName}`,
      BACKUP_RSYNC_GUI: `backup_rsync_gui${userName}`,
      FILE_FS_SHARED_GUI: `file_fs_shared_gui${userName}`,
      FILE_FS_SSH_GUI: `file_fs_ssh_gui${userName}`,
      IMAGE_FS_SHARED_GUI: `image_fs_shared_gui${userName}`,
      IMAGE_FS_SSH_GUI: `image_fs_ssh_gui${userName}`,
      IMAGE_CEPH_GUI: `image_ceph_gui${userName}`,
      IMAGE_LVM_GUI: `image_lvm_gui${userName}`,
      IMAGE_RAW_GUI: `image_raw_gui${userName}`,
      SYSTEM_FS_SHARED_GUI: `system_fs_shared_gui${userName}`,
      SYSTEM_FS_SSH_GUI: `system_fs_ssh_gui${userName}`,
      SYSTEM_CEPH_GUI: `system_ceph_gui${userName}`,
      SYSTEM_LVM_GUI: `system_lvm_gui${userName}`,
    },
  ]
}

const [DATASTORES, DATASTORES_GUI] = setDatastores()

const SERVERADMIN_USER = new User('serveradmin')
const USERS_GROUP = new Group('users')
// const ONEADMIN = new User('oneadmin')
// const USER_LABELS = [LABEL, 'LABEL_TEST']

const TABLE_STEP = {
  stepType: 'table',
  id: '0', // Resource to be selected
  resource: 'cluster',
  searchSelector: 'clusters',
}

describe('Sunstone GUI in Datastore tab', function () {
  before(function () {
    beforeAllDatastoreTest(DATASTORES)
  })

  beforeEach(function () {
    cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
      qs: { externalToken: Cypress.env('TOKEN') },
    })
  })

  // it('Should add a label to the datastore', function () {
  //   cy.navigateMenu(null, 'settings')
  //
  //   cy.then(() => cy.addUserLabels(USER_LABELS))
  //     .then(() => ONEADMIN.info())
  //     .then((info) => {
  //       const labels = info.TEMPLATE.LABELS
  //       expect(labels).to.include(LABEL)
  //     })
  //
  //     .then(() => {
  //       const [ds] = DATASTORES.addlabel
  //       addLabelToDatastore(ds, LABEL)
  //     })
  //     .then(() => cy.removeUserLabels(USER_LABELS))
  // })

  it('Should disable datastore', function () {
    const [ds] = DATASTORES.disable
    disableDatastore(ds)
  })

  it('Should enable datastore', function () {
    const [ds] = DATASTORES.enable
    enableDatastore(ds)
  })

  it('Should fail to disable an image datastore', function () {
    const [ds] = DATASTORES.disableFail
    disableDatastoreFail(ds)
  })

  it('Should change the owner of a datastore', function () {
    const [ds] = DATASTORES.ownership
    changeDatastoreOwnership(ds, SERVERADMIN_USER)
  })

  it('Should change the group of a datastore', function () {
    const [ds] = DATASTORES.ownership
    changeDatastoreGroup(ds, USERS_GROUP)
  })

  it('Should delete a datastore', function () {
    const [ds] = DATASTORES.delete
    deleteDatastore(ds)
  })

  it('Should add the datastore to a new cluster (keeping the old cluster)', function () {
    const [ds] = DATASTORES.appendCluster
    appendClusterToDatastore(ds)
  })

  it('Should add the datastore to a new cluster (removing the old cluster)', function () {
    const [ds] = DATASTORES.changeCluster
    changeDatastoreCluster(ds)
  })

  it('Should change the permissions of a datastore', function () {
    const [ds] = DATASTORES.changePermission
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
    changeDatastorePermissions(ds, newPermissions)
  })

  it('Should rename a datastore', function () {
    const [ds] = DATASTORES.rename
    const newName = ds.name.replace('ds_', 'ds_renamed_')
    renameDatastore(ds, newName)
  })

  it('Should create a fs-shared FILE datastore', function () {
    const stepsValues = [
      {
        stepType: 'simple',
        stepId: 'general',
        TYPE: 'FILE',
        NAME: DATASTORES_GUI.FILE_FS_SHARED_GUI,
        STORAGE_BACKEND: 'fs-shared',
      },
      TABLE_STEP,
      {
        stepType: 'simple',
        stepId: 'confAttributes',
      },
      {
        stepType: 'custom',
        TEST_CUSTOM: 'TEST_CUSTOM',
      },
    ]

    createDatastore(stepsValues)
  })

  it('Should create a fs-ssh FILE datastore', function () {
    const stepsValues = [
      {
        stepType: 'simple',
        stepId: 'general',
        TYPE: 'FILE',
        NAME: DATASTORES_GUI.FILE_FS_SSH_GUI,
        STORAGE_BACKEND: 'fs-ssh',
      },
      TABLE_STEP,
      {
        stepType: 'simple',
        stepId: 'confAttributes',
      },
      {
        stepType: 'custom',
        TEST_CUSTOM: 'TEST_CUSTOM',
      },
    ]

    createDatastore(stepsValues)
  })

  it('Should create a fs-shared IMAGE datastore', function () {
    const stepsValues = [
      {
        stepType: 'simple',
        stepId: 'general',
        TYPE: 'IMAGE',
        NAME: DATASTORES_GUI.IMAGE_FS_SHARED_GUI,
        STORAGE_BACKEND: 'fs-shared',
      },
      TABLE_STEP,
      {
        stepType: 'simple',
        stepId: 'confAttributes',
      },
      {
        stepType: 'custom',
        TEST_CUSTOM: 'TEST_CUSTOM',
      },
    ]

    createDatastore(stepsValues)
  })

  it('Should create a fs-ssh IMAGE datastore', function () {
    const stepsValues = [
      {
        stepType: 'simple',
        stepId: 'general',
        TYPE: 'IMAGE',
        NAME: DATASTORES_GUI.IMAGE_FS_SSH_GUI,
        STORAGE_BACKEND: 'fs-ssh',
      },
      TABLE_STEP,
      {
        stepType: 'simple',
        stepId: 'confAttributes',
      },
      {
        stepType: 'custom',
        TEST_CUSTOM: 'TEST_CUSTOM',
      },
    ]

    createDatastore(stepsValues)
  })

  it('Should create a ceph IMAGE datastore', function () {
    const stepsValues = [
      {
        stepType: 'simple',
        stepId: 'general',
        TYPE: 'IMAGE',
        NAME: DATASTORES_GUI.IMAGE_CEPH_GUI,
        STORAGE_BACKEND: 'ceph-ceph',
      },
      TABLE_STEP,
      {
        stepType: 'simple',
        stepId: 'confAttributes',
        CEPH_USER: 'oneadmin',
        CEPH_SECRET: 'secret',
        CEPH_HOST: ['localhost', 'testhost2'],
        BRIDGE_LIST: ['testhost'],
      },
      {
        stepType: 'custom',
        TEST_CUSTOM: 'TEST_CUSTOM',
      },
    ]

    createDatastore(stepsValues)
  })

  it('Should create a LVM IMAGE datastore', function () {
    const stepsValues = [
      {
        stepType: 'simple',
        stepId: 'general',
        TYPE: 'IMAGE',
        NAME: DATASTORES_GUI.IMAGE_LVM_GUI,
        STORAGE_BACKEND: 'fs-fs_lvm',
      },
      TABLE_STEP,
      {
        stepType: 'simple',
        stepId: 'confAttributes',
      },
      {
        stepType: 'custom',
        TEST_CUSTOM: 'TEST_CUSTOM',
      },
    ]

    createDatastore(stepsValues)
  })

  it('Should create a Raw Device Mapping IMAGE datastore', function () {
    const stepsValues = [
      {
        stepType: 'simple',
        stepId: 'general',
        TYPE: 'IMAGE',
        NAME: DATASTORES_GUI.IMAGE_RAW_GUI,
        STORAGE_BACKEND: 'dev-dev',
      },
      TABLE_STEP,
      {
        stepType: 'simple',
        stepId: 'confAttributes',
      },
      {
        stepType: 'custom',
        TEST_CUSTOM: 'TEST_CUSTOM',
      },
    ]

    createDatastore(stepsValues)
  })

  it('Should create a fs-shared SYSTEM datastore', function () {
    const stepsValues = [
      {
        stepType: 'simple',
        stepId: 'general',
        TYPE: 'SYSTEM',
        NAME: DATASTORES_GUI.SYSTEM_FS_SHARED_GUI,
        STORAGE_BACKEND: 'fs-shared',
      },
      TABLE_STEP,
      {
        stepType: 'simple',
        stepId: 'confAttributes',
      },
      {
        stepType: 'custom',
        TEST_CUSTOM: 'TEST_CUSTOM',
      },
    ]

    createDatastore(stepsValues)
  })

  it('Should create a fs-ssh SYSTEM datastore', function () {
    const stepsValues = [
      {
        stepType: 'simple',
        stepId: 'general',
        TYPE: 'SYSTEM',
        NAME: DATASTORES_GUI.SYSTEM_FS_SSH_GUI,
        STORAGE_BACKEND: 'fs-ssh',
      },
      TABLE_STEP,
      {
        stepType: 'simple',
        stepId: 'confAttributes',
      },
      {
        stepType: 'custom',
        TEST_CUSTOM: 'TEST_CUSTOM',
      },
    ]

    createDatastore(stepsValues)
  })

  it('Should create a ceph SYSTEM datastore', function () {
    const stepsValues = [
      {
        stepType: 'simple',
        stepId: 'general',
        TYPE: 'SYSTEM',
        NAME: DATASTORES_GUI.SYSTEM_CEPH_GUI,
        STORAGE_BACKEND: 'ceph-ceph',
      },
      TABLE_STEP,
      {
        stepType: 'simple',
        stepId: 'confAttributes',
        CEPH_USER: 'oneadmin',
        CEPH_SECRET: 'secret',
        CEPH_HOST: ['localhost', 'testhost2'],
        BRIDGE_LIST: ['testhost'],
      },
      {
        stepType: 'custom',
        TEST_CUSTOM: 'TEST_CUSTOM',
      },
    ]

    createDatastore(stepsValues)
  })

  it('Should create a LVM SYSTEM datastore', function () {
    const stepsValues = [
      {
        stepType: 'simple',
        stepId: 'general',
        TYPE: 'SYSTEM',
        NAME: DATASTORES_GUI.SYSTEM_LVM_GUI,
        STORAGE_BACKEND: 'fs-fs_lvm',
      },
      TABLE_STEP,
      {
        stepType: 'simple',
        stepId: 'confAttributes',
      },
      {
        stepType: 'custom',
        TEST_CUSTOM: 'TEST_CUSTOM',
      },
    ]

    createDatastore(stepsValues)
  })

  it('Should create a restic BACKUP datastore', function () {
    const stepsValues = [
      {
        stepType: 'simple',
        stepId: 'general',
        TYPE: 'BACKUP',
        NAME: DATASTORES_GUI.BACKUP_RESTIC_GUI,
        STORAGE_BACKEND: 'restic',
      },
      TABLE_STEP,
      {
        stepType: 'simple',
        stepId: 'confAttributes',
        RESTIC_PASSWORD: 'opennebula',
        RESTIC_SFTP_SERVER: 'localhost',
      },
      {
        stepType: 'custom',
        TEST_CUSTOM: 'TEST_CUSTOM',
      },
    ]

    createDatastore(stepsValues)
  })

  it('Should create a rsync BACKUP datastore', function () {
    const stepsValues = [
      {
        stepType: 'simple',
        stepId: 'general',
        TYPE: 'BACKUP',
        NAME: DATASTORES_GUI.BACKUP_RSYNC_GUI,
        STORAGE_BACKEND: 'rsync',
      },
      TABLE_STEP,
      {
        stepType: 'simple',
        stepId: 'confAttributes',
        RSYNC_HOST: 'localhost',
        RSYNC_USER: 'oneadmin',
      },
      {
        stepType: 'custom',
        TEST_CUSTOM: 'TEST_CUSTOM',
      },
    ]

    createDatastore(stepsValues)
  })

  it('Should cleanup allocated resources...', function () {
    cy.cleanup()
  })
})
