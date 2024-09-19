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

import { ENV } from '@commands/api'

/**
 * Loads the sunstone-server.conf file and saves the values in the
 * Cypress environment as `SUNSTONE_CONF`.
 *
 * @returns {Cypress.Chainable} - A promise that resolves to sunstone config
 */
const getSunstoneServerConf = () => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const configPath = `${baseUrl}/api/sunstone/config`

  return cy
    .request({ url: configPath, auth: { bearer: jwt } })
    .its('body.data')
    .then((config) => {
      Cypress.env(ENV.SUNSTONE_CONF, config)

      return config
    })
}

/**
 * Gets the OpenNebula configuration.
 *
 * @returns {Cypress.Chainable} - A promise that resolves to OpenNebula config
 */
const getOneConf = () => {
  const jwt = Cypress.env(ENV.TOKEN)
  const baseUrl = Cypress.config('baseUrl')
  const configPath = `${baseUrl}/api/system/config/`

  return cy
    .request({ url: configPath, auth: { bearer: jwt } })
    .its('body.data')
    .then((config) => {
      Cypress.env(ENV.ONED_CONF, config)

      return config
    })
}

Cypress.Commands.add('apiSunstoneConf', getSunstoneServerConf)
Cypress.Commands.add('getOneConf', getOneConf)
