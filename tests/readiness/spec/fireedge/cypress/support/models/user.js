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
import { Decoder } from '@nuintun/qrcode'
import { URI } from 'otpauth'

import { OpenNebulaResource } from '@models'

class User extends OpenNebulaResource {
  /**
   * @param {string} username - The username
   * @param {string} password - The password
   */
  constructor(username, password) {
    super(username)
    this.qrcode = new Decoder()
    this.password = password
  }

  /**
   * @returns {{ username: string, password: string }} Username and plain password
   */
  get credentials() {
    return { username: this.name, password: this.password }
  }

  /**
   * @returns {string} Authentication driver
   */
  get driver() {
    return this.json.AUTH_DRIVER
  }

  /**
   * Retrieves information for the image.
   *
   * @param {boolean} decrypt - Decrypt the password
   * @returns {Cypress.Chainable<object>}
   * - A promise that resolves to the user information
   */
  info(decrypt) {
    const id = this.id ?? this.name

    return cy.apiGetUser(id, { decrypt }).then((user) => {
      this.json = user

      return user
    })
  }

  /**
   * Allocates a new user in OpenNebula.
   *
   * @param {object} body - Request body for the POST request
   * @param {string} [body.username] - Username for the new user
   * @param {string} [body.password] - Password for the new user
   * @param {string} [body.driver] - Authentication driver for the new user
   * @param {string[]} [body.group] - Array of Group IDs
   * @returns {Cypress.Chainable<object>} A promise that resolves to the user information
   */
  allocate(body = {}) {
    body.username ??= this.name
    body.password ??= this.password

    return cy.apiAllocateUser(body).then((userId) => {
      this.id = userId

      return this.info()
    })
  }

  /**
   * Replaces the User template contents.
   *
   * @param {object} template - An object containing the template
   * @param {0|1} replace - Update type
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves to the user information
   */
  update(template, replace) {
    return cy
      .apiUpdateUser(this.id, { template, replace })
      .then(() => this.info())
  }

  /**
   * @returns {Cypress.Chainable<Cypress.Response>}
   * A promise that resolves to the user id
   */
  delete() {
    return cy.apiDeleteUser(this.id)
  }

  /**
   * Get base64 QR.
   *
   * @returns {Cypress.Chainable<object>} base64 QR 2FA
   */
  getqr() {
    return cy.apiUserGet2faQr().then((qrImage) => {
      this.qr = qrImage

      return qrImage
    })
  }

  /**
   * Decode QR.
   *
   * @returns {Cypress.Chainable<object>} otpauth path
   */
  decodeqr() {
    return this.qrcode.scan(this.qr).then((result) => result?.data)
  }

  /**
   * Get Authentication code.
   *
   * @returns {Cypress.Chainable<object>} authentication six-digit code
   */
  getAuthCode() {
    return this.decodeqr().then((data) => URI.parse(data).generate())
  }

  /**
   * Set 2FA to user.
   *
   * @param {string} key - authentication six-digit code
   * @returns {Cypress.Chainable<Cypress.Response>}
   * A promise that resolves to set TFA
   */
  set2fa(key) {
    return cy.apiSetTfa(key)
  }

  /**
   * Delete 2FA to user.
   *
   * @returns {Cypress.Chainable<object>}
   * A promise that resolves to delete TFA
   */
  delete2fa() {
    return cy.apiDeleteTfa()
  }
}

export default User
