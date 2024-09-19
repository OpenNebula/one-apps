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

const caseConfiguration = {
  initialData: {
    template: {
      name: 'caseConfiguration',
      hypervisor: 'kvm',
      description: 'Create a template with configuration',
      memory: 248,
      cpu: 0.1,
      context: {
        token: true,
        report: true,
        startScript: 'apt update',
      },
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create a template with configuration',
        'kvm',
        '248'
      ),
      CONTEXT: {
        NETWORK: 'YES',
        REPORT_READY: 'YES',
        TOKEN: 'YES',
        SSH_PUBLIC_KEY: '$USER[SSH_PUBLIC_KEY]',
        START_SCRIPT: 'apt update',
      },
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'context',
          sectionActions: [
            {
              type: 'update',
              template: {
                network: false,
                token: false,
                report: false,
                autoDeleteSshKey: true,
                startScript: 'apt upgrade',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with configuration',
          'kvm',
          '248'
        ),
        CONTEXT: {
          NETWORK: 'NO',
          REPORT_READY: 'NO',
          TOKEN: 'NO',
          START_SCRIPT: 'apt upgrade',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'context',
          sectionActions: [
            {
              type: 'update',
              template: {
                sshKey: 'sshKey',
                encodeScript: true,
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with configuration',
          'kvm',
          '248'
        ),
        CONTEXT: {
          NETWORK: 'NO',
          REPORT_READY: 'NO',
          TOKEN: 'NO',
          SSH_PUBLIC_KEY: 'sshKey',
          START_SCRIPT_BASE64: 'YXB0IHVwZ3JhZGU=',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'context',
          sectionActions: [
            {
              type: 'update',
              template: {
                sshKey: '',
                encodeScript: false,
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with configuration',
          'kvm',
          '248'
        ),
        CONTEXT: {
          NETWORK: 'NO',
          REPORT_READY: 'NO',
          TOKEN: 'NO',
          START_SCRIPT: 'apt upgrade',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'context',
          sectionActions: [
            {
              type: 'update',
              template: {
                startScript: '',
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with configuration',
          'kvm',
          '248'
        ),
        CONTEXT: {
          NETWORK: 'NO',
          REPORT_READY: 'NO',
          TOKEN: 'NO',
        },
      },
    },
  ],
}

const caseUserInputs = {
  initialData: {
    template: {
      name: 'caseUserInputs',
      hypervisor: 'kvm',
      description: 'Create a template with user inputs',
      memory: 248,
      cpu: 0.1,
      context: {
        userInputs: [
          {
            type: 'Text',
            name: 'FIELDTEXT1',
            description: 'description1',
            defaultValue: 'dv1',
            mandatory: true,
          },
          {
            type: 'Text',
            name: 'FIELDTEXT2',
          },
          {
            type: 'List multiple',
            name: 'FIELDLISTMULTIPLE1',
            description: 'descriptionListMultiple1',
            options: ['option1', 'option2', 'option3'],
            defaultValue: ['option2'],
          },
        ],
      },
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create a template with user inputs',
        'kvm',
        '248'
      ),
      CONTEXT: {
        FIELDTEXT1: '$FIELDTEXT1',
        FIELDTEXT2: '$FIELDTEXT2',
        FIELDLISTMULTIPLE1: '$FIELDLISTMULTIPLE1',
        SSH_PUBLIC_KEY: '$USER[SSH_PUBLIC_KEY]',
        NETWORK: 'YES',
      },
      INPUTS_ORDER: 'FIELDTEXT1,FIELDTEXT2,FIELDLISTMULTIPLE1',
      USER_INPUTS: {
        FIELDTEXT1: 'M|text|description1| |dv1',
        FIELDTEXT2: 'O|text|| |',
        FIELDLISTMULTIPLE1:
          'O|list-multiple|descriptionListMultiple1|option1,option2,option3|option2',
      },
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'context',
          sectionActions: [
            {
              type: 'delete',
              subSection: 'userInputs',
              id: 2,
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with user inputs',
          'kvm',
          '248'
        ),
        CONTEXT: {
          FIELDTEXT1: '$FIELDTEXT1',
          FIELDTEXT2: '$FIELDTEXT2',
          SSH_PUBLIC_KEY: '$USER[SSH_PUBLIC_KEY]',
          NETWORK: 'YES',
        },
        INPUTS_ORDER: 'FIELDTEXT1,FIELDTEXT2',
        USER_INPUTS: {
          FIELDTEXT1: 'M|text|description1| |dv1',
          FIELDTEXT2: 'O|text|| |',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'context',
          sectionActions: [
            {
              type: 'delete',
              subSection: 'userInputs',
              id: 0,
            },
            {
              type: 'create',
              template: {
                userInputs: [
                  {
                    type: 'Text64',
                    name: 'FIELDTEXT641',
                    description: 'description1',
                    defaultValue: 'dv1',
                    mandatory: true,
                  },
                ],
              },
            },
            {
              type: 'create',
              template: {
                userInputs: [
                  {
                    type: 'Text64',
                    name: 'FIELDTEXT642',
                  },
                ],
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with user inputs',
          'kvm',
          '248'
        ),
        CONTEXT: {
          FIELDTEXT2: '$FIELDTEXT2',
          FIELDTEXT641: '$FIELDTEXT641',
          FIELDTEXT642: '$FIELDTEXT642',
          SSH_PUBLIC_KEY: '$USER[SSH_PUBLIC_KEY]',
          NETWORK: 'YES',
        },
        INPUTS_ORDER: 'FIELDTEXT2,FIELDTEXT641,FIELDTEXT642',
        USER_INPUTS: {
          FIELDTEXT2: 'O|text|| |',
          FIELDTEXT641: 'M|text64|description1| |dv1',
          FIELDTEXT642: 'O|text64|| |',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'context',
          sectionActions: [
            {
              type: 'create',
              template: {
                userInputs: [
                  {
                    type: 'Boolean',
                    name: 'FIELDBOOLEAN1',
                    description: 'descriptionBoolean1',
                    defaultValue: 'YES',
                    mandatory: true,
                  },
                ],
              },
            },
            {
              type: 'create',
              template: {
                userInputs: [
                  {
                    type: 'Boolean',
                    name: 'FIELDBOOLEAN2',
                  },
                ],
              },
            },
            {
              type: 'create',
              template: {
                userInputs: [
                  {
                    type: 'Number',
                    name: 'FIELDNUMBER1',
                    description: 'descriptionNumber1',
                    defaultValue: '1',
                    mandatory: true,
                  },
                ],
              },
            },
            {
              type: 'create',
              template: {
                userInputs: [
                  {
                    type: 'Number',
                    name: 'FIELDNUMBER2',
                  },
                ],
              },
            },
            {
              type: 'create',
              template: {
                userInputs: [
                  {
                    type: 'Number float',
                    name: 'FIELDNUMBERFLOAT1',
                    description: 'descriptionNumberFloat1',
                    defaultValue: '1.5',
                  },
                ],
              },
            },
            {
              type: 'create',
              template: {
                userInputs: [
                  {
                    type: 'Number float',
                    name: 'FIELDNUMBERFLOAT2',
                    mandatory: true,
                  },
                ],
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with user inputs',
          'kvm',
          '248'
        ),
        CONTEXT: {
          FIELDTEXT2: '$FIELDTEXT2',
          FIELDTEXT641: '$FIELDTEXT641',
          FIELDTEXT642: '$FIELDTEXT642',
          FIELDBOOLEAN1: '$FIELDBOOLEAN1',
          FIELDBOOLEAN2: '$FIELDBOOLEAN2',
          FIELDNUMBER1: '$FIELDNUMBER1',
          FIELDNUMBER2: '$FIELDNUMBER2',
          FIELDNUMBERFLOAT1: '$FIELDNUMBERFLOAT1',
          FIELDNUMBERFLOAT2: '$FIELDNUMBERFLOAT2',
          SSH_PUBLIC_KEY: '$USER[SSH_PUBLIC_KEY]',
          NETWORK: 'YES',
        },
        INPUTS_ORDER:
          'FIELDTEXT2,FIELDTEXT641,FIELDTEXT642,FIELDBOOLEAN1,FIELDBOOLEAN2,FIELDNUMBER1,FIELDNUMBER2,FIELDNUMBERFLOAT1,FIELDNUMBERFLOAT2',
        USER_INPUTS: {
          FIELDTEXT2: 'O|text|| |',
          FIELDTEXT641: 'M|text64|description1| |dv1',
          FIELDTEXT642: 'O|text64|| |',
          FIELDBOOLEAN1: 'M|boolean|descriptionBoolean1| |YES',
          FIELDBOOLEAN2: 'O|boolean|| |',
          FIELDNUMBER1: 'M|number|descriptionNumber1| |1',
          FIELDNUMBER2: 'O|number|| |',
          FIELDNUMBERFLOAT1: 'O|number-float|descriptionNumberFloat1| |1.5',
          FIELDNUMBERFLOAT2: 'M|number-float|| |',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'context',
          sectionActions: [
            {
              type: 'delete',
              subSection: 'userInputs',
              id: 0,
            },
            {
              type: 'delete',
              subSection: 'userInputs',
              id: 3,
            },
            {
              type: 'delete',
              subSection: 'userInputs',
              id: 0,
            },
            {
              type: 'delete',
              subSection: 'userInputs',
              id: 1,
            },
            {
              type: 'delete',
              subSection: 'userInputs',
              id: 0,
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with user inputs',
          'kvm',
          '248'
        ),
        CONTEXT: {
          FIELDNUMBER1: '$FIELDNUMBER1',
          FIELDNUMBER2: '$FIELDNUMBER2',
          FIELDNUMBERFLOAT1: '$FIELDNUMBERFLOAT1',
          FIELDNUMBERFLOAT2: '$FIELDNUMBERFLOAT2',
          SSH_PUBLIC_KEY: '$USER[SSH_PUBLIC_KEY]',
          NETWORK: 'YES',
        },
        INPUTS_ORDER:
          'FIELDNUMBER1,FIELDNUMBER2,FIELDNUMBERFLOAT1,FIELDNUMBERFLOAT2',
        USER_INPUTS: {
          FIELDNUMBER1: 'M|number|descriptionNumber1| |1',
          FIELDNUMBER2: 'O|number|| |',
          FIELDNUMBERFLOAT1: 'O|number-float|descriptionNumberFloat1| |1.5',
          FIELDNUMBERFLOAT2: 'M|number-float|| |',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'context',
          sectionActions: [
            {
              type: 'delete',
              subSection: 'userInputs',
              id: 0,
            },
            {
              type: 'delete',
              subSection: 'userInputs',
              id: 0,
            },
            {
              type: 'delete',
              subSection: 'userInputs',
              id: 0,
            },
            {
              type: 'delete',
              subSection: 'userInputs',
              id: 0,
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with user inputs',
          'kvm',
          '248'
        ),
        CONTEXT: {
          SSH_PUBLIC_KEY: '$USER[SSH_PUBLIC_KEY]',
          NETWORK: 'YES',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'context',
          sectionActions: [
            {
              type: 'create',
              template: {
                userInputs: [
                  {
                    type: 'Range',
                    name: 'FIELDRANGE1',
                    description: 'descriptionRange1',
                    min: '1',
                    max: '2',
                    defaultValue: '1',
                    mandatory: true,
                  },
                ],
              },
            },
            {
              type: 'create',
              template: {
                userInputs: [
                  {
                    type: 'Range',
                    name: 'FIELDRANGE2',
                    description: 'descriptionRange2',
                    min: '1',
                    max: '2',
                    defaultValue: '1',
                  },
                ],
              },
            },
            {
              type: 'create',
              template: {
                userInputs: [
                  {
                    type: 'Range',
                    name: 'FIELDRANGEFLOAT1',
                    description: 'descriptionRangeFloat1',
                    min: '1.5',
                    max: '2.5',
                    defaultValue: '2',
                    mandatory: true,
                  },
                ],
              },
            },
            {
              type: 'create',
              template: {
                userInputs: [
                  {
                    type: 'Range',
                    name: 'FIELDRANGEFLOAT2',
                    description: 'descriptionRangeFloat2',
                    min: '1.5',
                    max: '2.5',
                    defaultValue: '2',
                  },
                ],
              },
            },
            {
              type: 'create',
              template: {
                userInputs: [
                  {
                    type: 'Password',
                    name: 'FIELDPASSWORD1',
                    description: 'descriptionPassword1',
                  },
                ],
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with user inputs',
          'kvm',
          '248'
        ),
        CONTEXT: {
          FIELDRANGE1: '$FIELDRANGE1',
          FIELDRANGE2: '$FIELDRANGE2',
          FIELDRANGEFLOAT1: '$FIELDRANGEFLOAT1',
          FIELDRANGEFLOAT2: '$FIELDRANGEFLOAT2',
          FIELDPASSWORD1: '$FIELDPASSWORD1',
          SSH_PUBLIC_KEY: '$USER[SSH_PUBLIC_KEY]',
          NETWORK: 'YES',
        },
        INPUTS_ORDER:
          'FIELDRANGE1,FIELDRANGE2,FIELDRANGEFLOAT1,FIELDRANGEFLOAT2,FIELDPASSWORD1',
        USER_INPUTS: {
          FIELDRANGE1: 'M|range|descriptionRange1|1..2|1',
          FIELDRANGE2: 'O|range|descriptionRange2|1..2|1',
          FIELDRANGEFLOAT1: 'M|range|descriptionRangeFloat1|1.5..2.5|2',
          FIELDRANGEFLOAT2: 'O|range|descriptionRangeFloat2|1.5..2.5|2',
          FIELDPASSWORD1: 'O|password|descriptionPassword1| |',
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'context',
          sectionActions: [
            {
              type: 'create',
              template: {
                userInputs: [
                  {
                    type: 'Number',
                    name: 'MEMORY',
                    mandatory: true,
                  },
                ],
              },
            },
            {
              type: 'create',
              template: {
                userInputs: [
                  {
                    type: 'Number',
                    name: 'CPU',
                    mandatory: true,
                  },
                ],
              },
            },
            {
              type: 'create',
              template: {
                userInputs: [
                  {
                    type: 'Number',
                    name: 'VCPU',
                    mandatory: true,
                  },
                ],
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with user inputs',
          'kvm',
          '248'
        ),
        CONTEXT: {
          FIELDRANGE1: '$FIELDRANGE1',
          FIELDRANGE2: '$FIELDRANGE2',
          FIELDRANGEFLOAT1: '$FIELDRANGEFLOAT1',
          FIELDRANGEFLOAT2: '$FIELDRANGEFLOAT2',
          FIELDPASSWORD1: '$FIELDPASSWORD1',
          SSH_PUBLIC_KEY: '$USER[SSH_PUBLIC_KEY]',
          NETWORK: 'YES',
        },
        INPUTS_ORDER:
          'FIELDRANGE1,FIELDRANGE2,FIELDRANGEFLOAT1,FIELDRANGEFLOAT2,FIELDPASSWORD1',
        USER_INPUTS: {
          FIELDRANGE1: 'M|range|descriptionRange1|1..2|1',
          FIELDRANGE2: 'O|range|descriptionRange2|1..2|1',
          FIELDRANGEFLOAT1: 'M|range|descriptionRangeFloat1|1.5..2.5|2',
          FIELDRANGEFLOAT2: 'O|range|descriptionRangeFloat2|1.5..2.5|2',
          FIELDPASSWORD1: 'O|password|descriptionPassword1| |',
          MEMORY: 'M|number|| |',
          CPU: 'M|number|| |',
          VCPU: 'M|number|| |',
        },
      },
    },
  ],
}

const caseFiles = {
  initialData: {
    template: {
      name: 'caseFiles',
      hypervisor: 'kvm',
      description: 'Create a template with files and init scripts',
      memory: 248,
      cpu: 0.1,
      context: {
        initScripts: ['init.sh'],
        files: ['contextimage1'],
      },
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create a template with files and init scripts',
        'kvm',
        '248'
      ),
      CONTEXT: {
        FILES_DS: '$FILE[IMAGE_ID=#contextimage1#]',
        INIT_SCRIPTS: 'init.sh',
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with files and init scripts',
          'kvm',
          '248'
        ).CONTEXT,
      },
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'context',
          sectionActions: [
            {
              type: 'update',
              template: {
                initScripts: ['myscript.sh'],
                files: ['contextimage2'],
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with files and init scripts',
          'kvm',
          '248'
        ),
        CONTEXT: {
          FILES_DS:
            '$FILE[IMAGE_ID=#contextimage1#] $FILE[IMAGE_ID=#contextimage2#]',
          INIT_SCRIPTS: 'init.sh myscript.sh',
          ...expectedTemplateMandatoryValues(
            '0.1',
            'Create a template with files and init scripts',
            'kvm',
            '248'
          ).CONTEXT,
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'context',
          sectionActions: [
            {
              type: 'update',
              template: {
                files: [],
                initScripts: [],
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with files and init scripts',
          'kvm',
          '248'
        ),
      },
    },
  ],
}

const caseCustomVars = {
  initialData: {
    template: {
      name: 'caseCustomVars',
      hypervisor: 'kvm',
      description: 'Create a template with context custom variables',
      memory: 248,
      cpu: 0.1,
      context: {
        customVars: {
          CUSTOMVAR1: 'customVarValue1',
          CUSTOMVAR2: 'customVarValue2',
        },
      },
    },
    expectedTemplate: {
      ...expectedTemplateMandatoryValues(
        '0.1',
        'Create a template with context custom variables',
        'kvm',
        '248'
      ),
      CONTEXT: {
        CUSTOMVAR1: 'customVarValue1',
        CUSTOMVAR2: 'customVarValue2',
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with context custom variables',
          'kvm',
          '248'
        ).CONTEXT,
      },
    },
  },
  updates: [
    {
      actions: [
        {
          step: 'extra',
          section: 'context',
          sectionActions: [
            {
              type: 'create',
              subSection: 'customVars',
              template: {
                customVars: {
                  CUSTOMVAR3: 'customVarValue3',
                },
              },
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with context custom variables',
          'kvm',
          '248'
        ),
        CONTEXT: {
          CUSTOMVAR1: 'customVarValue1',
          CUSTOMVAR2: 'customVarValue2',
          CUSTOMVAR3: 'customVarValue3',
          ...expectedTemplateMandatoryValues(
            '0.1',
            'Create a template with context custom variables',
            'kvm',
            '248'
          ).CONTEXT,
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'context',
          sectionActions: [
            {
              type: 'update',
              subSection: 'customVars',
              customVar: 'customvar1',
              value: 'customvar1Updated',
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with context custom variables',
          'kvm',
          '248'
        ),
        CONTEXT: {
          CUSTOMVAR1: 'customvar1Updated',
          CUSTOMVAR2: 'customVarValue2',
          CUSTOMVAR3: 'customVarValue3',
          ...expectedTemplateMandatoryValues(
            '0.1',
            'Create a template with context custom variables',
            'kvm',
            '248'
          ).CONTEXT,
        },
      },
    },
    {
      actions: [
        {
          step: 'extra',
          section: 'context',
          sectionActions: [
            {
              type: 'delete',
              subSection: 'customVars',
              customVar: 'customvar1',
            },
          ],
        },
      ],
      expectedTemplate: {
        ...expectedTemplateMandatoryValues(
          '0.1',
          'Create a template with context custom variables',
          'kvm',
          '248'
        ),
        CONTEXT: {
          CUSTOMVAR2: 'customVarValue2',
          CUSTOMVAR3: 'customVarValue3',
          ...expectedTemplateMandatoryValues(
            '0.1',
            'Create a template with context custom variables',
            'kvm',
            '248'
          ).CONTEXT,
        },
      },
    },
  ],
}

export const contextCases = [
  caseConfiguration,
  caseUserInputs,
  caseFiles,
  caseCustomVars,
]
