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

const getFSunstoneViewsConf = () =>
  cy
    .fixture('fsunstone_views')
    .then((fsunstoneView) => cy.readFile(fsunstoneView.pathConfig))
    .then((yaml) => cy.task('yamlToJson', yaml))
    .then((config) => {
      Cypress.env('FSUNSTONE_VIEW', config)

      return config
    })

const updateFSunstoneViewsConf = (newConfig = {}, backupConfig = true) => {
  let fixture

  return cy
    .fixture('fsunstone_views')
    .then((fsunstoneView) => (fixture = fsunstoneView))
    .then(() => backupConfig && cy.task('copy', fixture))
    .then(() => cy.task('jsonToYaml', newConfig))
    .then((yaml) => cy.writeFile(fixture.pathConfig, yaml))
    .then(() => getFSunstoneViewsConf())
}

const restoreFSunstoneViewsConf = (restart = false) =>
  cy
    .fixture('fsunstone_views')
    .then((fsunstoneView) =>
      cy.task('copy', {
        pathTemp: fsunstoneView.pathConfig,
        pathConfig: fsunstoneView.pathTemp,
      })
    )
    .then(() => restart && cy.restartServer())
    .then(() => getFSunstoneViewsConf())

const getFireedgeServerConf = () =>
  cy
    .fixture('fireedge_server')
    .then((fireedgeServer) => cy.readFile(fireedgeServer.pathConfig))
    .then((yaml) => cy.task('yamlToJson', yaml))
    .then((config) => {
      Cypress.env('FIREEDGE_CONF', config)

      return config
    })

const getFSunstoneServerConf = () =>
  cy
    .fixture('sunstone_server')
    .then((sunstoneServer) => cy.readFile(sunstoneServer.pathConfig))
    .then((yaml) => cy.task('yamlToJson', yaml))
    .then((config) => {
      Cypress.env('SUNSTONE_CONF', config)

      return config
    })

const getYamlFixture = (filename = '') =>
  cy.fixture(filename).then((yaml) => cy.task('yamlToJson', yaml))

const updateFireedgeServerConf = (newConfig = {}) => {
  let fixture

  return cy
    .fixture('fireedge_server')
    .then((fireedgeServer) => (fixture = fireedgeServer))
    .then(() => cy.task('copy', fixture))
    .then(() => cy.task('jsonToYaml', newConfig))
    .then((yaml) => cy.writeFile(fixture.pathConfig, yaml))
    .then(() => getFireedgeServerConf())
}

const updateFSunstoneServerConf = (newConfig = {}) => {
  let fixture

  return cy
    .fixture('sunstone_server')
    .then((sunstoneServer) => (fixture = sunstoneServer))
    .then(() => cy.task('copy', fixture))
    .then(() => cy.task('jsonToYaml', newConfig))
    .then((yaml) => cy.writeFile(fixture.pathConfig, yaml))
    .then(() => getFSunstoneServerConf())
}

const restoreFireedgeServerConf = (restart = false) =>
  cy
    .fixture('fireedge_server')
    .then((fireedgeServer) =>
      cy.task('copy', {
        pathTemp: fireedgeServer.pathConfig,
        pathConfig: fireedgeServer.pathTemp,
      })
    )
    .then(() => restart && cy.restartServer())

const restoreFSunstoneServerConf = (restart = false) =>
  cy
    .fixture('sunstone_server')
    .then((sunstoneServer) =>
      cy.task('copy', {
        pathTemp: sunstoneServer.pathConfig,
        pathConfig: sunstoneServer.pathTemp,
      })
    )
    .then(() => restart && cy.restartServer())

const addPrependCommand = (command = '', args = '') =>
  cy.task('dotenv', { log: false }).then((data) => {
    const prepend = data?.CLI_COMMAND_PREPEND
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
  })

const checkFireedgeServerRunning = (start) =>
  addPrependCommand('ss', ['-tanpl', 'sport = :2616', '--no-header'])
    .then(([command, params]) =>
      cy.exec([command, ...params].join(' '), { failOnNonZeroExit: false })
    )
    .then(
      (process) =>
        !!((start ? process.stdout : !process.stdout) && process.code === 0)
    )

const fireedgeCLIServer = (status = 'start') => {
  const start = status === 'start'

  return addPrependCommand('sudo', ['systemctl', status, 'opennebula-fireedge'])
    .then(([command, params]) =>
      cy.exec([command, ...params].join(' '), {
        failOnNonZeroExit: true,
        timeout: 120000 /* 2 minutes */,
      })
    )
    .then(() => cy.waitUntil(() => checkFireedgeServerRunning(start)))
}

const startServer = () => fireedgeCLIServer('start')

const stopServer = () => fireedgeCLIServer('stop')

const restartServer = () =>
  cy.all(
    () => stopServer(),
    () => startServer()
  )

const checkOpennebulaServiceRunning = (start) =>
  addPrependCommand('ss', ['-tanpl', 'sport = :2633', '--no-header'])
    .then(([command, params]) =>
      cy.exec([command, ...params].join(' '), { failOnNonZeroExit: false })
    )
    .then(
      (process) =>
        !!((start ? process.stdout : !process.stdout) && process.code === 0)
    )

const opennebulaCLIServer = (status = 'start') => {
  const start = status === 'start'

  return addPrependCommand('sudo', ['systemctl', status, 'opennebula'])
    .then(([command, params]) =>
      cy.exec([command, ...params].join(' '), {
        failOnNonZeroExit: true,
        timeout: 120000 /* 2 minutes */,
      })
    )
    .then(() => cy.waitUntil(() => checkOpennebulaServiceRunning(start)))
}

const startOpennebulaSevice = () => opennebulaCLIServer('start')

const stopOpennebulaSevice = () => opennebulaCLIServer('stop')

const restartOpennebulaService = () =>
  cy.all(
    () => stopOpennebulaSevice(),
    () => startOpennebulaSevice()
  )

/**
 * Function to manage opennebula-scheduler service.
 *
 * @param {string} status - status of the server (start|stop)
 * @returns {object} result - Result of execute command.
 */
const schedulerCLIServer = (status = 'start') =>
  addPrependCommand('sudo', ['systemctl', status, 'opennebula-scheduler']).then(
    ([command, params]) =>
      cy.exec([command, ...params].join(' '), {
        failOnNonZeroExit: true,
        timeout: 120000 /* 2 minutes */,
      })
  )

/**
 * Start opennebula-scheduler service.
 *
 * @returns {object} result - Result of execute command.
 */
const startScheduler = () => schedulerCLIServer('start')

/**
 * Stop opennebula-scheduler service.
 *
 * @returns {object} result - Result of execute command.
 */
const stopScheduler = () => schedulerCLIServer('stop')

const restartScheduler = () =>
  cy.all(
    () => stopScheduler(),
    () => startScheduler()
  )

Cypress.Commands.add('startServer', startServer)
Cypress.Commands.add('stopServer', stopServer)
Cypress.Commands.add('restartServer', restartServer)

Cypress.Commands.add('startScheduler', startScheduler)
Cypress.Commands.add('stopScheduler', stopScheduler)
Cypress.Commands.add('restartScheduler', restartScheduler)

Cypress.Commands.add('startOpennebulaSevice', startOpennebulaSevice)
Cypress.Commands.add('stopOpennebulaSevice', stopOpennebulaSevice)
Cypress.Commands.add('restartOpennebulaService', restartOpennebulaService)

Cypress.Commands.add('getYamlFixture', getYamlFixture)
Cypress.Commands.add('getFireedgeServerConf', getFireedgeServerConf)
Cypress.Commands.add('getFSunstoneViewsConf', getFSunstoneViewsConf)
Cypress.Commands.add('updateFSunstoneViewsConf', updateFSunstoneViewsConf)
Cypress.Commands.add('restoreFSunstoneViewsConf', restoreFSunstoneViewsConf)
Cypress.Commands.add('updateFireedgeServerConf', updateFireedgeServerConf)
Cypress.Commands.add('restoreFireedgeServerConf', restoreFireedgeServerConf)
Cypress.Commands.add('getFSunstoneServerConf', getFSunstoneServerConf)
Cypress.Commands.add('updateFSunstoneServerConf', updateFSunstoneServerConf)
Cypress.Commands.add('restoreFSunstoneServerConf', restoreFSunstoneServerConf)
