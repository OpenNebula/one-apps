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
import { expectedTemplateMandatoryValues } from './utils'

const caseBackup = {
  initialData: {
    template: {
      name: 'caseBackup',
      hypervisor: 'kvm',
      description: 'Create a template with backup',
      memory: 248,
      cpu: 0.1,
      backupConfig: {
        backupVolatile: true,
        fsFreeze: 'None',
        keepLast: '2',
        mode: 'Increment',
        incrementMode: 'CBT',
      },
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create a template with backup',
        'kvm',
        '248'
      ),
      BACKUP_CONFIG: {
        BACKUP_VOLATILE: 'YES',
        FS_FREEZE: 'NONE',
        KEEP_LAST: '2',
        MODE: 'INCREMENT',
        INCREMENT_MODE: 'CBT',
      },
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'backup',
          sectionActions: [
            {
              type: 'update',
              template: {
                fsFreeze: 'QEMU Agent',
                keepLast: '3',
                incrementMode: 'Snapshot',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with backup',
          'kvm',
          '248'
        ),
        BACKUP_CONFIG: {
          BACKUP_VOLATILE: 'YES',
          FS_FREEZE: 'AGENT',
          KEEP_LAST: '3',
          MODE: 'INCREMENT',
          INCREMENT_MODE: 'SNAPSHOT',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'backup',
          sectionActions: [
            {
              type: 'update',
              template: {
                mode: '-',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with backup',
          'kvm',
          '248'
        ),
        BACKUP_CONFIG: {
          BACKUP_VOLATILE: 'YES',
          FS_FREEZE: 'AGENT',
          KEEP_LAST: '3',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'backup',
          sectionActions: [
            {
              type: 'update',
              template: {
                backupVolatile: false,
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with backup',
          'kvm',
          '248'
        ),
        BACKUP_CONFIG: {
          BACKUP_VOLATILE: 'NO',
          FS_FREEZE: 'AGENT',
          KEEP_LAST: '3',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'backup',
          sectionActions: [
            {
              type: 'update',
              template: {
                fsFreeze: '-',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with backup',
          'kvm',
          '248'
        ),
        BACKUP_CONFIG: {
          BACKUP_VOLATILE: 'NO',
          KEEP_LAST: '3',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'backup',
          sectionActions: [
            {
              type: 'update',
              template: {
                fsFreeze: 'Suspend',
                mode: 'Full',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with backup',
          'kvm',
          '248'
        ),
        BACKUP_CONFIG: {
          BACKUP_VOLATILE: 'NO',
          FS_FREEZE: 'SUSPEND',
          MODE: 'FULL',
          KEEP_LAST: '3',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'backup',
          sectionActions: [
            {
              type: 'update',
              template: {
                keepLast: '',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with backup',
          'kvm',
          '248'
        ),
        BACKUP_CONFIG: {
          BACKUP_VOLATILE: 'NO',
          FS_FREEZE: 'SUSPEND',
          MODE: 'FULL',
        },
      },
    },
  ],
}

export const backupCases = [caseBackup]
