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
const { spawnSync } = require('child_process')
const { opennebula } = require('../../../cypress.config.js')
const fse = require('fs-extra')
const { promises: fs } = require('fs')

const { timeout } = opennebula

require('dotenv').config()
const { CLI_COMMAND_PREPEND: prepend } = process.env

/**
 * Add prepend of command example: 'ssh xxxx:'".
 *
 * @param {string} command - Command
 * @param {string|string[]} args - Arguments
 * @returns {Array} Prepend command and new arguments
 */
const addPrependCommand = (command = '', args = '') => {
  const ensuredArgs = Array.isArray(args) ? args : [args]

  if (!prepend) {
    const replaceQuotes = (text) => text?.replace?.(/"/gm, '') || text

    return [command, ensuredArgs.map(replaceQuotes)]
  }

  const splittedPrepend = prepend.split(' ').filter((el) => el !== '')
  const [prependCmd, ...prependArgs] = splittedPrepend
  // stringify all parameters
  const stringifyParams = [command, ...ensuredArgs].join(' ')

  return [prependCmd, [...prependArgs, stringifyParams]]
}

/**
 * Execute CLI command.
 *
 * @param {string} command - command
 * @param {string|string[]} args - command args
 * @returns {null|string} - CLI output
 */
const executeCommand = (command, args = []) => {
  const [cmd, params] = addPrependCommand(command, args)
  const execute = spawnSync(cmd, params, { timeout }) ?? {}
  if (execute.stdout && execute.status === 0) {
    return execute.stdout.toString()
  } else if (execute.stderr && execute.stderr.length > 0) {
    console.error(execute.stderr.toString())
  }

  return null
}

/**
 * Execute CLI command.
 *
 * @param {string} command - command
 * @param {string[]} args - command args
 * @returns {null|object} - CLI output JSON
 */
const executeCommandJSON = (command, args) => {
  const executedCommand = executeCommand(command, args)
  try {
    return JSON.parse(executedCommand, (k, val) => {
      try {
        return JSON.parse(val)
      } catch (error) {
        return val
      }
    })
  } catch (error) {
    return executedCommand
  }
}

/**
 * Add a drop-in service configuration file for opennebula-fireedge.
 *
 * @returns {Promise<boolean>} A promise that resolves to true if the modifications are successful, or rejects with an error.
 */
const modifyServiceFile = () =>
  new Promise((resolve, reject) => {
    fs.readFile('cypress/fixtures/fireedge-service.conf', 'utf-8')
      .then((conf) => {
        try {
          executeCommand('sudo', [
            'mkdir',
            '-p',
            '/etc/systemd/system/opennebula-fireedge.service.d',
          ])

          executeCommand('/bin/sh', [
            '-c',
            `echo '${conf}' | sudo tee /etc/systemd/system/opennebula-fireedge.service.d/override.conf`,
          ])
          executeCommand('sudo', ['systemctl', 'daemon-reload'])
          executeCommand('sudo', [
            'systemctl',
            'start',
            'opennebula-fireedge.service',
          ])

          resolve(true)
        } catch (err) {
          reject(err)
        }
      })
      .catch((err) => reject(err))
  })

/**
 * Remove any drop-in service configuration files for opennebula-fireedge.
 *
 * @returns {Promise<boolean>} A promise that resolves to true if the modifications are successful, or rejects with an error.
 */
const restoreServiceFile = () =>
  new Promise((resolve, reject) => {
    fse
      .pathExists('/etc/systemd/system/opennebula-fireedge.service.d')
      .then((exists) => {
        if (exists) {
          try {
            executeCommand('sudo', [
              'rm',
              '-r',
              '/etc/systemd/system/opennebula-fireedge.service.d',
            ])
            executeCommand('sudo', ['systemctl', 'daemon-reload'])
          } catch (err) {
            reject(err)
          }
        }
        resolve(true)
      })
      .catch((err) => reject(err))
  })
module.exports = {
  modifyServiceFile,
  restoreServiceFile,
  addPrependCommand,
  executeCommand,
  executeCommandJSON,
}
