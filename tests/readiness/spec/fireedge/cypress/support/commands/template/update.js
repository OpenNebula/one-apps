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
import {
  fillStorageSection,
  fillNetworkSection,
  fillOsAndCpuSection,
  fillGeneralStep,
  fillAttachAdvancedStep,
  fillNicNetworkStep,
  fillNicAdvancedStep,
  fillNicQosStep,
  fillAttachPciForm,
  fillIOSection,
  fillContextSection,
  fillSchedActionsSection,
  fillSchedActionForm,
  fillPlacementSection,
  fillNumaSection,
  fillBackupSection,
  fillPciDevicesSection,
} from '@support/commands/template/create'

import { FORCE } from '@support/commands/constants'

/**
 * Update the general section.
 *
 * @param {Array} actions - List of actions to do in the general section.
 */
const updateGeneral = (actions) => {
  // Iterate over each action
  actions.forEach((action) => {
    // Perform the action
    if (action.type === 'update') {
      fillGeneralStep(action.template, true)
    }
  })
}

/**
 * Update the storage section.
 *
 * @param {Array} sectionActions - List of actions to do in the storage section.
 * @param {object} IMAGES - Images to use in the disks.
 */
const updateStorage = (sectionActions, IMAGES) => {
  // Go to storage section
  cy.navigateTab('storage')

  // Iterate over each action
  sectionActions.forEach((action) => {
    // Perform the action
    if (action.type === 'create') {
      // Add image if the disk has image name
      if (action?.template?.image) {
        action.template.image = parseInt(IMAGES[action.template.image].json.ID)
      }

      fillStorageSection({ storage: [action.template] })
    } else if (action.type === 'update') {
      // Add image if the disk has image name
      action?.storageActions?.forEach((storageAction) => {
        if (storageAction.template?.image) {
          storageAction.template.image = parseInt(
            IMAGES[storageAction.template.image].json.ID
          )
        }
      })

      updateDisk(action)
    } else if (action.type === 'delete') {
      detachDisk(action.disk)
    }
  })
}

/**
 * Detach a disk.
 *
 * @param {number} disk - The index of the disk.
 */
const detachDisk = (disk) => {
  cy.navigateTab('storage')
  cy.getBySel(`disk-detach-${disk}`).click()
  cy.getBySel(`dg-accept-button`).click()
}

/**
 * Update a disk.
 *
 * @param {object} sectionAction - Complete action with template.
 */
const updateDisk = (sectionAction) => {
  // Go to storage tab
  cy.navigateTab('storage')

  // Open edit form
  cy.getBySel(`edit-${sectionAction.disk}`).click()

  sectionAction.storageActions.forEach((storageAction) => {
    cy.getBySel('modal-edit-disk').within(() => {
      // Check if the disk is volatile or image
      if (sectionAction.diskType === 'volatile') {
        // Click on the step of the disk form
        cy.getBySel(`step-${storageAction.step}`).click()

        if (storageAction.step === 'configuration') {
          updateVolatileForm(storageAction.template)
        } else if (storageAction.step === 'advanced') {
          fillAttachAdvancedStep(storageAction.template)
        }
      } else if (sectionAction.diskType === 'image') {
        // Click on the step of the disk form
        cy.getBySel(`step-${storageAction.step}`).click()

        if (storageAction.step === 'image') {
          updateImageForm(storageAction.template)
        } else if (storageAction.step === 'advanced') {
          fillAttachAdvancedStep(storageAction.template)
        }
      }
    })
  })

  // Check in which step it is the form and click the next/finish button until the form is finished
  cy.get(`[data-cy="modal-edit-disk"]`).then((body) => {
    if (sectionAction.diskType === 'volatile') {
      const configurationStep = body.find(`[data-cy="attach-disk-SIZE"]`)
      const advancedStep = body.find(`[data-cy="legend-general"]`)

      if (configurationStep && configurationStep.length > 0) {
        cy.wrap(body).within(() => {
          cy.getBySel('stepper-next-button').click()
          cy.getBySel('stepper-next-button').click()
        })
      }

      if (advancedStep && advancedStep.length > 0) {
        cy.wrap(body).within(() => {
          cy.getBySel('stepper-next-button').click()
        })
      }
    } else if (sectionAction.diskType === 'image') {
      const imageStep = body.find(`[data-cy="images"]`)
      const advancedStep = body.find(`[data-cy="legend-general"]`)

      if (imageStep && imageStep.length > 0) {
        cy.wrap(body).within(() => {
          cy.getBySel('stepper-next-button').click()
          cy.getBySel('stepper-next-button').click()
        })
      }

      if (advancedStep && advancedStep.length > 0) {
        cy.wrap(body).within(() => {
          cy.getBySel('stepper-next-button').click()
        })
      }
    }
  })
}

/**
 * Update volatile disk form.
 *
 * @param {object} disk - Disk object
 */
const updateVolatileForm = (disk) => {
  const { size, sizeunit, type, format, filesystem: fs } = disk

  size && cy.getBySelEndsWith('-SIZE').clear().type(size)
  type &&
    cy.getBySelEndsWith('-TYPE').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  type?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  type === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })

  format &&
    cy.getBySelEndsWith('-FORMAT').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  format?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  format === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })

  // Select size unit if exists
  if (sizeunit) {
    cy.getBySelEndsWith('-SIZEUNIT').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  sizeunit?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  sizeunit === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })
  }

  if (type?.toLowerCase() !== 'swap') {
    format &&
      cy.getBySelEndsWith('-FORMAT').then(({ selector }) => {
        cy.get(selector)
          .click()
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    format.toLowerCase()?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    format.toLowerCase() === $el?.text()
                  ) {
                    cy.wrap($el).click()

                    return false // Break
                  }
                })
            })
          })
      })

    fs &&
      cy.getBySelEndsWith('-FS').then(({ selector }) => {
        cy.get(selector)
          .click()
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    fs.toLowerCase()?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    fs.toLowerCase() === $el?.text()
                  ) {
                    cy.wrap($el).click()

                    return false // Break
                  }
                })
            })
          })
      })
  }
}

/**
 * Update image disk form.
 *
 * @param {object} disk - Disk object
 */
const updateImageForm = (disk) => {
  const { image: imageId } = disk

  imageId && cy.getBySel(`image-${imageId}`).click()
}

/**
 * Update the network section.
 *
 * @param {Array} sectionActions - List of actions to do in the network sections
 * @param {object} NETWORKS - Networks to use in the section.
 */
const updateNetwork = (sectionActions, NETWORKS) => {
  // Go to network section
  cy.navigateTab('network')

  // Iterate over each action
  sectionActions.forEach((action) => {
    // Perform the action
    if (action.type === 'create') {
      // Add the id of the vnet
      if (action?.template?.name) {
        action.template.id = parseInt(NETWORKS[action.template.name].json.ID)
      }

      fillNetworkSection({ networks: [action.template] })
    } else if (action.type === 'update') {
      // Add the id of the vnet
      action?.networkActions?.forEach((networkAction) => {
        if (networkAction.template?.name) {
          networkAction.template.id = parseInt(
            NETWORKS[networkAction.template.name].json.ID
          )
        }
      })

      action.alias ? updateAlias(action) : updateNic(action)
    } else if (action.type === 'delete') {
      action.alias
        ? detachAlias(action.nic, action.alias)
        : detachNic(action.nic)
    }
  })
}

/**
 * Detach a NIC.
 *
 * @param {number} nic - The index of the NIC.
 */
const detachNic = (nic) => {
  cy.navigateTab('network')
  cy.getBySel(`detach-nic-${nic}`).click()
  cy.getBySel(`dg-accept-button`).click()
}

/**
 * Detach an alias.
 *
 * @param {number} nic - The index of the NIC.
 * @param {number} alias - The index of the alias.
 */
const detachAlias = (nic, alias) => {
  // Navigate to network section
  cy.navigateTab('network')

  // Click to show alias modal
  cy.getBySel(`alias-nic-${nic}`).click()

  // Click on detach button
  cy.getBySel('modal-show-alias').within(() => {
    cy.getBySel(`detach-alias-${alias}-action`).click()
  })

  // Accept detach
  cy.getBySel('modal-detach-alias').within(() => {
    cy.getBySel(`dg-accept-button`).click()
  })

  // Accept alias form
  cy.getBySel('modal-show-alias').within(() => {
    cy.getBySel(`dg-accept-button`).click()
  })
}

/**
 * Update a NIC.
 *
 * @param {object} sectionAction - Complete action with template.
 */
const updateNic = (sectionAction) => {
  // Go to network section
  cy.navigateTab('network')

  // Open edit form
  cy.getBySel(`edit-${sectionAction.nic}`).click()

  sectionAction.networkActions.forEach((networkAction) => {
    cy.getBySel('modal-attach-nic').within(() => {
      // Click on the step of the nic form
      cy.getBySel(`step-${networkAction.step}`).click()

      if (
        networkAction.step === 'network' ||
        networkAction.step === 'network-auto'
      ) {
        fillNicNetworkStep(networkAction.template)
      } else if (networkAction.step === 'advanced') {
        fillNicAdvancedStep(networkAction.template)
      } else if (networkAction.step === 'qos') {
        fillNicQosStep(networkAction.template)
      }
    })
  })

  // Check in which step it is the form and click the next/finish button until the form is finished
  cy.get(`[data-cy="modal-attach-nic"]`).then((body) => {
    const networkStep = body.find(`[data-cy="vnets"]`)
    const networkAutoStep = body.find(`[data-cy="legend-network-rank"]`)
    const advancedStep = body.find(`[data-cy="legend-guacamole-connections"]`)
    const qosStep = body.find(`[data-cy="legend-override-in-qos"]`)

    if (advancedStep && advancedStep.length > 0) {
      cy.wrap(body).within(() => {
        cy.getBySel('stepper-next-button').click()
        cy.getBySel('stepper-next-button').click()
        cy.getBySel('stepper-next-button').click()
      })
    }

    if (
      (networkStep && networkStep.length > 0) ||
      (networkAutoStep && networkAutoStep.length > 0)
    ) {
      cy.wrap(body).within(() => {
        cy.getBySel('stepper-next-button').click()
        cy.getBySel('stepper-next-button').click()
      })
    }

    if (qosStep && qosStep.length > 0) {
      cy.wrap(body).within(() => {
        cy.getBySel('stepper-next-button').click()
      })
    }
  })
}

/**
 * Update an alias.
 *
 * @param {object} sectionAction - Complete action with template.
 */
const updateAlias = (sectionAction) => {
  // Go to network section
  cy.navigateTab('network')

  // Click to show alias modal
  cy.getBySel(`alias-nic-${sectionAction.nic}`).click()

  // Click on update button
  cy.getBySel('modal-show-alias').within(() => {
    cy.getBySel(`edit-${sectionAction.alias}`).click()
  })

  sectionAction.networkActions.forEach((networkAction) => {
    cy.getBySel('modal-attach-alias').within(() => {
      // Click on the step of the nic form
      cy.getBySel(`step-${networkAction.step}`).click()

      if (networkAction.step === 'network') {
        fillNicNetworkStep(networkAction.template)
      } else if (networkAction.step === 'advanced') {
        fillNicAdvancedStep(networkAction.template)
      }
    })
  })

  // Check in which step it is the form and click the next/finish button until the form is finished
  cy.get(`[data-cy="modal-attach-alias"]`).then((body) => {
    const networkStep = body.find(`[data-cy="vnets"]`)
    const advancedStep = body.find(`[data-cy="legend-guacamole-connections"]`)

    if (advancedStep && advancedStep.length > 0) {
      cy.wrap(body).within(() => {
        cy.getBySel('stepper-next-button').click()
      })
    }

    if (networkStep && networkStep.length > 0) {
      cy.wrap(body).within(() => {
        cy.getBySel('stepper-next-button').click()
        cy.getBySel('stepper-next-button').click()
      })
    }
  })

  // Accept alias form
  cy.getBySel('modal-show-alias').within(() => {
    cy.getBySel(`dg-accept-button`).click()
  })
}

/**
 * Update the booting section.
 *
 * @param {Array} actions - List of actions to do in the booting section.
 */
const updateBooting = (actions) => {
  // Iterate over each action
  actions.forEach((action) => {
    fillOsAndCpuSection({ osCpu: action.template }, 'extra')
  })
}

/**
 * Update the pci devices section.
 *
 * @param {Array} sectionActions - List of actions to do in the pci devices section
 */
const updatePcidevices = (sectionActions) => {
  // Go to pci section
  cy.navigateTab('pci')

  // Iterate over each action
  sectionActions.forEach((action) => {
    // Perform the action
    if (action.type === 'create') {
      fillPciDevicesSection({ pcis: [action.template] })
    } else if (action.type === 'update') {
      cy.getBySel(`edit-${action.pci}`).click()
      action.pciActions.forEach((pciAction) => {
        fillAttachPciForm(pciAction.template)
      })
    } else if (action.type === 'delete') {
      cy.navigateTab('pci')
      cy.getBySel(`detach-pci-${action.pci}`).click()
      cy.getBySel(`dg-accept-button`).click()
    }
  })
}

/**
 * Update the inputoutput section.
 *
 * @param {Array} actions - List of actions to do in the inputoutput section.
 */
const updateInputOutput = (actions) => {
  // Iterate over each action
  actions.forEach((action) => {
    if (action.subSection === 'input' && action.type === 'delete') {
      cy.navigateTab('input_output')
      cy.getBySel(`input-delete-${action.id}`).click()
    } else if (action.subSection === 'pci' && action.type === 'delete') {
      cy.navigateTab('input_output')
      cy.getBySel(`pci-delete-${action.id}`).click()
    } else {
      fillIOSection({ inputOutput: action.template }, 'extra')
    }
  })
}

/**
 * Update the context section.
 *
 * @param {Array} actions - List of actions to do in the context section.
 */
const updateContext = (actions) => {
  // Iterate over each action
  actions.forEach((action) => {
    if (action.subSection === 'userInputs' && action.type === 'delete') {
      cy.navigateTab('context')
      cy.getBySel(`delete-userInput-${action.id}`).click()
    }
    // TODO: Add drag and drop on customVars
    else if (action.subSection === 'customVars' && action.type === 'delete') {
      cy.navigateTab('context')

      // Expand the custom vars section if it's not already expanded
      cy.getBySel('context-custom-vars').click()

      // Click on delete button (force because it's hidden)
      cy.getBySel(`delete-${action.customVar}`).click(FORCE)

      // Confirm action
      cy.getBySel(`confirmation-dialog`)
        .should('exist')
        .then(($dialog) => {
          cy.wrap($dialog).find(`[data-cy=dg-accept-button]`).click()
        })
    } else if (action.subSection === 'customVars' && action.type === 'update') {
      cy.navigateTab('context')

      // Expand the custom vars section if it's not already expanded
      cy.getBySel('context-custom-vars').click()

      // Click on edit button (force because it's hidden)
      cy.getBySel(`edit-${action.customVar}`).click(FORCE)

      // Change value
      cy.getBySel(`text-${action.customVar}`).clear().type(action.value)

      // Confirm action
      cy.getBySel(`accept-${action.customVar}`).click(FORCE)
    } else {
      fillContextSection({ context: action.template }, 'extra')
    }
  })
}

/**
 * Update the schedule actions section.
 *
 * @param {Array} actions - List of actions to do in the schedule actions section.
 * @param {object} DS_BACKUP - Backup datastores
 */
const updateScheduleActions = (actions, DS_BACKUP) => {
  // Iterate over each action
  actions.forEach((action) => {
    if (action.type === 'update') {
      // Navigate to schedule actions tab
      cy.navigateTab('sched_action')

      // Open edit form
      cy.getBySel(`sched-update-${action.id}`).click()

      // Add id of backupDs
      if (action?.template?.backupDs) {
        action.template.backupDs =
          parseInt(DS_BACKUP[action.template.backupDs].datastore.json.ID) +
          ': ' +
          action.template.backupDs
      }

      // Fill the form
      fillSchedActionForm(action.template)
    } else if (action.type === 'delete') {
      // Navigate to schedule actions tab
      cy.navigateTab('sched_action')

      // Open edit form
      cy.getBySel(`sched-delete-${action.id}`).click()

      // Confirm
      cy.getBySel(`dg-accept-button`).click()
    } else if (action.type === 'create') {
      // Add id of backupDs
      if (action?.template?.backupDs) {
        action.template.backupDs =
          parseInt(DS_BACKUP[action.template.backupDs].datastore.json.ID) +
          ': ' +
          action.template.backupDs
      }

      fillSchedActionsSection({ schedActions: action.template }, 'extra')
    }
  })
}

/**
 * Update the placement section.
 *
 * @param {Array} actions - List of actions to do in the placement section.
 */
const updatePlacement = (actions) => {
  // Iterate over each action
  actions.forEach((action) => {
    cy.navigateTab('placement')
    fillPlacementSection({ placement: action.template })
  })
}

/**
 * Update the numa section.
 *
 * @param {Array} actions - List of actions to do in the numa section.
 */
const updateNuma = (actions) => {
  // Iterate over each action
  actions.forEach((action) => {
    cy.navigateTab('numa')
    fillNumaSection({ numa: action.template })
  })
}

/**
 * Update the backup section.
 *
 * @param {Array} actions - List of actions to do in the backup section.
 */
const updateBackup = (actions) => {
  // Iterate over each action
  actions.forEach((action) => {
    cy.navigateTab('backup')
    fillBackupSection({ backupConfig: action.template }, 'extra')
  })
}

export {
  updateGeneral,
  updateStorage,
  updateNetwork,
  updatePcidevices,
  updateBooting,
  updateInputOutput,
  updateContext,
  updateScheduleActions,
  updatePlacement,
  updateNuma,
  updateBackup,
}
