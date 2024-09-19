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
const { executeCommandJSON, executeCommand } = require('../../system')
const fse = require('fs-extra')
const { env } = require('process')

const COMMAND = 'onedb'

/**
 * Change body - Execute the CLI Command.
 *
 * @param {object} config - onedb params
 * @param {string} config.oneObject - one object
 * @param {string} config.xpath - xpath
 * @param {string} config.value - value
 * @param {string} config.id - object id
 * @param {string} config.action - action (--append, --delete)
 * @returns {null|string} - console response
 */
const changeBody = ({
  oneObject = '',
  xpath = '',
  value = '',
  id = '',
  action = '',
}) =>
  executeCommandJSON(COMMAND, ['change-body', oneObject, xpath, value, action])

/**
 * Change DEFAULT_AUTH in oned.conf.
 *
 * @param {string} value - default_auth value
 * @returns {Promise<boolean>} A promise that resolves to true if the modifications are successful, or rejects with an error.
 */
const changeDefaultAuth = (value = '') =>
  new Promise((resolve, reject) => {
    const file = '/etc/one/oned.conf'
    fse
      .pathExists(file)
      .then((exists) => {
        if (exists) {
          try {
            executeCommand('sed', [
              '-i',
              `s/#\\?DEFAULT_AUTH = .*/DEFAULT_AUTH = "${value}"/`,
              file,
            ])
          } catch (err) {
            reject(err)
          }
        }
        resolve(true)
      })
      .catch((err) => reject(err))
  })

/**
 * Create ONE_AUTH var.
 *
 * @param {string} path - path for ONE_AUTH
 * @returns {Promise<boolean>} A promise that resolves to true if the modifications are successful, or rejects with an error.
 */
const createOneAuthVar = (path = '') =>
  new Promise((resolve, reject) => {
    fse
      .pathExists(path)
      .then((exists) => {
        if (exists) {
          try {
            env.ONE_AUTH = `${path}`
          } catch (err) {
            reject(err)
          }
        }
        resolve(true)
      })
      .catch((err) => reject(err))
  })

/**
 * Delete ONE_AUTH var.
 *
 * @returns {Promise<boolean>} A promise that resolves to true if the modifications are successful, or rejects with an error.
 */
const deleteOneAuthVar = () =>
  new Promise((resolve, reject) => {
    try {
      delete env.ONE_AUTH
      resolve(true)
    } catch (err) {
      reject(err)
    }
  })

module.exports = {
  changeBody,
  changeDefaultAuth,
  createOneAuthVar,
  deleteOneAuthVar,
}
