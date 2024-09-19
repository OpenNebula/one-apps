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

// This function is called when a project is opened or re-opened (e.g. due to
// the project's config changing)

const webpack = require('@cypress/webpack-preprocessor')

const puppeteer = require('./puppeteer')
const opennebula = require('./opennebula')
const fireeedgeServer = require('./fireedgeServer')
const { modifyServiceFile, restoreServiceFile } = require('./system')

/**
 * Add functions as cypress tasks.
 *
 * @param {Function} on - cypress function
 * @param {object} config - cypress config
 * @returns {void}
 */
module.exports = (on, config) => {
  const options = {
    webpackOptions: require('../../webpack.config'),
    watchOptions: {},
  }

  on('file:preprocessor', webpack(options))

  on('task', { ...puppeteer, ...opennebula, ...fireeedgeServer })

  /**
   * Before run event.
   * Adds the drop-in service configuration file for opennebula-fireedge
   *
   * @returns {Promise} Promise returned from modifyServiceFile task.
   */

  on('before:run', function () {
    return modifyServiceFile()
  })

  /**
   * After run event.
   * Removes the drop-in service configuration file for opennebula-fireedge
   *
   * @returns {Promise} Promise returned from restoreServiceFile task.
   */

  on('after:run', function () {
    return restoreServiceFile()
  })
}
