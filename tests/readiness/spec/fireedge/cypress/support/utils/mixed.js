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
import { v4 } from 'uuid'

/**
 * Spy and stub network requests and responses.
 *
 * @param {object} data - Intercept options
 * @param {string} [data.name] - Intercept name
 * @param {'GET'|'POST'|'PUT'|'DELETE'} data.method - HTTP method
 * @param {string} data.url - Specify the URL to match
 * @returns {string} Intercept name
 */
const createIntercept = ({ name = v4(), method = 'GET', url = '' } = {}) => {
  cy.intercept({ method, url }).as(name)

  return `@${name}`
}

/**
 * Fills the inputs in the current form.
 *
 * @param {object} inputs - Inputs values
 * @param {string} prefixKey - Prefix used to select the inputs
 */
const fillInputs = (inputs = {}, prefixKey = '') => {
  Object.entries(inputs).forEach(([key, value]) => {
    if (typeof value === 'boolean') {
      value === false
        ? cy.getBySel(`${prefixKey}${key}`).uncheck().should('be.unchecked')
        : cy.getBySel(`${prefixKey}${key}`).check().should('be.checked')
    } else {
      cy.getBySel(`${prefixKey}${key}`).clear().type(value)
    }
  })
}

/**
 * Access an attribute of the object with a string key.
 *
 * @param {object} object - JS object where to search
 * @param {string} field - Field to search in the object
 * @returns {object} value - Value of the field in the object
 */
const accessAttribute = (object, field) => {
  // Get each field
  const segments = field.split('.')

  // Assign object to value
  let value = object

  // Iterate over each value
  for (const segment of segments) {
    value = value[segment]
  }

  // Return value
  return value
}

/**
 * Maps API methods for getting and deleting the specified resources.
 *
 * @returns {object} Mapping of resource names to their get and delete API methods.
 */
const mapObjectIO = () => ({
  templates: { get: cy.apiGetVmTemplates, delete: cy.apiDeleteVmTemplate },
  vmgroups: { get: cy.apiGetVmGroups, delete: cy.apiDeleteVmGroup },
  servicetemplates: {
    get: cy.apiGetServiceTemplates,
    delete: cy.apiDeleteServiceTemplate,
  },
  services: {
    get: cy.apiGetServices,
    delete: cy.apiDeleteService,
  },
  vrouters: {
    get: cy.apiGetVRouters,
    delete: cy.apiDeleteVRouter,
  },
  vms: { get: cy.apiGetVms, delete: cy.apiRecoverDeleteVm },
  datastores: { get: cy.apiGetDatastores, delete: cy.apiDeleteDatastore },
  vnets: { get: cy.apiGetVNetTemplates, delete: cy.apiDeleteVNetTemplate },
  vnettemplates: { get: cy.apiGetVNets, delete: cy.apiDeleteVNet },
  hosts: { get: cy.apiGetHosts, delete: cy.apiDeleteHost },
  clusters: { get: cy.apiGetClusters, delete: cy.apiDeleteCluster },
  users: { get: cy.apiGetUsers, delete: cy.apiDeleteUser },
  groups: { get: cy.apiGetGroups, delete: cy.apiDeleteGroup },
  images: { get: cy.apiGetImages, delete: cy.apiDeleteImage },
  secgroups: { get: cy.apiGetSecGroups, delete: cy.apiDeleteSecGroup },
  acls: { get: cy.apiGetAcls, delete: cy.apiDeleteAcl },
  marketplaces: { get: cy.apiGetMarketplaces, delete: cy.apiDeleteMarketplace },
})

/**
 * Transform list of restricted attributes in a map getting keys for the first element after split the element with "/".
 *
 * @param {Array} restrictedAttributes - List of restricted attributes.
 * @param {Array} restrictedAttributesException - List of restricted attributes that are not going to be checked.
 * @returns {object} - Map of the transformed restricted attributes.
 */
const transformAttributes = (
  restrictedAttributes = {},
  restrictedAttributesException = []
) => {
  // Define map
  const transformedAttrs = {}

  // Iterate over each attribute
  restrictedAttributes.forEach((attr) => {
    // Check if the attribute includes or not "/"
    const transformedValue = attr.includes('/')
      ? { key: attr.split('/')[0], value: attr.split('/')[1] }
      : { key: 'PARENT', value: attr }

    if (!transformedAttrs[transformedValue.key]) {
      transformedAttrs[transformedValue.key] = []
    }

    transformedAttrs[transformedValue.key].push(transformedValue.value)
  })

  // Delete exceptions
  Object.keys(transformedAttrs).forEach(
    (key) =>
      (transformedAttrs[key] = transformedAttrs[key].filter(
        (attribute) =>
          !restrictedAttributesException[key] ||
          !restrictedAttributesException[key].includes(attribute)
      ))
  )

  // Return list
  return transformedAttrs
}

/**
 * Check a form looking for the fields and checking if they are disabled or not depending on the user.
 *
 * @param {object} restrictedAttributes - Map of restricted attributes
 * @param {string} check - Condition to check
 */
const checkForm = (restrictedAttributes = [], check) => {
  // Get body to look for the fields without failures (cy.get gonna throw an error if the field not exists and we do not know if the restricted attribute it is on a form or not)
  cy.get('body').then((body) => {
    // Iterate over each attribute
    restrictedAttributes.forEach((attribute) => {
      // Checking if the attribute exists on the DOM
      const element = body.find(`[data-cy$="${attribute}"]`)
      if (element.length > 0) {
        // If exists, check that is disabled or not
        cy.log(
          attribute +
            ' is a restricte attribute and exists on this form. Checking ' +
            check
        )

        // If it's a div, check the children. That's becasue a div it's not disabled himself
        if (element.prop('tagName') === 'DIV') {
          // Iterate over each childer and check
          element.children().each((index, child) => {
            const $child = Cypress.$(child)
            cy.wrap($child).should(check)
          })
        } else {
          cy.getBySelLike(attribute).should(check)
        }
      } else {
        // If not exists, do nothing
        cy.log(
          attribute +
            ' is a restricte attribute and NOT exists on this form so there is no checking'
        )
      }
    })
  })
}

/**
 * Find if a item has restricted attributes.
 *
 * @param {object} item - The item where to find the attribute
 * @param {string} section - Section of the item
 * @param {object} mapRestrictedAttributes - Map of restricted attributes
 * @returns {boolean} - True if any restricted attribute is found on the item
 */
const hasRestrictedAttributes = (
  item,
  section,
  mapRestrictedAttributes = {}
) => {
  // Find if there is a restricted attribute in the item
  const restricteAttribute = mapRestrictedAttributes[section]?.find(
    (attribute) => item && item[attribute]
  )

  return !!restricteAttribute
}

export {
  accessAttribute,
  checkForm,
  createIntercept,
  fillInputs,
  hasRestrictedAttributes,
  mapObjectIO,
  transformAttributes,
}
