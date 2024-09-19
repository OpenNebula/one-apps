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
const { defineConfig } = require('cypress')

module.exports = defineConfig({
  defaultCommandTimeout: 80000,
  requestTimeout: 80000,
  responseTimeout: 80000,
  port: 2617,
  numTestsKeptInMemory: 20,
  env: {},
  experimentalRunEvents: true,
  video: false,
  viewportHeight: 720,
  viewportWidth: 1280,
  taskTimeout: 120000,
  chromeWebSecurity: false,
  reporter: 'mochawesome',
  reporterOptions: {
    reportDir: 'cypress/results',
    overwrite: false,
    html: false,
    json: true,
  },
  opennebula: {
    changeStateTimeout: 300000,
    tempPath: '/tmp/',
    timeout: 10000,
  },
  e2e: {
    // We've imported your old cypress plugins here.
    // You may want to clean this up later by importing these.
    setupNodeEvents(on, config) {
      return require('./cypress/plugins/index.js')(on, config)
    },

    experimentalRunAllSpecs: true,
    experimentalMemoryManagement: true,
    baseUrl: 'http://localhost:2616/fireedge',
  },
})
