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

import { FORCE } from '@support/commands/constants'
import { sentenceCase } from '@support/commands/helpers'
import { Disk, Network, VmTemplate } from '@support/commands/template/jsdocs'

/**
 * Fill information for template creation/update.
 *
 * @param {VmTemplate} templateTest - template object
 * @param {boolean} isUpdate - true if update, false if create
 */
const fillGeneralStep = (templateTest, isUpdate = false) => {
  const {
    name,
    hypervisor,
    vrouter,
    description,
    logo,
    memory,
    memoryHotResize,
    memoryMax,
    memoryResizeMode,
    memorySlots,
    memoryunit,
    memoryModificationType,
    memoryModificationOptions,
    memoryModificationMin,
    memoryModificationMax,
    cpu,
    cpuModificationType,
    cpuModificationOptions,
    cpuModificationMin,
    cpuModificationMax,
    vcpu,
    vcpuHotResize,
    vcpuMax,
    vcpuModificationType,
    vcpuModificationOptions,
    vcpuModificationMin,
    vcpuModificationMax,
    memoryCost,
    cpuCost,
    diskCost,
    user,
    group,
    vmgroup,
  } = templateTest

  // Informacion section
  cy.getBySel('general-hypervisor-HYPERVISOR')
    .find(`button[aria-pressed="false"]`)
    .each(($button) => {
      cy.wrap($button)
        .invoke('attr', 'value')
        .then(($value) => $value === hypervisor && cy.wrap($button).click())
    })

  !isUpdate && cy.getBySel('general-information-NAME').clear().type(name)

  vrouter
    ? cy.getBySel('general-hypervisor-VROUTER').check()
    : vrouter === false && cy.getBySel('general-hypervisor-VROUTER').uncheck()

  description
    ? cy.getBySel('general-information-DESCRIPTION').clear().type(description)
    : description === '' &&
      cy.getBySel('general-information-DESCRIPTION').clear()

  logo &&
    cy.getBySel('general-information-LOGO').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  logo?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  logo === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })

  // Memory section
  memory && cy.getBySel('general-capacity-MEMORY').clear().type(memory)
  memoryunit &&
    cy.getBySel('general-capacity-MEMORYUNIT').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  memoryunit?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  memoryunit === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })

  memoryHotResize
    ? cy.getBySel('general-capacity-HOT_RESIZE-MEMORY_HOT_ADD_ENABLED').check()
    : memoryHotResize === false &&
      cy
        .getBySel('general-capacity-HOT_RESIZE-MEMORY_HOT_ADD_ENABLED')
        .uncheck()
  memoryMax &&
    cy.getBySel('general-capacity-MEMORY_MAX').clear().type(memoryMax)

  memoryResizeMode &&
    cy.getBySel('general-capacity-MEMORY_RESIZE_MODE').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  memoryResizeMode?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  memoryResizeMode === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })

  memorySlots &&
    cy.getBySel('general-capacity-MEMORY_SLOTS').clear().type(memorySlots)

  memoryModificationType &&
    cy
      .getBySel('general-capacity-MODIFICATION-MEMORY-type')

      .then(({ selector }) => {
        cy.get(selector)
          .click()
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    memoryModificationType?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    memoryModificationType === $el?.text()
                  ) {
                    cy.wrap($el).click()

                    return false // Break
                  }
                })
            })
          })
      })

  memoryModificationOptions &&
    memoryModificationOptions.forEach((option) =>
      cy
        .getBySel('general-capacity-MODIFICATION-MEMORY-options')
        .type(`${option}{enter}`)
    )
  memoryModificationMin &&
    cy
      .getBySel('general-capacity-MODIFICATION-MEMORY-min')
      .clear()
      .type(memoryModificationMin)
  memoryModificationMax &&
    cy
      .getBySel('general-capacity-MODIFICATION-MEMORY-max')
      .clear()
      .type(memoryModificationMax)

  // Physical CPU section
  cpu && cy.getBySel('general-capacity-CPU').clear().type(cpu)

  cpuModificationType &&
    cy
      .getBySel('general-capacity-MODIFICATION-CPU-type')

      .then(({ selector }) => {
        cy.get(selector)
          .click()
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    cpuModificationType?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    cpuModificationType === $el?.text()
                  ) {
                    cy.wrap($el).click()

                    return false // Break
                  }
                })
            })
          })
      })

  cpuModificationOptions &&
    cpuModificationOptions.forEach((option) =>
      cy
        .getBySel('general-capacity-MODIFICATION-CPU-options')
        .type(`${option}{enter}`)
    )
  cpuModificationMin &&
    cy
      .getBySel('general-capacity-MODIFICATION-CPU-min')
      .clear(FORCE)
      .type(cpuModificationMin)
  cpuModificationMax &&
    cy
      .getBySel('general-capacity-MODIFICATION-CPU-max')
      .clear(FORCE)
      .type(cpuModificationMax)

  // Virtual CPU section
  vcpu
    ? cy.getBySel('general-capacity-VCPU').clear().type(vcpu)
    : vcpu === '' && cy.getBySel('general-capacity-VCPU').clear()

  vcpuHotResize
    ? cy.getBySel('general-capacity-HOT_RESIZE-CPU_HOT_ADD_ENABLED').check()
    : vcpuHotResize === false &&
      cy.getBySel('general-capacity-HOT_RESIZE-CPU_HOT_ADD_ENABLED').uncheck()
  vcpuMax && cy.getBySel('general-capacity-VCPU_MAX').clear().type(vcpuMax)

  vcpuModificationType &&
    cy
      .getBySel('general-capacity-MODIFICATION-VCPU-type')

      .then(({ selector }) => {
        cy.get(selector)
          .click()
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    vcpuModificationType?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    vcpuModificationType === $el?.text()
                  ) {
                    cy.wrap($el).click()

                    return false // Break
                  }
                })
            })
          })
      })

  vcpuModificationOptions &&
    vcpuModificationOptions.forEach((option) =>
      cy
        .getBySel('general-capacity-MODIFICATION-VCPU-options')
        .type(`${option}{enter}`)
    )
  vcpuModificationMin &&
    cy
      .getBySel('general-capacity-MODIFICATION-VCPU-min')
      .clear()
      .type(vcpuModificationMin)
  vcpuModificationMax &&
    cy
      .getBySel('general-capacity-MODIFICATION-VCPU-max')
      .clear()
      .type(vcpuModificationMax)

  // Cost section
  if (memoryCost) {
    cy.getBySel('general-showback-MEMORY_COST').clear()
    cy.getBySel('general-showback-MEMORY_COST').type(memoryCost)
  } else if (memoryCost === '') {
    cy.getBySel('general-showback-MEMORY_COST').clear()
  }

  if (cpuCost) {
    cy.getBySel('general-showback-CPU_COST').clear()
    cy.getBySel('general-showback-CPU_COST').type(cpuCost)
  } else if (cpuCost === '') {
    cy.getBySel('general-showback-CPU_COST').clear()
  }

  if (diskCost) {
    cy.getBySel('general-showback-DISK_COST').clear()
    cy.getBySel('general-showback-DISK_COST').type(diskCost)
  } else if (diskCost === '') {
    cy.getBySel('general-showback-DISK_COST').clear()
  }

  // Ownership section
  if (user) {
    cy.getBySel('general-ownership-AS_UID').clear().type(user)
    cy.getDropdownOptions().contains(user).click()
  } else if (user === '') {
    // Click on cross button to delete the content
    cy.getBySel('general-ownership-AS_UID')
      .parent('.MuiAutocomplete-inputRoot')
      .find('.MuiAutocomplete-clearIndicator[title=Clear]', FORCE)
      .click(FORCE)
  }

  if (group) {
    cy.getBySel('general-ownership-AS_GID').clear().type(group)
    cy.getDropdownOptions().contains(group).click()
  } else if (group === '') {
    // Click on cross button to delete the content
    cy.getBySel('general-ownership-AS_GID')
      .parent('.MuiAutocomplete-inputRoot')
      .find('.MuiAutocomplete-clearIndicator[title=Clear]', FORCE)
      .click(FORCE)
  }

  // VM group section
  if (vmgroup) {
    cy.getBySel('general-vm_group-VMGROUP-VMGROUP_ID').clear().type(vmgroup)
    cy.getDropdownOptions().contains(vmgroup).click()
  }
}

/**
 * Fill the data in the advanced step of a disk.
 *
 * @param {object} disk - Info about the disk
 */
const fillAttachAdvancedStep = (disk) => {
  const {
    size,
    target,
    readOnly,
    bus,
    cache,
    io,
    discard,
    iopsPerSecond,
    ioThreadId,
    throttlingBytes,
    throttlingIOPS,
    recoverySnapshotFreq,
  } = disk

  size
    ? cy.getBySelEndsWith('-SIZE').clear(FORCE).type(size, FORCE)
    : size === '' && cy.getBySelEndsWith('-SIZE').clear(FORCE)
  target
    ? cy.getBySelEndsWith('-TARGET').clear(FORCE).type(target, FORCE)
    : target === '' && cy.getBySelEndsWith('-TARGET').clear(FORCE)
  bus
    ? cy.getBySelEndsWith('-DEV_PREFIX').then(({ selector }) => {
        cy.get(selector)
          .click()
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    bus?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    bus === $el?.text()
                  ) {
                    cy.wrap($el).click()

                    return false // Break
                  }
                })
            })
          })
      })
    : bus === '' &&
      cy.getBySelEndsWith('-DEV_PREFIX').then(({ selector }) => {
        cy.get(selector)
          .click()
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    ''?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    $el?.text() === ''
                  ) {
                    cy.wrap($el).click()

                    return false // Break
                  }
                })
            })
          })
      })

  cache
    ? cy.getBySelEndsWith('-CACHE').then(({ selector }) => {
        cy.get(selector)
          .click()
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    cache.toLowerCase()?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    cache.toLowerCase() === $el?.text()
                  ) {
                    cy.wrap($el).click()

                    return false // Break
                  }
                })
            })
          })
      })
    : cache === '' &&
      cy.getBySelEndsWith('-CACHE').then(({ selector }) => {
        cy.get(selector)
          .click()
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    ''?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    $el?.text() === ''
                  ) {
                    cy.wrap($el).click()

                    return false // Break
                  }
                })
            })
          })
      })

  io
    ? cy.getBySelEndsWith('-IO').then(({ selector }) => {
        cy.get(selector)
          .click()
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    io.toLowerCase()?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    io.toLowerCase() === $el?.text()
                  ) {
                    cy.wrap($el).click()

                    return false // Break
                  }
                })
            })
          })
      })
    : io === '' &&
      cy.getBySelEndsWith('-IO').then(({ selector }) => {
        cy.get(selector)
          .click()
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    ''?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    $el?.text() === ''
                  ) {
                    cy.wrap($el).click()

                    return false // Break
                  }
                })
            })
          })
      })

  discard
    ? cy.getBySelEndsWith('-DISCARD').then(({ selector }) => {
        cy.get(selector)
          .click()
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    discard.toLowerCase()?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    discard.toLowerCase() === $el?.text()
                  ) {
                    cy.wrap($el).click()

                    return false // Break
                  }
                })
            })
          })
      })
    : discard === '' &&
      cy.getBySelEndsWith('-DISCARD').then(({ selector }) => {
        cy.get(selector)
          .click()
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    ''?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    $el?.text() === ''
                  ) {
                    cy.wrap($el).click()

                    return false // Break
                  }
                })
            })
          })
      })

  readOnly &&
    cy.getBySelEndsWith('-READONLY').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  readOnly.toUpperCase()?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  readOnly.toUpperCase() === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })

  iopsPerSecond
    ? cy
        .getBySelEndsWith('-SIZE_IOPS_SEC')
        .clear(FORCE)
        .type(iopsPerSecond, FORCE)
    : iopsPerSecond === '' && cy.getBySelEndsWith('-SIZE_IOPS_SEC').clear(FORCE)

  ioThreadId
    ? cy.getBySelEndsWith('-IOTHREADS').clear(FORCE).type(ioThreadId, FORCE)
    : ioThreadId === '' && cy.getBySelEndsWith('-IOTHREADS').clear(FORCE)

  // Throttling (Bytes/s)
  if (throttlingBytes) {
    throttlingBytes.totalValue
      ? cy
          .getBySel('throttling-bytes-TOTAL_BYTES_SEC')
          .clear(FORCE)
          .type(throttlingBytes.totalValue, FORCE)
      : throttlingBytes.totalValue === '' &&
        cy.getBySel('throttling-bytes-TOTAL_BYTES_SEC').clear(FORCE)
    throttlingBytes.totalMaximum
      ? cy
          .getBySel('throttling-bytes-TOTAL_BYTES_SEC_MAX')
          .clear(FORCE)
          .type(throttlingBytes.totalMaximum, FORCE)
      : throttlingBytes.totalMaximum === '' &&
        cy.getBySel('throttling-bytes-TOTAL_BYTES_SEC_MAX').clear(FORCE)
    throttlingBytes.totalMaximumLength
      ? cy
          .getBySel('throttling-bytes-TOTAL_BYTES_SEC_MAX_LENGTH')
          .clear(FORCE)
          .type(throttlingBytes.totalMaximumLength, FORCE)
      : throttlingBytes.totalMaximumLength === '' &&
        cy.getBySel('throttling-bytes-TOTAL_BYTES_SEC_MAX_LENGTH').clear(FORCE)
    throttlingBytes.readValue
      ? cy
          .getBySel('throttling-bytes-READ_BYTES_SEC')
          .clear(FORCE)
          .type(throttlingBytes.readValue, FORCE)
      : throttlingBytes.readValue === '' &&
        cy.getBySel('throttling-bytes-READ_BYTES_SEC').clear(FORCE)
    throttlingBytes.readMaximum
      ? cy
          .getBySel('throttling-bytes-READ_BYTES_SEC_MAX')
          .clear(FORCE)
          .type(throttlingBytes.readMaximum, FORCE)
      : throttlingBytes.readMaximum === '' &&
        cy.getBySel('throttling-bytes-READ_BYTES_SEC_MAX').clear(FORCE)
    throttlingBytes.readMaximumLength
      ? cy
          .getBySel('throttling-bytes-READ_BYTES_SEC_MAX_LENGTH')
          .clear(FORCE)
          .type(throttlingBytes.readMaximumLength, FORCE)
      : throttlingBytes.readMaximumLength === '' &&
        cy.getBySel('throttling-bytes-READ_BYTES_SEC_MAX_LENGTH').clear(FORCE)
    throttlingBytes.writeValue
      ? cy
          .getBySel('throttling-bytes-WRITE_BYTES_SEC')
          .clear(FORCE)
          .type(throttlingBytes.writeValue, FORCE)
      : throttlingBytes.writeValue === '' &&
        cy.getBySel('throttling-bytes-WRITE_BYTES_SEC').clear(FORCE)
    throttlingBytes.writeMaximum
      ? cy
          .getBySel('throttling-bytes-WRITE_BYTES_SEC_MAX')
          .clear(FORCE)
          .type(throttlingBytes.writeMaximum, FORCE)
      : throttlingBytes.writeMaximum === '' &&
        cy.getBySel('throttling-bytes-WRITE_BYTES_SEC_MAX').clear(FORCE)
    throttlingBytes.writeMaximumLength
      ? cy
          .getBySel('throttling-bytes-WRITE_BYTES_SEC_MAX_LENGTH')
          .clear(FORCE)
          .type(throttlingBytes.writeMaximumLength, FORCE)
      : throttlingBytes.writeMaximumLength === '' &&
        cy.getBySel('throttling-bytes-WRITE_BYTES_SEC_MAX_LENGTH').clear(FORCE)
  }

  // Throttling (IOPS)
  if (throttlingIOPS) {
    throttlingIOPS.totalValue
      ? cy
          .getBySel('throttling-iops-TOTAL_IOPS_SEC')
          .clear(FORCE)
          .type(throttlingIOPS.totalValue, FORCE)
      : throttlingIOPS.totalValue === '' &&
        cy.getBySel('throttling-iops-TOTAL_IOPS_SEC').clear(FORCE)
    throttlingIOPS.totalMaximum
      ? cy
          .getBySel('throttling-iops-TOTAL_IOPS_SEC_MAX')
          .clear(FORCE)
          .type(throttlingIOPS.totalMaximum, FORCE)
      : throttlingIOPS.totalMaximum === '' &&
        cy.getBySel('throttling-iops-TOTAL_IOPS_SEC_MAX').clear(FORCE)
    throttlingIOPS.totalMaximumLength
      ? cy
          .getBySel('throttling-iops-TOTAL_IOPS_SEC_MAX_LENGTH')
          .clear(FORCE)
          .type(throttlingIOPS.totalMaximumLength, FORCE)
      : throttlingIOPS.totalMaximumLength === '' &&
        cy.getBySel('throttling-iops-TOTAL_IOPS_SEC_MAX_LENGTH').clear(FORCE)
    throttlingIOPS.readValue
      ? cy
          .getBySel('throttling-iops-READ_IOPS_SEC')
          .clear(FORCE)
          .type(throttlingIOPS.readValue, FORCE)
      : throttlingIOPS.readValue === '' &&
        cy.getBySel('throttling-iops-READ_IOPS_SEC').clear(FORCE)
    throttlingIOPS.readMaximum
      ? cy
          .getBySel('throttling-iops-READ_IOPS_SEC_MAX')
          .clear(FORCE)
          .type(throttlingIOPS.readMaximum, FORCE)
      : throttlingIOPS.readMaximum === '' &&
        cy.getBySel('throttling-iops-READ_IOPS_SEC_MAX').clear(FORCE)
    throttlingIOPS.readMaximumLength
      ? cy
          .getBySel('throttling-iops-READ_IOPS_SEC_MAX_LENGTH')
          .clear(FORCE)
          .type(throttlingIOPS.readMaximumLength, FORCE)
      : throttlingIOPS.readMaximumLength === '' &&
        cy.getBySel('throttling-iops-READ_IOPS_SEC_MAX_LENGTH').clear(FORCE)
    throttlingIOPS.writeValue
      ? cy
          .getBySel('throttling-iops-WRITE_IOPS_SEC')
          .clear(FORCE)
          .type(throttlingIOPS.writeValue, FORCE)
      : throttlingIOPS.writeValue === '' &&
        cy.getBySel('throttling-iops-WRITE_IOPS_SEC').clear(FORCE)
    throttlingIOPS.writeMaximum
      ? cy
          .getBySel('throttling-iops-WRITE_IOPS_SEC_MAX')
          .clear(FORCE)
          .type(throttlingIOPS.writeMaximum, FORCE)
      : throttlingIOPS.writeMaximum === '' &&
        cy.getBySel('throttling-iops-WRITE_IOPS_SEC_MAX').clear(FORCE)
    throttlingIOPS.writeMaximumLength
      ? cy
          .getBySel('throttling-iops-WRITE_IOPS_SEC_MAX_LENGTH')
          .clear(FORCE)
          .type(throttlingIOPS.writeMaximumLength, FORCE)
      : throttlingIOPS.writeMaximumLength === '' &&
        cy.getBySel('throttling-iops-WRITE_IOPS_SEC_MAX_LENGTH').clear(FORCE)
  }

  // Edge cluster
  recoverySnapshotFreq
    ? cy
        .getBySel('edge-cluster-RECOVERY_SNAPSHOT_FREQ')
        .clear(FORCE)
        .type(recoverySnapshotFreq, FORCE)
    : recoverySnapshotFreq === '' &&
      cy.getBySel('edge-cluster-RECOVERY_SNAPSHOT_FREQ').clear(FORCE)
}

/**
 * Fill attach volatile disk form.
 *
 * @param {Disk} disk - Disk object
 * @param {boolean} update - True if it's an update operation
 */
const fillAttachVolatileForm = (disk, update) => {
  const { size, sizeunit, type, format, filesystem: fs, ...advancedDisk } = disk

  cy.getBySel(update ? 'modal-edit-disk' : 'modal-attach-volatile').within(
    () => {
      // GENERAL
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

      cy.getBySel('stepper-next-button').click()

      // ADVANCED
      fillAttachAdvancedStep(advancedDisk)

      // FINISH DIALOG
      cy.getBySel('stepper-next-button').click(FORCE)
    }
  )
}

/**
 * Fill attach image form.
 *
 * @param {Disk} disk - Disk object
 * @param {boolean} update - True if it's an update operation
 */
const fillAttachImageForm = (disk, update) => {
  const { image: imageId, ...advancedDisk } = disk

  cy.getBySel(update ? 'modal-edit-disk' : 'modal-attach-image')
    .within(() => {
      // SELECT IMAGE
      imageId && cy.getBySel(`image-${imageId}`).click()
      cy.getBySel('stepper-next-button').click()

      // ADVANCED
      fillAttachAdvancedStep(advancedDisk)

      // FINISH DIALOG
      cy.getBySel('stepper-next-button').click(FORCE)
    })
    .should('not.exist')
}

/**
 * Fill storage section on the create/update form.
 *
 * @param {VmTemplate} templateTest - template object
 */
const fillStorageSection = (templateTest) => {
  const { storage } = templateTest

  if (!storage) return

  const ensuredStorage = Array.isArray(storage) ? storage : [storage]

  cy.navigateTab('storage')

  cy.wrap(ensuredStorage).each((disk) => {
    cy.getBySel('add-disk').click()

    if (!isNaN(Number(disk.image))) {
      cy.getBySel('attach-image').click()
      fillAttachImageForm(disk)
    } else {
      cy.getBySel('attach-volatile').click()
      fillAttachVolatileForm(disk)
    }
  })
}

/**
 * Fill the network step with data.
 *
 * @param {object} nic - NIC data
 */
const fillNicNetworkStep = (nic) => {
  if (!nic) return

  const { id, schedRank, schedReqs } = nic

  if (id) {
    cy.getBySel('search-vnets').clear().type(nic.id)
    cy.getBySel(`network-${id}`).click()
  }

  // Sched rank and schedReqs
  schedRank
    ? cy.getBySel('network-rank-SCHED_RANK').clear(FORCE).type(schedRank, FORCE)
    : schedRank === '' && cy.getBySel('network-rank-SCHED_RANK').clear(FORCE)
  schedReqs
    ? cy
        .getBySel('network-requirements-SCHED_REQUIREMENTS')
        .clear(FORCE)
        .type(schedReqs, FORCE)
    : schedReqs === '' &&
      cy.getBySel('network-requirements-SCHED_REQUIREMENTS').clear(FORCE)
}

/**
 * Fill the nic info in the advanced step.
 *
 * @param {object} nic - Nic info
 */
const fillNicAdvancedStep = (nic) => {
  const { rdp, ssh, rdpOptions, skipContext, ipv4, ipv6, pci, mtu, auto } = nic

  // Automatic network selection
  auto
    ? cy.getBySel('general-NETWORK_MODE').check(FORCE)
    : auto === false && cy.getBySel('general-NETWORK_MODE').uncheck(FORCE)

  // Skip context
  skipContext
    ? cy.getBySel('general-EXTERNAL').check(FORCE)
    : skipContext === false && cy.getBySel('general-EXTERNAL').uncheck(FORCE)

  // Guacamole connections
  rdp
    ? cy.getBySelEndsWith('-RDP').check(FORCE)
    : rdp === false && cy.getBySelEndsWith('-RDP').uncheck(FORCE)

  if (rdpOptions) {
    const {
      disableAudio,
      disableBitmap,
      disableGlyph,
      disableOffscreen,
      enableAudioInput,
      enableDesktopComposition,
      enableFontSmoothing,
      enableWindowDrag,
      enableMenuAnimations,
      enableTheming,
      enableWallpaper,
      resizeMethod,
      keyboardLayout,
    } = rdpOptions

    keyboardLayout &&
      cy
        .getBySelEndsWith('-RDP_SERVER_LAYOUT')
        .clear(FORCE)
        .type(keyboardLayout, FORCE)
        .type('{downArrow}', FORCE)
        .type('{enter}', FORCE)

    resizeMethod &&
      cy.getBySelEndsWith('-RDP_RESIZE_METHOD').then(({ selector }) => {
        cy.get(selector)
          .click()
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    resizeMethod?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    resizeMethod === $el?.text()
                  ) {
                    cy.wrap($el).click()

                    return false // Break
                  }
                })
            })
          })
      })

    disableAudio
      ? cy.getBySelEndsWith('-RDP_DISABLE_AUDIO').check(FORCE)
      : disableAudio === false &&
        cy.getBySelEndsWith('-RDP_DISABLE_AUDIO').uncheck(FORCE)

    disableBitmap
      ? cy.getBySelEndsWith('-RDP_DISABLE_BITMAP_CACHING').check(FORCE)
      : disableBitmap === false &&
        cy.getBySelEndsWith('-RDP_DISABLE_BITMAP_CACHING').uncheck(FORCE)

    disableGlyph
      ? cy.getBySelEndsWith('-RDP_DISABLE_GLYPH_CACHING').check(FORCE)
      : disableGlyph === false &&
        cy.getBySelEndsWith('-RDP_DISABLE_GLYPH_CACHING').uncheck(FORCE)

    disableOffscreen
      ? cy.getBySelEndsWith('-RDP_DISABLE_OFFSCREEN_CACHING').check(FORCE)
      : disableOffscreen === false &&
        cy.getBySelEndsWith('-RDP_DISABLE_OFFSCREEN_CACHING').uncheck(FORCE)

    enableAudioInput
      ? cy.getBySelEndsWith('-RDP_ENABLE_AUDIO_INPUT').check(FORCE)
      : enableAudioInput === false &&
        cy.getBySelEndsWith('-RDP_ENABLE_AUDIO_INPUT').uncheck(FORCE)

    enableDesktopComposition
      ? cy.getBySelEndsWith('-RDP_ENABLE_DESKTOP_COMPOSITION').check(FORCE)
      : enableDesktopComposition === false &&
        cy.getBySelEndsWith('-RDP_ENABLE_DESKTOP_COMPOSITION').uncheck(FORCE)

    enableFontSmoothing
      ? cy.getBySelEndsWith('-RDP_ENABLE_FONT_SMOOTHING').check(FORCE)
      : enableFontSmoothing === false &&
        cy.getBySelEndsWith('-RDP_ENABLE_FONT_SMOOTHING').uncheck(FORCE)

    enableWindowDrag
      ? cy.getBySelEndsWith('-RDP_ENABLE_FULL_WINDOW_DRAG').check(FORCE)
      : enableWindowDrag === false &&
        cy.getBySelEndsWith('-RDP_ENABLE_FULL_WINDOW_DRAG').uncheck(FORCE)

    enableMenuAnimations
      ? cy.getBySelEndsWith('-RDP_ENABLE_MENU_ANIMATIONS').check(FORCE)
      : enableMenuAnimations === false &&
        cy.getBySelEndsWith('-RDP_ENABLE_MENU_ANIMATIONS').uncheck(FORCE)

    enableTheming
      ? cy.getBySelEndsWith('-RDP_ENABLE_THEMING').check(FORCE)
      : enableTheming === false &&
        cy.getBySelEndsWith('-RDP_ENABLE_THEMING').uncheck(FORCE)

    enableWallpaper
      ? cy.getBySelEndsWith('-RDP_ENABLE_WALLPAPER').check(FORCE)
      : enableWallpaper === false &&
        cy.getBySelEndsWith('-RDP_ENABLE_WALLPAPER').uncheck(FORCE)
  }

  ssh
    ? cy.getBySelEndsWith('-SSH').click(FORCE)
    : ssh === false && cy.getBySelEndsWith('-SSH').uncheck(FORCE)

  // IPv4
  const { ip, mac, mask, address, gateway, domains, method } = ipv4 || {}

  ip
    ? cy.getBySel('override-ipv4-IP').clear(FORCE).type(ip, FORCE)
    : ip === '' && cy.getBySel('override-ipv4-IP').clear(FORCE)
  mac
    ? cy.getBySel('override-ipv4-MAC').clear(FORCE).type(mac, FORCE)
    : mac === '' && cy.getBySel('override-ipv4-MAC').clear(FORCE)
  mask
    ? cy.getBySel('override-ipv4-NETWORK_MASK').clear(FORCE).type(mask, FORCE)
    : mask === '' && cy.getBySel('override-ipv4-NETWORK_MASK').clear(FORCE)
  address
    ? cy
        .getBySel('override-ipv4-NETWORK_ADDRESS')
        .clear(FORCE)
        .type(address, FORCE)
    : address === '' &&
      cy.getBySel('override-ipv4-NETWORK_ADDRESS').clear(FORCE)
  gateway
    ? cy.getBySel('override-ipv4-GATEWAY').clear(FORCE).type(gateway, FORCE)
    : gateway === '' && cy.getBySel('override-ipv4-GATEWAY').clear(FORCE)
  domains
    ? cy
        .getBySel('override-ipv4-SEARCH_DOMAIN')
        .clear(FORCE)
        .type(domains, FORCE)
    : domains === '' && cy.getBySel('override-ipv4-SEARCH_DOMAIN').clear(FORCE)
  method &&
    cy.getBySelEndsWith('override-ipv4-METHOD').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  method?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  method === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })

  // IPv6
  const { v6Ip, v6Gateway, v6Method } = ipv6 || {}

  v6Ip
    ? cy.getBySel('override-ipv6-IP6').clear(FORCE).type(v6Ip, FORCE)
    : v6Ip === '' && cy.getBySel('override-ipv6-IP6').clear(FORCE)
  v6Gateway
    ? cy.getBySel('override-ipv6-GATEWAY6').clear(FORCE).type(v6Gateway, FORCE)
    : v6Gateway === '' && cy.getBySel('override-ipv6-GATEWAY6').clear(FORCE)
  v6Method &&
    cy.getBySelEndsWith('override-ipv6-IP6_METHOD').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  v6Method?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  v6Method === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })

  // PCI device
  if (pci) {
    // eslint-disable-next-line cypress/no-unnecessary-waiting
    cy.wait(5000) // Should be a intercept to the /hostpool/admininfo call
    const { type, name, shortAddress } = pci

    type &&
      cy.getBySelEndsWith('-PCI_TYPE').then(({ selector }) => {
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
                    cy.wrap($el).click(FORCE)

                    return false // Break
                  }
                })
            })
          })
      })

    name &&
      cy.getBySelEndsWith('-DEVICE_LIST').then(({ selector }) => {
        cy.get(selector)
          .click(FORCE)
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    name?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    name === $el?.text()
                  ) {
                    cy.wrap($el).click(FORCE)

                    return false // Break
                  }
                })
            })
          })
      })

    // Type shortAddress
    if (shortAddress) {
      cy.getBySelEndsWith('-SHORT_ADDRESS').clear(FORCE)
      cy.getBySelEndsWith('-SHORT_ADDRESS').type(shortAddress)
    } else if (shortAddress === '') {
      cy.getBySelEndsWith('-SHORT_ADDRESS').clear(FORCE)
    }
  }

  // MTU
  mtu
    ? cy.getBySel('guest-GUEST_MTU').clear(FORCE).type(mtu, FORCE)
    : mtu === '' && cy.getBySel('guest-GUEST_MTU').clear(FORCE)
}

/**
 * Fill the QoS step of nic.
 *
 * @param {object} nic - Info of the nic
 */
const fillNicQosStep = (nic) => {
  const { inboundAverage, inboundPeak, inboundPeakBurst } = nic?.inbound || {}

  const { outboundAverage, outboundPeak, outboundPeakBurst } =
    nic?.outbound || {}

  // Inbound section
  inboundAverage
    ? cy
        .getBySel('override-in-qos-INBOUND_AVG_BW')
        .clear(FORCE)
        .type(inboundAverage, FORCE)
    : inboundAverage === '' &&
      cy.getBySel('override-in-qos-INBOUND_AVG_BW').clear(FORCE)
  inboundPeak
    ? cy
        .getBySel('override-in-qos-INBOUND_PEAK_BW')
        .clear(FORCE)
        .type(inboundPeak, FORCE)
    : inboundPeak === '' &&
      cy.getBySel('override-in-qos-INBOUND_PEAK_BW').clear(FORCE)
  inboundPeakBurst
    ? cy
        .getBySel('override-in-qos-INBOUND_PEAK_KB')
        .clear(FORCE)
        .type(inboundPeakBurst, FORCE)
    : inboundPeakBurst === '' &&
      cy.getBySel('override-in-qos-INBOUND_PEAK_KB').clear(FORCE)

  // Outbound section
  outboundAverage
    ? cy
        .getBySel('override-out-qos-OUTBOUND_AVG_BW')
        .clear(FORCE)
        .type(outboundAverage, FORCE)
    : outboundAverage === '' &&
      cy.getBySel('override-out-qos-OUTBOUND_AVG_BW').clear(FORCE)
  outboundPeak
    ? cy
        .getBySel('override-out-qos-OUTBOUND_PEAK_BW')
        .clear(FORCE)
        .type(outboundPeak, FORCE)
    : outboundPeak === '' &&
      cy.getBySel('override-out-qos-OUTBOUND_PEAK_BW').clear(FORCE)
  outboundPeakBurst
    ? cy
        .getBySel('override-out-qos-OUTBOUND_PEAK_KB')
        .clear(FORCE)
        .type(outboundPeakBurst, FORCE)
    : outboundPeakBurst === '' &&
      cy.getBySel('override-out-qos-OUTBOUND_PEAK_KB').clear(FORCE)
}

/**
 * Fill attach nic form.
 *
 * @param {Network} nic - Network object
 */
const fillAttachNicForm = (nic) => {
  cy.getBySel('modal-attach-nic').within(() => {
    // Advanced step
    fillNicAdvancedStep(nic)
    cy.getBySel('stepper-next-button').click(FORCE)

    // Network step
    fillNicNetworkStep(nic)
    cy.getBySel('stepper-next-button').click(FORCE)

    // QoS step
    fillNicQosStep(nic)
    cy.getBySel('stepper-next-button').click(FORCE)
  })
}

/**
 * Fill attach pci form.
 *
 * @param {Network} pci - PCI device object
 */
const fillAttachPciForm = (pci) => {
  cy.getBySel('modal-attach-pci').within(() => {
    const { specifyDevice, deviceName, shortAddress } = pci

    // Check specify device switch
    specifyDevice
      ? cy.getBySel('form-dg-SPECIFIC_DEVICE').check()
      : specifyDevice === false &&
        cy.getBySel('form-dg-SPECIFIC_DEVICE').uncheck()

    // Select device name
    deviceName &&
      cy.getBySel('form-dg-PCI_DEVICE_NAME').then(({ selector }) => {
        // eslint-disable-next-line cypress/no-unnecessary-waiting
        cy.wait(5000)
        cy.get(selector)
          .click(FORCE)
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    deviceName?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    deviceName === $el?.text()
                  ) {
                    cy.wrap($el).click(FORCE)

                    return false // Break
                  }
                })
            })
          })
      })

    // Type shortAddress
    if (shortAddress) {
      cy.getBySel('form-dg-SHORT_ADDRESS').clear()
      const wrapType = (input) => {
        for (const char of input) {
          cy.getBySel('form-dg-SHORT_ADDRESS').type(`${char}`)
        }
        cy.getBySel('form-dg-SHORT_ADDRESS').type(`{downArrow}`)

        cy.getBySel('form-dg-SHORT_ADDRESS').type(`{enter}`)
      }

      wrapType(shortAddress)
    } else if (shortAddress === '') {
      cy.getBySel('form-dg-SHORT_ADDRESS').clear()
    }

    // Click accept
    cy.getBySel('dg-accept-button').click(FORCE)
  })
}

/**
 * Fill attach alias form.
 *
 * @param {Network} alias - Network object
 */
const fillAttachAliasForm = (alias) => {
  cy.getBySel('modal-attach-alias').within(() => {
    // Network step
    fillNicNetworkStep(alias)
    cy.getBySel('stepper-next-button').click(FORCE)

    // Advanced step
    fillNicAdvancedStep(alias)
    cy.getBySel('stepper-next-button').click(FORCE)
  })
}

/**
 * Fill network section on the create/update form.
 *
 * @param {VmTemplate} templateTest - template object
 */
const fillNetworkSection = (templateTest) => {
  const { networks } = templateTest
  if (!networks) return
  const ensuredNics = Array.isArray(networks) ? networks : [networks]
  cy.navigateTab('network')

  ensuredNics.forEach((nic) => {
    if (nic.parent) {
      cy.getBySel(`alias-nic-${nic.parent}`).click(FORCE)

      cy.getBySel('modal-show-alias').within(() => {
        cy.getBySel('add-alias').click(FORCE)
      })

      fillAttachAliasForm(nic)

      cy.getBySel('modal-show-alias').within(() => {
        cy.getBySel('dg-accept-button').click(FORCE)
      })
    } else {
      cy.getBySel('add-nic').click(FORCE)

      fillAttachNicForm(nic)
    }
  })
}

/**
 * Fill PCI device section on the create/update form.
 *
 * @param {VmTemplate} templateTest - template object
 */
const fillPciDevicesSection = (templateTest) => {
  const { pcis } = templateTest
  if (!pcis) return
  const ensuredPcis = Array.isArray(pcis) ? pcis : [pcis]
  cy.navigateTab('pci')

  ensuredPcis.forEach((pci) => {
    cy.getBySel('attach-pci').click()
    fillAttachPciForm(pci)
  })
}

/**
 * Fill IO section on the create/update form.
 *
 * @param {VmTemplate} templateTest - template object
 * @param {string} [stepId] - Step id
 */
const fillIOSection = (templateTest, stepId) => {
  const { inputOutput } = templateTest

  if (!inputOutput) return

  const {
    graphics,
    inputs,
    ip,
    port,
    keymap,
    customKeymap,
    password,
    randomPassword,
    command,
    video,
  } = inputOutput

  const getSelector = (id) =>
    cy.getBySel([stepId, id].filter(Boolean).join('-'))

  cy.navigateTab('input_output').within(() => {
    // Graphics
    graphics
      ? getSelector('io-graphics-GRAPHICS-TYPE').check()
      : graphics === false && getSelector('io-graphics-GRAPHICS-TYPE').uncheck()

    ip
      ? getSelector('io-graphics-GRAPHICS-LISTEN').clear().type(ip)
      : ip === '' && getSelector('io-graphics-GRAPHICS-LISTEN').clear()
    port
      ? getSelector('io-graphics-GRAPHICS-PORT').clear().type(port)
      : port && getSelector('io-graphics-GRAPHICS-PORT').clear()

    if (keymap) {
      getSelector('io-graphics-GRAPHICS-KEYMAP')
        .clear()
        .type(keymap)
        .type('{downArrow}')
        .type('{enter}')

      if (keymap.toLowerCase() === 'custom' && customKeymap) {
        getSelector('io-graphics-GRAPHICS-CUSTOM_KEYMAP')
          .clear()
          .type(customKeymap)
      }
    }

    randomPassword
      ? getSelector('io-graphics-GRAPHICS-RANDOM_PASSWD').check()
      : randomPassword === false &&
        getSelector('io-graphics-GRAPHICS-RANDOM_PASSWD').uncheck()
    password
      ? getSelector('io-graphics-GRAPHICS-PASSWD').clear().type(password)
      : password === '' && getSelector('io-graphics-GRAPHICS-PASSWD').clear()
    command
      ? getSelector('io-graphics-GRAPHICS-COMMAND').clear().type(command)
      : command === '' && getSelector('io-graphics-GRAPHICS-COMMAND').clear()

    // Video
    if (video) {
      const {
        type,
        iommu,
        ats,
        vram,
        resolution,
        resolutionWidth,
        resolutionHeight,
      } = video

      type &&
        getSelector('io-video-VIDEO-TYPE').then(({ selector }) => {
          cy.get(selector)
            .click()
            .then(() => {
              cy.document().then((doc) => {
                cy.wrap(doc?.body)
                  .find('.MuiAutocomplete-option')
                  .each(($el) => {
                    if (
                      video.type?.toLowerCase() ===
                        $el?.attr('data-value')?.toLowerCase() ||
                      video.type === $el?.text()
                    ) {
                      cy.wrap($el).click()

                      return false // Break
                    }
                  })
              })
            })
        })

      iommu
        ? getSelector('io-video-VIDEO-IOMMU').check(FORCE)
        : iommu === false && getSelector('io-video-VIDEO-IOMMU').uncheck(FORCE)
      ats
        ? getSelector('io-video-VIDEO-ATS').check(FORCE)
        : ats === false && getSelector('io-video-VIDEO-ATS').uncheck(FORCE)
      vram
        ? getSelector('io-video-VIDEO-VRAM').clear().type(vram)
        : vram === '' && getSelector('io-video-VIDEO-VRAM').clear()
      resolution &&
        getSelector('io-video-VIDEO-RESOLUTION').then(({ selector }) => {
          cy.get(selector)
            .click(FORCE)
            .then(() => {
              cy.document().then((doc) => {
                cy.wrap(doc?.body)
                  .find('.MuiAutocomplete-option')
                  .each(($el) => {
                    if (
                      resolution?.toLowerCase() ===
                        $el?.attr('data-value')?.toLowerCase() ||
                      resolution === $el?.text()
                    ) {
                      cy.wrap($el).click(FORCE)

                      return false // Break
                    }
                  })
              })
            })
        })

      resolutionWidth
        ? getSelector('io-video-VIDEO-RESOLUTION_WIDTH')
            .clear()
            .type(resolutionWidth)
        : resolutionWidth === '' &&
          getSelector('io-video-VIDEO-RESOLUTION_WIDTH').clear()
      resolutionHeight
        ? getSelector('io-video-VIDEO-RESOLUTION_HEIGHT')
            .clear()
            .type(resolutionHeight)
        : resolutionHeight === '' &&
          getSelector('io-video-VIDEO-RESOLUTION_HEIGHT').clear()
    }

    // Inputs
    if (inputs) {
      const ensuredInputs = Array.isArray(inputs) ? inputs : [inputs]

      cy.wrap(ensuredInputs).each(({ type, bus }) => {
        type &&
          getSelector('io-inputs-TYPE').then(({ selector }) => {
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

        bus &&
          getSelector('io-inputs-BUS').then(({ selector }) => {
            cy.get(selector)
              .click()
              .then(() => {
                cy.document().then((doc) => {
                  cy.wrap(doc?.body)
                    .find('.MuiAutocomplete-option')
                    .each(($el) => {
                      if (
                        bus?.toLowerCase() ===
                          $el?.attr('data-value')?.toLowerCase() ||
                        bus === $el?.text()
                      ) {
                        cy.wrap($el).click()

                        return false // Break
                      }
                    })
                })
              })
          })

        getSelector('add-io-inputs').click()
      })
    }
  })
}

/**
 * Fill OS & CPU section on the create/update form.
 *
 * @param {VmTemplate} templateTest - template object
 * @param {string} [stepId] - Step id
 */
const fillOsAndCpuSection = (templateTest, stepId) => {
  const { osCpu } = templateTest

  if (!osCpu) return

  const {
    arch,
    bus,
    os,
    root,
    kernel,
    bootloader,
    uuid,
    acpi,
    pae,
    apic,
    hyperV,
    localtime,
    guestAgent,
    virtioScsiQueues,
    ioThreads,
    firmware,
    kernelOptions,
    ramDisk,
    rawData,
    validate,
    model,
    feature,
    virtualBlkQueues,
    bootOrder,
  } = osCpu

  const getSelector = (id) =>
    cy.getBySel([stepId, id].filter(Boolean).join('-'))

  // Navigate to OS&CPU section
  cy.navigateTab('booting')

  // Boot order
  if (bootOrder) {
    const { check, uncheck } = bootOrder

    // Check disk and nics
    check && check.forEach((item) => cy.getBySel(item).children().eq(0).check())

    // Uncheck disk and nics
    uncheck &&
      uncheck.forEach((item) => cy.getBySel(item).children().eq(0).uncheck())
  }

  // CPU model
  model &&
    getSelector('os-cpu-model-CPU_MODEL-MODEL').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  model?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  model === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })

  feature &&
    getSelector('os-cpu-model-CPU_MODEL-FEATURES').then(({ selector }) => {
      cy.get(selector).then(($element) => {
        // Check if the next sibling is the clear button
        const clearButton = $element
          .next('.MuiAutocomplete-endAdornment')
          .find('.MuiAutocomplete-clearIndicator')
        if (clearButton.length > 0) {
          cy.wrap(clearButton).click({ force: true })
        }
      })

      // Wait for any potential DOM updates and re-select the parent element
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc.body)
              .find('.MuiAutocomplete-option')
              .each(($option) => {
                const optionValue = $option.attr('data-value')
                const optionText = $option.text()

                if (
                  feature?.toLowerCase() === optionValue?.toLowerCase() ||
                  feature === optionText
                ) {
                  cy.wrap($option).click()

                  return false // Break the loop
                }
              })
          })
        })
    })

  // Boot
  arch &&
    getSelector('os-boot-OS-ARCH').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  arch?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  arch === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })

  bus &&
    getSelector('os-boot-OS-SD_DISK_BUS').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  bus?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  bus === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })

  os &&
    getSelector('os-boot-OS-MACHINE').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  os?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  os === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })

  root
    ? getSelector('os-boot-OS-ROOT').clear().type(root)
    : root === '' && getSelector('os-boot-OS-ROOT').clear()
  kernel
    ? getSelector('os-boot-OS-KERNEL_CMD').clear().type(kernel)
    : kernel === '' && getSelector('os-boot-OS-KERNEL_CMD').clear()

  bootloader
    ? getSelector('os-boot-OS-BOOTLOADER').clear().type(bootloader)
    : bootloader === '' && getSelector('os-boot-OS-BOOTLOADER').clear()

  uuid
    ? getSelector('os-boot-OS-UUID').clear().type(uuid)
    : uuid === '' && getSelector('os-boot-OS-UUID').clear()

  if (firmware) {
    const { secure, firmware: firmwareOS } = firmware

    if (firmwareOS) {
      getSelector('os-boot-OS-FIRMWARE')
        .clear()
        .type(`{backspace}${firmwareOS}`)
      secure
        ? getSelector('os-boot-OS-FIRMWARE_SECURE').check(FORCE)
        : secure === false &&
          getSelector('os-boot-OS-FIRMWARE_SECURE').uncheck(FORCE)
    }
  }

  // Features
  acpi &&
    getSelector('os-features-FEATURES-ACPI').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  sentenceCase(acpi)?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  sentenceCase(acpi) === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })

  pae &&
    getSelector('os-features-FEATURES-PAE').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  sentenceCase(pae)?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  sentenceCase(pae) === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })

  apic &&
    getSelector('os-features-FEATURES-APIC').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  sentenceCase(apic)?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  sentenceCase(apic) === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })

  hyperV &&
    getSelector('os-features-FEATURES-HYPERV').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  sentenceCase(hyperV)?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  sentenceCase(hyperV) === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })

  localtime &&
    getSelector('os-features-FEATURES-LOCALTIME').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  sentenceCase(localtime)?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  sentenceCase(localtime) === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })

  guestAgent &&
    getSelector('os-features-FEATURES-GUEST_AGENT').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  sentenceCase(guestAgent)?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  sentenceCase(guestAgent) === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })

  virtioScsiQueues &&
    getSelector('os-features-FEATURES-VIRTIO_SCSI_QUEUES').then(
      ({ selector }) => {
        cy.get(selector)
          .click()
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    virtioScsiQueues?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    virtioScsiQueues === $el?.text()
                  ) {
                    cy.wrap($el).click()

                    return false // Break
                  }
                })
            })
          })
      }
    )

  virtualBlkQueues &&
    getSelector('os-features-FEATURES-VIRTIO_BLK_QUEUES').then(
      ({ selector }) => {
        cy.get(selector)
          .click()
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    virtualBlkQueues?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    virtualBlkQueues === $el?.text()
                  ) {
                    cy.wrap($el).click()

                    return false // Break
                  }
                })
            })
          })
      }
    )

  ioThreads
    ? getSelector('os-features-FEATURES-IOTHREADS').clear().type(ioThreads)
    : ioThreads === '' && getSelector('os-features-FEATURES-IOTHREADS').clear()

  // Kernel
  if (kernelOptions) {
    const { enable, os: osKernelOptions } = kernelOptions

    enable
      ? getSelector('os-kernel-OS-KERNEL_PATH_ENABLED').check(FORCE)
      : enable === false &&
        getSelector('os-kernel-OS-KERNEL_PATH_ENABLED').uncheck(FORCE)

    if (enable) {
      osKernelOptions
        ? getSelector('os-kernel-OS-KERNEL').clear().type(osKernelOptions)
        : osKernelOptions === '' && getSelector('os-kernel-OS-KERNEL').clear()
    } else if (enable === false) {
      if (osKernelOptions) {
        getSelector('os-kernel-OS-KERNEL_DS').clear().type(osKernelOptions)
        cy.getDropdownOptions().contains(osKernelOptions).click()
      } else if (osKernelOptions === '') {
        // Click on cross button to delete the content
        getSelector('os-kernel-OS-KERNEL_DS')
          .parent('.MuiAutocomplete-inputRoot')
          .find('.MuiAutocomplete-clearIndicator[title=Clear]', FORCE)
          .click(FORCE)
      }
    }
  }

  // Ramdisk
  if (ramDisk) {
    const { enable, initrd } = ramDisk

    enable
      ? getSelector('os-ramdisk-OS-RAMDISK_PATH_ENABLED').check(FORCE)
      : enable === false &&
        getSelector('os-ramdisk-OS-RAMDISK_PATH_ENABLED').uncheck(FORCE)

    if (enable) {
      initrd
        ? getSelector('os-ramdisk-OS-INITRD').clear().type(initrd)
        : initrd === '' && getSelector('os-ramdisk-OS-INITRD').clear()
    } else if (enable === false) {
      if (initrd) {
        getSelector('os-ramdisk-OS-INITRD_DS').clear().type(initrd)
        cy.getDropdownOptions().click()
      } else if (initrd === '') {
        // Click on cross button to delete the content
        getSelector('os-ramdisk-OS-INITRD_DS')
          .parent('.MuiAutocomplete-inputRoot')
          .find('.MuiAutocomplete-clearIndicator[title=Clear]', FORCE)
          .click(FORCE)
      }
    }
  }

  // Raw data
  rawData
    ? getSelector('os-raw-RAW-DATA').clear().type(rawData)
    : rawData === '' && getSelector('os-raw-RAW-DATA').clear()
  validate
    ? getSelector('os-raw-RAW-VALIDATE').check()
    : validate === false && getSelector('os-raw-RAW-VALIDATE').uncheck()
}

/**
 * Fill context section on the create/update form.
 *
 * @param {VmTemplate} templateTest - template object
 * @param {string} [stepId] - Step id
 */
const fillContextSection = (templateTest, stepId) => {
  const { context } = templateTest

  if (!context) return

  const {
    network,
    token,
    report,
    autoAddSshKey,
    autoDeleteSshKey,
    sshKey,
    startScript,
    encodeScript,
    files,
    initScripts,
    userInputs,
    customVars,
  } = context

  const getSelector = (id) =>
    cy.getBySel([stepId, id].filter(Boolean).join('-'))

  cy.navigateTab('context')

  network
    ? getSelector('context-configuration-others-CONTEXT-NETWORK').check()
    : network === false &&
      getSelector('context-configuration-others-CONTEXT-NETWORK').uncheck()
  token
    ? getSelector('context-configuration-others-CONTEXT-TOKEN').check()
    : token === false &&
      getSelector('context-configuration-others-CONTEXT-TOKEN').uncheck()
  report
    ? getSelector('context-configuration-others-CONTEXT-REPORT_READY').check()
    : report === false &&
      getSelector('context-configuration-others-CONTEXT-REPORT_READY').uncheck()
  autoAddSshKey && getSelector('add-context-ssh-public-key').click()
  autoDeleteSshKey && getSelector('delete-context-ssh-public-key').click()
  sshKey
    ? getSelector('context-ssh-public-key-CONTEXT-SSH_PUBLIC_KEY')
        .clear()
        .type(sshKey)
    : sshKey === '' &&
      getSelector('context-ssh-public-key-CONTEXT-SSH_PUBLIC_KEY').clear()
  startScript
    ? getSelector('context-script-CONTEXT-START_SCRIPT')
        .clear()
        .type(startScript)
    : startScript === '' &&
      getSelector('context-script-CONTEXT-START_SCRIPT').clear()
  encodeScript
    ? getSelector('context-script-CONTEXT-ENCODE_START_SCRIPT').check()
    : encodeScript === false &&
      getSelector('context-script-CONTEXT-ENCODE_START_SCRIPT').uncheck()

  // Files and init scripts
  if (files || initScripts) {
    // Expand the file section if it's not already expanded
    cy.getBySel('legend-extra-context-files').click()

    // initScripts
    if (initScripts && initScripts.length > 0) {
      initScripts.forEach((initScript) => {
        getSelector('context-files-CONTEXT-INIT_SCRIPTS').clear()
        getSelector('context-files-CONTEXT-INIT_SCRIPTS').type(
          `${initScript}{enter}`
        )
      })
    } else if (initScripts && initScripts?.length === 0) {
      getSelector('context-files-CONTEXT-INIT_SCRIPTS')
        .parent('.MuiAutocomplete-inputRoot')
        .find('.MuiAutocomplete-clearIndicator[title=Clear]', FORCE)
        .click(FORCE)
    }

    // files
    if (files && files.length > 0) {
      files.forEach((file) => {
        getSelector('context-files-CONTEXT-FILES_DS').clear()
        cy.getDropdownOptions().contains(file).click()
      })
    } else if (files && files?.length === 0) {
      getSelector('context-files-CONTEXT-FILES_DS')
        .parent('.MuiAutocomplete-inputRoot')
        .find('.MuiAutocomplete-clearIndicator[title=Clear]', FORCE)
        .click(FORCE)
    }
  }

  // Custom vars
  if (customVars) {
    // Expand the custom vars section if it's not already expanded
    cy.getBySel('context-custom-vars').click()

    Object.entries(customVars).forEach(([varName, varValue]) => {
      cy.getBySelLike('text-name-').clear().type(varName)
      cy.getBySelLike('text-value-').clear().type(`${varValue}{enter}`)
    })
  }

  // User inputs
  if (userInputs) {
    cy.wrap(Array.isArray(userInputs) ? userInputs : [userInputs]).each(
      ({
        type,
        name: nameUserInput,
        description: descriptionUserInput,
        defaultValue,
        mandatory,
        options,
        min,
        max,
      }) => {
        type &&
          getSelector('context-user-input-type').then(({ selector }) => {
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

        nameUserInput &&
          getSelector('context-user-input-name').clear().type(nameUserInput)
        descriptionUserInput &&
          getSelector('context-user-input-description')
            .clear()
            .type(descriptionUserInput)

        options?.forEach((option) => {
          getSelector('context-user-input-options')
            .clear()
            .type(`${option}{enter}`)
        })

        min && getSelector('context-user-input-min').clear().type(min)
        max && getSelector('context-user-input-max').clear().type(max)

        if (type === 'Boolean' || type === 'List')
          defaultValue &&
            getSelector('context-user-input-default').then(({ selector }) => {
              cy.get(selector)
                .click()
                .then(() => {
                  cy.document().then((doc) => {
                    cy.wrap(doc?.body)
                      .find('.MuiAutocomplete-option')
                      .each(($el) => {
                        if (
                          defaultValue?.toLowerCase() ===
                            $el?.attr('data-value')?.toLowerCase() ||
                          defaultValue === $el?.text()
                        ) {
                          cy.wrap($el).click()

                          return false // Break
                        }
                      })
                  })
                })
            })
        else if (type === 'List multiple') {
          defaultValue?.forEach((dv) => {
            getSelector('context-user-input-default').then(({ selector }) => {
              cy.get(selector)
                .click()
                .then(() => {
                  cy.document().then((doc) => {
                    cy.wrap(doc?.body)
                      .find('.MuiAutocomplete-option')
                      .each(($el) => {
                        if (
                          dv?.toLowerCase() ===
                            $el?.attr('data-value')?.toLowerCase() ||
                          dv === $el?.text()
                        ) {
                          cy.wrap($el).click()

                          return false // Break
                        }
                      })
                  })
                })
            })
          })
        } else
          defaultValue &&
            getSelector('context-user-input-default').clear().type(defaultValue)

        mandatory && getSelector('context-user-input-mandatory').check()
        getSelector('add-context-user-input').click()
      }
    )
  }
}

/**
 * Fill BACKUP section on the create/update form.
 *
 * @param {VmTemplate} templateTest - template object
 * @param {string} [stepId] - Step id
 */
const fillBackupSection = (templateTest, stepId) => {
  const { backupConfig } = templateTest
  if (!backupConfig) return

  const { backupVolatile, fsFreeze, keepLast, mode, incrementMode } =
    backupConfig

  const getSelector = (id) =>
    cy.getBySel([stepId, id].filter(Boolean).join('-'))

  cy.navigateTab('backup').within(() => {
    backupVolatile
      ? getSelector(
          'backup-configuration-BACKUP_CONFIG-BACKUP_VOLATILE'
        ).check()
      : backupVolatile === false &&
        getSelector(
          'backup-configuration-BACKUP_CONFIG-BACKUP_VOLATILE'
        ).uncheck()

    fsFreeze &&
      getSelector('backup-configuration-BACKUP_CONFIG-FS_FREEZE').then(
        ({ selector }) => {
          cy.get(selector)
            .click(FORCE)
            .then(() => {
              cy.document().then((doc) => {
                cy.wrap(doc?.body)
                  .find('.MuiAutocomplete-option')
                  .each(($el) => {
                    if (
                      fsFreeze?.toLowerCase() ===
                        $el?.attr('data-value')?.toLowerCase() ||
                      fsFreeze === $el?.text()
                    ) {
                      cy.wrap($el).click(FORCE)

                      return false // Break
                    }
                  })
              })
            })
        }
      )

    if (keepLast || keepLast === '') {
      getSelector('backup-configuration-BACKUP_CONFIG-KEEP_LAST')
        .should('exist')
        .clear()
      getSelector('backup-configuration-BACKUP_CONFIG-KEEP_LAST').type(
        `{selectall}${keepLast || ''}`
      )
    }

    mode &&
      getSelector('backup-configuration-BACKUP_CONFIG-MODE').then(
        ({ selector }) => {
          cy.get(selector)
            .click(FORCE)
            .should('exist')
            .then(() => {
              cy.document().then((doc) => {
                cy.wrap(doc?.body)
                  .find('.MuiAutocomplete-option')
                  .each(($el) => {
                    if (
                      mode?.toLowerCase() ===
                        $el?.attr('data-value')?.toLowerCase() ||
                      mode === $el?.text()
                    ) {
                      cy.wrap($el).click(FORCE)

                      return false // Break
                    }
                  })
              })
            })
        }
      )

    incrementMode &&
      getSelector('backup-configuration-BACKUP_CONFIG-INCREMENT_MODE').then(
        ({ selector }) => {
          cy.get(selector)
            .click()
            .then(() => {
              cy.document().then((doc) => {
                cy.wrap(doc?.body)
                  .find('.MuiAutocomplete-option')
                  .each(($el) => {
                    if (
                      incrementMode?.toLowerCase() ===
                        $el?.attr('data-value')?.toLowerCase() ||
                      incrementMode === $el?.text()
                    ) {
                      cy.wrap($el).click()

                      return false // Break
                    }
                  })
              })
            })
        }
      )
  })
}

/**
 * Fill scheduler actions section on the create/update form.
 *
 * @param {VmTemplate} templateTest - template object
 */
const fillSchedActionsSection = (templateTest) => {
  const { schedActions } = templateTest

  if (!schedActions) return

  const ensuredActions = Array.isArray(schedActions)
    ? schedActions
    : [schedActions]

  cy.navigateTab('sched_action')

  cy.wrap(ensuredActions).each((action) => {
    cy.getBySel('sched-add').click(FORCE)
    fillSchedActionForm(action)
  })
}

/**
 * Fill the schedule action form.
 *
 * @param {object} actionItem - Action object
 */
const fillSchedActionForm = (actionItem) => {
  const {
    action,
    time,
    periodic,
    period,
    repeat,
    repeatValue,
    repeatDaysOfTheWeek,
    endType,
    endTypeNumberOfRepetitions,
    endTypeDate,
    backupDs,
    snapshotName,
  } = actionItem

  cy.getBySel('modal-sched-actions')

  // Select the type of schedule action
  action &&
    cy.getBySelEndsWith('-ACTION').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  action?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  action === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })

  // Backup datastore
  backupDs &&
    cy.getBySelEndsWith('-ARGS-DS_ID').then(({ selector }) => {
      cy.get(selector)
        .click()
        .then(() => {
          cy.document().then((doc) => {
            cy.wrap(doc?.body)
              .find('.MuiAutocomplete-option')
              .each(($el) => {
                if (
                  backupDs?.toLowerCase() ===
                    $el?.attr('data-value')?.toLowerCase() ||
                  backupDs === $el?.text()
                ) {
                  cy.wrap($el).click()

                  return false // Break
                }
              })
          })
        })
    })

  // Snapshot
  snapshotName &&
    cy.getBySelEndsWith('-ARGS-NAME').clear().type(snapshotName, FORCE)

  // Periodic time
  if (periodic) {
    // Click on type of periodic button (one time, periodic or relative)
    cy.getBySel('form-dg-PERIODIC')
      .find(`button[aria-pressed="false"]`)
      .each(($button) => {
        cy.wrap($button)
          .invoke('attr', 'value')
          .then(($value) => $value === periodic && cy.wrap($button).click())
      })
  }

  // If periodic time is relative, only have to fill two fields
  if (periodic === 'RELATIVE') {
    time && cy.getBySelEndsWith('-RELATIVE_TIME').clear().type(time, FORCE)
    period &&
      cy.getBySelEndsWith('-PERIOD').then(({ selector }) => {
        cy.get(selector)
          .click()
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    period?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    period === $el?.text()
                  ) {
                    cy.wrap($el).click()

                    return false // Break
                  }
                })
            })
          })
      })
  } else {
    // One time and periodic have time field
    time && cy.fillDatetimePicker('form-dg-TIME', time)

    // Periodic also has to fill other fields
    if (periodic === 'PERIODIC') {
      if (repeat) {
        // Granularity of the action
        cy.getBySelEndsWith('-REPEAT').then(({ selector }) => {
          cy.get(selector)
            .click()
            .then(() => {
              cy.document().then((doc) => {
                cy.wrap(doc?.body)
                  .find('.MuiAutocomplete-option')
                  .each(($el) => {
                    if (
                      repeat?.toLowerCase() ===
                        $el?.attr('data-value')?.toLowerCase() ||
                      repeat === $el?.text()
                    ) {
                      cy.wrap($el).click()

                      return false // Break
                    }
                  })
              })
            })
        })

        // Check type of granularity of the action and fill the corresponding field
        const upperRepeat = repeat.toUpperCase()

        // Select day of the week
        repeatDaysOfTheWeek &&
          cy.getBySelEndsWith('-WEEKLY').then(({ selector }) => {
            cy.get(selector)
              .click()
              .then(() => {
                cy.document().then((doc) => {
                  cy.wrap(doc?.body)
                    .find('.MuiAutocomplete-option')
                    .each(($el) => {
                      cy.wrap(repeatDaysOfTheWeek)?.each((day) => {
                        if (
                          day?.toLowerCase() ===
                            $el.attr('data-value')?.toLowerCase() ||
                          day === $el.text()
                        ) {
                          cy.wrap(doc.body)
                            .find('.MuiAutocomplete-option')
                            .contains($el.text())
                            .click()
                          // Reopen options
                          cy.get(selector).click()
                        }
                      })
                    })
                })
              })
          })

        // Select value for the repeat
        repeatValue
          ? cy.getBySel(`form-dg-${upperRepeat}`).clear().type(repeatValue)
          : repeatValue === '' && cy.getBySel(`form-dg-${upperRepeat}`).clear()
      }

      // End type
      endType &&
        cy.getBySelEndsWith('-END_TYPE').then(({ selector }) => {
          cy.get(selector)
            .click(FORCE)
            .then(() => {
              cy.document().then((doc) => {
                cy.wrap(doc?.body)
                  .find('.MuiAutocomplete-option')
                  .each(($el) => {
                    if (
                      endType?.toLowerCase() ===
                        $el?.attr('data-value')?.toLowerCase() ||
                      endType === $el?.text()
                    ) {
                      cy.wrap($el).click()

                      return false // Break
                    }
                  })
              })
            })
        })

      endTypeNumberOfRepetitions
        ? cy
            .getBySelEndsWith('-END_VALUE')
            .clear()
            .type(endTypeNumberOfRepetitions, FORCE)
        : endTypeNumberOfRepetitions === '' &&
          cy.getBySelEndsWith('-END_VALUE').clear()

      endTypeDate && cy.fillDatetimePicker('form-dg-END_VALUE', endTypeDate)
    }
  }

  // FINISH DIALOG
  cy.getBySel('dg-accept-button').click(FORCE)
}

/**
 * Fill placement section on the create/update form.
 *
 * @param {VmTemplate} templateTest - template object
 */
const fillPlacementSection = (templateTest) => {
  const { placement } = templateTest

  if (!placement) return

  const { hostRequirement, schedRank, dsSchedRequirement, dsSchedRank } =
    placement

  cy.navigateTab('placement').within(() => {
    hostRequirement
      ? cy
          .getBySel('extra-placement-host-SCHED_REQUIREMENTS')
          .clear()
          .type(hostRequirement)
      : hostRequirement === '' &&
        cy.getBySel('extra-placement-host-SCHED_REQUIREMENTS').clear()
    schedRank
      ? cy.getBySel('extra-placement-host-SCHED_RANK').clear().type(schedRank)
      : schedRank === '' &&
        cy.getBySel('extra-placement-host-SCHED_RANK').clear()
    dsSchedRequirement
      ? cy
          .getBySel('extra-placement-ds-SCHED_DS_REQUIREMENTS')
          .clear()
          .type(dsSchedRequirement)
      : dsSchedRequirement === '' &&
        cy.getBySel('extra-placement-ds-SCHED_DS_REQUIREMENTS').clear()
    dsSchedRank
      ? cy
          .getBySel('extra-placement-ds-SCHED_DS_RANK')
          .clear()
          .type(dsSchedRank)
      : dsSchedRank === '' &&
        cy.getBySel('extra-placement-ds-SCHED_DS_RANK').clear()
  })
}

/**
 * Fill NUMA section on the create/update form.
 *
 * @param {VmTemplate} templateTest - template object
 */
const fillNumaSection = (templateTest) => {
  const { numa } = templateTest

  if (!numa) return

  const {
    vcpu: numaVCPU,
    numaTopology,
    pinPolicy,
    cores,
    sockets,
    threads,
    hugepages,
    memoryAccess,
    numaAffinity,
  } = numa

  cy.navigateTab('numa').within(() => {
    numaTopology
      ? cy.getBySel('extra-numa-TOPOLOGY-ENABLE_NUMA').check()
      : numaTopology === false &&
        cy.getBySel('extra-numa-TOPOLOGY-ENABLE_NUMA').uncheck()

    numaVCPU
      ? cy.getBySel('extra-vcpu-VCPU').clear().type(numaVCPU)
      : numaVCPU === '' && cy.getBySel('extra-vcpu-VCPU').clear()

    pinPolicy &&
      cy.getBySel('extra-numa-TOPOLOGY-PIN_POLICY').then(({ selector }) => {
        cy.get(selector)
          .click()
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    pinPolicy?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    pinPolicy === $el?.text()
                  ) {
                    cy.wrap($el).click()

                    return false // Break
                  }
                })
            })
          })
      })

    numaAffinity
      ? cy
          .getBySel('extra-numa-TOPOLOGY-NODE_AFFINITY')
          .clear()
          .type(numaAffinity)
      : numaAffinity === '' &&
        cy.getBySel('extra-numa-TOPOLOGY-NODE_AFFINITY').clear()

    cores
      ? cy.getBySel('extra-numa-TOPOLOGY-CORES').clear().type(cores)
      : cores === '' && cy.getBySel('extra-numa-TOPOLOGY-CORES').clear()

    sockets
      ? cy.getBySel('extra-numa-TOPOLOGY-SOCKETS').clear().type(sockets)
      : sockets === '' && cy.getBySel('extra-numa-TOPOLOGY-SOCKETS').clear()

    threads
      ? cy.getBySel('extra-numa-TOPOLOGY-THREADS').clear().type(threads)
      : threads === '' && cy.getBySel('extra-numa-TOPOLOGY-THREADS').clear()

    hugepages &&
      cy.getBySel('extra-numa-TOPOLOGY-HUGEPAGE_SIZE').then(({ selector }) => {
        cy.get(selector)
          .click()
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    hugepages?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    hugepages === $el?.text()
                  ) {
                    cy.wrap($el).click()

                    return false // Break
                  }
                })
            })
          })
      })

    memoryAccess &&
      cy.getBySel('extra-numa-TOPOLOGY-MEMORY_ACCESS').then(({ selector }) => {
        cy.get(selector)
          .click()
          .then(() => {
            cy.document().then((doc) => {
              cy.wrap(doc?.body)
                .find('.MuiAutocomplete-option')
                .each(($el) => {
                  if (
                    memoryAccess?.toLowerCase() ===
                      $el?.attr('data-value')?.toLowerCase() ||
                    memoryAccess === $el?.text()
                  ) {
                    cy.wrap($el).click()

                    return false // Break
                  }
                })
            })
          })
      })
  })
}

/**
 * Fill forms Template via GUI.
 *
 * @param {VmTemplate} templateTest - template
 * @param {boolean} isUpdate - is update
 */
const fillTemplateGUI = (templateTest, isUpdate = false) => {
  cy.getBySel('main-layout').click()

  fillGeneralStep(templateTest, isUpdate)

  cy.getBySel('stepper-next-button').click()

  fillStorageSection(templateTest)
  fillNetworkSection(templateTest)
  fillPciDevicesSection(templateTest)
  fillOsAndCpuSection(templateTest, 'extra')
  fillIOSection(templateTest, 'extra')
  fillContextSection(templateTest, 'extra')
  fillSchedActionsSection(templateTest)
  fillPlacementSection(templateTest)
  fillNumaSection(templateTest)
  fillBackupSection(templateTest, 'extra')

  cy.getBySel('stepper-next-button').click()
}

export {
  fillAttachNicForm,
  fillAttachImageForm,
  fillAttachVolatileForm,
  fillBackupSection,
  fillContextSection,
  fillGeneralStep,
  fillIOSection,
  fillNetworkSection,
  fillNicNetworkStep,
  fillNicAdvancedStep,
  fillNicQosStep,
  fillPciDevicesSection,
  fillAttachPciForm,
  fillNumaSection,
  fillOsAndCpuSection,
  fillPlacementSection,
  fillSchedActionsSection,
  fillSchedActionForm,
  fillStorageSection,
  fillTemplateGUI,
  fillAttachAdvancedStep,
}
