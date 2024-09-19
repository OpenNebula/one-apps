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
import { User } from '@models'
import { userKey } from '@utils/constants'

/**
 * Loads the sunstone-server.conf file and saves the values in the
 * Cypress environment as `SUNSTONE_CONF`.
 *
 * @param {object} adminData - User data
 * @param {string} adminData.username - username
 * @param {string} adminData.password - password
 * @param {object} userData - create user
 * @param {string} userData.username - username
 * @param {string} userData.password - password
 * @returns {Cypress.Chainable} - A promise that resolves to the JWT token
 */
const authenticate = (adminData = {}, userData = {}) => {
  const { username: user, password: token } = adminData
  const { username: userOther, password: tokenOther } = userData

  const loginUser = (usr, tokn) => {
    const baseUrl = Cypress.config('baseUrl')
    const authPath = `${baseUrl}/api/auth`

    return cy
      .request('POST', authPath, { user: usr, token: tokn })
      .then((response) => {
        let tkn
        if (response.status === 304) {
          tkn = Cypress.env(ENV.TOKEN)
          if (!tkn) {
            throw new Error('The token is not defined in Cypress.env')
          }
        } else {
          tkn = response?.body?.data?.token
          if (!tkn) {
            throw new Error(
              response.status === 202
                ? 'The user has the 2FA'
                : 'The token was not found in the response'
            )
          }
          Cypress.env(ENV.TOKEN, tkn)
        }

        return tkn
      })
  }

  if (userOther && tokenOther) {
    const userApi = new User(user, token)

    return loginUser(user, token)
      .then(() =>
        userApi.allocate({ username: userOther, password: tokenOther })
      )
      .then(() => loginUser(userOther, tokenOther))
  } else {
    return loginUser(user, token)
  }
}

const wrapperAuth = (config) => {
  const isAdmin = Cypress.env(userKey)

  const params = [config?.admin]
  isAdmin && params.push(config?.user)

  return authenticate(...params)
}

Cypress.Commands.add('apiAuth', authenticate)
Cypress.Commands.add('wrapperAuth', wrapperAuth)
