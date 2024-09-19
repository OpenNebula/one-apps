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
 * @typedef {object} configSelectImage - config select image
 * @property {number} id - id vm
 * @property {string} name - name vm
 */

/**
 * @typedef {object} configChangeOwnership - config change ownership image
 * @property {object} image - info image
 * @property {number} image.id - id image
 * @property {string} image.name - name image
 * @property {string} action - action image
 * @property {string} value - value for change
 */

/**
 * @typedef Image - Image
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
