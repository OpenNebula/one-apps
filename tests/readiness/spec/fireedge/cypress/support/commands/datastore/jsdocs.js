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
 * @typedef {object} configSelectDatastore - config select datastore
 * @property {number} id - id vm
 * @property {string} name - name vm
 */

/**
 * @typedef {object} configChangeOwnership - config change ownership datastore
 * @property {object} datastore - info datastore
 * @property {number} datastore.id - id datastore
 * @property {string} datastore.name - name datastore
 * @property {string} action - action datastore
 * @property {string} value - value for change
 */

// TODO: Change the attributes to the correct ones
/**
 * @typedef Datastore - Datastore
 * @property {string} name - Name
 * @property {string} [description] - Description
 * @property {string} [type] - Type
 * @property {string} [persistent] - Persistent
 * @property {number} [size] - Size
 * @property {string} [path] - Path
 * @property {string} [upload] - Upload
 * @property {object} datastore - Datastore
 * @property {string} [bus] - Bus
 * @property {string} [device] - Device
 * @property {string} [format] - Format
 * @property {string} [fs] - Fs
 * @property {object} customAttributes - custom attributes
 */

exports.unused = {}
