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

/**
 * Create a template with the basic attributes using the parameters as values.
 *
 * @param {string} cpu - CPU value
 * @param {string} description - Description value
 * @param {string} hypervisor -Type of hypervisor
 * @param {string} memory - Memory value
 * @param {object} addDefaultValues - Object that indicates if add or not default values in the template
 * @param {boolean} addDefaultValues.sshPublicKey - If add or not the sshPublicKey
 * @param {boolean} addDefaultValues.network - If add or not network contextualization
 * @param {boolean} addDefaultValues.graphicsType - If add or not the graphicsType
 * @param {boolean} addDefaultValues.graphicsListen - If add or not network graphicsListen
 * @param {boolean} addDefaultValues.hostRequirements - If add or not network hostRequirements
 * @returns {object} - The template with the attributes.
 */
export const expectedTemplateAllValues = (
  cpu,
  description,
  hypervisor,
  memory,
  {
    sshPublicKey = true,
    network = true,
    graphicsType = true,
    graphicsListen = true,
    hostRequirements = true,
  }
) => {
  let basic = {
    CPU: `${cpu}`,
    HYPERVISOR: `${hypervisor}`,
    MEMORY: `${memory}`,
  }

  if (basic) basic = { ...basic, CPU: `${cpu}` }

  if (description) basic = { ...basic, DESCRIPTION: `${description}` }

  if (hypervisor) basic = { ...basic, HYPERVISOR: `${hypervisor}` }

  if (memory) basic = { ...basic, MEMORY: `${memory}` }

  // Context default values
  let context = {}

  if (sshPublicKey) {
    context = {
      ...context,
      SSH_PUBLIC_KEY: '$USER[SSH_PUBLIC_KEY]',
    }
  }

  if (network) {
    context = {
      ...context,
      NETWORK: 'YES',
    }
  }

  if (context) {
    basic = {
      ...basic,
      CONTEXT: {
        ...context,
      },
    }
  }

  if (context && Object.keys(context).length > 0) {
    basic = {
      ...basic,
      CONTEXT: {
        ...context,
      },
    }
  }

  // Graphics default values
  let graphics = {}

  if (graphicsType) {
    graphics = {
      ...graphics,
      TYPE: 'VNC',
    }
  }

  if (graphicsListen) {
    graphics = {
      ...graphics,
      LISTEN: '0.0.0.0',
    }
  }

  if (graphics && Object.keys(graphics).length > 0) {
    basic = {
      ...basic,
      GRAPHICS: {
        ...graphics,
      },
    }
  }

  // Host requirements expression default values
  let schedRequirements = {}

  if (hostRequirements) {
    schedRequirements = {
      SCHED_REQUIREMENTS: `(HYPERVISOR=${hypervisor})`,
    }
  }

  if (schedRequirements && Object.keys(schedRequirements).length > 0) {
    basic = {
      ...basic,
      ...schedRequirements,
    }
  }

  return basic
}

/**
 * Create a tempalte with the mandatory values as parameters and the default values.
 *
 * @param {string} cpu - CPU value
 * @param {string} description - Description value
 * @param {string} hypervisor -Type of hypervisor
 * @param {string} memory - Memory value
 * @returns {object} - The template with the attributes.
 */
export const expectedTemplateMandatoryValues = (
  cpu,
  description,
  hypervisor,
  memory
) => {
  let basic = {
    CPU: `${cpu}`,
    HYPERVISOR: `${hypervisor}`,
    MEMORY: `${memory}`,
  }

  if (basic) basic = { ...basic, CPU: `${cpu}` }

  if (description) basic = { ...basic, DESCRIPTION: `${description}` }

  if (hypervisor) basic = { ...basic, HYPERVISOR: `${hypervisor}` }

  if (memory) basic = { ...basic, MEMORY: `${memory}` }

  basic = {
    ...basic,
    CONTEXT: {
      SSH_PUBLIC_KEY: '$USER[SSH_PUBLIC_KEY]',
      NETWORK: 'YES',
    },
    GRAPHICS: {
      TYPE: 'VNC',
      LISTEN: '0.0.0.0',
    },
    SCHED_REQUIREMENTS: `(HYPERVISOR=${hypervisor})`,
  }

  return basic
}
