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
const { config } = require('dotenv')
const { parse: yamlToJson, stringify: jsonToYaml } = require('yaml')
const { copySync: fsCopy, ensureDirSync: fsDirSync } = require('fs-extra')
const path = require('path')

/**
 * @returns {object} dotenv content file
 */
const dotenv = () => {
  config()

  return process.env
}

/**
 * Copy file.
 *
 * @param {object} config - config copy file.
 * @param {string} config.pathConfig - path file
 * @param {string} config.pathTemp - destination path.
 * @returns {Promise} promise return file
 */
const copy = ({ pathConfig = '', pathTemp = '' }) =>
  new Promise((resolve, reject) => {
    try {
      fsDirSync(path.dirname(pathTemp))
      fsCopy(pathConfig, pathTemp)

      resolve(true)
    } catch (error) {
      reject(
        new Error(
          `Failed to copy from ${pathConfig} to ${pathTemp}: ${error.message}`
        )
      )
    }
  })

module.exports = {
  yamlToJson,
  jsonToYaml,
  dotenv,
  copy,
}
