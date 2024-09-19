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
 * @typedef {object} configSelectSecGroup - config select security group
 * @property {number} id - id vm
 * @property {string} name - name vm
 */

/**
 * @typedef {object} configChangeOwnership - config change ownership security group
 * @property {object} securityGroup - info security group
 * @property {number} securityGroup.id - id security group
 * @property {string} securityGroup.name - name security group
 * @property {string} action - action security group
 * @property {string} value - value for change
 */

/**
 * @typedef SecurityGroup - SecurityGroup
 * @property {string} NAME - Name
 * @property {string} [DESCRIPTION] - Description
 * @property {object[]} RULE - rules
 * @property {string} RULE.RULE_TYPE - type
 * @property {object} RULE.PROTOCOL - protocol
 * @property {string} RULE.PROTOCOL.value - protocol value
 * @property {string} [RULE.PROTOCOL.ICMP] - ICMP
 * @property {string} [RULE.PROTOCOL.ICMPv6] - ICMPv6
 * @property {object} RULE.RANGE_TYPE - range type
 * @property {string} RULE.RANGE_TYPE.value - range value
 * @property {string} [RULE.RANGE_TYPE.RANGE] - range
 * @property {object} RULE.TARGET - target
 * @property {string} RULE.TARGET.value - target value
 * @property {string} [RULE.TARGET.IP] - ip
 * @property {number} [RULE.TARGET.SIZE] - size
 */

exports.unused = {}
