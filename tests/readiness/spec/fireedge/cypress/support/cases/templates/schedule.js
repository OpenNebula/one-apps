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
import { randomDate, addOneYear } from '@commands/helpers'

// Date2 cannot use the same year as date1 because the MUI component doesn't react to click in the same year
const date1 = randomDate()
const date2 = randomDate(date1.year)
const dateAfter2 = addOneYear(date2)

const caseOneTime = {
  initialData: {
    template: {
      name: 'caseOneTime',
      hypervisor: 'kvm',
      description: 'Create a template with one time',
      memory: 248,
      cpu: 0.1,
      schedActions: [
        {
          action: 'Hold',
          periodic: 'ONETIME',
          time: date1,
        },
        {
          action: 'Hold',
          periodic: 'ONETIME',
          time: date1,
        },
      ],
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create a template with one time',
        'kvm',
        '248'
      ),
      SCHED_ACTION: [
        {
          ACTION: 'hold',
          TIME: date1.epoch,
        },
        {
          ACTION: 'hold',
          TIME: date1.epoch,
        },
      ],
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'schedule',
          sectionActions: [
            {
              type: 'delete',
              id: 0,
            },
            {
              type: 'create',
              template: {
                action: 'Stop',
                periodic: 'ONETIME',
                time: date2,
              },
            },
            {
              type: 'update',
              id: 0,
              template: {
                action: 'Resume',
                time: date2,
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with one time',
          'kvm',
          '248'
        ),
        SCHED_ACTION: [
          {
            ACTION: 'resume',
            TIME: date2.epoch,
          },
          {
            ACTION: 'stop',
            TIME: date2.epoch,
          },
        ],
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'schedule',
          sectionActions: [
            {
              type: 'update',
              id: 1,
              template: {
                action: 'Backup',
                backupDs: 'dsBackup1',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with one time',
          'kvm',
          '248'
        ),
        SCHED_ACTION: [
          {
            ACTION: 'resume',
            TIME: date2.epoch,
          },
          {
            ACTION: 'backup',
            TIME: date2.epoch,
            ARGS: 'dsBackup1',
          },
        ],
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'schedule',
          sectionActions: [
            {
              type: 'update',
              id: 1,
              template: {
                backupDs: 'dsBackup2',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with one time',
          'kvm',
          '248'
        ),
        SCHED_ACTION: [
          {
            ACTION: 'resume',
            TIME: date2.epoch,
          },
          {
            ACTION: 'backup',
            TIME: date2.epoch,
            ARGS: 'dsBackup2',
          },
        ],
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'schedule',
          sectionActions: [
            {
              type: 'update',
              id: 0,
              template: {
                action: 'Snapshot create',
                snapshotName: 'snapshotName1',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with one time',
          'kvm',
          '248'
        ),
        SCHED_ACTION: [
          {
            ACTION: 'snapshot-create',
            TIME: date2.epoch,
            ARGS: 'snapshotName1',
          },
          {
            ACTION: 'backup',
            TIME: date2.epoch,
            ARGS: 'dsBackup2',
          },
        ],
      },
    },
  ],
}

const caseRelative = {
  initialData: {
    template: {
      name: 'caseRelative',
      hypervisor: 'kvm',
      description: 'Create a template with relative time',
      memory: 248,
      cpu: 0.1,
      schedActions: [
        {
          action: 'Stop',
          periodic: 'RELATIVE',
          time: '1',
          period: 'Years',
        },
        {
          action: 'Suspend',
          periodic: 'RELATIVE',
          time: '2',
          period: 'Days',
        },
      ],
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create a template with relative time',
        'kvm',
        '248'
      ),
      SCHED_ACTION: [
        {
          ACTION: 'stop',
          TIME: '+31536000',
        },
        {
          ACTION: 'suspend',
          TIME: '+172800',
        },
      ],
    },
  },
  updates: [],
}

const casePeriodic = {
  initialData: {
    template: {
      name: 'casePeriodic',
      hypervisor: 'kvm',
      description: 'Create a template with periodic time',
      memory: 248,
      cpu: 0.1,
      schedActions: [
        {
          action: 'Stop',
          periodic: 'PERIODIC',
          repeat: 'Daily',
          time: date1,
          endType: 'Never',
        },
        {
          action: 'Reboot',
          periodic: 'PERIODIC',
          repeat: 'Weekly',
          time: date1,
          repeatDaysOfTheWeek: ['Monday', 'Wednesday', 'Saturday'],
          endType: 'Never',
        },
        {
          action: 'Release',
          periodic: 'PERIODIC',
          repeat: 'Monthly',
          repeatValue: '15',
          time: date1,
          endType: 'Never',
        },
        {
          action: 'Resume',
          periodic: 'PERIODIC',
          repeat: 'Yearly',
          repeatValue: '150',
          time: date1,
          endType: 'Never',
        },
        {
          action: 'Suspend',
          periodic: 'PERIODIC',
          repeat: 'Hourly',
          repeatValue: '5',
          time: date1,
          endType: 'Never',
        },
      ],
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create a template with periodic time',
        'kvm',
        '248'
      ),
      SCHED_ACTION: [
        {
          ACTION: 'stop',
          TIME: date1.epoch,
          DAYS: '0,1,2,3,4,5,6',
          END_TYPE: '0',
          REPEAT: '0',
        },
        {
          ACTION: 'reboot',
          TIME: date1.epoch,
          DAYS: '1,3,6',
          END_TYPE: '0',
          REPEAT: '0',
        },
        {
          ACTION: 'release',
          TIME: date1.epoch,
          REPEAT: '1',
          END_TYPE: '0',
          DAYS: '15',
        },
        {
          ACTION: 'resume',
          TIME: date1.epoch,
          REPEAT: '2',
          END_TYPE: '0',
          DAYS: '150',
        },
        {
          ACTION: 'suspend',
          TIME: date1.epoch,
          REPEAT: '3',
          END_TYPE: '0',
          DAYS: '5',
        },
      ],
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'schedule',
          sectionActions: [
            {
              type: 'delete',
              id: 0,
            },
            {
              type: 'create',
              template: {
                action: 'Stop',
                periodic: 'PERIODIC',
                time: date2,
                repeat: 'Monthly',
                repeatValue: '2',
                endType: 'Never',
              },
            },
            {
              type: 'update',
              id: 0,
              template: {
                periodic: 'PERIODIC',
                action: 'Resume',
                time: date2,
              },
            },
            {
              type: 'update',
              id: 2,
              template: {
                periodic: 'PERIODIC',
                repeat: 'Yearly',
                repeatValue: '250',
                endType: 'Repetition',
                endTypeNumberOfRepetitions: 10,
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with periodic time',
          'kvm',
          '248'
        ),
        SCHED_ACTION: [
          {
            ACTION: 'resume',
            TIME: date2.epoch,
            DAYS: '1,3,6',
            END_TYPE: '0',
            REPEAT: '0',
          },
          {
            ACTION: 'release',
            TIME: date1.epoch,
            REPEAT: '1',
            END_TYPE: '0',
            DAYS: '15',
          },
          {
            ACTION: 'resume',
            TIME: date1.epoch,
            REPEAT: '2',
            END_TYPE: '1',
            END_VALUE: '10',
            DAYS: '250',
          },
          {
            ACTION: 'suspend',
            TIME: date1.epoch,
            REPEAT: '3',
            END_TYPE: '0',
            DAYS: '5',
          },
          {
            ACTION: 'stop',
            TIME: date2.epoch,
            REPEAT: '1',
            END_TYPE: '0',
            DAYS: '2',
          },
        ],
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'schedule',
          sectionActions: [
            {
              type: 'update',
              id: 2,
              template: {
                periodic: 'PERIODIC',
                endType: 'Repetition',
                endTypeNumberOfRepetitions: 20,
              },
            },
            {
              type: 'update',
              id: 0,
              template: {
                periodic: 'PERIODIC',
                endType: 'Date',
                endTypeDate: dateAfter2,
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with periodic time',
          'kvm',
          '248'
        ),
        SCHED_ACTION: [
          {
            ACTION: 'resume',
            TIME: date2.epoch,
            DAYS: '1,3,6',
            END_TYPE: '2',
            END_VALUE: dateAfter2.epoch,
            REPEAT: '0',
          },
          {
            ACTION: 'release',
            TIME: date1.epoch,
            REPEAT: '1',
            END_TYPE: '0',
            DAYS: '15',
          },
          {
            ACTION: 'resume',
            TIME: date1.epoch,
            REPEAT: '2',
            END_TYPE: '1',
            END_VALUE: '20',
            DAYS: '250',
          },
          {
            ACTION: 'suspend',
            TIME: date1.epoch,
            REPEAT: '3',
            END_TYPE: '0',
            DAYS: '5',
          },
          {
            ACTION: 'stop',
            TIME: date2.epoch,
            REPEAT: '1',
            END_TYPE: '0',
            DAYS: '2',
          },
        ],
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'schedule',
          sectionActions: [
            {
              type: 'delete',
              id: 0,
            },
            {
              type: 'delete',
              id: 0,
            },
            {
              type: 'delete',
              id: 0,
            },
            {
              type: 'delete',
              id: 0,
            },
            {
              type: 'delete',
              id: 0,
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with periodic time',
          'kvm',
          '248'
        ),
      },
    },
  ],
}

export const scheduleActionCases = [caseOneTime, caseRelative, casePeriodic]
