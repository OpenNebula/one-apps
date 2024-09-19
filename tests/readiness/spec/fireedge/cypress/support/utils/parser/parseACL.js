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

// File to define parser functions to create ACLs rules
// Documentation about manage ACLs -> https://docs.opennebula.io/6.7/management_and_operations/users_groups_management/chmod.html#manage-acl

// Hex values for different user types
export const ACL_ID = {
  '#': 0x100000000,
  '@': 0x200000000,
  '*': 0x400000000,
  '%': 0x800000000,
}

export const ACL_USERS = {
  INDIVIDUAL: { type: 'INDIVIDUAL', id: '#', value: 0x100000000 },
  GROUP: { type: 'GROUP', id: '@', value: 0x200000000 },
  ALL: { type: 'ALL', id: '*', value: 0x400000000 },
  CLUSTER: { type: 'CLUSTER', id: '%', value: 0x800000000 },
}

// Hex values for different resource types
export const ACL_RESOURCES = {
  VM: { name: 'VM', value: 0x1000000000n },
  HOST: { name: 'HOST', value: 0x2000000000n },
  NET: { name: 'NET', value: 0x4000000000n },
  IMAGE: { name: 'IMAGE', value: 0x8000000000n },
  USER: { name: 'USER', value: 0x10000000000n },
  TEMPLATE: { name: 'TEMPLATE', value: 0x20000000000n },
  GROUP: { name: 'GROUP', value: 0x40000000000n },
  DATASTORE: { name: 'DATASTORE', value: 0x100000000000n },
  CLUSTER: { name: 'CLUSTER', value: 0x200000000000n },
  DOCUMENT: { name: 'DOCUMENT', value: 0x400000000000n },
  ZONE: { name: 'ZONE', value: 0x800000000000n },
  SECGROUP: { name: 'SECGROUP', value: 0x1000000000000n },
  VDC: { name: 'VDC', value: 0x2000000000000n },
  VROUTER: { name: 'VROUTER', value: 0x4000000000000n },
  MARKETPLACE: { name: 'MARKETPLACE', value: 0x8000000000000n },
  MARKETPLACEAPP: { name: 'MARKETPLACEAPP', value: 0x10000000000000n },
  VMGROUP: { name: 'VMGROUP', value: 0x20000000000000n },
  VNTEMPLATE: { name: 'VNTEMPLATE', value: 0x40000000000000n },
  BACKUPJOB: { name: 'BACKUPJOB', value: 0x100000000000000n },
}

// Hex values for different right types
export const ACL_RIGHTS = {
  USE: { name: 'USE', value: 0x1 },
  MANAGE: { name: 'MANAGE', value: 0x2 },
  ADMIN: { name: 'ADMIN', value: 0x4 },
  CREATE: { name: 'CREATE', value: 0x8 },
}

/**
 * Parses a rule string, e.g. "#5 HOST+VM/@12 INFO+CREATE+DELETE *".
 *
 * @param {string} rule - The ACL rule
 * @returns {number} - The hex value for the four components of a rule (user, resources, rights and zone)
 */
const parseAcl = (rule) => {
  // Get each component
  const ruleComponents = rule.split(' ')

  /**
   * Array to store values. Position:
   * 0: User
   * 1: Resources
   * 2: Rights
   * 3: Zone
   */
  const ret = []

  // Get value for user
  ret[0] = parseUser(ruleComponents[0]).toString(16)

  // Get value for resources
  ret[1] = parseResources(ruleComponents[1])

  // Get value for rights
  ret[2] = parseRights(ruleComponents[2])

  // Get value for zone (optional)
  if (ruleComponents.length > 3) {
    ret[3] = parseZone(ruleComponents[3])
  }

  // Create response
  const response = {
    user: ret[0],
    resource: ret[1],
    right: ret[2],
  }

  // Add zone if exists
  if (ret.length === 4) {
    response.zone = ret[3]
  }

  // Return value
  return response
}

/**
 * Calculate the hex value for a user.
 *
 * @param {string} userString - The user string is composed only by an ID definition.
 * @returns {number} - The hex value of the user
 */
const parseUser = (userString) => calculateIds(userString).toString(16)

/**
 * Calculate the hex value for resources.
 *
 * @param {string} resourceString - The resources string is composed by a list of ‘+’ separated resource types, ‘/’ and an ID definition, e.g. "HOST+VM/@12"
 * @returns {number} - The hex value of the resources
 */
const parseResources = (resourceString) => {
  // Get the resources lst and the id definition
  const components = resourceString.split('/')
  const resources = components[0]
  const user = components[1]

  // Init value with 0
  let resourcesValue = 0n

  // Add the hex value of each resource
  resources
    .split('+')
    .forEach((resource) => (resourcesValue += ACL_RESOURCES[resource].value))

  // Add the value for the id definition
  resourcesValue += BigInt(calculateIds(user))

  // Return the hex decimal value
  return resourcesValue.toString(16)
}

/**
 * Calculate the hex value for rights.
 *
 * @param {string} rightsString - The rights string is a list of operations separated by the ‘+’ character., e.g. "INFO+CREATE+DELETE"
 * @returns {number} - The hex value of the rights
 */
const parseRights = (rightsString) => {
  // Get each right
  const rights = rightsString.split('+')

  // Init value with 0
  let rightsValue = 0

  // Add the value of each right
  rights.forEach((right) => (rightsValue += ACL_RIGHTS[right].value))

  // Return the hex value of the rights
  return rightsValue.toString(16)
}

/**
 * Calculate the hex value for zone.
 *
 * @param {string} zoneString - The zone string is an ID definition of the zones where the rule applies, e.g. "@12"
 * @returns {number} - The hex value of the zone
 */
const parseZone = (zoneString) =>
  // Return the hex value for zone
  calculateIds(zoneString).toString(16)

/**
 * Calculate integer value for a id definition.
 *
 * @param {string} id - Id definition. Position 0 it's the type and from 1 to final position it's the identifier, e.g. "#5"
 * @returns {number} - The value for the id definition
 */
const calculateIds = (id) => {
  // Get the hex value for the id definition type
  let idValue = ACL_ID[id[0]]

  // Check the identifer
  if (id.length > 1) {
    // Get integer value of the identifier and add to the users value
    idValue += parseInt(id.substring(1))
  }

  // Return the integer id value
  return idValue
}

export { parseAcl }
