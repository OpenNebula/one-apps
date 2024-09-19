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

import { SecurityGroup } from '@models' // eslint-disable-line no-unused-vars

/**
 * @typedef ReserveLeaseTest
 * @property {'ar'|'vnet'} __switch__ - Reservation type
 * @property {string} [size] - Size
 * @property {string} [network_id] - Existing reservation
 * @property {string} [name] - Name of the new Network Virtual
 * @property {string} [arId] - Reserve from specific Address Range
 * @property {string} [addr] - First address
 */

/**
 * @typedef AddressRangeTest
 * @property {'IP4'|'IP6'|'IP6_STATIC'|'IP4_6'|'ETHER'} type - Type
 * @property {string} [ip] - IP
 * @property {string} [mac] - MAC
 * @property {string} [ip6] - IPv6
 * @property {string} [size] - Size
 * @property {string} [prefixLength] - Prefix length
 * @property {string} [globalPrefix] - Global prefix
 * @property {string} [ulaPrefix] - ULA prefix
 * @property {object} [custom] - Custom attributes
 */

/**
 * @typedef VnContextTest
 * @property {string} [address] - Network address
 * @property {string} [mask] - Network mask
 * @property {string} [gateway] - Gateway
 * @property {string} [gateway6] - IPv6 Gateway
 * @property {string} [dns] - DNS
 * @property {undefined|'dhcp'|'skip'|'static'} [method] - Method
 * @property {undefined|'dhcp'|'disable'|'skip'|'static'} [method6] - IPv6 Method
 * @property {object} [custom] - Custom attributes
 */

/**
 * @typedef VirtualNetworkTest
 * @property {string} name - Name
 * @property {string} [description] - Description
 * @property {string} [cluster] - Cluster
 * @property {'bridge'|'fw'|'ebtables'|'802.1Q'|'vxlan'|'ovswitch'|'ovswitch_vxlan'} vnMad - Driver
 * @property {string} [bridge] - Bridge
 * @property {string} [phydev] - Physical device
 * @property {boolean} [filterIpSpoofing] - Filter IP spoofing
 * @property {boolean} [filterMacSpoofing] - Filter MAC spoofing
 * @property {string} [mtu] - Maximum Transmission Unit of the interface
 * @property {boolean} [automaticVlanId] - Automatic VLAN id
 * @property {string} [vlanId] - VLAN id
 * @property {boolean} [automaticOuterVlanId] - Automatic Outer VLAN id
 * @property {string} [outerVlanId] - Outer VLAN id
 * @property {'evpn'|'multicast'} [vxlanMode] - VXLAN mode
 * @property {'dev'|'local_ip'} [vxlanTep] - VXLAN tunnel endpoint
 * @property {string} [vxlanMc] - VXLAN multicast
 * @property {AddressRangeTest[]} [ranges] - Address Ranges
 * @property {SecurityGroup|SecurityGroup[]} [sg] - Security Group
 * @property {string|number} [inboundAvgBw] - Average bandwidth for Inbound traffic
 * @property {string|number} [inboundPeakBw] - Peak bandwidth for Inbound traffic
 * @property {string|number} [inboundPeakKb] - Peak burst for Inbound traffic
 * @property {string|number} [outboundAvgBw] - Average bandwidth for Outbound traffic
 * @property {string|number} [outboundPeakBw] - Peak bandwidth for Outbound traffic
 * @property {string|number} [outboundPeakKb] - Peak burst for Outbound traffic
 * @property {VnContextTest} [context] - Context
 */
