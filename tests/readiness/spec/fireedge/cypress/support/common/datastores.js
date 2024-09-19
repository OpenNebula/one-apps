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

const { Datastore, Cluster } = require('@models')
const { Intercepts, createIntercept } = require('@support/utils/index')
const { PermissionsGui } = require('@support/commands/common')

const DATASTORE = new Datastore('files')
const CLUSTER = new Cluster('new_cluster')
const DEFAULT_CLUSTER = new Cluster('default')

const SYSTEM_DS_XML = {
  TYPE: 'SYSTEM_DS',
  TM_MAD: 'ssh',
}

const SYSTEM_DS_XML_WITH_LABELS = {
  TYPE: 'SYSTEM_DS',
  TM_MAD: 'ssh',
  LABELS: 'LABEL',
}

const IMAGE_DS_XML = {
  DS_MAD: 'fs',
  TM_MAD: 'ssh',
}

const LABEL = 'LABEL'

const TYPE_TO_NUMBER = {
  IMAGE: '0',
  SYSTEM: '1',
  FILE: '2',
  BACKUP: '3',
}

const CIPHER_KEYS = {
  RESTIC_PASSWORD: 'RESTIC_PASSWORD',
}

const IGNORED_KEYS = {
  stepType: 'stepType',
  stepId: 'stepId',
}

const joinWithSpaces = (values) => values.join(' ')
const joinWithCommas = (values) => values.join(',')

const JOINABLE_KEYS = {
  CEPH_HOST: joinWithCommas,
  BRIDGE_LIST: joinWithSpaces,
  RESTRICTED_DIRS: joinWithSpaces,
  SAFE_DIRS: joinWithSpaces,
}

/**
 * @param {object} datastoresToCreate - Datastores to create
 * @param {boolean} createForUser - True if the datastore is created for a user
 */
const beforeAllDatastoreTest = (datastoresToCreate, createForUser = false) => {
  cy.fixture('auth')
    .then((auth) => cy.apiAuth(auth.admin))
    .then(() => cy.cleanup())
    .then(() => CLUSTER.allocate({ name: CLUSTER.name }))
    .then(() => DEFAULT_CLUSTER.info())
    .then(() => DATASTORE.info())
    .then(() => {
      const datastores = Object.values(datastoresToCreate)
      const allocateFn =
        ([ds, attributes]) =>
        async () => {
          await ds.allocate({
            template: { ...attributes, NAME: ds.name },
            cluster: DEFAULT_CLUSTER.id,
          })

          if (createForUser) {
            ds.chmod({
              ownerUse: 1,
              ownerManage: 1,
              ownerAdmin: 0,
              groupUse: 0,
              groupManage: 0,
              groupAdmin: 0,
              otherUse: 1,
              otherManage: 1,
              otherAdmin: 0,
            })
          }
        }

      return cy.all(...datastores.map(allocateFn))
    })
}

/**
 * @param {object} datastores - Datastores to delete
 * @param {object} datastoresGui - Datastore names to delete
 */
const afterAllDatastoreTest = (datastores, datastoresGui) => {
  // comment theses lines if you want to keep the Datastores after the test
  cy.then(() =>
    Object.values(datastores).forEach(([ds]) => ds?.delete?.())
  ).then(() => {
    const deleteFn = (ds) => () => {
      const datastore = new Datastore(ds)

      return datastore.info().then(() => datastore.delete())
    }

    return cy.all(...Object.values(datastoresGui).map(deleteFn))
  })
  // Activate this line when the delete method has been created
  // .then(() => CLUSTER.delete())
}

/**
 * Disable a datastore.
 *
 * @param {object} datastore - Datastore to disable
 */
const disableDatastore = (datastore) => {
  if (datastore.id === undefined) throw new Error('Datastore was not created')
  cy.navigateMenu('storage', 'Datastores')
  cy.disableDatastore(datastore)
  cy.validateDatastoreState('DISABLED')
}

/**
 * Enable a datastore.
 *
 * @param {object} datastore - Datastore to disable
 */
const enableDatastore = (datastore) => {
  if (datastore.id === undefined) throw Error('Datastore was not created')
  cy.navigateMenu('storage', 'Datastores')
  cy.enableDatastore(datastore).then(() => cy.validateDatastoreState('READY'))
}

/**
 * Disable a datastore (Should fail).
 *
 * @param {object} datastore - Datastore to disable
 */
const disableDatastoreFail = (datastore) => {
  if (datastore.id === undefined) throw new Error('Datastore was not created')
  cy.navigateMenu('storage', 'Datastores')
  cy.disableDatastore(datastore)
  cy.get('div[id=notistack-snackbar]').should('be.visible')
  cy.get('div[id=notistack-snackbar]').should(
    'have.text',
    '[one.datastore.enable] Only SYSTEM_DS can be disabled or enabled'
  )
  cy.validateDatastoreState('READY')
}

/**
 * @param {object} datastore - Datastore to change ownership
 * @param {object} newOwner - New owner
 */
const changeDatastoreOwnership = (datastore, newOwner) => {
  if (datastore.id === undefined) return
  cy.navigateMenu('storage', 'Datastores')
  cy.all(() => newOwner.info())
    .then(() =>
      cy.changeOwnerDatastore({
        datastore,
        resource: newOwner,
      })
    )
    .then(() => {
      cy.navigateTab('info').within(() => {
        cy.getBySel('owner').should('have.text', newOwner.name)
      })
    })
}

/**
 * @param {object} datastore - Datastore to change ownership
 * @param {object} newGroup -  New group
 */
const changeDatastoreGroup = (datastore, newGroup) => {
  if (datastore.id === undefined) return
  cy.navigateMenu('storage', 'Datastores')
  cy.all(() => newGroup.info())
    .then(() =>
      cy.changeGroupDatastore({
        datastore,
        resource: newGroup,
      })
    )
    .then(() => {
      cy.navigateTab('info').within(() => {
        cy.getBySel('group').should('have.text', newGroup.name)
      })
    })
}

/**
 * @param {object} datastore - Datastore to change permissions
 * @param {PermissionsGui} permissions - Permissions to change
 */
const changeDatastorePermissions = (datastore, permissions) => {
  if (datastore.id === undefined) throw new Error('Datastore was not created')
  cy.navigateMenu('storage', 'Datastores')
  cy.clickDatastoreRow(datastore)
    .then(() =>
      cy.changePermissions(
        permissions,
        Intercepts.SUNSTONE.DATASTORE_CHANGE_MOD
      )
    )
    .then(() => cy.validatePermissions(permissions))
}

/**
 * @param {object} datastore - datastore to rename
 * @param {string} newName - New name
 */
const renameDatastore = (datastore, newName) => {
  if (datastore.id === undefined) return

  cy.navigateMenu('storage', 'Datastores')
  cy.clickDatastoreRow(datastore)
    .then(() => cy.renameResource(newName))
    .then(() => (datastore.name = newName))
    .then(() => cy.getDatastoreRow(datastore).click().contains(newName))
}

/**
 * @param {object} datastore - Datastore to delete
 */
const deleteDatastore = (datastore) => {
  if (datastore.id === undefined) throw Error('Datastore was not created')
  cy.navigateMenu('storage', 'Datastores')
  cy.deleteDatastore(datastore)
    .its('response.body.id')
    .should('eq', 200)
    .then(() => {
      cy.getDatastoreTable({ search: datastore.name }).within(() => {
        cy.get(`[role='row'][data-cy$='${datastore.id}']`).should('not.exist')
      })
    })
}

const selectCluster = (datastore, opts) => {
  if (datastore.id === undefined) throw Error('Datastore was not created')
  cy.navigateMenu('storage', 'Datastores')

  return cy
    .clickDatastoreRow(datastore)
    .then(() => cy.contains('Select Cluster').click())
    .then(() => cy.getBySel('modal-select-cluster').should('be.visible'))
    .then(() => cy.getBySel(`cluster-${CLUSTER.id}`).should('be.visible'))
    .then(() => {
      if (!opts) {
        cy.getBySel(`cluster-${DEFAULT_CLUSTER.id}`).click()
      }
    })
    .then(() => cy.contains(CLUSTER.name).click(opts))
    .then(() => cy.contains('Accept').click())
    .then(() => cy.getBySel('unselect').click())
    .then(() => cy.getBySel('refresh').click())
}

/**
 * @param {object} datastore - Datastore to append cluster
 */
const appendClusterToDatastore = (datastore) => {
  selectCluster(datastore, { ctrlKey: true }).then(() =>
    cy
      .getDatastoreRow(datastore)
      .click()
      .should('be.visible')
      .then(($datastoreRow) => {
        cy.wrap($datastoreRow).contains('+1 More').should('be.visible')
      })
  )
}

/**
 * @param {object} datastore - Datastore to change cluster
 */
const changeDatastoreCluster = (datastore) => {
  selectCluster(datastore).then(() =>
    cy
      .getDatastoreRow(datastore)
      .click()
      .should('be.visible')
      .then(($datastoreRow) => {
        cy.wrap($datastoreRow).contains(CLUSTER.id).should('be.visible')
      })
  )
}

/**
 * @param {object} datastore - Datastore to add label
 * @param {string} label - Label to add
 */
const addLabelToDatastore = (datastore, label) => {
  if (datastore.id === undefined) throw Error('Datastore was not created')
  cy.navigateMenu('storage', 'Datastores')

  cy.applyLabelsToDatastoreRows([datastore], [label]).then(() => {
    datastore.info().then((info) => {
      // exists in the resource
      const dsLabels = info.TEMPLATE.LABELS

      cy.wrap(dsLabels).should('contain', label)

      // exist on the UI
      cy.getDatastoreRow(datastore).click().contains(label)
    })
  })
}

/**
 * @param {object} datastore - Datastore to add label
 * @param {string} label - Label to add
 */
const deleteLabelfromDatastore = (datastore, label) => {
  if (datastore.id === undefined) throw Error('Datastore was not created')
  // const intercept = createIntercept(Intercepts.SUNSTONE.DATASTORE)
  cy.navigateMenu('storage', 'Datastores')
  cy.applyLabelsToDatastoreRows([datastore], [label], true).then(() => {
    datastore.info().then((info) => {
      // not exist on the UI
      const dsLabels =
        info.TEMPLATE && info.TEMPLATE.LABELS ? info.TEMPLATE.LABELS : '' // Does not exist

      cy.getDatastoreRow(datastore, { clearSearch: true })
        .click()
        .find(`[data-cy='label-${label}']`)
        .should('not.exist')
      // exists in the resource
      cy.wrap(dsLabels).should('not.include', label)
    })
    // cy.wait(intercept)
  })
}

/**
 * @param {Array[Object]} stepsValues - Values for each step
 */
const createDatastore = (stepsValues) => {
  cy.navigateMenu('storage', 'Datastores')
  cy.getBySel('action-datastore_create_dialog').click()
  const intercept = createIntercept(Intercepts.SUNSTONE.DATASTORES)
  cy.fillStepper(stepsValues)

  cy.wait(intercept)

  // Validate the datastore was created
  const [general, cluster, configAttrs, customVars] = stepsValues
  const datastore = new Datastore(general.NAME)

  // Wait until datastore is updated/created
  // TODO: REMOVE STATIC WAIT, MAKE THIS MORE ROBUST
  // eslint-disable-next-line cypress/no-unnecessary-waiting
  cy.wait(5000)
  cy.waitUntil(
    () =>
      datastore
        .info()
        .then((info) => info && info?.TYPE === TYPE_TO_NUMBER?.[general.TYPE]),
    { timeout: 12000, interval: 4000 }
  ).then(() => {
    // Validations for general values
    expect(datastore.json).to.have.property(
      'TYPE',
      TYPE_TO_NUMBER[general.TYPE]
    )

    const [dsMad, tmMad] = general.STORAGE_BACKEND.split('-')

    if (general.TYPE === 'SYSTEM') {
      expect(datastore.json).to.have.property('DS_MAD', '-')
    } else {
      expect(datastore.json).to.have.property('DS_MAD', dsMad)
    }

    tmMad
      ? expect(datastore.json).to.have.property('TM_MAD', tmMad)
      : expect(datastore.json).to.have.property('TM_MAD', '-')

    expect(datastore.json.CLUSTERS).to.have.property('ID', cluster.id)

    // Validations for custom variables
    if (customVars != null) {
      for (const [key, value] of [
        ...Object.entries(customVars),
        ...Object.entries(configAttrs),
      ]) {
        // Some values are cipher by opennebula core,
        // we will check if they are different
        if (Object.values(IGNORED_KEYS).includes(key)) {
          console.info(`Ignoring key ${key}...`)
        } else if (Object.values(CIPHER_KEYS).includes(key)) {
          expect(datastore.json.TEMPLATE).to.have.property(key)
          expect(datastore.json.TEMPLATE[key]).to.not.equal(value)
        } else if (Object.keys(JOINABLE_KEYS).includes(key)) {
          expect(datastore.json.TEMPLATE).to.have.property(key)
          expect(datastore.json.TEMPLATE[key]).to.include(
            JOINABLE_KEYS[key](value)
          )
        } else expect(datastore.json.TEMPLATE).to.have.property(key, value)
      }
    }
  })
}

module.exports = {
  SYSTEM_DS_XML,
  SYSTEM_DS_XML_WITH_LABELS,
  IMAGE_DS_XML,
  LABEL,
  beforeAllDatastoreTest,
  disableDatastore,
  disableDatastoreFail,
  enableDatastore,
  changeDatastorePermissions,
  changeDatastoreOwnership,
  changeDatastoreGroup,
  renameDatastore,
  deleteDatastore,
  appendClusterToDatastore,
  changeDatastoreCluster,
  afterAllDatastoreTest,
  addLabelToDatastore,
  deleteLabelfromDatastore,
  createDatastore,
}
