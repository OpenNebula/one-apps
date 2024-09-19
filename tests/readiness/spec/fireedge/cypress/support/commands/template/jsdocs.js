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
 * @typedef Disk - Disk object
 * @property {number} [image] - Image id
 * @property {number} [size] - Image size
 * @property {string} [target] - Image target
 * @property {string} [readOnly] - Read only
 * @property {string} [bus] - Disk bus
 * @property {string} [cache] - Disk cache
 * @property {string} [io] - IO
 * @property {string} [discard] - Discard
 * @property {string} [type] - Type
 * @property {string} [format] - Format
 * @property {string} [filesystem] - System
 * @property {string} [vcenterAdapterType] - vCenter adapter type
 * @property {string} [vcenterDiskType] - vCenter disk type
 */

/**
 * @typedef Network - Virtual Network object
 * @property {number} [id] - Id
 * @property {boolean} [rdp] - RDP enabled
 * @property {configRDP} [rdpOptions] - Connection options for RDP
 * @property {boolean} [ssh] - SSH enabled
 * @property {string} [alias] - Alias name
 */

/**
 * @typedef OsAndCpu - OS and CPU object
 * @property {string} [arch] - Architecture
 * @property {string} [bus] - Bus type
 * @property {string} [os] - OS
 * @property {string} [osModel] - OS model
 * @property {string} [root] - Path root
 * @property {string} [kernel] - Command kernel
 * @property {string} [bootloader] - Boot loader
 * @property {string} [uuid] - UUID
 * @property {string} [acpi] - ACPI
 * @property {string} [pae] - PAE
 * @property {string} [apic] - APIC
 * @property {string} [hyperV] - HyperV enabled
 * @property {string} [localtime] - Local time
 * @property {string} [guestAgent] - Guest Agent
 * @property {number} [virtioScsiQueues] - VIRTIO SCSI Queues
 * @property {number} [ioThreads] - IO threads
 * @property {string} [rowData] - Row data
 * @property {boolean} [validate] - Validate
 * @property {object} [firmware] - Firmware
 * @property {boolean} [firmware.enable] - Enable
 * @property {string} [firmware.firmware] - Firmware path
 * @property {boolean} [firmware.secure] - Secure firmware
 * @property {object} [kernelOptions] - Kernel options
 * @property {boolean} [kernelOptions.enable] - Kernel options enable
 * @property {string} [kernelOptions.os] - Kernel OS
 * @property {object} [ramDisk] - Ram disk
 * @property {boolean} [ramDisk.enable] - Enable ram disk
 * @property {string} [ramDisk.initrd] - Init ram disk
 */

/**
 * @typedef InputDevice - Input device object
 * @property {'mouse'|'tablet'} type - Input type
 * @property {'usb'|'usb2'} bus - Input bus
 */

/**
 * @typedef InputAndOutput - Input and output object
 * @property {string} [graphics] - graphics
 * @property {string} [ip] - IP
 * @property {number} [port] - PORT
 * @property {string} [keymap] - Keymap
 * @property {string} [customKeymap] - Custom keymap
 * @property {string} [password] - Password
 * @property {boolean} [randomPassword] - Random password
 * @property {string} [command] - Init command
 * @property {InputDevice|InputDevice[]} [inputs] - Input devices
 */

/**
 * @typedef UserInput - User input object
 * @property {boolean} mandatory - Mandatory
 * @property {string} type - Type
 * @property {string} name - Name
 * @property {string} description - Description
 * @property {string} [defaultValue] - Default value
 */

/**
 * @typedef Context - Context object
 * @property {boolean} [network] - Fill automatically the networking parameters for each NIC
 * @property {boolean} [token] - Create a token.txt file for OneGate monitorization
 * @property {boolean} [report] - Report
 * @property {boolean} [autoAddSshKey] - Add ssh key automatically
 * @property {string} [sshKey] - SSH key
 * @property {string} [startScript] - Start script
 * @property {boolean} [encodeScript] - Encode base64 script
 * @property {string} [files] - Space-separated list of File images to include in context device
 * @property {string} [initScripts] - Init scripts
 * @property {object} [customVars] - Custom variables with format: {'VAR_NAME': 'VAR_VALUE'}
 * @property {UserInput|UserInput[]} [userInputs] - User inputs
 */

/**
 * @typedef SchedAction - Scheduler action object
 * @property {string} [action] - Action
 * @property {number} [time] - Time
 * @property {string} [period] - Period
 * @property {object} [periodic] - Periodic object
 * @property {string} [periodic.repeat] - Repeat
 * @property {number} [periodic.time] - Periodic time
 * @property {string} [periodic.endType] - End type (date or duration)
 */

/**
 * @typedef Placement - Placement object
 * @property {string} [hostRequirement] - Host requirement
 * @property {string} [schedRank] - Schedule rank
 * @property {string} [dsSchedRequirement] - Datastore sched requirement
 * @property {string} [dsSchedRank] - Datastore sched rank
 */

/**
 * @typedef Numa - NUMA object
 * @property {number} [vcpu] - VCPU
 * @property {string} [pinPolicy] - Pin policy
 * @property {number} [cores] - Cores
 * @property {number} [sockets] - Sockets
 * @property {number} [threads] - Threads
 * @property {string} [hugepages] - Huge pages
 * @property {string} [memoryAccess] - Memory access
 */

/**
 * @typedef VmTemplate - VM Template
 * @property {string} name - Name
 * @property {string} [hypervisor] - Hypervisor
 * @property {string} [description] - Description
 * @property {string} [logo] - Logo
 * @property {number} [memory] - Memory
 * @property {number} [memoryMax] - Max memory
 * @property {number} [cpu] - CPU
 * @property {number} [vcpu] - Virtual CPU
 * @property {number} [vcpuMax] - Max Virtual CPU
 * @property {string} [user] - owner
 * @property {string} [group] - Group
 * @property {string} [vmgroup] - VM group
 * @property {Disk|Disk[]} [storage] - storage
 * @property {Network|Network[]} [networks] - networks
 * @property {OsAndCpu} [osCpu] - OS & CPU
 * @property {InputAndOutput} [inputOutput] - Input & Output
 * @property {Context} [context] - Context
 * @property {SchedAction|SchedAction[]} [schedActions] - Schedule actions
 * @property {Placement} [placement] - Placement
 * @property {Numa} [numa] - NUMA
 */

/**
 * @typedef TemplateFromCli - TEMPLATE CLI output
 * @property {string} ID - Identifier
 * @property {object} PERMISSIONS - Permissions
 * @property {number} PERMISSIONS.OWNER_U - Owner user
 * @property {number} PERMISSIONS.OWNER_M - Owner manager
 * @property {number} PERMISSIONS.OWNER_A - Owner admin
 * @property {number} PERMISSIONS.GROUP_U - Group user
 * @property {number} PERMISSIONS.GROUP_M - Group manager
 * @property {number} PERMISSIONS.GROUP_A - Group admin
 * @property {number} PERMISSIONS.OTHER_U - Other user
 * @property {number} PERMISSIONS.OTHER_M - Other manager
 * @property {number} PERMISSIONS.OTHER_A - Other admin
 * @property {string} NAME - Name.
 * @property {string} UNAME - Owner name
 * @property {string} GNAME - Group name
 * @property {string} REGTIME - Registration time
 */

/**
 * @typedef {object} configSelectTemplate - config select template
 * @property {number} id - id template
 * @property {string} name - name template
 */

/**
 * @typedef {object} configChangeOwnership - config change ownership template
 * @property {object} templateInfo - info vm
 * @property {number} templateInfo.id - id vm
 * @property {string} templateInfo.name - name vm
 * @property {string} action - action vm
 * @property {string} value - value for change
 */

/**
 * @typedef {object} configMarket - config change lock template
 * @property {string} market - info market
 * @property {number} market.ID - id market
 * @property {string} market.NAME - name market
 * @property {string} market.MARKET_MAD - market_mad
 * @property {string} market.BASE_URL - market base url
 * @property {string} market.PUBLIC_DIR - market public dir
 */

/**
 * @typedef {object} configRDP - RDP connection options
 * @property {boolean} [disableAudio] - Disable RDP Audio
 * @property {boolean} [disableBitmap] - Disable RDP bitmap caching
 * @property {boolean} [disableGlyph] - Disable RDP glyph caching
 * @property {boolean} [disableOffscreen] - Disable RDP offscreen caching
 * @property {boolean} [enableAudioInput] - Enable RDP Audio Input
 * @property {boolean} [enableDesktopComposition] - Enable RDP desktop composition
 * @property {boolean} [enableFontSmoothing] - Enable RDP Font Smoothing
 * @property {boolean} [enableWindowDrag] - Enable RDP window drag
 * @property {boolean} [enableMenuAnimations] - Enable RDP menu animations
 * @property {boolean} [enableTheming] - Enable RDP theming
 * @property {boolean} [enableWallpaper] - Enable RDP wallpaper
 * @property {boolean} [resizeMethod] - RDP resize method
 */

export {}
