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
 * @typedef {object} User - User model
 * @property {string} name - The name of the user
 * @property {number} id - The ID of the user
 * @property {Function} info - A method to fetch user info
 * @property {Function} quota - A method to set user quota
 */

/**
 * @typedef {object} Group - Group model
 * @property {number} id - The ID of the group
 */

/**
 * @typedef {object} QuotaTypes - Types of quotas and their properties
 * @property {object} datastore - Datastore quota properties
 * @property {object} vm - VM quota properties
 * @property {object} network - Network quota properties
 * @property {object} image - Image quota properties
 */

exports.unused = {}
