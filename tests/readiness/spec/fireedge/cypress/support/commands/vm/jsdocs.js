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
 * @typedef {object} TemplateCapacity - template CLI output
 * @property {number} id - template ID
 * @property {number} name - template NAME
 * @property {object} [template] - template
 * @property {string} [template.CPU] - template CPU
 * @property {string} [template.VCPU] - template VCPU
 * @property {string} [template.MEMORY] - template MEMORY
 * @property {string} [template.CPU_COST] - template CPU_COST
 * @property {string} [template.MEMORY_COST] - template MEMORY_COST
 */

/**
 * @typedef Disk
 * @property {number} DISK_ID - Id
 * @property {string} [TYPE] -  Type
 * @property {boolean} [CLONE] - Clone
 * @property {string} [TARGET] - Target
 * @property {string} [DATASTORE] - Datastore
 * @property {string} [MONITOR_SIZE] - Monitor size
 */

/**
 * @typedef Nic - NIC
 * @property {string} NIC_ID - Id
 * @property {string} NETWORK - Name
 * @property {string} IP - IP
 * @property {string} MAC - MAC
 */

/**
 * @typedef NicAlias - NIC alias
 * @property {number} NIC_ID -  Id
 * @property {string} ALIAS_ID - Alias id
 * @property {number} PARENT - Parent
 * @property {number} PARENT_ID - Parent id
 * @property {string} NETWORK - Network
 * @property {string} IP - IP
 * @property {string} MAC - MAX
 * @property {string} BRIDGE - Bridge
 */

/**
 * @typedef SecurityGroupRule
 * @property {number|string} SECURITY_GROUP_ID - ID
 * @property {string} SECURITY_GROUP_NAME - Name
 * @property {string} PROTOCOL - Protocol
 * @property {string} RULE_TYPE - Rule type
 * @property {number|string} ICMP_TYPE - ICMP type
 * @property {number|string} [ICMPv6_TYPE] - ICMP v6 type
 * @property {number|string} [RANGE] - Range
 * @property {number|string} [NETWORK_ID] - Network id
 * @property {number|string} [SIZE] - Network size
 * @property {string} [IP] - Network IP
 * @property {string} [MAC] - Network MAC
 */

/**
 * @typedef {object} VmTemplateCreate - VM Template for UI
 * @property {string} templateId - template ID
 * @property {object} vmTemplate - VM Template
 * @property {string} [vmTemplate.vmname] - VM Template name
 * @property {number} [vmTemplate.instances] - VM Template instances
 * @property {boolean} [vmTemplate.hold] - VM Template hold
 * @property {boolean} [vmTemplate.persistent] - VM Template persistent
 * @property {number} [vmTemplate.memory] - VM Template memory
 * @property {number} [vmTemplate.cpu] - VM Template cpu
 * @property {number} [vmTemplate.vcpu] - VM Template vcpu
 * @property {string} [vmTemplate.user] - VM Template user
 * @property {string} [vmTemplate.group] - VM Template group
 * @property {string} [vmTemplate.vmgroup] - VM Template vmgroup
 * @property {object|object[]} [vmTemplate.storage] - VM Template storage
 * @property {number} [vmTemplate.storage.image] - image id
 * @property {number} [vmTemplate.storage.size] - image size
 * @property {string} [vmTemplate.storage.target] - image target
 * @property {string} [vmTemplate.storage.readOnly] - image read only
 * @property {string} [vmTemplate.storage.bus] - image bus
 * @property {string} [vmTemplate.storage.cache] - image cache
 * @property {string} [vmTemplate.storage.io] - image io
 * @property {string} [vmTemplate.storage.discard] - image discard
 * @property {string} [vmTemplate.storage.type] - image type
 * @property {string} [vmTemplate.storage.format] - image format
 * @property {string} [vmTemplate.storage.filesystem] - image system
 * @property {object|object[]} [vmTemplate.networks] - VM Template network
 * @property {number} [vmTemplate.networks.id] - network id
 * @property {boolean} [vmTemplate.networks.rdp] - network rdp
 * @property {boolean} [vmTemplate.networks.ssh] - network ssh
 * @property {string} [vmTemplate.networks.alias] - network alias
 * @property {object} [vmTemplate.placement] - VM Template placement
 * @property {object|object[]} [vmTemplate.schedActions] - VM Template schedule actions
 * @property {string} [vmTemplate.schedActions.action] - action
 * @property {Date} [vmTemplate.schedActions.time] - time
 * @property {string} [vmTemplate.schedActions.period] - period
 * @property {object} [vmTemplate.schedActions.periodic] - periodic object
 * @property {string} [vmTemplate.schedActions.periodic.repeat] - repeat
 * @property {number|number[]} [vmTemplate.schedActions.periodic.time] - time
 * @property {string} [vmTemplate.schedActions.periodic.endType] - end type
 * @property {string[]} [vmTemplate.osBooting] - VM Template os booting
 */

/**
 * @typedef {object} VmInfo - VM CLI output.
 * @property {string} ID - Id
 * @property {object} PERMISSIONS - Permissions
 * @property {number} PERMISSIONS.OWNER_U - Owner user
 * @property {number} PERMISSIONS.OWNER_M - Owner manager
 * @property {number} PERMISSIONS.OWNER_A - Owner admin
 * @property {number} PERMISSIONS.GROUP_U - Group user
 * @property {number} PERMISSIONS.GROUP_M - Group manager
 * @property {number} PERMISSIONS.GROUP_A - Group admin
 * @property {number} PERMISSIONS.OTHER_U - Other user
 * @property {number} PERMISSIONS.OTHER_M - Other manager
 * @property {number} PERMISSIONS.OTHER_A - Other admin
 * @property {string} NAME - Name
 * @property {string} RESCHED - Resched
 * @property {string} STIME - Start time
 * @property {string} LCM_STATE - LCM state
 * @property {string} ETIME - End time
 * @property {string} UNAME - User name
 * @property {string} GNAME - Group name
 * @property {object} TEMPLATE - Template information
 * @property {Disk|Disk[]} [TEMPLATE.DISK] - Disk information
 * @property {Nic|Nic[]} [TEMPLATE.NIC] - NIC information
 * @property {NicAlias|NicAlias[]} [TEMPLATE.NIC_ALIAS] - NIC alias information
 * @property {SecurityGroupRule|SecurityGroupRule[]} [TEMPLATE.SECURITY_GROUP_RULE] - Security group rule information
 */

export {}
