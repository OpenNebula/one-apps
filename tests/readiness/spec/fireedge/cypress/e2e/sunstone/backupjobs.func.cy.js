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
import { randomDate } from '@commands/helpers'
import {
  afterAllBackupJobsTest,
  beforeAllBackupJobTest,
  changeBackupJobsGroup,
  changeBackupJobsOwnership,
  changeBackupJobsPermissions,
  createBackupJobGUI,
  deleteBackupJob,
  lockBackupJob,
  renameBackupJob,
  unlockBackupJob,
} from '@common/backupjobs'
import {
  BackupJobs,
  Cluster,
  Datastore,
  Group,
  Host,
  MarketplaceApp,
  User,
} from '@models'
import { PermissionsGui } from '@support/commands/common'

const NON_ONEADMIN_USER = new User('serveradmin')
const USERS_GROUP = new Group('users')
const DATASTORE_NAME_BK = 'backup_ds'
const DATASTORE_NAME_IMG = 'default'
const VM_NAME = 'Ttylinux - KVM'
const BACKUPJOB_NAME_GUI = 'backupjob_gui'
const BACKUPJOB_NAME_ACTION = 'backupjob_action'
const TEMPLATE_HOST = { hostname: '9.9.9.9', imMad: 'dummy', vmmMad: 'dummy' }
const VMS = [
  {
    name: 'Vm for backupjob GUI',
  },
  {
    name: 'Vm to be added to BackupJob',
  },
  {
    name: 'vm for backupjobs actions',
  },
]
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

const BACKUPJOB_TEMPLATE = ({
  name = '',
  vms = '',
  datastore = '',
  schedActions = '',
} = {}) => {
  const template = {
    BACKUP_VMS: vms,
    BACKUP_VOLATILE: 'YES',
    DATASTORE_ID: '2',
    FS_FREEZE: 'NONE',
    KEEP_LAST: 1,
    MODE: 'FULL',
    NAME: name,
    PRIORITY: '20',
  }
  if (datastore) {
    template.DATASTORE_ID = datastore
  }

  if (schedActions) {
    template.schedActions = schedActions
  }

  return template
}

const DS_TEMPLATE = {
  TYPE: 'BACKUP_DS',
  DS_MAD: 'rsync',
  RESTIC_COMPRESION: '-',
  RSYNC_HOST: './tmp',
  RSYNC_USER: './',
  DISK_TYPE: 'block',
}

const MARKET_APP = new MarketplaceApp(VM_NAME)
const HOST = new Host()
const DATASTORE_BK = new Datastore(DATASTORE_NAME_BK)
const DATASTORE_IMG = new Datastore(DATASTORE_NAME_IMG)
const BACKUPJOB_GUI = new BackupJobs(BACKUPJOB_NAME_GUI)
const BACKUPJOB_ACTION = new BackupJobs(BACKUPJOB_NAME_ACTION)
const CLUSTER = new Cluster('default')

describe('Sunstone GUI in BackupJobs tab', function () {
  before(function () {
    beforeAllBackupJobTest({
      DATASTORE_BK,
      DATASTORE_IMG,
      DS_TEMPLATE,
      CLUSTER,
      HOST,
      TEMPLATE_HOST,
      MARKET_APP,
      VM_NAME,
      VMS,
      BACKUPJOB_ACTION,
      BACKUPJOB_NAME_ACTION,
      BACKUPJOB_TEMPLATE,
    })
  })

  beforeEach(function () {
    cy.fixture('auth').then((auth) => {
      cy.visit(`${Cypress.config('baseUrl')}/sunstone`)
      cy.login(auth.admin)
    })
  })

  after(function () {
    afterAllBackupJobsTest({ VMS, VM_NAME, HOST, BACKUPJOB_GUI })
  })

  it('Should CREATE a Backup Job GUI', function () {
    createBackupJobGUI(
      BACKUPJOB_TEMPLATE({
        name: BACKUPJOB_NAME_GUI,
        vms: VMS[0].data,
        datastore: DATASTORE_BK,
        schedActions: [
          {
            time: randomDate(),
            periodic: 'ONETIME',
          },
          {
            time: randomDate(),
            periodic: 'PERIODIC',
            repeat: 'Monthly',
            endType: 'Never',
            endValue: '3',
          },
        ],
      })
    )
  })

  it('Should LOCK Backup Job', function () {
    lockBackupJob(BACKUPJOB_ACTION)
  })

  it('Should UNLOCK Backup Job', function () {
    unlockBackupJob(BACKUPJOB_ACTION)
  })

  it('Should CHANGE PERMISSIONS Backup Job', function () {
    changeBackupJobsPermissions(BACKUPJOB_ACTION, newPermissions)
  })

  it('Should CHANGE-OWNERSHIP (user) Backup Job', function () {
    changeBackupJobsOwnership(BACKUPJOB_ACTION, NON_ONEADMIN_USER)
  })

  it('Should CHANGE-OWNERSHIP (group) Backup Job', function () {
    changeBackupJobsGroup(BACKUPJOB_ACTION, USERS_GROUP)
  })

  it('Should RENAME Backup Job', function () {
    const newName = BACKUPJOB_ACTION.name.replace(
      'backupjob_',
      'backupjob_renamed_'
    )

    renameBackupJob(BACKUPJOB_ACTION, newName)
  })

  it('Should DELETE Backup Job', function () {
    deleteBackupJob(BACKUPJOB_ACTION)
  })
})
