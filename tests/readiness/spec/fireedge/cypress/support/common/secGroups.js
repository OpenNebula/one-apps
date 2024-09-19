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
const { Group, SecurityGroup, User } = require('@models')
const { Intercepts } = require('@support/utils')

const SERVERADMIN_USER = new User('serveradmin')
const USERS_GROUP = new Group('users')

/**
 * Function to be executed before each Security group test.
 */
const beforeEachSecGroupTest = () => {
  cy.visit(`${Cypress.config('baseUrl')}/sunstone`, {
    qs: { externalToken: Cypress.env('TOKEN') },
  })
}

/**
 * Before cypress for security group tests.
 *
 * @param {object} resources - resources
 */
const beforeAllSecGroupTest = (resources = {}) => {
  const { SECGROUPS, BASIC_SECGROUP_XML } = resources

  cy.fixture('auth')
    .then((auth) => cy.wrapperAuth(auth))
    .then(() => {
      const secGroups = Object.values(SECGROUPS)
      const allocateFn = (secGroup) => () =>
        secGroup.allocate({
          template: { ...BASIC_SECGROUP_XML, NAME: secGroup.name },
        })

      return cy.all(...secGroups.map(allocateFn))
    })
}

/**
 * After cypress for security group tests.
 *
 * @param {object} resources - resources
 */
const afterAllSecGroupsTest = (resources = {}) => {
  const { SECGROUPS, SECGROUPS_GUI } = resources
  // comment theses lines if you want to keep the Security Groups after the test
  cy.then(() =>
    // this deletes the automatically created security groups
    Object.values(SECGROUPS).forEach((secGroup) => secGroup?.delete?.())
  ).then(() => {
    const deleteFn = (secGrp) => () => {
      const secGroup = new SecurityGroup(secGrp)

      return secGroup.info().then(() => secGroup.delete())
    }

    // this delete the manually created security groups
    return cy.all(...Object.values(SECGROUPS_GUI).map(deleteFn))
  })
}

/**
 * Create a security group GUI.
 *
 * @param {object} resources - resources
 */
const createSecGroupGUI = (resources = {}) => {
  const { SECGROUP_TEMPLATE_GUI, SECGROUPS_GUI } = resources

  cy.navigateMenu('networks', 'Security Groups')
  cy.createSecurityGroupGUI({
    ...SECGROUP_TEMPLATE_GUI,
    NAME: SECGROUPS_GUI.CREATE_GUI,
    DESCRIPTION: `Description ${SECGROUPS_GUI.CREATE_GUI}`,
  })
    .its('response.body.id')
    .should('eq', 200)
}

/**
 * Update a security group GUI.
 *
 * @param {object} resources - resources
 */
const updateSecGroupGUI = (resources = {}) => {
  const { SECGROUP_TEMPLATE_GUI, SECGROUPS_GUI, SECGROUPS } = resources

  cy.navigateMenu('networks', 'Security Groups')
  cy.updateSecurityGroupGUI(
    {
      ...SECGROUP_TEMPLATE_GUI,
      NAME: SECGROUPS_GUI.CREATE_GUI,
      DESCRIPTION: `Description! ${SECGROUPS_GUI.CREATE_GUI}`,
    },
    SECGROUPS.update
  )
    .its('response.body.id')
    .should('eq', 200)
}

/**
 * Commit a security group GUI.
 *
 * @param {object} SECGROUPS - security groups
 */
const commitSecGroupGUI = (SECGROUPS) => {
  if (SECGROUPS.commit.id === undefined) return
  cy.navigateMenu('networks', 'Security Groups')

  cy.commitSecurityGroup(SECGROUPS.commit)
    .its('response.body.id')
    .should('eq', 200)
}

/**
 * Clone a security group GUI.
 *
 * @param {object} resources - resources
 */
const cloneSecGroupGUI = (resources = {}) => {
  const { SECGROUPS, SECGROUPS_GUI } = resources

  if (SECGROUPS.clone.id === undefined) return
  cy.navigateMenu('networks', 'Security Groups')

  cy.cloneSecurityGroup(SECGROUPS.clone, SECGROUPS_GUI.CLONE)
    .its('response.body.id')
    .should('eq', 200)
}

/**
 * Delete a security group GUI.
 *
 * @param {object} SECGROUPS - security groups
 */
const deleteSecGroupGUI = (SECGROUPS) => {
  if (SECGROUPS.delete.id === undefined) return
  cy.navigateMenu('networks', 'Security Groups')
  cy.deleteSecGroup(SECGROUPS.delete)
    .its('response.body.id')
    .should('eq', 200)
    .then(() => {
      cy.getSecGroupTable({ search: SECGROUPS.delete.name }).within(() => {
        cy.get(`[role='row'][data-cy$='${SECGROUPS.delete.id}']`).should(
          'not.exist'
        )
      })
    })
}

/**
 * Change permissions a security group GUI.
 *
 * @param {object} resources - resources
 */
const changePermissionsSecGroupGUI = (resources = {}) => {
  const { SECGROUPS, NEW_PERMISSIONS } = resources

  if (SECGROUPS.changePermission.id === undefined) return
  cy.navigateMenu('networks', 'Security Groups')

  cy.clickSecGroupRow(SECGROUPS.changePermission)
    .then(() =>
      cy.changePermissions(
        NEW_PERMISSIONS,
        Intercepts.SUNSTONE.SECGROUP_CHANGE_MOD
      )
    )
    .then(() => cy.validatePermissions(NEW_PERMISSIONS))
}

/**
 * Rename a security group GUI.
 *
 * @param {object} SECGROUPS - security groups
 */
const renameSecGroupGUI = (SECGROUPS) => {
  if (SECGROUPS.rename.id === undefined) return
  const newName = SECGROUPS.rename.name.replace('sec_', 'sec_renamed_')
  cy.navigateMenu('networks', 'Security Groups')
  cy.clickSecGroupRow(SECGROUPS.rename)
    .then(() => cy.renameResource(newName))
    .then(() => (SECGROUPS.rename.name = newName))
    .then(() => cy.getSecGroupRow(SECGROUPS.rename).contains(newName))
}

/**
 * Change owner a security group GUI.
 *
 * @param {object} SECGROUPS - security groups
 */
const changeOwnershipGUI = (SECGROUPS) => {
  if (SECGROUPS.ownership.id === undefined) return
  cy.navigateMenu('networks', 'Security Groups')
  cy.all(
    () => SERVERADMIN_USER.info(),
    () => USERS_GROUP.info()
  )
    .then(() =>
      cy.changeSecGroupOwner(SECGROUPS.ownership, { user: SERVERADMIN_USER })
    )
    .then(() =>
      cy.changeSecGroupGroup(SECGROUPS.ownership, { group: USERS_GROUP })
    )
    .then(() => {
      cy.navigateTab('info').within(() => {
        cy.getBySel('owner').should('have.text', SERVERADMIN_USER.name)
        cy.getBySel('group').should('have.text', USERS_GROUP.name)
      })
    })
}

module.exports = {
  beforeEachSecGroupTest,
  beforeAllSecGroupTest,
  afterAllSecGroupsTest,
  createSecGroupGUI,
  updateSecGroupGUI,
  commitSecGroupGUI,
  cloneSecGroupGUI,
  deleteSecGroupGUI,
  changePermissionsSecGroupGUI,
  renameSecGroupGUI,
  changeOwnershipGUI,
}
