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

/**
 * Check if two objects are different and return the differences.
 *
 * @param {object} obj1 - First object
 * @param {object} obj2 - Second object
 * @returns {object} - Difference between objects
 */
const deepObjectDiff = (obj1, obj2) => {
  const diff = {}

  function compareObjects(innerObj1, innerObj2, path) {
    Object.keys(innerObj1).forEach((key) => {
      const newPath = path ? `${path}.${key}` : key

      if (Object.prototype.hasOwnProperty.call(innerObj2, key)) {
        if (
          typeof innerObj1[key] === 'object' &&
          typeof innerObj2[key] === 'object'
        ) {
          compareObjects(innerObj1[key], innerObj2[key], newPath)
        } else if (innerObj1[key] !== innerObj2[key]) {
          diff[newPath] = { inObj1: innerObj1[key], inObj2: innerObj2[key] }
        }
      } else {
        diff[newPath] = { inObj1: innerObj1[key], inObj2: undefined }
      }
    })

    Object.keys(innerObj2).forEach((key) => {
      const newPath = path ? `${path}.${key}` : key

      if (!Object.prototype.hasOwnProperty.call(innerObj1, key)) {
        diff[newPath] = { inObj1: undefined, inObj2: innerObj2[key] }
      }
    })
  }

  compareObjects(obj1, obj2, '')

  return diff
}

/**
 * Print in a readable way the differences between two objects.
 *
 * @param {string} result - The differences in a readable way
 * @returns {string} - Final differences
 */
function diffToString(result) {
  function nestedDiffToString(diff, indentation = 2, previousString = '') {
    const spaces = ' '.repeat(indentation)

    let resultString = ''

    Object.keys(diff).forEach((key) => {
      const entry = diff[key]
      resultString = previousString + `${spaces}${key}:\n`

      if (entry.inObj1 !== undefined) {
        resultString += `${spaces}  - In obj1: ${entry.inObj1}\n`
      }

      if (entry.inObj2 !== undefined) {
        resultString += `${spaces}  - In obj2: ${entry.inObj2}\n`
      }

      if (
        entry.inObj1 !== undefined &&
        typeof entry.inObj1 === 'object' &&
        entry.inObj2 !== undefined &&
        typeof entry.inObj2 === 'object'
      ) {
        resultString = nestedDiffToString(entry, indentation + 4, resultString)
      }
    })

    return resultString
  }

  return nestedDiffToString(result)
}

/**
 * Get the differences between two objects.
 *
 * @param {object} obj1 - First object
 * @param {object} obj2 - Second object
 * @returns {string} - Differences in a readable way
 */
const getDiff = (obj1, obj2) => {
  const differences = deepObjectDiff(obj1, obj2)

  return differences && Object.entries(differences).length > 0
    ? diffToString(differences)
    : 'No differences'
}

export { getDiff }
