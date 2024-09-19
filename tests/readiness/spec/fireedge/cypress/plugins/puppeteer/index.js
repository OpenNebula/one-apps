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

const md5 = require('md5')
const puppeteer = require('puppeteer')
const { PNG } = require('pngjs')
const pixelmatch = require('pixelmatch')
const {
  writeFileSync,
  readFileSync,
  readdirSync,
  removeSync,
} = require('fs-extra')
const { resolve } = require('path')
const {
  ttyImage,
  ttyImageName,
  currentImageName,
  wildImage,
  wildImageName,
} = require('./config')

const {
  browsers,
  elements,
  baseUrl: configBaseURL,
  browserArgs,
} = require('./config')

const downloadPath = '/tmp/pptrDownload'

/**
 * Get Temporal path file.
 *
 * @param {string} name - filename
 * @param {string} ext - file extension
 * @returns {string} pathfile
 */
const tmpPath = (name, ext = 'png') => resolve(`/tmp/${name}.${ext}`)

/**
 * Save base64 image to PNG.
 *
 * @param {string} data - base64 data file
 * @param {string} name - filename
 */
const base64ToPNG = (data = '', name = '') => {
  const dataWithoutHeader = data.replace(/^data:image\/png;base64,/, '')

  writeFileSync(tmpPath(name), dataWithoutHeader, 'base64')
}

/**
 * Launch puppeter browser.
 *
 * @param {string} config - browser config
 * @param {string} config.browser - cypress type browser
 * @param {string} config.baseUrl - base URl
 * @returns {object} pprt
 */
const puppeteerLaunch = async (config = {}) => {
  const { browser, baseUrl, viewportHeight, viewportWidth } = config

  const browserUrl = baseUrl || configBaseURL
  const browserHeadless = (browser && browser.isHeadless) || false
  const pptrConfig = {
    args: browserArgs,
    product:
      browser && browser.name && browser.name === browsers.firefox
        ? browser.name
        : browsers.chrome,
    headless: browserHeadless,
    devtools: !browserHeadless,
  }

  if (viewportHeight && viewportWidth) {
    pptrConfig.defaultViewport = {
      width: viewportWidth,
      height: viewportHeight,
    }
  }

  writeFileSync(
    tmpPath('ppt-config', 'txt'),
    JSON.stringify({ ...config, pagePPTURL: browserUrl })
  )
  const pptr = await puppeteer.launch(pptrConfig)

  const context = await pptr.createIncognitoBrowserContext()
  const page = await context.newPage()
  await page.setDefaultNavigationTimeout(0)
  await page._client.send('Page.setDownloadBehavior', {
    behavior: 'allow',
    downloadPath,
  })
  await page.goto(`${browserUrl}`)
  removeSync(downloadPath)

  return {
    browser: pptr,
    page,
  }
}

/**
 * Wait for request.
 *
 * @param {string} url - url.
 * @param {object} page - pptr page.
 */
const waitForRequest = async (url = '', page) => {
  await page.waitForResponse((response) => response.url().startsWith(url))
}

/**
 * Wait till html is redered.
 *
 * @param {object} page - pptr page
 * @param {number} timeout - timeout
 */
const waitTillHTMLRendered = async (page, timeout = 30000) => {
  const checkDurationMsecs = 1000
  const maxChecks = timeout / checkDurationMsecs
  let lastHTMLSize = 0
  let checkCounts = 1
  let countStableSizeIterations = 0
  const minStableSizeIterations = 3

  while (checkCounts++ <= maxChecks) {
    const html = await page.content()
    const currentHTMLSize = html.length

    lastHTMLSize !== 0 && currentHTMLSize === lastHTMLSize
      ? countStableSizeIterations++
      : (countStableSizeIterations = 0)

    if (countStableSizeIterations >= minStableSizeIterations) break

    lastHTMLSize = currentHTMLSize
    await page.waitForTimeout(checkDurationMsecs)
  }
}

/**
 * Login in fireedge.
 *
 * @param {object} auth - data auth
 * @param {string} auth.username - data auth username
 * @param {string} auth.password - data auth user password
 * @param {string} auth.jwtName - name JWT
 * @param {object} page - pptr page
 * @param {boolean} isUser - True if the user doesn't have administrative privileges
 * @returns {object} puppeteer browser information
 */
const logIn = async (auth = {}, page, isUser = false) => {
  const { jwtName, admin: adminCredentials, user: userCredentials } = auth
  const { username, password } = isUser ? userCredentials : adminCredentials
  let rtn = null
  if (page && username && password && jwtName) {
    try {
      await waitTillHTMLRendered(page)
      await page.waitForSelector(elements.username)
      await page.focus(elements.username)
      await page.keyboard.type(username)

      await page.waitForSelector(elements.password)
      await page.focus(elements.password)
      await page.keyboard.type(password)

      await page.waitForSelector(elements.submit)
      await page.focus(elements.submit)
      await page.click(elements.submit, { force: true })

      await page.waitForNavigation({ timeout: 90000 })

      const jwt = await page.evaluate(
        (key) => localStorage.getItem(key),
        jwtName
      )
      if (jwt) {
        rtn = jwt
      }
    } catch (error) {
      writeFileSync(tmpPath('ppt-url', 'txt'), JSON.stringify(page.url()))
      page.screenshot({ path: '/tmp/error_login.png' })
    }
  }

  return rtn
}

/**
 * Navigate using sidedabar menu.
 *
 * @param {object} navigate - navigate object
 * @param {string} navigate.parent - item parent
 * @param {string} navigate.item - item menu
 * @param {object} page - pptr page
 */
const navigateMenu = async (navigate = {}, page) => {
  const { parent, item } = navigate

  await page.waitForSelector(elements.mainMenu)
  await page.hover(elements.mainMenu)

  await page.waitForTimeout(300)

  await page.waitForSelector(`div[data-cy=${parent}]`)
  const $parent = await page.$(`div[data-cy=${parent}]`)
  const classValue = await (await $parent.getProperty('className')).jsonValue()
  !classValue.includes('open') && (await $parent.click())

  // Wait 3 seconds to the submenu is not hidden
  await page.waitForTimeout(3000)

  const $item = await page.$x(
    `//span[contains(@data-cy, "main-menu-item") and text()="${item}"]`
  )
  await $item?.[0]?.click()
}

/**
 * Click on button Console.
 *
 * @param {object} vm - vm config.
 * @param {number} vm.id - vm id.
 * @param {string} vm.waitURLListVms - url for wait
 * @param {string} vm.type - type console
 * @param {object} page - pprt page
 */
const clickConsoleButton = async (vm = {}, page) => {
  const { id, type } = vm
  await waitTillHTMLRendered(page)
  const xpath = `//button[contains(@data-cy, "${id}-${type}")]`
  await page.waitForTimeout(xpath)
  const $item = await page.$x(xpath)
  await $item?.[0]?.click()
}

/**
 * Find marketapp and download.
 *
 * @param {object} app - vm config.
 * @param {number} app.id - vm id.
 * @param {string} app.waitURLListVms - url for wait
 * @param {object} page - pptr page
 * @returns {string[]} downloaded md5 files
 */
const findAndDownloadMarketapp = async (app = {}, page) => {
  try {
    const { id, name, waitURLList } = app
    await waitForRequest(waitURLList, page)
    await waitTillHTMLRendered(page)

    const searchXpath = `//input[contains(@data-cy, "search-apps")]`
    await page.waitForTimeout(searchXpath)
    const $finder = await page.$x(searchXpath)

    // type in finder the marketapp name
    await $finder?.[0]?.type(name)

    // find marketapp on list
    await page.waitForTimeout(1000)
    const rowMarketAppXpath = `//div[contains(@data-cy, "app-${id}")]`
    await page.waitForTimeout(rowMarketAppXpath)
    const $rowMarketApp = await page.$x(rowMarketAppXpath)
    await $rowMarketApp?.[0]?.click()

    // press download marketapp button
    const downloadButtonXpath = `//button[contains(@data-cy, "action-download")]`
    await page.waitForTimeout(downloadButtonXpath)
    const $downloadButton = await page.$x(downloadButtonXpath)

    await $downloadButton?.[0]?.click()
    await page.waitForTimeout(90000)
  } catch (error) {
    await page.screenshot({ path: '/tmp/error_download.png' })
  }

  try {
    const files = readdirSync(downloadPath)

    return files.map((file) => md5(readFileSync(`${downloadPath}/${file}`)))
  } catch (error) {
    return []
  }
}

/**
 * Get Data from vm console.
 *
 * @param {object} vm - vm config
 * @param {number} vm.id - vm id
 * @param {string} vm.waitURLConsole - url for wait
 * @param {object} page - pptr page
 * @returns {object} console information
 */
const getDataConsolePage = async (vm = {}, page) => {
  const { id, type, waitURLConsole } = vm
  const mainImage = type === 'vmrc' ? wildImage : ttyImage
  const mainImageName = type === 'vmrc' ? wildImageName : ttyImageName

  base64ToPNG(mainImage, mainImageName)

  const mainPage = await page.browser()
  const newPagePromise = new Promise((resolve) =>
    mainPage.once('targetcreated', (target) => resolve(target.page()))
  )
  const consolePage = await newPagePromise
  await waitForRequest(waitURLConsole, consolePage)
  await waitTillHTMLRendered(consolePage)
  const $id = await consolePage.$('[data-cy=id]')
  const $name = await consolePage.$('[data-cy=name]')
  const $ips = await consolePage.$('[data-cy=ips]')
  const $state = await consolePage.$('[data-cy=state]')
  const $canvas = await consolePage.$x('//main//canvas')
  const $fullScreenbutton = await consolePage.$x(
    `//button[contains(@data-cy, "${id}-${type}-fullscreen-button")]`
  )
  const $ctrlAltDel = await consolePage.$x(
    `//button[contains(@data-cy, "${id}-${type}-ctrl-alt-del-button")]`
  )
  const $reconnect = await consolePage.$x(
    `//button[contains(@data-cy, "${id}-${type}-reconnect-button")]`
  )
  const $screenshot = await consolePage.$x(
    `//button[contains(@data-cy, "${id}-${type}-screenshot-button")]`
  )

  const imageCanvas = await consolePage.evaluate(() => {
    const $elementCanvas = document.evaluate(
      '//main//canvas',
      document,
      null,
      XPathResult.FIRST_ORDERED_NODE_TYPE,
      null
    ).singleNodeValue

    const evtPressEnter = new KeyboardEvent('keydown', { key: 'Enter' })
    evtPressEnter.keyCode = 13
    $elementCanvas?.dispatchEvent?.(evtPressEnter)

    return {
      data: $elementCanvas?.toDataURL?.(),
      width: $elementCanvas?.width,
      height: $elementCanvas?.height,
    }
  })

  base64ToPNG(imageCanvas.data, currentImageName)

  const diff = new PNG({ width: imageCanvas.width, height: imageCanvas.height })

  const diffPixels = pixelmatch(
    PNG.sync.read(readFileSync(tmpPath(mainImageName))).data,
    PNG.sync.read(readFileSync(tmpPath(currentImageName))).data,
    diff.data,
    imageCanvas.width,
    imageCanvas.height,
    { threshold: 0.1 }
  )
  const diffPercent =
    (diffPixels / (imageCanvas.width * imageCanvas.height)) * 100

  return {
    url: consolePage.url(),
    id: await (await $id?.getProperty?.('innerText'))?.jsonValue(),
    name: await (await $name?.getProperty?.('innerText'))?.jsonValue(),
    ips: await (await $ips?.getProperty?.('innerText'))?.jsonValue(),
    state: await (await $state?.getProperty?.('innerText'))?.jsonValue(),
    canvas: await !!$canvas?.[0],
    canvasPercent: diffPercent,
    fullscreen: await !!$fullScreenbutton,
    ctrlAltDel: await !!$ctrlAltDel,
    reconnect: await !!$reconnect,
    screenshot: await !!$screenshot,
  }
}

/**
 * Open External Browser.
 *
 * @param {object} cypressConfig - cypress config
 * @returns {object} - pptr browser
 */
const externalBrowser = (cypressConfig = {}) =>
  (async () => await puppeteerLaunch(cypressConfig))()

/**
 * Open Browser, login on fireedge and return the JWT.
 *
 * @param {object} config - config
 * @param {object} config.auth - auth config
 * @param {object} config.cypress - cypress config
 * @returns {null|string} - return JWT
 */
const externalBrowserLogin = (config = {}) => {
  const { auth, cypress, isUser } = config
  if (auth && cypress) {
    return (async () => {
      const { page, browser } = await externalBrowser(cypress)
      const pptrLogin = await logIn(auth, page, isUser)
      if (browser && browser.close) {
        await browser.close()
      }

      return pptrLogin
    })()
  } else {
    return null
  }
}

/**
 * Open Browser, login on fireedge, go to marketapps, download marketapp and return data of new page.
 *
 * @param {object} config - config
 * @param {object} config.auth - auth config
 * @param {object} config.cypress - cypress config
 * @param {object} config.vm - vm config
 * @returns {null|object} - data console
 */
const externalBrowserDownloadMarketapp = (config = {}) => {
  const { auth, cypress, app } = config
  if (auth && cypress) {
    return (async () => {
      const { page, browser } = await externalBrowser(cypress)
      await logIn(auth, page)
      await navigateMenu(
        {
          parent: 'storage',
          item: 'Apps',
        },
        page
      )
      const dataConsolePage = await findAndDownloadMarketapp(app, page, browser)

      if (browser && browser.close) {
        await browser.close()
      }

      return dataConsolePage
    })()
  } else {
    return null
  }
}

/**
 * Open Browser, login on fireedge, go to Vm, open console and return data of console.
 *
 * @param {object} config - config
 * @param {object} config.auth - auth config
 * @param {object} config.cypress - cypress config
 * @param {object} config.vm - vm config
 * @returns {null|object} - data console
 */
const externalBrowserConsole = (config = {}) => {
  const { auth, cypress, vm } = config
  if (auth && cypress) {
    return (async () => {
      const { page, browser } = await externalBrowser(cypress)
      await logIn(auth, page)
      await navigateMenu(
        {
          parent: 'instances',
          item: 'VMs',
        },
        page
      )
      await clickConsoleButton(vm, page)
      const dataConsolePage = await getDataConsolePage(vm, page)

      if (browser && browser.close) {
        await browser.close()
      }

      return dataConsolePage
    })()
  } else {
    return null
  }
}

module.exports = {
  externalBrowser,
  externalBrowserLogin,
  externalBrowserConsole,
  externalBrowserDownloadMarketapp,
}
