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
  expectedTemplateMandatoryValues,
  expectedTemplateAllValues,
} from './utils'

const casePlacement = {
  initialData: {
    template: {
      name: 'casePlacement',
      hypervisor: 'kvm',
      description: 'Create a template with placement',
      memory: 248,
      cpu: 0.1,
      placement: {
        hostRequirement: 'NAME@>host & RUNNING_VMS < 15',
        schedRank: 'schedRank1',
        dsSchedRequirement: 'dsSchedRequirement1',
        dsSchedRank: 'dsSchedRank1',
      },
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create a template with placement',
        'kvm',
        '248'
      ),
      SCHED_REQUIREMENTS: 'NAME@>host & RUNNING_VMS < 15',
      SCHED_RANK: 'schedRank1',
      SCHED_DS_REQUIREMENTS: 'dsSchedRequirement1',
      SCHED_DS_RANK: 'dsSchedRank1',
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'placement',
          sectionActions: [
            {
              type: 'update',
              template: {
                hostRequirement: 'NAME=host | RUNNING_VMS > 15',
                schedRank: 'schedRank2',
                dsSchedRequirement: 'dsSchedRequirement2',
                dsSchedRank: 'dsSchedRank2',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with placement',
          'kvm',
          '248'
        ),
        SCHED_REQUIREMENTS: 'NAME=host | RUNNING_VMS > 15',
        SCHED_RANK: 'schedRank2',
        SCHED_DS_REQUIREMENTS: 'dsSchedRequirement2',
        SCHED_DS_RANK: 'dsSchedRank2',
      },
    },
    {
      actions: [
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                hypervisor: 'dummy',
              },
            },
          ],
        },
        {
          step: 'extra',
          section: 'placement',
          sectionActions: [
            {
              type: 'update',
              template: {
                schedRank: '',
                dsSchedRequirement: '',
                dsSchedRank: '',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with placement',
          'dummy',
          '248'
        ),
        SCHED_REQUIREMENTS:
          '(NAME=host | RUNNING_VMS > 15) & (HYPERVISOR=dummy)',
      },
    },
    {
      actions: [
        {
          step: 'general',
          section: 'general',
          sectionActions: [
            {
              type: 'update',
              template: {
                hypervisor: 'kvm',
              },
            },
          ],
        },
        {
          step: 'extra',
          section: 'placement',
          sectionActions: [
            {
              type: 'update',
              template: {
                hostRequirement: 'NAME=localhost',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with placement',
          'kvm',
          '248'
        ),
        SCHED_REQUIREMENTS: 'NAME=localhost',
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'placement',
          sectionActions: [
            {
              type: 'update',
              template: {
                hostRequirement: '',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateAllValues(
          '0.1',
          'Create a template with placement',
          'kvm',
          '248',
          {
            hostRequirements: false,
          }
        ),
      },
    },
  ],
}

export const placementCases = [casePlacement]
