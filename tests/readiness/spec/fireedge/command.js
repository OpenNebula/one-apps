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
const cypress = require('cypress')
const marge = require('mochawesome-report-generator')
const { env } = require('process')
const { merge } = require('mochawesome-merge')
const {
  existsSync,
  mkdirsSync,
  readFileSync,
  writeFileSync,
  removeSync,
} = require('fs-extra')
const { dirname, resolve } = require('path')

const config = {
  headless: true,
  spec: ((env && env.ENV_TYPE) || 'func')
    .split('|')
    .map((type) => `./cypress/e2e/**/*.${type}.cy.js`)
    .join(','),
  browser: 'chrome',
}

if (process && process.argv && Array.isArray(process.argv)) {
  const rgexBrowser = /^browser=/g
  const pass = process.argv.find((argv) => rgexBrowser.test(argv))
  if (pass) {
    config.browser = pass.replace(rgexBrowser, '')
  }
}

const breakCommand = (error = '') => {
  let number = 0
  if (error) {
    number = 1
    console.error(error)
  }
  process.exit(number)
}

const generateReport = (
  options = {
    reportDir: 'cypress/results',
    reportFilename: 'merge-results',
    saveJson: true,
    saveHtml: false,
    files: ['./cypress/results/*.json'],
  }
) => merge(options).then((report) => marge.create(report, options))

const parseReport = (dataReport = '') => {
  if (
    !(env && env.NO_REPORT) &&
    dataReport &&
    Array.isArray(dataReport) &&
    dataReport.slice(-1).pop()
  ) {
    const pathMergeJson = dataReport.slice(-1).pop()
    const bsname = dirname(pathMergeJson)
    const fileData = readFileSync(pathMergeJson, 'utf8')
    if (fileData) {
      const dataJSON = JSON.parse(fileData)
      const parsedJSON = {}

      // version
      parsedJSON.version = dataJSON.meta.mochawesome.version

      // examples
      const examples = []
      // results -19
      if (dataJSON.results) {
        dataJSON.results.forEach((results) => {
          const pathTest = results.fullFile
          // results.suites -28
          if (results && results.suites && Array.isArray(results.suites)) {
            results.suites.forEach((suites) => {
              // result.suites.tests -36
              if (
                suites &&
                suites.tests &&
                Array.isArray(suites.tests) &&
                suites.tests.length > 0
              ) {
                suites.tests.forEach((test) => {
                  const parsedTest = {}
                  parsedTest.id = pathTest
                  parsedTest.description = test.title || null
                  parsedTest.full_description = test.fullTitle || null
                  parsedTest.status = test.pass ? 'passed' : 'failed'
                  parsedTest.file_path = pathTest
                  parsedTest.line_number = null
                  parsedTest.run_time = test.duration || null
                  parsedTest.pending_message = null

                  parsedTest.exception = {
                    class: test ? test.err.message : '',
                    backtrace:
                      test && test.err.estack ? [test.err.estack] : null,
                    message:
                      test && test.code && test.code.length
                        ? test.code.replace(/(")|(\\)/gm, '')
                        : '',
                  }
                  examples.push(parsedTest)
                })
              } else if (
                suites &&
                suites.suites &&
                Array.isArray(suites.suites) &&
                suites.suites.length > 0
              ) {
                suites.suites.forEach((suiteChildren) => {
                  if (
                    suiteChildren &&
                    suiteChildren.tests &&
                    Array.isArray(suiteChildren.tests) &&
                    suiteChildren.tests.length > 0
                  ) {
                    suiteChildren.tests.forEach((test) => {
                      const parsedTest = {}
                      parsedTest.id = pathTest
                      parsedTest.description = test.title || null
                      parsedTest.full_description = test.fullTitle || null
                      parsedTest.status = test.pass ? 'passed' : 'failed'
                      parsedTest.file_path = pathTest
                      parsedTest.line_number = null
                      parsedTest.run_time = test.duration || null
                      parsedTest.pending_message = null

                      parsedTest.exception = {
                        class: test ? test.err.message : '',
                        backtrace:
                          test && test.err.estack ? [test.err.estack] : null,
                        message:
                          test && test.code && test.code.length
                            ? test.code.replace(/(")|(\\)/gm, '')
                            : '',
                      }
                      examples.push(parsedTest)
                    })
                  }
                })
              }
            })
          }
        })
      }
      parsedJSON.examples = examples

      // summary
      parsedJSON.summary = {
        duration: dataJSON.stats.duration,
        example_count: dataJSON.stats.tests,
        failure_count: dataJSON.stats.failures,
        pending_count: dataJSON.stats.pending,
        errors_outside_of_examples_count: dataJSON.stats.other,
      }

      // summary_line
      parsedJSON.summary_line = `${dataJSON.stats.testsRegistered} examples, ${dataJSON.stats.failures} failures`

      // clear results folder
      removeSync(bsname)

      // create path for results for jenkins
      const jenkinsResultsPath = resolve(__dirname, '..', '..', 'results')
      if (!existsSync(jenkinsResultsPath)) {
        mkdirsSync(jenkinsResultsPath)
      }

      // create JSON file
      writeFileSync(
        resolve(jenkinsResultsPath, 'results.json'),
        JSON.stringify(parsedJSON)
      )
    }
  }
  breakCommand()
}

const runTests = (callback = () => undefined, cfg = config) => {
  cypress
    .run(cfg)
    .then((results) => {
      if (results && results.status !== 'failed') {
        generateReport().then(parseReport).catch(breakCommand)
      } else {
        callback(results.message)
      }
    })
    .catch((error) => breakCommand(error))
}

runTests((mssgChrome) => {
  console.error(mssgChrome)
  config.browser = 'chromium'
  runTests((mssgChromium) => breakCommand(mssgChromium), config)
})
