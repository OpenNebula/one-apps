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

import { mapObjectIO } from '@utils/mixed'
import { XMLBuilder } from 'fast-xml-parser'

/**
 * @param {object} json - JSON
 * @param {object} [options] - Options to parser
 * @param {boolean} [options.addRoot] - Add ROOT element as parent
 * @returns {string} Xml in string format
 */
export const jsonToXml = (json, { addRoot = true, ...options } = {}) => {
  const builder = new XMLBuilder(options)

  return builder.build(addRoot ? { ROOT: json } : json)
}

/**
 * Converts the boolean value into a readable format.
 *
 * @param {boolean} bool - Boolean value.
 * @returns {'Yes'|'No'} - If true return 'Yes', in other cases, return 'No'.
 */
export const booleanToString = (bool) => (+bool ? 'Yes' : 'No')

/**
 * Converts the string value into a boolean.
 *
 * @param {string} str - String value.
 * @returns {boolean} - If str is "yes" or 1 then returns true, in other cases, return false.
 */
export const stringToBoolean = (str) =>
  String(str).toLowerCase() === 'yes' || +str === 1

/**
 * Converts the time values into "mm/dd/yyyy, hh:mm:ss" format.
 *
 * @param {number|string} time - Time to convert.
 * @returns {string} - Time string.
 */
export const timeToString = (time) =>
  +time ? new Date(+time * 1000).toLocaleString() : '-'

/**
 * UpperCase first character.
 *
 * @param {string} input - text to uppercase
 * @returns {string} text with first character in uppercase
 */
export const upperCaseFirst = (input) =>
  input.charAt(0).toUpperCase() + input.substring(1)

/**
 * Transform into a lower case with spaces between words, then capitalize the string.
 *
 * @param {string} input - String to transform
 * @returns {string} Sentence
 */
export const sentenceCase = (input) => {
  const sentence = input
    .replace(/[-_]([A-Za-z])/g, ' $1')
    .replace(/([A-Z])([A-Z][a-z])/g, '$1 $2')
    .replace(/([a-z])([A-Z])/g, '$1 $2')
    .toLowerCase()

  return upperCaseFirst(sentence)
}

/**
 * Transform into a snake case string.
 *
 * @param {string} input - String to transform
 * @returns {string} string
 * @example // "test-string" => "test_string"
 * @example // "testString" => "test_string"
 * @example // "TESTString" => "test_string"
 */
export const toSnakeCase = (input) => sentenceCase(input).replace(/\s/g, '_')

/**
 * Get info nest year.
 *
 * @returns {number} get next full year
 */
export const nextYear = () => {
  const date = new Date()

  return date.getFullYear() + 1
}

/**
 * Replace all number attributes of an object to string.
 *
 * @param {object} json - Object to convert.
 * @returns {object} - Object converted.
 */
export const replaceJsonWithStringValues = (json) => {
  const replacer = (_, value) =>
    value && typeof value === 'object' ? value : String(value)

  const jsonString = JSON.stringify(json, replacer)

  return JSON.parse(jsonString)
}

/**
 * Converts a long string of units into a readable format e.g KB, MB, GB, TB, YB.
 *
 * @param {number|string} value - The quantity of units.
 * @param {'KB'|'MB'|'GB'|'TB'|'PB'|'EB'|'ZB'|'YB'} unit - The unit of value. Defaults in KB
 * @param {number} fractionDigits
 * - Number of digits after the decimal point. Must be in the range 0 - 20, inclusive
 * @returns {string} Returns an string displaying sizes for humans.
 */
export const prettyBytes = (value, unit = 'KB', fractionDigits = 0) => {
  const UNITS = ['KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB']
  let ensuredValue = +value

  if (Math.abs(ensuredValue) === 0) return `${value} ${UNITS[0]}`

  let idxUnit = UNITS.indexOf(unit)

  while (ensuredValue >= 1024) {
    ensuredValue /= 1024
    idxUnit += 1
  }

  return `${ensuredValue.toFixed(fractionDigits)} ${UNITS[idxUnit]}`
}

/**
 * Returns progress bar information.
 *
 * @param {object} progress - progress data
 * @param {number} progress.total - total
 * @param {number} progress.used - used
 * @returns {{
 * percentMemUsed: number,
 * percentMemLabel: string
 * }} progress bar information
 */
export const getDataProgressBar = ({ total = 0, used = 0 }) => {
  const percentMemUsed = (+used * 100) / +total || 0

  const isMemUsageNegative = +used < 0
  const usedMemBytes = prettyBytes(Math.abs(+used))
  const totalMemBytes = prettyBytes(+total)
  const percentMemLabel = `${
    isMemUsageNegative ? '-' : ''
  }${usedMemBytes} / ${totalMemBytes} 
      (${Math.round(isFinite(percentMemUsed) ? percentMemUsed : '--')}%)`

  return {
    percentMemUsed,
    percentMemLabel,
  }
}

/**
 * Returns if tha value is an object.
 *
 * @param {*} obj - object to check
 * @returns {boolean} `true` if is an object
 */
export const isObject = (obj) =>
  Object.prototype.toString.call(obj) === '[object Object]'

/**
 * Formats a number into a string according to the currency configuration.
 *
 * @param {number|bigint} number - Number to format
 * @param {Intl.NumberFormatOptions} options - Options to format the number
 * @returns {string} - Number in string format with the currency symbol
 */
export const formatNumberByCurrency = (number, options) => {
  try {
    const SUNSTONE_CONF = Cypress.env('SUNSTONE_CONF')
    const currency = SUNSTONE_CONF?.currency ?? 'EUR'
    const locale = SUNSTONE_CONF?.default_lang?.replace('_', '-') ?? undefined

    return Intl.NumberFormat(locale, {
      style: 'currency',
      currency,
      currencyDisplay: 'narrowSymbol',
      notation: 'compact',
      compactDisplay: 'long',
      maximumFractionDigits: 2,
      ...options,
    }).format(number)
  } catch {
    return number.toString()
  }
}

/**
 * Converts the lock level to its string value.
 *
 * @param {number} level - Level code number
 * @returns {string} - Lock level text
 */
export const levelLockToString = (level) =>
  ({
    0: 'None',
    1: 'Use',
    2: 'Manage',
    3: 'Admin',
    4: 'All',
  }[level] || '-')

/**
 * Set the zone id for the API.
 *
 * @param {number} zoneID - zone ID
 * @returns {number} - zone ID
 */
export const setZoneApi = (zoneID) => {
  const position = 'zone'
  if (zoneID) {
    // const zoneNumberID = parseInt(zoneID, 10)
    Cypress.env(position, zoneID)
  }

  return Cypress.env(position)
}

/**
 * Add the zone query parameter for the api URL.
 *
 * @param {string} url - URL
 * @returns {string} - URL with zone
 */
export const addZoneRequestQuery = (url = '') => {
  const id = setZoneApi()
  if (id) {
    return `${url}/?zone=${id}`
  }

  return url
}

/**
 * Maps resources for cleanup, taking into account optional filtering config.
 *
 * @param {object} [cleanupData={}] - Optional data for resources to be cleaned up.
 * @param {object} [protectedResources={}] - Optional protected resources data for exclusion during cleanup.
 * @returns {Promise<object>} A Cypress promise that resolves to a map of resources to be cleaned up.
 */
export const mapCleanup = (cleanupData = {}, protectedResources = {}) => {
  const functionMapping = mapObjectIO()

  const data = Object.assign(
    {},
    ...Object.keys(functionMapping).map((key) => ({
      [key]: { IDS: [], NAMES: [] },
    })),
    cleanupData
  )

  const cleanupMap = {}

  return cy
    .wrap(Object.keys(data))
    .each((object) => {
      if (!functionMapping[object]) return

      const protectedData = {
        protectedByIds: protectedResources[object]?.IDS || [],
        protectedByNames: protectedResources[object]?.NAMES || [],
      }

      const isResourceProtected = (resource) =>
        protectedData.protectedByIds.includes(resource.ID) ||
        protectedData.protectedByNames.includes(resource.NAME)

      functionMapping[object]
        .get()
        .then((resources) =>
          resources
            .filter(
              (obj) =>
                (!data[object].NAMES?.length ||
                  data[object].NAMES.includes(obj.NAME) ||
                  !data[object].IDS?.length ||
                  data[object].IDS.includes(obj.ID)) &&
                !isResourceProtected(obj)
            )
            .map(({ ID, NAME }) => ({ ID, NAME }))
        )
        .then((filteredResources) => {
          cleanupMap[object] = {
            deleteFunc: (id) => functionMapping[object].delete(id),
            ids: filteredResources,
          }
        })
    })
    .then(() => cleanupMap)
}

/**
 * Generates a random intenger between min and max parameters.
 *
 * @param {number} min - Minimum value
 * @param {number} max - Maximum value
 * @param {number} exclude - Exclude value
 * @returns {number} - A random integer
 */
const getRandomInt = (min, max, exclude) => {
  let randomNum
  do {
    randomNum = Math.floor(Math.random() * (max - min + 1)) + min
  } while (randomNum === exclude)

  return randomNum
}

/**
 * Generates a random time period between AM and PM.
 *
 * @returns {string} - Time period
 */
const getRandomPeriod = () => (Math.random() < 0.5 ? 'AM' : 'PM')

/**
 * Generates a random date.
 *
 * @param {number} excludeYear - A year to exclude
 * @returns {object} - Object with the date
 */
export const randomDate = (excludeYear) => {
  const year = getRandomInt(
    new Date().getFullYear() + 1,
    new Date().getFullYear() + 5,
    excludeYear
  )
  const month = getRandomInt(1, 12)
  const day = getRandomInt(1, 28)
  const hours = getRandomInt(1, 12)
  const minutesTemp = getRandomInt(1, 59)
  const minutes =
    minutesTemp % 60 >= 56
      ? '00'
      : (Math.ceil(minutesTemp / 5) * 5).toString().padStart(2, '0')
  const seconds = 0
  const period = getRandomPeriod()

  const date = new Date(
    `${year}-${month}-${day} ${hours}:${minutes}:${seconds} ${period}`
  )

  return {
    year: year.toString(),
    month: date.toLocaleString('default', { month: 'short' }),
    day: day.toString(),
    period: period,
    hours: hours.toString(),
    minutes: minutes,
    epoch: Math.floor(date.getTime() / 1000).toString(),
  }
}

/**
 * Add one year to the actual date.
 *
 * @param {object} date - Date to add a year
 * @returns {object} - Date adding a year
 */
export const addOneYear = (date) => {
  const existingDate = new Date(date.epoch * 1000)
  existingDate.setFullYear(existingDate.getFullYear() + 1)

  return {
    ...date,
    year: existingDate.getFullYear(),
    epoch: Math.floor(existingDate.getTime() / 1000).toString(),
  }
}
