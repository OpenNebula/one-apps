#!/usr/bin/env bash

# ---------------------------------------------------------------------------- #
# Copyright 2018-2022, OpenNebula Project, OpenNebula Systems                  #
#                                                                              #
# Licensed under the Apache License, Version 2.0 (the "License"); you may      #
# not use this file except in compliance with the License. You may obtain      #
# a copy of the License at                                                     #
#                                                                              #
# http://www.apache.org/licenses/LICENSE-2.0                                   #
#                                                                              #
# Unless required by applicable law or agreed to in writing, software          #
# distributed under the License is distributed on an "AS IS" BASIS,            #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.     #
# See the License for the specific language governing permissions and          #
# limitations under the License.                                               #
# ---------------------------------------------------------------------------- #

# Important notes #############################################################
#
#
# **********************
# * Context parameters *
# **********************
#
# [DNS]
#
# ONEAPP_VNF_DNS_ALLOWED_NETWORKS         <network>/<prefix> ...
# ONEAPP_VNF_DNS_CONFIG                   <base64>
# ONEAPP_VNF_DNS_ENABLED                  <boolean>
# ONEAPP_VNF_DNS_INTERFACES               <ip>[@<port>]|<eth>[/<ip>[@<port>]] ...
# ONEAPP_VNF_DNS_MAX_CACHE_TTL            <number>
# ONEAPP_VNF_DNS_NAMESERVERS              <ip>[@<port>] ...
# ONEAPP_VNF_DNS_TCP_DISABLED             <boolean>
# ONEAPP_VNF_DNS_UDP_DISABLED             <boolean>
# ONEAPP_VNF_DNS_UPSTREAM_TIMEOUT         <number> # msecs
# ONEAPP_VNF_DNS_USE_ROOTSERVERS          <boolean>
#
#
# [DHCP4]
#
# ONEAPP_VNF_DHCP4_<ETH>                  <network>/<prefix>:<pool-start>-<pool-end>
# ONEAPP_VNF_DHCP4_<ETH>_GATEWAY          <ip> ...
# ONEAPP_VNF_DHCP4_<ETH>_DNS              <ip> ...
# ONEAPP_VNF_DHCP4_<ETH>_MTU              <number>
# ONEAPP_VNF_DHCP4_AUTHORITATIVE          <boolean>
# ONEAPP_VNF_DHCP4_CONFIG                 <base64>
# ONEAPP_VNF_DHCP4_DNS                    <ip> ...
# ONEAPP_VNF_DHCP4_ENABLED                <boolean>
# ONEAPP_VNF_DHCP4_GATEWAY                <ip> ...
# ONEAPP_VNF_DHCP4_HOOK[0-9]              <base64-json>
# ONEAPP_VNF_DHCP4_INTERFACES             <eth>[/<ip>] ...
# ONEAPP_VNF_DHCP4_LEASE_DATABASE         <base64-json>
# ONEAPP_VNF_DHCP4_LEASE_TIME             <number>
# ONEAPP_VNF_DHCP4_LOGFILE                <filename>
# ONEAPP_VNF_DHCP4_MAC2IP_ENABLED         <boolean>
# ONEAPP_VNF_DHCP4_MAC2IP_MACPREFIX       <FF>:<FF> # e.g.: "02:00"
# ONEAPP_VNF_DHCP4_MAC2IP_SUBNETS         <network>/<prefix> ...
# ONEAPP_VNF_DHCP4_SUBNET[0-9]            <base64-json>
#
#
# [ROUTER4]
#
# ONEAPP_VNF_ROUTER4_ENABLED              <boolean>
# ONEAPP_VNF_ROUTER4_INTERFACES           <eth> ...
#
#
# [NAT4]
#
# ONEAPP_VNF_NAT4_ENABLED                 <boolean>
# ONEAPP_VNF_NAT4_INTERFACES_OUT          <eth> ...
#
#
# [SDNAT4]
#
# ONEAPP_VNF_SDNAT4_ENABLED               <boolean>
# # TODO: this is noop
# ONEAPP_VNF_SDNAT4_ONEGATE_ENABLED       <boolean>
# ONEAPP_VNF_SDNAT4_INTERFACES            <eth> ...
# ONEAPP_VNF_SDNAT4_REFRESH_RATE          <number>
# TODO:
# ONEAPP_VNF_SDNAT4_<ETH>_RULE            <ip>:<ip>
#
#
# [LB]
#
# ONEAPP_VNF_LB_ENABLED                   <boolean>
# ONEAPP_VNF_LB_ONEGATE_ENABLED           <boolean>
# ONEAPP_VNF_LB_INTERFACES                <eth> ...
# ONEAPP_VNF_LB_REFRESH_RATE              <number>
# ONEAPP_VNF_LB_FWMARK_OFFSET             <number> # must be >1 (default 10000)
# ONEAPP_VNF_LB_CONFIG                    <base64>
# ONEAPP_VNF_LB[0-9]_IP                   <ip>
# ONEAPP_VNF_LB[0-9]_PROTOCOL             TCP|UDP|BOTH # optional
# ONEAPP_VNF_LB[0-9]_PORT                 <number> # optional
# ONEAPP_VNF_LB[0-9]_METHOD               NAT|DR (default NAT)
# ONEAPP_VNF_LB[0-9]_FWMARK               <number> # optional - must be >0
# ONEAPP_VNF_LB[0-9]_TIMEOUT              <seconds> # optional (default 10s)
# ONEAPP_VNF_LB[0-9]_SCHEDULER            <alg> # default wlc
#
# ONEAPP_VNF_LB[0-9]_SERVER[0-9]_HOST
# ONEAPP_VNF_LB[0-9]_SERVER[0-9]_PORT
# ONEAPP_VNF_LB[0-9]_SERVER[0-9]_WEIGHT
# ONEAPP_VNF_LB[0-9]_SERVER[0-9]_ULIMIT
# ONEAPP_VNF_LB[0-9]_SERVER[0-9]_LLIMIT
#
# via onegate:
# ONEGATE_LB[0-9]_IP
# ONEGATE_LB[0-9]_PROTOCOL
# ONEGATE_LB[0-9]_PORT
# ONEGATE_LB[0-9]_SERVER_HOST
# ONEGATE_LB[0-9]_SERVER_PORT
# ONEGATE_LB[0-9]_SERVER_WEIGHT
# ONEGATE_LB[0-9]_SERVER_ULIMIT
# ONEGATE_LB[0-9]_SERVER_LLIMIT
#
#
# [HAPROXY]
#
# ONEAPP_VNF_HAPROXY_ENABLED              <boolean>
# ONEAPP_VNF_HAPROXY_ONEGATE_ENABLED      <boolean>
# ONEAPP_VNF_HAPROXY_INTERFACES           <eth> ...
# ONEAPP_VNF_HAPROXY_REFRESH_RATE         <number>
# ONEAPP_VNF_HAPROXY_CONFIG               <base64>
# ONEAPP_VNF_HAPROXY_LB[0-9]_IP           <ip>
# ONEAPP_VNF_HAPROXY_LB[0-9]_PORT         <number> # optional
#
# ONEAPP_VNF_HAPROXY_LB[0-9]_SERVER[0-9]_HOST
# ONEAPP_VNF_HAPROXY_LB[0-9]_SERVER[0-9]_PORT
#
# via onegate:
# ONEGATE_HAPROXY_LB[0-9]_IP
# ONEGATE_HAPROXY_LB[0-9]_PORT
# ONEGATE_HAPROXY_LB[0-9]_SERVER_HOST
# ONEGATE_HAPROXY_LB[0-9]_SERVER_PORT
#
#
# [KEEPALIVED]
#
# ONEAPP_VNF_KEEPALIVED_ENABLED           <boolean>
# ONEAPP_VNF_KEEPALIVED_INTERFACES        <eth> ...
# ONEAPP_VNF_KEEPALIVED_INTERVAL          <float>
# ONEAPP_VNF_KEEPALIVED_PASSWORD          <pass> # must be under 8 characters
# ONEAPP_VNF_KEEPALIVED_PRIORITY          <number>
# ONEAPP_VNF_KEEPALIVED_VRID              <1-255>
# ONEAPP_VNF_KEEPALIVED_<ETH>_INTERVAL    <float>
# ONEAPP_VNF_KEEPALIVED_<ETH>_PASSWORD    <pass> # must be under 8 characters
# ONEAPP_VNF_KEEPALIVED_<ETH>_PRIORITY    <number>
# ONEAPP_VNF_KEEPALIVED_<ETH>_VRID        <1-255>
#
#
# [VROUTER]
#
# ONEAPP_VROUTER_<ETH>_MANAGEMENT         <boolean>
# ONEAPP_VROUTER_<ETH>_VIP[0-9]           <ip>
#
#
# [OLD VROUTER]
#
# VROUTER_ID                              <number>
# VROUTER_KEEPALIVED_ID                   <number>
# VROUTER_KEEPALIVED_PASSWORD             <pass>
# <ETH>_VROUTER_IP                        <ip>
# <ETH>_VROUTER_MANAGEMENT                <boolean>
#
#
# *****************************
# * Loopback interface ('lo') *
# *****************************
#
# Using the loopback ('lo') as a VNF interface is tricky - this summarize it:
#
# ROUTER:
#   enabling forwarding on the loopback should not affect anything because of
#   the way iptables works - that means that this:
#     net.ipv4.conf.lo.forwarding = 1
#   does nothing - at least according to this great guide:
#       https://www.frozentux.net/iptables-tutorial/chunkyhtml/c962.html
#   (if I understood it properly) and as I verified it by tests. So it is not
#   used at all - lo forwarding is implicitly zero if not explicitly requested
#   by the user.
#
# KEEPALIVED:
#   there is no sense or means to run vrrp instance on the loopback... That
#   means that 'lo' is simply skipped/ignored.
#
# DNS:
#   'lo' is enabled by default if DNS is enabled - so 'lo' in interfaces does
#   not change the fact.
#
# DHCP4:
#   if the loopback is used as of one the interfaces then subnet is configured
#   accordingly - it will provide leases for the loopback address range
#   (127.0.0.0/8 if not specified in more detail).
#
# NAT4:
#   loopback can be used as a NAT interface too although the use-case can be
#   very specific if useful at all...
#
# Important notes #############################################################


### ShellCheck ################################################################

# shellcheck disable=SC1091
# shellcheck disable=SC2086
# shellcheck disable=SC2059
true

# these exports are unnecessary but it makes ShellCheck happy...

export ONE_SERVICE_NAME
export ONE_SERVICE_VERSION
export ONE_SERVICE_DESCRIPTION
export ONE_SERVICE_SHORT_DESCRIPTION
export ONE_SERVICE_BUILD
export ONE_SERVICE_PARAMS
export ONE_SERVICE_RECONFIGURABLE

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


# List of contextualization parameters
ONE_SERVICE_PARAMS=(
    'ONEAPP_VNF_ROUTER4_ENABLED'            'configure' 'ROUTER4 Enable IPv4 routing service'                               'O|boolean'
    'ONEAPP_VNF_ROUTER4_INTERFACES'         'configure' 'ROUTER4 Managed interfaces (default: all)'                         'O|text'
    'ONEAPP_VNF_NAT4_ENABLED'               'configure' 'NAT4 Enable network address translation'                           'O|boolean'
    'ONEAPP_VNF_NAT4_INTERFACES_OUT'        'configure' 'NAT4 External/outgoing interfaces for NAT (default: none)'         'O|text'
    'ONEAPP_VNF_DNS_ENABLED'                'configure' 'DNS Enable recursor service'                                       'O|boolean'
    'ONEAPP_VNF_DNS_INTERFACES'             'configure' 'DNS Listening interfaces (default: all)'                           'O|text'
    'ONEAPP_VNF_DNS_CONFIG'                 'configure' 'DNS Full Unbound config in base64'                                 'O|boolean'
    'ONEAPP_VNF_DNS_USE_ROOTSERVERS'        'configure' 'DNS Directly use root name servers (default: true)'                'O|boolean'
    'ONEAPP_VNF_DNS_NAMESERVERS'            'configure' 'DNS Upstream nameservers to forward queries'                       'O|text'
    'ONEAPP_VNF_DNS_ALLOWED_NETWORKS'       'configure' 'DNS Allowed client networks to make queries'                       'O|text'
    'ONEAPP_VNF_DNS_UPSTREAM_TIMEOUT'       'configure' 'DNS Upstream nameservers connection timeout (msecs)'               'O|number'
    'ONEAPP_VNF_DNS_MAX_CACHE_TTL'          'configure' 'DNS Maximum caching time (secs)'                                   'O|number'
    'ONEAPP_VNF_DNS_TCP_DISABLED'           'configure' 'DNS Disable TCP protocol'                                          'O|boolean'
    'ONEAPP_VNF_DNS_UDP_DISABLED'           'configure' 'DNS Disable UDP protocol'                                          'O|boolean'
    'ONEAPP_VNF_KEEPALIVED_ENABLED'         'configure' 'KEEPALIVED Enable vrouter service'                                 'O|boolean'
    'ONEAPP_VNF_KEEPALIVED_INTERFACES'      'configure' 'KEEPALIVED Managed interfaces (default: all)'                      'O|text'
    'ONEAPP_VNF_KEEPALIVED_PASSWORD'        'configure' 'KEEPALIVED Global vrouter password'                                'O|boolean'
    'ONEAPP_VNF_KEEPALIVED_INTERVAL'        'configure' 'KEEPALIVED Global advertising interval (secs)'                     'O|float'
    'ONEAPP_VNF_KEEPALIVED_PRIORITY'        'configure' 'KEEPALIVED Global vrouter priority'                                'O|number'
    'ONEAPP_VNF_KEEPALIVED_VRID'            'configure' 'KEEPALIVED Global vrouter id (1-255)'                              'O|number'
    'ONEAPP_VNF_DHCP4_ENABLED'              'configure' 'DHCP4 Enable service'                                              'O|boolean'
    'ONEAPP_VNF_DHCP4_INTERFACES'           'configure' 'DHCP4 Listening interfaces (default: all)'                         'O|text'
    'ONEAPP_VNF_DHCP4_CONFIG'               'configure' 'DHCP4 Full ISC Kea config in base64 JSON'                          'O|text'
    'ONEAPP_VNF_DHCP4_DNS'                  'configure' 'DHCP4 Global default nameservers'                                  'O|text'
    'ONEAPP_VNF_DHCP4_GATEWAY'              'configure' 'DHCP4 Global default gateway/routers'                              'O|text'
    'ONEAPP_VNF_DHCP4_AUTHORITATIVE'        'configure' 'DHCP4 Server authoritativity (default: true)'                      'O|boolean'
    'ONEAPP_VNF_DHCP4_LEASE_TIME'           'configure' 'DHCP4 Lease time in seconds'                                       'O|number'
    'ONEAPP_VNF_DHCP4_LEASE_DATABASE'       'configure' 'DHCP4 Lease database in base64 JSON'                               'O|text'
    'ONEAPP_VNF_DHCP4_LOGFILE'              'configure' 'DHCP4 Log filename'                                                'O|text'
    'ONEAPP_VNF_DHCP4_SUBNET'               'configure' 'DHCP4 Subnet definition(s) in base64 JSON'                         'O|text'
    'ONEAPP_VNF_DHCP4_HOOK'                 'configure' 'DHCP4 Hook definition(s) in base64 JSON'                           'O|text'
    'ONEAPP_VNF_DHCP4_MAC2IP_ENABLED'       'configure' 'DHCP4 Enable hook for MAC-to-IP DHCP lease (default: true)'        'O|boolean'
    'ONEAPP_VNF_DHCP4_MAC2IP_MACPREFIX'     'configure' 'DHCP4 HW/MAC address prefix for MAC-to-IP hook (default: 02:00)'   'O|text'
    'ONEAPP_VNF_DHCP4_MAC2IP_SUBNETS'       'configure' 'DHCP4 List of subnets for MAC-to-IP hook'                          'O|text'
)

# Control variables
ONE_SERVICE_RECONFIGURABLE=true


### Appliance metadata ########################################################

ONE_SERVICE_NAME='Service VNF - KVM'
ONE_SERVICE_VERSION=latest
ONE_SERVICE_VERSION_VNF_DHCP4=2.2.0
ONE_SERVICE_BUILD=$(date +%s)
ONE_SERVICE_SHORT_DESCRIPTION='VNF Appliance for KVM hosts'
ONE_SERVICE_DESCRIPTION=$(cat <<EOF
VNF Appliance providing multiple of VNFs.

Initial configuration can be customized via parameters:

$(params2md 'configure')

**[DHCP4 VNF]**

This VNF provide the dhcp service via [ISC Kea](https://www.isc.org/kea/)
software suite (version \`${ONE_SERVICE_VERSION_VNF_DHCP4}\`).

If you don't provide any context then some sensible default will be used.
Basically dhcp server will serve on every interface for all subnets associated
with the appliance.

If parameter supports multiple of values then they are separated by spaces,
e.g.:

\`\`\`
ONEAPP_VNF_DHCP4_INTERFACES="eth1 eth2 eth3"
\`\`\`

If you wish to have a full control over this VNF then you can provide the
complete configuration via \`ONEAPP_VNF_DHCP4_CONFIG\`. It must be a valid ISC
Kea config file (JSON) encoded in base64. How to create one take a look in the
[documentation](https://kea.readthedocs.io/en/v$(printf \
"${ONE_SERVICE_VERSION_VNF_DHCP4}" | tr '.' '_')/arm/dhcp4-srv.html).

The most important context variable is the \`ONEAPP_VNF_DHCP4_INTERFACES\`.
Firstly it will determine on which interface it will listen for dhcp requests
and secondly it will determine for which subnets it will provide leases (if no
\`ONEAPP_VNF_DHCP4_SUBNET\` is provided) - it will auto-generate subnet lease
configuration.

The value can be either just an interface name (like \`eth0\`) or with appended
IP address (e.g.: \`eth0/192.168.1.1\`) to pinpoint the listening address and
subnet leases - if more than one address is used on the interface and each is
in a different subnet (you can use one interface more than once if IPs will
differ: \`eth0/192.168.1.1\` \`eth0/10.0.0.1\`).

For more tailored subnet configuration you can use \`ONEAPP_VNF_DHCP4_SUBNET\`
context variables (you can use more than one by adding numbering:
\`ONEAPP_VNF_DHCP4_SUBNET0\`). The value here must be a valid JSON
[configuration](https://kea.readthedocs.io/en/v1_6_0/arm/dhcp4-srv.html#configuration-of-ipv4-address-pools)
for ISC Kea subnet4 and the result must be base64 encoded.

DHCP4 also recognizes dynamic context. parameters - they are searched and
applied based on the interfaces in \`ONEAPP_VNF_DHCP4_INTERFACES\` variable.

For example: if we defined \`eth0\` as a one of the listening interfaces then
the following is also recognized as contextualization parameters:

\`\`\`
    ONEAPP_VNF_DHCP4_ETH0=<cidr subnet>:<start ip>-<end ip>
    ONEAPP_VNF_DHCP4_ETH0_DNS=<ip> ...
    ONEAPP_VNF_DHCP4_ETH0_GATEWAY=<ip> ...
    ONEAPP_VNF_DHCP4_ETH0_MTU=<number>
\`\`\`

**NOTE**: Subnets defined by \`ONEAPP_VNF_DHCP4_SUBNET*\` params take
precedence over \`ONEAPP_VNF_DHCP4_<IFACE>*\` params - so if you define even
one \`ONEAPP_VNF_DHCP4_SUBNET\` then only these subnets will be configured.

**BEWARE: Because this appliance allows reconfiguration some previously defined
variables will be still respected! This can pose a problem if for example a
\`ONEAPP_VNF_DHCP4_SUBNET0\` was defined already but now you wish to use
dynamic per interface \`ONEAPP_VNF_DHCP4_<IFACE>*\` variables. In that case you
must also provide an override for the old \`ONEAPP_VNF_DHCP4_SUBNET0\`
variable...simply set it empty: \`ONEAPP_VNF_DHCP4_SUBNET0=""\`.**

The DHCP4 VNF also provides other contextualization parameters among which is
the prominent **onelease** hook (\`ONEAPP_VNF_DHCP4_MAC2IP_ENABLED\`). It
serves a simple purpose of leasing IP addresses to OpenNebula's VMs matching
their HW/MAC addresses (check the \`ONEAPP_VNF_DHCP4_MAC2IP_MACPREFIX\` param
to be in line with OpenNebula's generated MAC addresses). This behavior is by
default enabled - if you wish to disable it then just simply set
\`ONEAPP_VNF_DHCP4_MAC2IP_ENABLED\` to \`false\`.

EOF
)


### Contextualization defaults ################################################

ONEAPP_VNF_DHCP4_AUTHORITATIVE="${ONEAPP_VNF_DHCP4_AUTHORITATIVE:-true}"
ONEAPP_VNF_DHCP4_LEASE_TIME="${ONEAPP_VNF_DHCP4_LEASE_TIME:-3600}"
ONEAPP_VNF_DHCP4_LOGFILE="${ONEAPP_VNF_DHCP4_LOGFILE:-/var/log/kea/kea-dhcp4.log}"
ONEAPP_VNF_DHCP4_MAC2IP_ENABLED="${ONEAPP_VNF_DHCP4_MAC2IP_ENABLED:-true}"
ONEAPP_VNF_KEEPALIVED_INTERVAL="${ONEAPP_VNF_KEEPALIVED_INTERVAL:-1}"
ONEAPP_VNF_KEEPALIVED_PRIORITY="${ONEAPP_VNF_KEEPALIVED_PRIORITY:-100}"
ONEAPP_VNF_KEEPALIVED_VRID="${ONEAPP_VNF_KEEPALIVED_VRID:-1}"
ONEAPP_VNF_DNS_UPSTREAM_TIMEOUT="${ONEAPP_VNF_DNS_UPSTREAM_TIMEOUT:-1128}"
ONEAPP_VNF_DNS_MAX_CACHE_TTL="${ONEAPP_VNF_DNS_MAX_CACHE_TTL:-3600}"
ONEAPP_VNF_DNS_USE_ROOTSERVERS="${ONEAPP_VNF_DNS_USE_ROOTSERVERS:-true}"
ONEAPP_VNF_DHCP4_MAC2IP_MACPREFIX="${ONEAPP_VNF_DHCP4_MAC2IP_MACPREFIX:-02:00}"
ONEAPP_VNF_SDNAT4_REFRESH_RATE="${ONEAPP_VNF_SDNAT4_REFRESH_RATE:-30}"
ONEAPP_VNF_SDNAT4_ONEGATE_ENABLED="${ONEAPP_VNF_SDNAT4_ONEGATE_ENABLED:-true}"
ONEAPP_VNF_LB_REFRESH_RATE="${ONEAPP_VNF_LB_REFRESH_RATE:-30}"
ONEAPP_VNF_LB_ONEGATE_ENABLED="${ONEAPP_VNF_LB_ONEGATE_ENABLED:-false}"
ONEAPP_VNF_LB_FWMARK_OFFSET="${ONEAPP_VNF_LB_FWMARK_OFFSET:-10000}"
ONEAPP_VNF_HAPROXY_REFRESH_RATE="${ONEAPP_VNF_HAPROXY_REFRESH_RATE:-30}"
ONEAPP_VNF_HAPROXY_ONEGATE_ENABLED="${ONEAPP_VNF_HAPROXY_ONEGATE_ENABLED:-false}"

### Globals ###################################################################

DEP_PKGS="\
    coreutils \
    openssh-server \
    curl \
    jq \
    openssl \
    ca-certificates \
    bind-tools \
    boost \
    postgresql-client \
    mariadb-client \
    mariadb-connector-c \
    cassandra-cpp-driver \
    xz \
    procps \
    py3-psutil \
    unbound \
    keepalived \
    iptables \
    ip6tables \
    logrotate \
    ipvsadm \
    libcap \
    dns-root-hints \
    ruby-concurrent-ruby \
    fping \
    "

ALL_SUPPORTED_VNF_NAMES="\
    DHCP4
    ROUTER4
    DNS
    KEEPALIVED
    NAT4
    SDNAT4
    LB
    HAPROXY
    "

# leave these empty
ENABLED_VNF_LIST=
DISABLED_VNF_LIST=
UPDATED_VNF_LIST=
ETH_TRIPLETS=

# Runing Alpine version
ALPINE_VERSION=$(. /etc/os-release ; \
    echo "${VERSION_ID}" | awk 'BEGIN{FS="."}{print $1 "." $2;}')

# ONE VNF service
ONE_VNF_OPENRC_NAME="one-vnf"
ONE_VNF_PIDFILE="/run/one-vnf.pid"
ONE_VNF_SERVICE_SCRIPT="/opt/one-appliance/lib/one-vnf/one-vnf.rb"
ONE_VNF_SERVICE_CONFIG="/opt/one-appliance/etc/one-vnf-config.js"

# TODO: refactor these variable names to VNF_DHCP4_*
# onekea installation directory
ONEKEA_PREFIX="/usr"

# onekea version
ONEKEA_VERSION="${ONE_SERVICE_VERSION_VNF_DHCP4:-2.2.0}"
ONEKEA_ONELEASE4_VERSION="1.1.1-r0"

# onekea artifact filename
ONEKEA_ARTIFACT="onekea-${ONEKEA_VERSION}/kea-hook-onelease4-${ONEKEA_ONELEASE4_VERSION}.apk"

# onekea library artifact filename
ONEKEA_ARTIFACT_LIBHOOK_LEASE="libkea-onelease-dhcp4.so"

# VNF DHCP4 specifics
ONEKEA_DHCP4_CONFIG="/etc/kea/kea-dhcp4.conf"
ONEKEA_DHCP6_CONFIG="/etc/kea/kea-dhcp6.conf"
ONEKEA_DHCP4_CONFIG_TEMP="/etc/kea/kea-dhcp4.conf-new"
ONEKEA_DHCP4_LOGROTATE="/etc/logrotate.d/onekea"

ONEKEA_DHCP4_PIDFILE="/run/kea-dhcp4.pid"
ONEKEA_DHCP6_PIDFILE="/run/kea-dhcp6.pid"

# VNF ROUTER4 specifics
VNF_ROUTER4_SYSCTL="/etc/sysctl.d/01-one-router4.conf"

# VNF KEEPALIVED specifics
VNF_KEEPALIVED_CONFIG_DIR="/etc/keepalived/"
VNF_KEEPALIVED_CONFIG="${VNF_KEEPALIVED_CONFIG_DIR}/keepalived.conf"
VNF_KEEPALIVED_NOTIFY_SCRIPT="/etc/keepalived/ha-failover.sh"
VNF_KEEPALIVED_NOTIFY_LOGROTATE="/etc/logrotate.d/ha-failover"
VNF_KEEPALIVED_HA_STATUS_SCRIPT="/etc/keepalived/ha-check-status.sh"
VNF_KEEPALIVED_PIDFILE="/run/keepalived.pid"

# VNF DNS specifics
VNF_DNS_CONFIG="/etc/unbound/unbound.conf"
VNF_DNS_CONFIG_TEMP="/etc/unbound/unbound.conf-new"
VNF_DNS_PIDFILE="/run/one-unbound.pid"
VNF_DNS_OPENRC_NAME="one-unbound"

# VNF NAT4 specifics
VNF_NAT4_OPENRC_NAME="one-nat4"
VNF_NAT4_IPTABLES_RULES="/etc/iptables/nat4-rules"

# VNF SDNAT4 specifics
#VNF_SDNAT4_IPTABLES_RULES="/etc/iptables/sdnat4-rules"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


#
# service implementation
#

service_cleanup()
{
    rm -f "$ONEKEA_DHCP4_CONFIG_TEMP"
}

service_install()
{
    # packages
    install_pkgs ${DEP_PKGS}

    # fix open-rc - start crashed services
    install_openrc_config

    # install one-vnf service
    install_one_vnf_service

    # fix sshd
    enable_ssh_forwarding

    # VNFs

    # VNF DHCP
    install_dhcp
    install_onekea_hooks

    # VNF DNS
    install_dns

    # VNF NAT
    install_nat

    # VNF KEEPALIVED
    install_keepalived

    # VNF HAPROXY
    install_haproxy

    # VNF TOOLS
    install_tools

    # disable all VNFs
    # NOTE: using workaround for failing ruby in packer/qemu:
    # qemu: /usr/lib/ruby/2.7.0/rubygems/core_ext/kernel_require.rb:83:in `require': cannot load such file -- json (LoadError)
    # (probably due to C extensions with json??)
    _SKIP_ONE_VNF=YES stop_and_disable_vnfs "$ALL_SUPPORTED_VNF_NAMES"
    _SKIP_ONE_VNF=''

    # service metadata
    create_one_service_metadata

    # cleanup
    postinstall_cleanup

    msg info "INSTALLATION FINISHED"

    return 0
}

service_configure()
{
    #
    # Initialization
    #

    msg info '============================='
    msg info '=== CONFIGURATION STARTED ==='
    msg info '============================='

    # load last context state
    load_context

    # workaround for mismatch in user designated interfaces, one context and
    # actual interfaces on the system...
    make_eth_triplets

    # reintroduce vrouter variables as ONEAPP variables...
    # - some just for compatibility reasons with the original vrouter
    # - rest of the variables affect more or all VNFs
    #
    # NOTE: NICs and networking changes affect basically all...
    #
    # BEWARE: the original vrouter variables will always take precedence over
    # their ONEAPP_ alternatives (to avoid confusing the users using sunstone
    # UI which still supports original vrouter)...
    load_vrouter_variables

    # comb and sort multivalue variables
    assort_multivalue_variables

    # decide which VNFs will be enabled/disabled
    sortout_vnfs

    #
    # VNFs Specific Configuration
    #

    # VNF ROUTER4
    configure_router4

    # VNF KEEPALIVED
    configure_keepalived

    # VNF DHCP4
    configure_dhcp4

    # VNF DNS
    configure_dns

    # VNF NAT4
    configure_nat4

    # VNF SDNAT4
    configure_sdnat4

    # VNF LB
    configure_lb

    # VNF HAPROXY
    configure_haproxy

    #
    # Finalization
    #

    # save the current context
    save_context

    # enable/disable VNFs
    toggle_vnfs

    # store credentials
    report_config

    msg info "--- CONFIGURATION FINISHED ---"

    return 0
}

service_bootstrap()
{
    msg info "BOOTSTRAP FINISHED"

    return 0
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


#
# functions
#

postinstall_cleanup()
{
    msg info "Delete cache and stored packages"
    apk cache clean || true
    rm -rf /var/cache/apk/*

    msg info "Remove artifact directory: ${ONE_SERVICE_SETUP_DIR}/vnf"
    rm -rf "${ONE_SERVICE_SETUP_DIR}/vnf"
}

install_pkgs()
{
    msg info "Fix repositories file"
    _alpine_version=$(sed -n \
        's/[[:space:]]*VERSION_ID=\([0-9]\+\.[0-9]\+\).*/\1/p' \
        /etc/os-release)

    cat > /etc/apk/repositories <<EOF
http://dl-cdn.alpinelinux.org/alpine/v${_alpine_version}/main
http://dl-cdn.alpinelinux.org/alpine/v${_alpine_version}/community

#http://dl-cdn.alpinelinux.org/alpine/edge/main
#http://dl-cdn.alpinelinux.org/alpine/edge/community
#http://dl-cdn.alpinelinux.org/alpine/edge/testing
EOF
    msg info "Install required packages"
    if ! { apk update && apk upgrade && apk add --no-cache "${@}" ; } ; then
        msg error "Package(s) installation failed"
        exit 1
    fi
}

install_openrc_config()
{
    msg info "Backup the original Open-RC configuration file to: /etc/rc.conf~onesave"
    cp -a "/etc/rc.conf" "/etc/rc.conf~onesave"

    msg info "Setup Open-RC: /etc/rc.conf"
    cat > /etc/rc.conf <<EOF
# Global OpenRC configuration settings

# rc will attempt to start crashed services by default.
#rc_crashed_stop=YES
rc_crashed_start=YES

# on Linux and Hurd, this is the number of ttys allocated for logins
# It is used in the consolefont, keymaps, numlock and termencoding
# service scripts.
rc_tty_number=12
EOF
}

install_one_vnf_service()
{
    msg info "Install '${ONE_VNF_OPENRC_NAME}' service: /etc/init.d/${ONE_VNF_OPENRC_NAME}"

    cat > "/etc/init.d/${ONE_VNF_OPENRC_NAME}" <<EOF
#!/sbin/openrc-run

# following the good practices described here:
# https://github.com/OpenRC/openrc/blob/master/service-script-guide.md

name="${ONE_VNF_OPENRC_NAME}"
description="ONE-VNF is a provider of a dynamic VNFs (re)configuration"

configfile='${ONE_VNF_SERVICE_CONFIG}'

command="${ONE_VNF_SERVICE_SCRIPT}"
command_args="-c '\${configfile}'"
command_background="yes"
command_user="root:root"
pidfile="${ONE_VNF_PIDFILE}"

start_stop_daemon_args="
    --wait 120
    \$start_stop_daemon_args"

extra_commands="reload"

depend() {
    after firewall
    use logger
}

reload() {
    ebegin "Reloading \${RC_SVCNAME}"
    start-stop-daemon --signal HUP --pidfile "\${pidfile}"
    eend \$?
}

EOF

    chmod 0755 "/etc/init.d/${ONE_VNF_OPENRC_NAME}"

    # install the actual service script
    mkdir -p /opt/one-appliance/lib
    mv -v "${ONE_SERVICE_SETUP_DIR}/vnf/one-vnf" /opt/one-appliance/lib/
    chmod 0755 "${ONE_VNF_SERVICE_SCRIPT}"

    msg info "Enable the '${ONE_VNF_OPENRC_NAME}' service on start"
    rc-update add "${ONE_VNF_OPENRC_NAME}"

    msg info "Create the initial '${ONE_VNF_OPENRC_NAME}' config: ${ONE_VNF_SERVICE_CONFIG}"
    _config_dir=$(dirname "${ONE_VNF_SERVICE_CONFIG}")
    mkdir -p "${_config_dir}"
    echo '{}' | jq . > "${ONE_VNF_SERVICE_CONFIG}"
    chmod 0644 "${ONE_VNF_SERVICE_CONFIG}"
}

enable_ssh_forwarding()
{
    sed -i '/^[[:space:]]*AllowTcpForwarding/d' /etc/ssh/sshd_config
    sed -i '/^[[:space:]]*AllowAgentForwarding/d' /etc/ssh/sshd_config

    echo 'AllowTcpForwarding yes' >> /etc/ssh/sshd_config
    echo 'AllowAgentForwarding yes' >> /etc/ssh/sshd_config
}

# TODO: aliases - deduplicate code by implicating that ETH0_IP is
# ETH0_ALIAS_IP...this should be implemented everywhere where geth* is used
#   ETH0_ALIAS0_CONTEXT_FORCE_IPV4 = "",
#   ETH0_ALIAS0_DNS = "192.168.101.1",
#   ETH0_ALIAS0_EXTERNAL = "",
#   ETH0_ALIAS0_GATEWAY = "192.168.101.1",
#   ETH0_ALIAS0_GATEWAY6 = "",
#   ETH0_ALIAS0_IP = "192.168.101.100",
#   ETH0_ALIAS0_IP6 = "",
#   ETH0_ALIAS0_IP6_PREFIX_LENGTH = "",
#   ETH0_ALIAS0_IP6_ULA = "",
#   ETH0_ALIAS0_MAC = "02:00:c0:a8:65:64",
#   ETH0_ALIAS0_MASK = "255.255.255.0",
#   ETH0_ALIAS0_MTU = "",
#   ETH0_ALIAS0_NETWORK = "",
#   ETH0_ALIAS0_SEARCH_DOMAIN = "",
#   ETH0_ALIAS0_VLAN_ID = "41",
#   ETH0_ALIAS0_VROUTER_IP = "",
#   ETH0_ALIAS0_VROUTER_IP6 = "",
#   ETH0_ALIAS0_VROUTER_MANAGEMENT = "",
load_vrouter_variables()
{
    msg info "Try to load original vrouter's parameters if used"

    # TODO: alias (improve this)
    # TODO: IPv6
    # These changes the character of the network and affects basically
    # everything...we record them and track their changes
    #
    # PART 1:
    # reset all variables relevant to removed NIC (unset would mask the change
    # and script would not be able recognize that any change to NIC happened)
    _recorded_eths=$(env | \
        sed -n 's/^ONEAPP_VROUTER_\(ETH[0-9]\+\)_.*/\1/p' | sort -u)
    for _recorded_eth in ${_recorded_eths} ; do
        _recorded_aliases=$(env | \
            sed -n "s/^ONEAPP_VROUTER_${_recorded_eth}_\(ALIAS[0-9]\+\)_.*/\1/p" | \
            sort -u)

        _eth=$(geth1 "${_recorded_eth}" 1)
        if [ -z "$_eth" ] ; then
            # unset
            for _item in IP MASK MAC DNS GATEWAY MTU ; do
                msg info "RESET: ONEAPP_VROUTER_${_recorded_eth}_${_item}"
                eval "ONEAPP_VROUTER_${_recorded_eth}_${_item}=''"
                eval "export ONEAPP_VROUTER_${_recorded_eth}_${_item}"

                # interface is gone so we erase all aliases for it
                for _recorded_alias in ${_recorded_aliases} ; do
                    msg info "RESET: ONEAPP_VROUTER_${_recorded_eth}_${_recorded_alias}_${_item}"
                    eval "ONEAPP_VROUTER_${_recorded_eth}_${_recorded_alias}_${_item}=''"
                    eval "export ONEAPP_VROUTER_${_recorded_eth}_${_recorded_alias}_${_item}"
                done
            done
        else
            # interface is still there but alias does not have to be
            for _item in IP MASK MAC DNS GATEWAY MTU ; do
                for _recorded_alias in ${_recorded_aliases} ; do
                    _value=$(eval "printf \"\$${_eth}_${_recorded_alias}_${_item}\"")
                    if [ -z "$_value" ] ; then
                        msg info "RESET: ONEAPP_VROUTER_${_eth}_${_recorded_alias}_${_item}"
                        eval "ONEAPP_VROUTER_${_eth}_${_recorded_alias}_${_item}=''"
                        eval "export ONEAPP_VROUTER_${_eth}_${_recorded_alias}_${_item}"
                    fi
                done
            done
        fi
    done

    # old vrouter's context variables, e.g.:
    #   VROUTER_ID:
    #       noop
    #   VROUTER_KEEPALIVED_ID:
    #       It serves as a default if ONEAPP_VNF_KEEPALIVED_<ETH?>_VRID are
    #       absent
    #   VROUTER_KEEPALIVED_PASSWORD:
    #       Equivalent to ONEAPP_VNF_KEEPALIVED_PASSWORD
    #   ETH?_VROUTER_IP:
    #       Is tied closely with Keepalived VNF (it implements it) but also it
    #       affects all other VNFs (it exposes their function on this VIP)
    #   ETH?_VROUTER_IP6:
    #       TODO
    #   ETH?_VROUTER_MANAGEMENT:
    #       this is VNF agnostic, can be overruled by VNF specific interfaces
    #       variable (like ONEAPP_VNF_<?>_INTERFACES)

    for _eth in $(get_eths) ; do
        # these variables affects some or all VNFs:
        #
        #   ETH0_CONTEXT_FORCE_IPV4=
        #   ETH0_DNS=8.8.8.8
        #   ETH0_GATEWAY6=
        #   ETH0_GATEWAY=192.168.122.1
        #   ETH0_IP6=
        #   ETH0_IP6_PREFIX_LENGTH=
        #   ETH0_IP6_ULA=
        #   ETH0_IP=192.168.122.10
        #   ETH0_MAC=02:00:c0:a8:7a:0a
        #   ETH0_MASK=255.255.255.0
        #   ETH0_MTU=
        #   ETH0_NETWORK=192.168.122.0
        #   ETH0_SEARCH_DOMAIN=
        #   ETH0_VLAN_ID=
        #   ETH0_VROUTER_IP6=
        #   ETH0_VROUTER_IP=
        #   ETH0_VROUTER_MANAGEMENT=

        # some of these are irrelevant (as of now) for any VNF but most of them
        # affect directly or indirectly some or all VNFs - we will record their
        # values so we can compare them in the future; by doing that we will
        # know what VNFs need to be reconfigured...

        # VROUTER_MANAGEMENT
        _management=$(eval "printf \"\$${_eth}_VROUTER_MANAGEMENT\"")
        # inject a new context variable into the environment
        eval "ONEAPP_VROUTER_$(geth3 ${_eth} 1)_MANAGEMENT='${_management}'"
        eval "export ONEAPP_VROUTER_$(geth3 ${_eth} 1)_MANAGEMENT"
        msg info "INJECTED: ONEAPP_VROUTER_$(geth3 ${_eth} 1)_MANAGEMENT =" \
            "$_management"

        # TODO: IPv6
        # VROUTER_IP
        _vip=$(eval "printf \"\$${_eth}_VROUTER_IP\"")
        # inject a new context variable into the environment
        eval "ONEAPP_VROUTER_$(geth3 ${_eth} 1)_VIP='${_vip}'"
        eval "export ONEAPP_VROUTER_$(geth3 ${_eth} 1)_VIP"
        msg info "INJECTED: ONEAPP_VROUTER_$(geth3 ${_eth} 1)_VIP =" \
            "$_vip"

        # TODO: IPv6
        # These changes the character of the network and affects basically
        # everything...we record them and track their changes
        #
        # PART 2:
        # update the variables with the actual values
        for _item in IP MASK MAC DNS GATEWAY MTU ; do
            _value=$(eval "printf \"\$${_eth}_${_item}\"")
            # inject and record a new context variable into the environment
            eval "ONEAPP_VROUTER_$(geth3 ${_eth} 1)_${_item}='${_value}'"
            eval "export ONEAPP_VROUTER_$(geth3 ${_eth} 1)_${_item}"
            msg info "SAVED: ${_eth}_${_item} as ONEAPP_VROUTER_$(geth3 ${_eth} 1)_${_item} =" \
                "$_value"

            # TODO: alias (improve this)
            # and the same for aliases
            _aliases=$(env | \
                sed -n "s/^${_eth}_\(ALIAS[0-9]\+\)_.*/\1/p" | sort -u)
            for _alias in ${_aliases} ; do
                _value=$(eval "printf \"\$${_eth}_${_alias}_${_item}\"")
                # inject and record a new context variable into the environment
                eval "ONEAPP_VROUTER_$(geth3 ${_eth} 1)_${_alias}_${_item}='${_value}'"
                eval "export ONEAPP_VROUTER_$(geth3 ${_eth} 1)_${_alias}_${_item}"
                msg info "SAVED: ${_eth}_${_alias}_${_item} as ONEAPP_VROUTER_$(geth3 ${_eth} 1)_${_alias}_${_item} =" \
                    "$_value"
            done
        done

        # VROUTER_KEEPALIVED_ID
        #
        # BEWARE:
        # because it is not possible to honor two sources of values which are in
        # a conflict the VROUTER_KEEPALIVED_ID serves only as a fallback in the
        # absence of ONEAPP_VNF_KEEPALIVED_<ETH?>_VRID...
        _vrid=$(eval "printf \"\$ONEAPP_VNF_KEEPALIVED_$(geth3 ${_eth} 1)_VRID\"")
        if [ -z "$_vrid" ] && [ -n "$VROUTER_KEEPALIVED_ID" ] ; then
            # only if we did not provided per instance virtual ID...

            if ! is_valid_vrouter_id "$VROUTER_KEEPALIVED_ID" ; then
                msg error "Used 'VROUTER_KEEPALIVED_ID' with an invalid value (it must be in 1-255): ${VROUTER_KEEPALIVED_ID}"
            fi

            # inject a new context variable into the environment
            eval "ONEAPP_VNF_KEEPALIVED_$(geth3 ${_eth} 1)_VRID='${VROUTER_KEEPALIVED_ID}'"
            eval "export ONEAPP_VNF_KEEPALIVED_$(geth3 ${_eth} 1)_VRID"
            msg info "INJECTED: ONEAPP_VNF_KEEPALIVED_$(geth3 ${_eth} 1)_VRID =" \
                "$VROUTER_KEEPALIVED_ID"
        fi
    done

    # for backwards compatibility support with the old vrouter we test if any
    # old vrouter variable was set
    if [ -n "${VROUTER_ID}${VROUTER_KEEPALIVED_ID}" ] ; then
        # VROUTER_KEEPALIVED_PASSWORD
        #
        # BEWARE:
        # this is necessary to be able to _delete_ (reset) the usage of a password;
        # the ONEAPP_VNF_KEEPALIVED_PASSWORD must be always overwritten no matter
        # the content of the VROUTER_KEEPALIVED_PASSWORD...
        #
        # inject a new context variable into the environment
        ONEAPP_VNF_KEEPALIVED_PASSWORD="${VROUTER_KEEPALIVED_PASSWORD}"
        export ONEAPP_VNF_KEEPALIVED_PASSWORD
        msg info "INJECTED: ONEAPP_VNF_KEEPALIVED_PASSWORD =" \
            "$VROUTER_KEEPALIVED_PASSWORD"

        # IMPLICIT KEEPALIVED
        if [ -z "${ONEAPP_VNF_KEEPALIVED_ENABLED}" ] ; then
            msg info "Detected old VROUTER context - we enable KEEPALIVED VNF implicitly"
            # inject a new context variable into the environment
            ONEAPP_VNF_KEEPALIVED_ENABLED=YES
            export ONEAPP_VNF_KEEPALIVED_ENABLED
            msg info "INJECTED: ONEAPP_VNF_KEEPALIVED_ENABLED = YES"
        fi

        # IMPLICIT ROUTER4
        if [ -z "${ONEAPP_VNF_ROUTER4_ENABLED}" ] ; then
            msg info "Detected old VROUTER context - we enable ROUTER4 VNF implicitly"
            # inject a new context variable into the environment
            ONEAPP_VNF_ROUTER4_ENABLED=YES
            export ONEAPP_VNF_ROUTER4_ENABLED
            msg info "INJECTED: ONEAPP_VNF_ROUTER4_ENABLED = YES"
        fi
    fi
}

# unify the value separators (spaces, commas, semicolons) and sort the values
# where it does not break meaning and parse !<eth> expressions
assort_multivalue_variables()
{
    msg info "Unify the separators for multivalue parameters"

    # sortable multivalue variables are these:
    # (it will also deduplicate the values)
    for _var in \
        ONEAPP_VNF_DNS_ALLOWED_NETWORKS \
        ONEAPP_VNF_DNS_INTERFACES \
        ONEAPP_VNF_DHCP4_INTERFACES \
        ONEAPP_VNF_DHCP4_MAC2IP_SUBNETS \
        ONEAPP_VNF_ROUTER4_INTERFACES \
        ONEAPP_VNF_NAT4_INTERFACES_OUT \
        ONEAPP_VNF_SDNAT4_INTERFACES \
        ONEAPP_VNF_LB_INTERFACES \
        ONEAPP_VNF_HAPROXY_INTERFACES \
        ONEAPP_VNF_KEEPALIVED_INTERFACES \
        ;
    do
        _value=$(eval "printf \"\$${_var}\"" | \
            tr ',;' ' ' | \
            sed -e 's/^[[:space:]]*//' \
                -e 's/[[:space:]]*$//' \
                -e 's/[[:space:]]\+/ /g' | \
            tr ' ' '\n' | sort -u | tr '\n' ' ' | \
            sed 's/[[:space:]]*$//')

        # save the modified value back
        eval "${_var}=\"${_value}\""
        eval "export ${_var}"
    done

    # unsortable (the order is significant) multivalue variables are these:
    _plus_eth_vars=$(env | sed -n \
        -e 's/^\(ONEAPP_VNF_DHCP4_ETH[0-9]\+_DNS\)=.*/\1/p' \
        -e 's/^\(ONEAPP_VNF_DHCP4_ETH[0-9]\+_GATEWAY\)=.*/\1/p' \
        )
    for _var in \
        ONEAPP_VNF_DNS_NAMESERVERS \
        ONEAPP_VNF_DHCP4_DNS \
        ONEAPP_VNF_DHCP4_GATEWAY \
        ${_plus_eth_vars} ;
    do
        _value=$(eval "printf \"\$${_var}\"" | \
            tr ',;' ' ' | \
            sed -e 's/^[[:space:]]*//' \
                -e 's/[[:space:]]*$//' \
                -e 's/[[:space:]]\+/ /g')

        # save the modified value back
        eval "${_var}=\"${_value}\""
        eval "export ${_var}"
    done

    # interface params require a special treatment
    # it should be eth<num> or lo, but it also can be an ip address or !<eth>
    for _var in \
        ONEAPP_VNF_DNS_INTERFACES \
        ONEAPP_VNF_DHCP4_INTERFACES \
        ONEAPP_VNF_ROUTER4_INTERFACES \
        ONEAPP_VNF_NAT4_INTERFACES_OUT \
        ONEAPP_VNF_SDNAT4_INTERFACES \
        ONEAPP_VNF_LB_INTERFACES \
        ONEAPP_VNF_HAPROXY_INTERFACES \
        ONEAPP_VNF_KEEPALIVED_INTERFACES \
        ;
    do
        # because we are using the eth triplet system, we can upcase all eths
        # in interfaces variables...
        _value=$(eval "printf \"\$${_var}\"" | \
            tr '[:lower:]' '[:upper:]')

        _disabled_eths=
        _interfaces=
        for _iface in ${_value} ; do
            if echo "$_iface" | grep -q -e '^[!]ETH[0-9]\+$' -e '^[!]LO$' ; then
                # valid expression for: do not use this interface
                _iface=$(printf "$_iface" | tr -d '!')
                _disabled_eths="${_disabled_eths} ${_iface}"
            else
                # valid interface
                _interfaces="${_interfaces} ${_iface}"
            fi
        done

        if [ -n "$_interfaces" ] ; then
            # negated eths has no meaning now
            _disabled_eths=
        fi

        _value=$(printf "${_interfaces}" | \
            sed -e 's/^[[:space:]]*//' \
                -e 's/[[:space:]]*$//' \
                -e 's/[[:space:]]\+/ /g')

        # save the modified value back
        eval "${_var}=\"${_value}\""
        eval "export ${_var}"

        msg info "INJECTED: ${_var} = ${_value}"

        # save the disabled interfaces
        _value=$(printf "${_disabled_eths}" | \
            sed -e 's/^[[:space:]]*//' \
                -e 's/[[:space:]]*$//' \
                -e 's/[[:space:]]\+/ /g')

        # inject a new context variable into the environment:
        #   ONEAPP_VNF_<var>_INTERFACES_DISABLED
        eval "${_var}_DISABLED=\"${_value}\""
        eval "export ${_var}_DISABLED"

        msg info "INJECTED: ${_var}_DISABLED = ${_value}"
    done
}

sortout_vnfs()
{
    msg info "Sort out VNFs: ENABLED/DISABLED"

    for _vnf in ${ALL_SUPPORTED_VNF_NAMES} ; do
        _value=$(eval "printf \"\$ONEAPP_VNF_${_vnf}_ENABLED\"" | \
            tr '[:upper:]' '[:lower:]')

        case "${_value}" in
            1|true|yes|t|y)
                msg info "VNF ${_vnf} will be: ENABLED"
                ENABLED_VNF_LIST="${ENABLED_VNF_LIST} ${_vnf}"

                # out of those enabled are any changed?
                if is_changed "${_vnf}" ; then
                    msg info "VNF ${_vnf} is modified - it will be: RELOADED"
                    UPDATED_VNF_LIST="${UPDATED_VNF_LIST} ${_vnf}"
                fi
                ;;
            ''|0|false|no|f|n)
                msg info "VNF ${_vnf} will be: DISABLED"
                DISABLED_VNF_LIST="${DISABLED_VNF_LIST} ${_vnf}"
                ;;
            *)
                msg warning "Unknown value ('${_value}') for: ONEAPP_VNF_${_vnf}_ENABLED"
                msg warning "VNF ${_vnf} will be: SKIPPED/UNCHANGED"
                ;;
        esac
    done
}

# arg: <VNFs>
is_running()
(
    _vnfs="$1"

    for _vnf in $_vnfs ; do
        case "$_vnf" in
            DHCP4)
                is_running_dhcp4
                return $?
                ;;
            DNS)
                is_running_dns
                return $?
                ;;
            NAT4)
                # iptables is a kernel module, there is no process to be
                # signaled - we want this to report: RUNNING
                #
                # that will always force reload_nat4 which basically replaces
                # the NAT table with the correct rules everytime (stop, start)
                return 0 # it IS running
                ;;
            SDNAT4)
                is_running_sdnat4
                return $?
                ;;
            ROUTER4)
                # sysctl has no process - we want this to report: NOT RUNNING
                #
                # by starting it each time we ensure that sysctl.conf is
                # correct - reload would just reread the current file which
                # could have had forwarding disabled...
                return 1 # it is not running
                ;;
            LB)
                is_running_lb
                return $?
                ;;
            HAPROXY)
                is_running_haproxy
                return $?
                ;;
            KEEPALIVED)
                is_running_keepalived
                return $?
                ;;
            *)
                msg error "Unknown VNF name: This is a bug - this should never happen"
                ;;
        esac
    done
)

# arg: <list of VNFs>
enable_vnfs()
{
    _enabled_vnfs="$1"

    for _vnf in $_enabled_vnfs ; do
        case "$_vnf" in
            DHCP4)
                msg info "Enable DHCP4 VNF"
                enable_dhcp4
                ;;
            DNS)
                msg info "Enable DNS VNF"
                enable_dns
                ;;
            NAT4)
                msg info "Enable NAT4 VNF"
                enable_nat4
                ;;
            SDNAT4)
                msg info "Enable SDNAT4 VNF"
                enable_sdnat4
                ;;
            ROUTER4)
                msg info "Enable ROUTER4 VNF"
                enable_router4
                ;;
            LB)
                msg info "Enable LB VNF"
                enable_lb
                ;;
            HAPROXY)
                msg info "Enable HAPROXY VNF"
                enable_haproxy
                ;;
            KEEPALIVED)
                # skip this
                :
                ;;
            *)
                msg error "Unknown VNF name: This is a bug - this should never happen"
                ;;
        esac
    done
}

# arg: <list of VNFs>
start_vnfs()
{
    _enabled_vnfs="$1"

    for _vnf in $_enabled_vnfs ; do
        case "$_vnf" in
            DHCP4)
                msg info "Start DHCP4 VNF"
                start_dhcp4
                ;;
            DNS)
                msg info "Start DNS VNF"
                start_dns
                ;;
            NAT4)
                msg info "Start NAT4 VNF"
                start_nat4
                ;;
            SDNAT4)
                msg info "Start SDNAT4 VNF"
                start_sdnat4
                ;;
            ROUTER4)
                msg info "Start ROUTER4 VNF"
                start_router4
                ;;
            LB)
                msg info "Start LB VNF"
                start_lb
                ;;
            HAPROXY)
                msg info "Start HAPROXY VNF"
                start_haproxy
                ;;
            KEEPALIVED)
                # skip this
                :
                ;;
            *)
                msg error "Unknown VNF name: This is a bug - this should never happen"
                ;;
        esac
    done
}

# arg: <list of VNFs>
stop_and_disable_vnfs()
{
    _disabled_vnfs="$1"

    for _vnf in $_disabled_vnfs ; do
        case "$_vnf" in
            DHCP4)
                msg info "Stop and disable DHCP4 VNF"
                disable_dhcp4
                stop_dhcp4
                ;;
            DNS)
                msg info "Stop and disable DNS VNF"
                disable_dns
                stop_dns
                ;;
            NAT4)
                msg info "Stop and disable NAT4 VNF"
                disable_nat4
                stop_nat4
                ;;
            SDNAT4)
                [ -n "${_SKIP_ONE_VNF}" ] && continue
                msg info "Stop and disable SDNAT4 VNF"
                disable_sdnat4
                stop_sdnat4
                ;;
            ROUTER4)
                msg info "Stop and disable ROUTER4 VNF"
                disable_router4
                stop_router4
                ;;
            LB)
                [ -n "${_SKIP_ONE_VNF}" ] && continue
                msg info "Stop and disable LB VNF"
                disable_lb
                stop_lb
                ;;
            HAPROXY)
                [ -n "${_SKIP_ONE_VNF}" ] && continue
                msg info "Stop and disable HAPROXY VNF"
                disable_haproxy
                stop_haproxy
                ;;
            KEEPALIVED)
                msg info "Stop and disable KEEPALIVED VNF"
                disable_keepalived
                stop_keepalived
                ;;
            *)
                msg error "Unknown VNF name: This is a bug - this should never happen"
                ;;
        esac
    done
}

# arg: <list of VNFs>
reload_vnfs()
{
    _updated_vnfs="$1"

    for _vnf in $_updated_vnfs ; do
        case "$_vnf" in
            DHCP4)
                msg info "Reload DHCP4 VNF"
                reload_dhcp4
                ;;
            DNS)
                msg info "Reload DNS VNF"
                reload_dns
                ;;
            NAT4)
                msg info "Reload NAT4 VNF"
                reload_nat4
                ;;
            SDNAT4)
                msg info "Reload SDNAT4 VNF"
                reload_sdnat4
                ;;
            ROUTER4)
                msg info "Reload ROUTER4 VNF"
                reload_router4
                ;;
            LB)
                msg info "Reload LB VNF"
                reload_lb
                ;;
            HAPROXY)
                msg info "Reload HAPROXY VNF"
                reload_haproxy
                ;;
            KEEPALIVED)
                # skip this
                :
                ;;
            *)
                msg error "Unknown VNF name: This is a bug - this should never happen"
                ;;
        esac
    done
}

# TODO: if not running then just start them - if they are running reload them...
toggle_vnfs()
{
    msg info "Toggle VNF services (Start/Stop)"

    # do we have HA setup with keepalived?
    if is_in_list KEEPALIVED "$ENABLED_VNF_LIST" ; then
        # Keepalived's notify script will take care of services...

        msg info "Keepalived will take care of starting and stopping of VNFs"

        msg info "Stop and disable all VNFs except keepalived"
        _vnfs=$(for _vnf in $ALL_SUPPORTED_VNF_NAMES ; do echo "$_vnf" ; done \
            | sed '/^KEEPALIVED$/d')
        stop_and_disable_vnfs "$_vnfs"

        # first verify that keepalived has at least one vrrp instance otherwise
        # it has nothing to do and it behaves undeterministically (it can be in
        # all states: MASTER, BACKUP, FAULT - at least from my experience...)
        if grep -q '^vrrp_instance ' "$VNF_KEEPALIVED_CONFIG" ; then
            # enable and start keepalived

            msg info "Enable KEEPALIVED VNF"
            enable_keepalived

            if is_running_keepalived ; then
                # TODO: improve this
                # we must always reload (actually restart) keepalived to trigger
                # restart/reload of all changed VNFs

                #if is_in_list KEEPALIVED "$UPDATED_VNF_LIST" ; then
                #    msg info "Reload KEEPALIVED VNF"
                #    reload_keepalived
                #fi

                msg info "Reload/restart KEEPALIVED VNF"
                reload_keepalived
            else
                msg info "Start KEEPALIVED VNF"
                start_keepalived
            fi
        else
            # disable idle (no instance) keepalived
            msg warning "Keepalived has no vrrp instance - it has nothing to do..."
            stop_and_disable_vnfs 'KEEPALIVED'
        fi
    else
        # no HA and no keepalived - that means we take care of VNFs...

        # stop and disable unrequested VNFs/services
        stop_and_disable_vnfs "$DISABLED_VNF_LIST"

        # enable requested VNFs/services
        enable_vnfs "$ENABLED_VNF_LIST"

        # reload/start updated and enabled VNFs/services
        for _vnf in ${ENABLED_VNF_LIST} ; do
            if is_running "${_vnf}" ; then
                if is_in_list "${_vnf}" "$UPDATED_VNF_LIST" ; then
                    reload_vnfs "${_vnf}"
                fi
            else
                start_vnfs "${_vnf}"
            fi
        done
    fi
}

# arg: <VNF>
is_changed()
(
    _vnf="$1"

    for i in $(get_changed_context_vars) ; do
        if echo "$i" | grep -q \
            -e "^ONEAPP_VNF_${_vnf}_" \
            -e "^ONEAPP_VNF_LB[0-9]*_" \
            -e "^ONEAPP_VNF_HAPROXY_LB[0-9]*_" \
            -e "^ONEAPP_VROUTER_" \
            ;
        then
            return 0
        fi
    done

    return 1
)

# args: <values> <option>
prepare_args()
(
    _values="$1"
    _option="$2"
    _args=''

    for i in ${_values} ; do
        _args="${_args} ${_option} ${i}"
    done

    echo "$_args"
)

# args: <variable-name-prefix> <option>
# the value must be a base64 encoded string
prepare_args_from_prefix()
(
    _prefix="$1"
    _option="$2"
    _args=''

    _varnames=$(env | sed -n "s/^\(${_prefix}[0-9]*\)=.*/\1/p")

    for _varname in ${_varnames} ; do
        _value=$(eval "printf \"\$${_varname}\"" | \
            base64 -d | base64 -w 0)
        if [ -n "$_value" ] ; then
            _args="${_args} ${_option} ${_value}"
        fi
    done

    echo "$_args"
)

# return IPs from all ONEAPP_VROUTER_<ETH>_VIP as arguments to
# kea-config-generator
return_all_vips_as_args()
(
    _vips=$(env | sed -n "s/^ONEAPP_VROUTER_ETH[0-9]*_VIP=\(.*\)/\1/p")
    _args=''

    for _vip in ${_vips} ; do
        _args="${_args} --floating-ip ${_vip}"
    done

    echo "$_args"
)

# arg: <MAC>
find_iface_by_mac()
(
    _iface=$(ip a | awk -v mac="$1" '
        {
            if ($1 == "link/ether" && tolower($2) == tolower(mac)) {
                print iface;
                exit;
            } else {
                iface = $0;
            }
        }' | sed -n 's/[[:space:]]*[0-9]\+:[[:space:]]\+\([^:]\+\):.*/\1/p')

    if [ -n "$_iface" ] ; then
        printf "%s" ${_iface}
    fi
)

# TODO: ipv6
#
# returns ethernet name triplet for each ETH<NUM>_IP paired with the actual
# in-system interface name by MAC and desired user provided interface name...
# for example:
#   <user-eth>:<system-eth>:<one-eth>
#   ETH0:ens2:ETH7
make_eth_triplets()
{
    _eth_triplets=  # here we will be saving our triplets
    _num=0          # first triplet member always start from zero (user eth)

    # grab all opennebula's context ETH<?>_IP variables
    _one_eths=$(env | sed -n "s/^\(ETH[0-9]\+\)_IP=.*/\1/p" | sort -u)

    # compose triplets...
    for _one_eth in ${_one_eths} ; do
        _one_mac=$(eval "printf \"\$${_one_eth}_MAC\"")
        if [ -n "$_one_mac" ] ; then
            # workaround LXD interface naming issue (eth0@if1313):
            #   https://github.com/lxc/lxd/issues/2796
            # by chomping the '@...' suffix...
            _system_eth=$(find_iface_by_mac "${_one_mac}" | sed 's/@.*//')

            # maybe context variable does not match actual state...
            if [ -z "$_system_eth" ] ; then
                continue
            fi

            # now we have all
            _eth_triplet="ETH${_num}:${_system_eth}:${_one_eth}"
            _eth_triplets="${_eth_triplets} ${_eth_triplet}"
            _num=$(( _num + 1 ))
        fi
    done

    # we save it and add the loopback triplet
    ETH_TRIPLETS="LO:lo:LO ${_eth_triplets}"
}

# it returns a member or the whole triplet, which must match the expression
# (interface/eth name) in the column from the first argument
# args: <1-3 for searched member> <expression> [<1-3 member to display>]
geth()
(
    _eth=$(echo "${ETH_TRIPLETS}" | tr '[:space:]' '\n' | \
        awk -v f="$1" -v x="$2" -v n="${3:-0}" '
        BEGIN {
            FS=":";
        }
        {
            if (x == $(f)) {
                print $(n);
                exit;
            }
        }')

    if [ -n "$_eth" ] ; then
        printf "$_eth"
    fi
)

# wrapper for geth to search through the first member of the triplet
# that means: find the first argument among the user-eth member of the triplet
# arg: <expression> [<1-3>]
geth1()
{
    geth 1 "$@"
}

# wrapper for geth to search through the second member of the triplet
# that means: find the first argument among the real-eth member of the triplet
# arg: <expression> [<1-3>]
geth2()
{
    geth 2 "$@"
}

# wrapper for geth to search through the third member of the triplet
# that means: find the first argument among the context-eth member of the triplet
# arg: <expression> [<1-3>]
geth3()
{
    geth 3 "$@"
}

# it returns ONE interface names - the third member of the eth triplet
# args: [<list of disabled interfaces>]
get_eths()
(
    _disabled_eths="$1"

    for _triplet in ${ETH_TRIPLETS} ; do
        _eth=$(printf "${_triplet}" | cut -d":" -f3)

        # skip loopback triplet
        if [ "$_eth" = 'LO' ] ; then
            continue
        fi

        for _disabled_eth in ${_disabled_eths} ; do
            _disabled_eth=$(geth1 "$_disabled_eth" 3)
            if [ "$_eth" = "$_disabled_eth" ] ; then
                # do not return this interface because it is disabled
                _eth=
                break
            fi
        done
        if [ -n "$_eth" ] ; then
            echo "$_eth"
        fi
    done
)

# args: <eth> <list of disabled interfaces>
is_disabled_eth()
(
    _eth="$1"
    _disabled_eths="$2"

    for i in ${_disabled_eths} ; do
        if [ "$i" = "$_eth" ] ; then
            return 0
        fi
    done

    return 1
)

# arg: <VNF>
to_be_configured()
(
    # this is configuration guard - if VNF service is not enabled or changed
    # there is no need to (re)configure it

    _vnf="$1"

    # except when it is not being reconfigured but configured...
    if { ! is_true ONE_SERVICE_RECONFIGURE ; } \
        && is_in_list "${_vnf}" "$ENABLED_VNF_LIST" ;
    then
        # reconfigure trigger was not used - this is either the first time
        # configuration or after restart configuration...
        return 0
    fi

    # reconfigure argument was passed so we will do a check...
    if is_in_list "${_vnf}" "$ENABLED_VNF_LIST" && is_changed "${_vnf}" ; then
        # we want to proceed with the configuration
        return 0
    fi

    msg info "VNF ${_vnf} was not enabled or changed - skipping (re)configuration"

    return 1
)


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


#
# VNFs
#


### VNF DHCP4 #################################################################

# prepare logfile location - must be owned by kea user
install_onekea_logfile()
{
    msg info "Create default Kea logging directory: /var/log/kea"
    mkdir -p /var/log/kea
    chown -R kea:kea /var/log/kea

    msg info "Prepare the Kea's logfile: ${ONEAPP_VNF_DHCP4_LOGFILE}"

    _dir=$(dirname "${ONEAPP_VNF_DHCP4_LOGFILE}")

    if ! [ -e "$_dir" ] ; then
        # directory does not exist yet - so it is no issue to chown it...
        mkdir -p "$_dir"
        chown -R kea:kea "$_dir"
    elif ! [ -d "$_dir" ] ; then
        msg error "Path is not a directory: ${_dir}"
    fi

    touch "${ONEAPP_VNF_DHCP4_LOGFILE}"
    chown kea:kea "${ONEAPP_VNF_DHCP4_LOGFILE}"

    msg info "Install logrotate script: ${ONEKEA_DHCP4_LOGROTATE}"
    cat > "$ONEKEA_DHCP4_LOGROTATE" <<EOF
${ONEAPP_VNF_DHCP4_LOGFILE} {
    compress
    rotate 10
    weekly
    notifempty
    missingok
    copytruncate
}
EOF
}

save_kea_config()
{
    msg info "Backup the original dhcp4 config to '${ONEKEA_DHCP4_CONFIG}~onesave'"
    cp -a "${ONEKEA_DHCP4_CONFIG}" "${ONEKEA_DHCP4_CONFIG}~onesave"

    msg info "Backup the original dhcp6 config to '${ONEKEA_DHCP6_CONFIG}~onesave'"
    cp -a "${ONEKEA_DHCP6_CONFIG}" "${ONEKEA_DHCP6_CONFIG}~onesave"
}

install_onekea_hooks()
{
    # TODO: replace with official package from alpine repo (when ready)
    # onekea installation
    msg info "Install ISC Kea hook(s) from the artifact"
    apk --allow-untrusted add "${ONE_SERVICE_SETUP_DIR}/vnf/${ONEKEA_ARTIFACT}"
    rm -f "${ONE_SERVICE_SETUP_DIR}/vnf/${ONEKEA_ARTIFACT}"

    # install kea-config-generator
    mv "${ONE_SERVICE_SETUP_DIR}/vnf/kea-config-generator" \
        "${ONEKEA_PREFIX}/sbin/kea-config-generator"
    chmod 0755 "${ONEKEA_PREFIX}/sbin/kea-config-generator"

    # this enables the unprivileged kea process to bind on the interface
    for _bin in kea-dhcp4 kea-dhcp6 ; do
        setcap 'cap_net_bind_service,cap_net_raw=+ep' \
            "${ONEKEA_PREFIX}/sbin/${_bin}"
    done
}

install_dhcp()
{
    msg info "Install ISC Kea dhcp server"
    if ! apk add \
        --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing \
        kea \
        kea-admin \
        kea-ctrl-agent \
        kea-dhcp-ddns \
        kea-dhcp4 \
        kea-dhcp6 \
        kea-doc \
        kea-shell \
        kea-hook-flex-option \
        kea-hook-ha \
        kea-hook-lease-cmds \
        kea-hook-mysql-cb \
        kea-hook-stat-cmds \
        ;
    then
        msg error "ISC Kea dhcp server package installation failed"
        exit 1
    fi

    install_onekea_logfile

    # backup original files from package
    save_kea_config
}

# args: <eth triplet> [<alias>]
create_subnet4()
(
    _triplet="$1"
    _alias="${2:+_}${2}"    # e.g.: _ALIAS0

    _user_eth=$(echo "${_triplet}" | cut -d":" -f1)
    _real_eth=$(echo "${_triplet}" | cut -d":" -f2)
    _one_eth=$(echo "${_triplet}" | cut -d":" -f3)

    # ONEAPP_VNF_DHCP4_ETH0=<cidr subnet>:<start ip>-<end ip>
    _value=$(eval "printf \"\$ONEAPP_VNF_DHCP4_${_user_eth}${_alias}\"" | tr -d '[:space:]')
    _subnet=$(echo "$_value" | awk 'BEGIN{FS=":"} {print $1}')
    _pool=$(echo "$_value" | awk 'BEGIN{FS=":"} {print $2}')

    if [ -n "$_subnet" ] && [ -z "$_pool" ] ; then
        msg error \
            "'ONEAPP_VNF_DHCP4_${_user_eth}${_alias}' must contain a subnet and a range/pool" \
            || true # this function is buried in subshell so we cannot abort quickly
    elif [ -z "$_subnet" ] ; then
        return 0
    fi

    # ONEAPP_VNF_DHCP4_ETH0_DNS=<ip>[[ ,;]<ip>...]
    _dns=$(eval "printf \"\$ONEAPP_VNF_DHCP4_${_user_eth}${_alias}_DNS\"")
    if [ -z "$_dns" ] ; then
        # ETH0_DNS
        _dns=$(eval "printf \"\$${_one_eth}${_alias}_DNS\"")
    fi
    if [ -n "$_dns" ] ; then
        _dns=$(echo "$_dns" | \
            tr ',;' ' ' | \
            sed -e 's/^[[:space:]]*//' \
                -e 's/[[:space:]]*$//' \
                -e 's/[[:space:]]\+/, /g')
    fi

    # ONEAPP_VNF_DHCP4_ETH0_GATEWAY=<ip>[[ ,;]<ip>...]
    _gateway=$(eval "printf \"\$ONEAPP_VNF_DHCP4_${_user_eth}${_alias}_GATEWAY\"")
    if [ -z "$_gateway" ] ; then
        # ETH0_GATEWAY
        _gateway=$(eval "printf \"\$${_one_eth}${_alias}_GATEWAY\"")
    fi
    if [ -n "$_gateway" ] ; then
        _gateway=$(echo "$_gateway" | \
            tr ',;' ' ' | \
            sed -e 's/^[[:space:]]*//' \
                -e 's/[[:space:]]*$//' \
                -e 's/[[:space:]]\+/, /g')
    fi

    # ONEAPP_VNF_DHCP4_ETH0_MTU=<number>
    _mtu=$(eval "printf \"\$ONEAPP_VNF_DHCP4_${_user_eth}${_alias}_MTU\"")
    if [ -z "$_mtu" ] ; then
        # ETH0_MTU
        _mtu=$(eval "printf \"\$${_one_eth}${_alias}_MTU\"")
    fi

    cat <<EOF | jq | base64 -w 0
{
    "subnet": "${_subnet}",
    "pools": [
        {
            "pool": "${_pool}"
        }
    ],
    "option-data": [

$(if [ -n "$_dns" ] ; then cat <<DNS
        {
            "name": "domain-name-servers",
            "data": "${_dns}"
        }
DNS
fi ;)

$(if [ -n "$_gateway" ] ; then cat <<GATEWAY
        ${_dns:+,}
        {
            "name": "routers",
            "data": "${_gateway}"
        }
GATEWAY
fi ;)

$(if [ -n "$_mtu" ] ; then cat <<MTU
        ${_gateway:+,}
        {
            "name": "interface-mtu",
            "data": "${_mtu}"
        }
MTU
fi ;)

    ]

}
EOF
)

# TODO: IPv6 (we need separate version subnet6 into another file)
return_subnets()
(
    _subnets=$(prepare_args_from_prefix \
        ONEAPP_VNF_DHCP4_SUBNET --subnet4)

    # if ONEAPP_VNF_DHCP4_SUBNET* is used then we skip other subnet creation
    if [ -n "$_subnets" ] ; then
        echo "$_subnets"
        return
    fi

    # we preset ONEAPP_VNF_DHCP4_<IFACE>* variables with values from ETH<NUM>_*
    # but the ONEAPP_VNF_DHCP4_<IFACE>* variables always take precedence!
    #
    # also we respect the ONEAPP_VNF_DHCP4_INTERFACES in all cases - so if
    # listen interfaces have been set then only those relevant ETH<NUM>_* vars
    # will be applicated...

    # we add loopback so we can generate proper subnet
    for _eth in LO $(get_eths "$ONEAPP_VNF_DHCP4_INTERFACES_DISABLED") ; do
        _aliases=$(env | sed -n "s/^${_eth}_\(ALIAS[0-9]\+\)_.*/\1/p" | \
            sort -u)

        # create list of all subnet and pool variables (including aliases)
        _ethaliases="$(geth3 ${_eth} 1)"
        for _alias in ${_aliases} ; do
            _ethaliases="${_ethaliases} $(geth3 ${_eth} 1)_${_alias}"
        done

        for _ethalias in ${_ethaliases} ; do
            _oneapp_ethalias=$(eval "printf \"\$ONEAPP_VNF_DHCP4_${_ethalias}\"")
            if [ -z "$_oneapp_ethalias" ] ; then
                # undefined subnet and pool...so we remedy it...
                if [ "$_eth" = 'LO' ] ; then
                    _eth_address='127.0.0.1'
                    _eth_mask='255.0.0.0'
                else
                    _alias=$(echo "$_ethalias" | cut -d"_" -f2 | \
                        sed -n 's/^ALIAS[0-9]*$/_&/p')
                    _eth_address=$(eval "printf \"\$${_eth}${_alias}_IP\"")
                    _eth_mask=$(eval "printf \"\$${_eth}${_alias}_MASK\"")
                fi
                _eth_subnet_and_pool=$(python3 -c '
import sys
import ipaddress

# this script generates subnet and pool per requested interface
# args: <eth-name> <ip> [<netmask>]

args = {
    "eth": "",
    "addr": "",
    "mask": "255.255.255.0" # default netmask if missing
}

argc = 0
for arg in sys.argv:
    if argc == 1:
        args["eth"] = arg
    elif argc == 2:
        args["addr"] = arg
    elif argc == 3:
        args["mask"] = arg
    argc += 1

if args["addr"] == "" or args["mask"] == "":
    print("SKIPPED: [!] No ip address or no netmask for interface: \"%s\""
          % args["eth"], file=sys.stderr)
    sys.exit(0)

# create subnet
subnet = ipaddress.ip_network(args["addr"] + "/" + args["mask"], strict=False)

if subnet.num_addresses < 4:
    print("SKIPPED: [!] provided ip range was too small: \"%s\""
          % subnet, file=sys.stderr)
    sys.exit(0)

pool_start = subnet[2]  # exempt the lowest ip
pool_end = subnet[-2]   # exempt the broadcast ip

# print the subnet and the pool
print(str(subnet.network_address), "/", str(subnet.prefixlen), ":",
      str(pool_start), "-", str(pool_end), sep="", end="")
                ' ${_eth} ${_eth_address} ${_eth_mask})

                # inject newly generated variable into environment
                eval "ONEAPP_VNF_DHCP4_${_ethalias}='${_eth_subnet_and_pool}'"
                eval "export ONEAPP_VNF_DHCP4_${_ethalias}"
            fi

            # gateway, dns, mtu
            for _item in GATEWAY DNS MTU ; do
                _oneapp_eth_item=$(eval "printf \"\$ONEAPP_VNF_DHCP4_${_ethalias}_${_item}\"")
                if [ -z "$_oneapp_eth_item" ] ; then
                    # we provide our value
                    _alias=$(echo "$_ethalias" | cut -d"_" -f2 | \
                        sed -n 's/^ALIAS[0-9]*$/_&/p')
                    _eth_item=$(eval "printf \"\$${_eth}${_alias}_${_item}\"")

                    # inject newly generated variable into environment
                    eval "ONEAPP_VNF_DHCP4_${_ethalias}_${_item}='${_eth_item}'"
                    eval "export ONEAPP_VNF_DHCP4_${_ethalias}_${_item}"
                fi
            done
        done
    done

    # we take one interface name at a time and we look for variables:
    #   ONEAPP_VNF_DHCP4_<IFACE>_*
    # from which we construct subnet json

    _eths=
    if [ -n "${ONEAPP_VNF_DHCP4_INTERFACES}" ] ; then
        # user provided us with list of interfaces (eth0, eth0/<ip>)
        for _iface in ${ONEAPP_VNF_DHCP4_INTERFACES} ; do
            # interface name must be a part of an environment variable...
            _eth=$(echo "$_iface" | awk 'BEGIN{FS="/"} {print $1}')

            _eth=$(geth1 "$_eth" 3)

            if [ -n "$_eth" ] ; then
                _eths="${_eths} ${_eth}"
            else
                msg warning "VNF DHCP4: Invalid network interface name: ${_iface} (SKIPPING)"
                continue
            fi
        done
    else
        # fallback to ETH<NUM>_* designated interfaces
        _eths=$(get_eths "$ONEAPP_VNF_DHCP4_INTERFACES_DISABLED")
    fi

    _triplets=
    for _eth in ${_eths} ; do
        _management_eth=$(eval "printf \"\$ONEAPP_VROUTER_$(geth3 ${_eth} 1)_MANAGEMENT\"")

        if is_true _management_eth ; then
            continue
        else
            _triplet=$(geth3 "${_eth}")
            _triplets="${_triplets} ${_triplet}"
        fi
    done

    # prioritize the ETHs before ALIASES
    for _triplet in ${_triplets} ; do
        _subnet=$(create_subnet4 "${_triplet}")
        if [ -n "$_subnet" ] ; then
            _subnets="${_subnets} ${_subnet}"
        fi
    done

    # after ETHs extend the subnet list with aliases
    for _triplet in ${_triplets} ; do
        # aliases
        _eth=$(echo "$_triplet" | cut -d":" -f3)
        _aliases=$(env | \
            sed -n "s/^${_eth}_\(ALIAS[0-9]\+\)_.*/\1/p" | \
            sort -u)
        for _alias in ${_aliases} ; do
            _subnet=$(create_subnet4 "${_triplet}" "$_alias")
            if [ -n "$_subnet" ] ; then
                _subnets="${_subnets} ${_subnet}"
            fi
        done
    done

    # we add option --subnet4 to each subnet and make sure we have no
    # duplicated subnet
    _arg_subnets=
    for _subnet in ${_subnets} ; do
        # check if the subnet is not present already
        _new_subnet_value=$(echo "$_subnet" | base64 -d | \
            jq -cr .subnet | tr -d '[:space:]')
        _present=no
        for s in ${_arg_subnets} ; do
            # skip option argument...
            if [ "$s" == '--subnet4' ] ; then
                continue
            fi

            _iter_subnet_value=$(echo "$s" | base64 -d | \
                jq -cr .subnet | tr -d '[:space:]')
            if [ "$_iter_subnet_value" == "$_new_subnet_value" ] ; then
                _present=yes
                break
            fi
        done

        # this subnet was not yet seen - so we will add it to the list
        if [ "$_present" == no ] ; then
            _arg_subnets="${_arg_subnets} --subnet4 ${_subnet}"
        fi
    done

    # at the last we return the subnet arguments
    echo "$_arg_subnets"
)

return_onelease4_subnets()
(
    _comma=
    for _subnet in ${ONEAPP_VNF_DHCP4_MAC2IP_SUBNETS} ; do
        if [ -z "$_comma" ] ; then
            _comma=","
        else
            printf ",\n"
        fi
        printf "\"${_subnet}\""
    done
)

configure_dhcp4()
{
    # configuration guard
    if ! to_be_configured DHCP4 ; then
        return 0
    fi

    msg info "VNF DHCP4: configure ISC Kea dhcp server"

    # network onecontext:
    #
    # ETH0_CONTEXT_FORCE_IPV4=
    # ETH0_DNS=8.8.8.8
    # ETH0_GATEWAY6=
    # ETH0_GATEWAY=192.168.122.1
    # ETH0_IP6=
    # ETH0_IP6_PREFIX_LENGTH=
    # ETH0_IP6_ULA=
    # ETH0_IP=192.168.122.10
    # ETH0_MAC=02:00:c0:a8:7a:0a
    # ETH0_MASK=255.255.255.0
    # ETH0_MTU=
    # ETH0_NETWORK=192.168.122.0
    # ETH0_SEARCH_DOMAIN=
    # ETH0_VLAN_ID=
    # ETH0_VROUTER_IP6=
    # ETH0_VROUTER_IP=
    # ETH0_VROUTER_MANAGEMENT=
    #
    # our context:
    #
    # ONEAPP_VNF_DHCP4_INTERFACES=<iface>[/<ip>] ...
    # ONEAPP_VNF_DHCP4_DNS=<ip> ...
    # ONEAPP_VNF_DHCP4_GATEWAY=<ip> ...
    # ONEAPP_VNF_DHCP4_AUTHORITATIVE=<boolean>
    # ONEAPP_VNF_DHCP4_LEASE_TIME=<number>
    # ONEAPP_VNF_DHCP4_LOGFILE=<filename>
    # ONEAPP_VNF_DHCP4_LEASE_DATABASE=<database json in base64>
    # ONEAPP_VNF_DHCP4_MAC2IP_ENABLED=<boolean>
    # ONEAPP_VNF_DHCP4_MAC2IP_MACPREFIX="00:00"
    # ONEAPP_VNF_DHCP4_MAC2IP_SUBNETS=<cidr> ...
    # ONEAPP_VNF_DHCP4_SUBNET[<number>]=<subnet json in base64>
    # or
    # ONEAPP_VNF_DHCP4_CONFIG (whole file in base64)
    #
    # eth0 example:
    #
    # ONEAPP_VNF_DHCP4_ETH0=<cidr subnet>:<start ip>-<end ip>
    # ONEAPP_VNF_DHCP4_ETH0_DNS=<ip> ...
    # ONEAPP_VNF_DHCP4_ETH0_GATEWAY=<ip> ...
    # ONEAPP_VNF_DHCP4_ETH0_MTU=<number>
    # ONEAPP_VNF_DHCP4_ETH0_ONELEASE=<boolean> TODO

    msg info "Create ISC Kea dhcp4 configuration file: ${ONEKEA_DHCP4_CONFIG_TEMP}"
    if [ -n "$ONEAPP_VNF_DHCP4_CONFIG" ] ; then
        msg info "Config file provided via 'ONEAPP_VNF_DHCP4_CONFIG'"
        echo "$ONEAPP_VNF_DHCP4_CONFIG" | base64 -d | \
            jq . > "$ONEKEA_DHCP4_CONFIG_TEMP"
    else
        msg info "Config file will be generated by 'kea-config-generator'"
        run_kea_config_generator
    fi

    # last crucial step
    msg info "Check validity of the ISC Kea configuration"
    if kea-dhcp4 -t "$ONEKEA_DHCP4_CONFIG_TEMP" ; then
        msg info "Saving a new valid configuration: ${ONEKEA_DHCP4_CONFIG}"
        mv -v "$ONEKEA_DHCP4_CONFIG_TEMP" "$ONEKEA_DHCP4_CONFIG"
        chmod 0644 "$ONEKEA_DHCP4_CONFIG"
    else
        exit 1
    fi
}

# TODO: IPv6 (separate version for IPv6 to another file)
run_kea_config_generator()
{
    msg info "Prepare options for kea-config-generator..."

    # prepare options
    #
    # variables with multiple values (space, comma or semicolon separated)

    # interfaces
    msg info "kea-config-generator: interfaces"
    _interfaces=
    for _iface in ${ONEAPP_VNF_DHCP4_INTERFACES} ; do
        # interface name must be ETH<num>
        _eth=$(echo "$_iface" | awk 'BEGIN{FS="/"} {print $1}')

        _eth=$(geth1 "$_eth" 1)

        if [ -n "$_eth" ] ; then
            # skip management interface
            _management_eth=$(eval "printf \"\$ONEAPP_VROUTER_${_eth}_MANAGEMENT\"")
            if is_true _management_eth ; then
                continue
            fi

            _ip=$(echo "$_iface" | awk 'BEGIN{FS="/"} {print $2}')
            _interfaces="${_interfaces} $(geth1 "$_eth" 2)${_ip:+/}${_ip}"

            # TODO: does this makes sense?
            # add aliases but only if IP addresses are explicitly used (otherwise plain interface covers everything)
            #if [ -n "$_ip" ] ; then
            #    _aliases=$(env | \
            #        sed -n "s/^ONEAPP_VROUTER_${_eth}_\(ALIAS[0-9]\+\)_.*/\1/p" | \
            #        sort -u)
            #    for _alias in ${_aliases} ; do
            #        _ip=$(eval "printf \"\$ONEAPP_VROUTER_${_eth}_${_alias}_IP\"")
            #        if [ -n "$_ip" ] ; then
            #            _interfaces="${_interfaces} $(geth1 "$_eth" 2)${_ip:+/}${_ip}"
            #        fi
            #    done
            #fi
        else
            msg warning "VNF DHCP4: Invalid network interface name: ${_iface} (SKIPPING)"
            continue
        fi
    done
    if [ -z "$_interfaces" ] && [ -n "$ONEAPP_VNF_DHCP4_INTERFACES_DISABLED" ] ; then
        for _iface in $(get_eths "$ONEAPP_VNF_DHCP4_INTERFACES_DISABLED") ; do
            # skip management interface
            _management_eth=$(eval "printf \"\$ONEAPP_VROUTER_$(geth3 ${_iface} 1)_MANAGEMENT\"")
            if is_true _management_eth ; then
                continue
            fi

            _interfaces="${_interfaces} $(geth3 ${_iface} 2)"
        done
    fi
    _interfaces=$(prepare_args \
        "$_interfaces" --interface)

    msg info "kea-config-generator: nameservers"
    _nameservers=$(prepare_args \
        "$ONEAPP_VNF_DHCP4_DNS" --domain-name-server)

    msg info "kea-config-generator: gateway/routers"
    _routers=$(prepare_args \
        "$ONEAPP_VNF_DHCP4_GATEWAY" --router)

    # base64 encoded jsons
    msg info "kea-config-generator: subnets"
    _subnets=$(return_subnets)

    msg info "kea-config-generator: hooks"
    _hooks=$(prepare_args_from_prefix \
        ONEAPP_VNF_DHCP4_HOOK --hook)

    # onelease hook
    msg info "kea-config-generator: MAC-to-IP 'onelease' hook"
    if is_true ONEAPP_VNF_DHCP4_MAC2IP_ENABLED ; then
        _onelease_hook=$(cat <<EOF | base64 -w 0
            {
                "library": "${ONEKEA_PREFIX}/lib/kea/hooks/${ONEKEA_ARTIFACT_LIBHOOK_LEASE}",
                "parameters": {
                    "enabled": true,
$(if [ -n "$ONEAPP_VNF_DHCP4_MAC2IP_MACPREFIX" ] ; then cat <<MACPREFIX
                    "byte-prefix": "${ONEAPP_VNF_DHCP4_MAC2IP_MACPREFIX}",
MACPREFIX
fi)
$(if [ -n "$ONEAPP_VNF_DHCP4_MAC2IP_SUBNETS" ] ; then cat <<SUBNETS
                    "subnets": [
                        $(return_onelease4_subnets)
                    ],
SUBNETS
fi)
                    "logger-name": "onekea-lease-dhcp4",
                    "debug": false,
                    "debug-logfile": "/var/log/kea/onekea-lease-dhcp4-debug.log"
                }
            }
EOF
        )
    else
        _onelease_hook=""
    fi

    # lease database
    msg info "kea-config-generator: lease database"
    if [ -n "$ONEAPP_VNF_DHCP4_LEASE_DATABASE" ] ; then
        _lease_database=$(echo "$ONEAPP_VNF_DHCP4_LEASE_DATABASE" | \
            base64 -d | base64 -w 0)
    else
        _lease_database=""
    fi

    # global authoritative
    msg info "kea-config-generator: authoritativity"
    if is_true ONEAPP_VNF_DHCP4_AUTHORITATIVE ; then
        _authoritative="--authoritative"
    else
        _authoritative=""
    fi

    # VIPs
    msg info "kea-config-generator: exclude VIPs (if used) from dhcp leases"
    _vips=$(return_all_vips_as_args)

    # generate config file
    kea-config-generator \
        ${_authoritative} \
        ${_interfaces:---interface \*} \
        ${_nameservers} \
        ${_routers} \
        ${_subnets} \
        ${_hooks} \
        ${_vips} \
        ${_onelease_hook:+--hook} ${_onelease_hook} \
        ${_lease_database:+--lease-database} ${_lease_database} \
        --lease-time "${ONEAPP_VNF_DHCP4_LEASE_TIME}" \
        --logfile "${ONEAPP_VNF_DHCP4_LOGFILE}" \
        | jq . > "$ONEKEA_DHCP4_CONFIG_TEMP"

    # workaround for missing interface(s)
    if [ -z "$_subnets" ] && \
        { [ -n "$ONEAPP_VNF_DHCP4_INTERFACES" ] || \
        [ -n "$ONEAPP_VNF_DHCP4_INTERFACES_DISABLED" ] ; } ;
    then
        _dhcp4_config_temp=$(< "$ONEKEA_DHCP4_CONFIG_TEMP" \
            jq '.Dhcp4.subnet4 = []' | \
            jq '.Dhcp4."interfaces-config".interfaces = []')
        echo "$_dhcp4_config_temp" | jq . > "$ONEKEA_DHCP4_CONFIG_TEMP"
    fi
}

is_running_dhcp4()
{
    check_pidfile "${ONEKEA_DHCP4_PIDFILE}"
}

enable_dhcp4()
{
    rc-update add kea-dhcp4
}

start_dhcp4()
{
    rc-service kea-dhcp4 start
    msg info "Waiting for Kea to start (pidfile: ${ONEKEA_DHCP4_PIDFILE})..."
    wait_for_pidfile "${ONEKEA_DHCP4_PIDFILE}"
}

restart_dhcp4()
{
    stop_dhcp4
    start_dhcp4
}

reload_dhcp4()
{
    if [ -f "${ONEKEA_DHCP4_PIDFILE}" ] ; then
        _dhcp4_pid=$(cat "${ONEKEA_DHCP4_PIDFILE}")
    else
        _dhcp4_pid=
    fi

    if echo "${_dhcp4_pid}" | grep -q '^[0-9]\+$' ; then
        if kill -0 ${_dhcp4_pid} ; then
            kill -1 ${_dhcp4_pid}
        else
            restart_dhcp4
        fi
    else
        restart_dhcp4
    fi
}

disable_dhcp4()
{
    rc-update del kea-dhcp4 || true
    rc-update del kea-dhcp4 boot default || true
}

stop_dhcp4()
{
    rc-service kea-dhcp4 stop || true

    while is_running_dhcp4 ; do
        sleep 1s
    done

    rm -f "${ONEKEA_DHCP4_PIDFILE}"
}


### VNF KEEPALIVED ############################################################

install_keepalived()
{
    save_keepalived_config
    install_keepalived_notify_script

    # snmp support is not compiled in for Alpine package so no querying of the
    # keepalived status with snmpget but there is now even simpler way:
    #   kill -USR2 $(cat /run/keepalived.pid)
    #   cat /tmp/keepalived.stats
    install_keepalived_ha_status_script
}

install_keepalived_notify_script()
{
    msg info "Install keepalived's notify script from the artifact"

    mv -v "${ONE_SERVICE_SETUP_DIR}/vnf/ha-failover.sh" \
        "${VNF_KEEPALIVED_NOTIFY_SCRIPT}"

    chmod 0755 "${VNF_KEEPALIVED_NOTIFY_SCRIPT}"

    msg info "Install logrotate script: ${VNF_KEEPALIVED_NOTIFY_LOGROTATE}"
    cat > "$VNF_KEEPALIVED_NOTIFY_LOGROTATE" <<EOF
${VNF_KEEPALIVED_NOTIFY_LOGROTATE} {
    compress
    rotate 5
    size 100k
    notifempty
    missingok
    copytruncate
}
EOF
}

install_keepalived_ha_status_script()
{
    msg info "Install keepalived's check cluster status script from the artifact"

    mv -v "${ONE_SERVICE_SETUP_DIR}/vnf/ha-check-status.sh" \
        "${VNF_KEEPALIVED_HA_STATUS_SCRIPT}"

    chmod 0755 "${VNF_KEEPALIVED_HA_STATUS_SCRIPT}"
}

save_keepalived_config()
{
    if [ -f "${VNF_KEEPALIVED_CONFIG}" ] ; then
        msg info "Backup the original keepalived config to '${VNF_KEEPALIVED_CONFIG}~onesave'"
        cp -a "${VNF_KEEPALIVED_CONFIG}" "${VNF_KEEPALIVED_CONFIG}~onesave"
    fi

    if [ ! -d "${VNF_KEEPALIVED_CONFIG_DIR}" ] ; then
        msg info "Creating keepalived config dir '${VNF_KEEPALIVED_CONFIG_DIR}'"
        mkdir -p "${VNF_KEEPALIVED_CONFIG_DIR}"
    fi
}

# arg: <router_id>
is_valid_vrouter_id()
(
    _vrid="$1"
    if printf "$_vrid" | grep -q '^[0-9]\+$' ; then
        [ "$_vrid" -ge 1 ] && [ "$_vrid" -le 255 ]
    else
        return 1
    fi
)

# arg: <user-eth>
get_keepalived_vrid()
(
    _eth="$1"
    _vrid=$(eval "printf \"\$ONEAPP_VNF_KEEPALIVED_${_eth}_VRID\"")
    if [ -z "$_vrid" ] ; then
        # TODO: consider to generate different VRID per instance to not duplicate
        # VRID between different interfaces - it can cause problems
        #
        # we will default to one
        _vrid="${ONEAPP_VNF_KEEPALIVED_VRID}"
    fi

    if is_valid_vrouter_id "$_vrid" ; then
        printf "$_vrid"
    else
        msg error "Invalid virtual router id (must be in 1-255): ${_vrid}"
    fi
)

# arg: <user-eth>
get_keepalived_priority()
(
    _eth="$1"
    _value=$(eval "printf \"\$ONEAPP_VNF_KEEPALIVED_${_eth}_PRIORITY\"")
    if [ -n "$_value" ] ; then
        if printf "$_value" | grep -q '^[-+]\?[0-9]\+$' ; then
            printf "$_value"
        else
            msg error "Invalid virtual router priority (must be a number): ${_value}"
        fi
    else
        # we will default to hundred
        printf ${ONEAPP_VNF_KEEPALIVED_PRIORITY}
    fi
)

# arg: <user-eth>
get_keepalived_interval()
(
    _eth="$1"
    _value=$(eval "printf \"\$ONEAPP_VNF_KEEPALIVED_${_eth}_INTERVAL\"")
    if [ -n "$_value" ] ; then
        printf "$_value"
    else
        # we default to 1 sec
        printf ${ONEAPP_VNF_KEEPALIVED_INTERVAL}
    fi
)

# arg: <user-eth>
return_keepalived_vips()
(
    _eth="$1"
    for _vipname in $(env | \
        sed -n "s/^\(ONEAPP_VROUTER_${_eth}_VIP[0-9]*\)=.*/\1/p" | \
        sort -u) ;
    do
        # print VIP on the stdout
        eval "echo \"\$${_vipname}\""
    done
)

# arg: <user-eth>
return_keepalived_passauth()
(
    _eth="$1"
    _value=$(eval "printf \"\$ONEAPP_VNF_KEEPALIVED_${_eth}_PASSWORD\"")
    if [ -n "$_value" ] || [ -n "$ONEAPP_VNF_KEEPALIVED_PASSWORD" ] ; then
        cat <<EOF
authentication {
  auth_type PASS
  auth_pass ${_value:-${ONEAPP_VNF_KEEPALIVED_PASSWORD}}
}
EOF
    fi
)

# arg: <triplet> [<notify>]
create_keepalived_vrrp_instance()
(
    _triplet="$1"
    _notify="$2"
    _user_eth=$(echo "${_triplet}" | cut -d":" -f1)
    _real_eth=$(echo "${_triplet}" | cut -d":" -f2)
    _one_eth=$(echo "${_triplet}" | cut -d":" -f3)

    cat <<EOF
vrrp_instance ${_user_eth} {
  state BACKUP
  interface ${_real_eth}
  virtual_router_id $(get_keepalived_vrid "${_user_eth}")
  priority $(get_keepalived_priority "${_user_eth}")
  advert_int $(get_keepalived_interval "${_user_eth}")
  virtual_ipaddress {
$(return_keepalived_vips "${_user_eth}" | sed 's/.*/    &/')
  }
$(return_keepalived_passauth "${_user_eth}" | sed 's/.*/  &/')
$(test -n "${_notify}" && echo "${_notify}" | sed 's/.*/  &/')
}

EOF
)

create_keepalived_global_defs()
(
    cat <<EOF
global_defs {
  script_user root
  enable_script_security
}

EOF
)

# arg: <list of triplets>
create_keepalived_vrrp_sync_group()
(
    _triplets="$1"

    cat <<EOF
vrrp_sync_group vrouter {
  group {
$(for _triplet in ${_triplets} ; do echo "    $(printf ${_triplet} | cut -d':' -f1)" ; done ;)
  }

  notify ${VNF_KEEPALIVED_NOTIFY_SCRIPT} root

}

EOF
)

configure_keepalived()
{
    # configuration guard
    if ! to_be_configured KEEPALIVED ; then
        return 0
    fi

    msg info "VNF KEEPALIVED: write Keepalived configuration: ${VNF_KEEPALIVED_CONFIG}"

    # write keepalived.conf
    #
    # keepalived has no validity check of the configuration - so no point to
    # write to a temp file...
    {
        # prepare list of ETHs/VRRPs
        _eths=
        if [ -n "${ONEAPP_VNF_KEEPALIVED_INTERFACES}" ] ; then
            for _iface in ${ONEAPP_VNF_KEEPALIVED_INTERFACES} ; do
                _eth=$(geth1 "$_iface" 3)

                if [ "$_eth" = 'LO' ] ; then
                    msg warning "VNF KEEPALIVED: Loopback cannot be used as a vrrp interface (SKIPPING)"
                    continue
                elif [ -n "$_eth" ] ; then
                    _eths="${_eths} ${_eth}"
                else
                    msg warning "VNF KEEPALIVED: Invalid network interface name: ${_iface} (SKIPPING)"
                    continue
                fi
            done
        else
            # fallback to ETH<NUM>_* designated interfaces
            _eths=$(get_eths "$ONEAPP_VNF_KEEPALIVED_INTERFACES_DISABLED")
        fi

        _triplets=
        for _eth in ${_eths} ; do
            _management_eth=$(eval "printf \"\$ONEAPP_VROUTER_$(geth3 ${_eth} 1)_MANAGEMENT\"")

            if is_true _management_eth ; then
                continue
            else
                _triplet=$(geth3 "${_eth}")
                _triplets="${_triplets} ${_triplet}"
            fi
        done

        # create global_defs
        create_keepalived_global_defs

        # NOTE:
        # Keepalived is flip-flopping its behavior regarding sync groups...
        # It sometimes accepts group with just one interface and sometimes
        # doesn't...
        #
        # I made an issue for it:
        # https://github.com/acassen/keepalived/issues/1912
        #
        # But until they decide what's what I will workaround it like this:

        _triplet_count=$(echo "${_triplets}" | wc -w)

        if [ "$_triplet_count" -gt 1 ] ; then
            # create vrrp sync group
            create_keepalived_vrrp_sync_group "$_triplets"

            # write vrrp instances
            for _triplet in ${_triplets} ; do
                create_keepalived_vrrp_instance "$_triplet"
            done
        elif [ "$_triplet_count" -eq 1 ] ; then
            # write one vrrp instance (notice the 's' at the end of _triplets)
            create_keepalived_vrrp_instance \
                $_triplets \
                "notify ${VNF_KEEPALIVED_NOTIFY_SCRIPT} root"
        else
            msg warning "VNF KEEPALIVED: No network interfaces - empty config"
        fi
    } > "$VNF_KEEPALIVED_CONFIG"
}

is_running_keepalived()
{
    check_pidfile "${VNF_KEEPALIVED_PIDFILE}"
}

enable_keepalived()
{
    rc-update add keepalived
}

start_keepalived()
{
    rc-service keepalived start
    msg info "Waiting for Keepalived to start (pidfile: ${VNF_KEEPALIVED_PIDFILE})..."
    wait_for_pidfile "${VNF_KEEPALIVED_PIDFILE}"
}

restart_keepalived()
{
    stop_keepalived
    rc-service keepalived start
}

reload_keepalived()
{
    # we must restart to trigger stop-start for VNFs (otherwise transition
    # script is not invoked...)
    #rc-service keepalived restart
    restart_keepalived
}

disable_keepalived()
{
    rc-update del keepalived || true
    rc-update del keepalived boot default || true
}

stop_keepalived()
{
    rc-service keepalived stop || true

    while is_running_keepalived ; do
        sleep 1s
    done

    #rm -f "${VNF_KEEPALIVED_PIDFILE}"
}


### VNF DNS ###################################################################

install_dns()
{
    save_unbound_config
    install_one_unbound_service

    # ensure that original unbound service will not start
    rc-service unbound stop || true
    rc-update del unbound || true
}

save_unbound_config()
{
    msg info "Backup the original unbound config to '${VNF_DNS_CONFIG}~onesave'"
    cp -a "${VNF_DNS_CONFIG}" "${VNF_DNS_CONFIG}~onesave"
}

install_one_unbound_service()
{
    # install one-unbound service replacement without supervise-daemon to fix
    # the issue with never completing one-contexd service
    msg info "Install ${VNF_DNS_OPENRC_NAME} service: /etc/init.d/${VNF_DNS_OPENRC_NAME}"

    cat > "/etc/init.d/${VNF_DNS_OPENRC_NAME}" <<EOF
#!/sbin/openrc-run

extra_commands="checkconfig configtest"
extra_started_commands="reload"

name="one-unbound"
description="unbound is a Domain Name Server (DNS) that is used to resolve host names to IP address."
description_checkconfig="Run syntax tests for configuration files only."
description_reload="Kills all children and reloads the configuration."

# Upper case variables are here only for backward compatibility.
: \${cfgfile:=\${UNBOUND_CONFFILE:-/etc/unbound/unbound.conf}}

command=/usr/sbin/unbound
command_args="\$command_args"
pidfile="${VNF_DNS_PIDFILE}"

required_files="\$cfgfile"

depend() {
    need net
    use logger
    provide dns
    after auth-dns entropy
}

checkconfig() {
    ebegin "Checking \$cfgfile"
    /usr/sbin/unbound-checkconf -f "\$cfgfile" >/dev/null
    eend \$?
}

fix_resolv_conf() {
    echo "nameserver 127.0.0.1" > /etc/resolv.conf
    echo "nameserver ::1" >> /etc/resolv.conf
}

start_pre() {
    checkconfig
    fix_resolv_conf
}

reload() {
    start_pre || return \$?

    ebegin "Reloading \$name"
    kill -HUP \$(cat \${pidfile})
    eend \$?
}

EOF

    # permissions
    chmod 0755 "/etc/init.d/${VNF_DNS_OPENRC_NAME}"
}

configure_dns()
{
    # configuration guard
    if ! to_be_configured DNS ; then
        return 0
    fi

    msg info "VNF DNS: configure unbound service as DNS recursor"

    msg info "Create unbound dns recursor configuration file: ${VNF_DNS_CONFIG}"
    if [ -n "$ONEAPP_VNF_DNS_CONFIG" ] ; then
        msg info "Config file provided via 'ONEAPP_VNF_DNS_CONFIG'"
        echo "$ONEAPP_VNF_DNS_CONFIG" | base64 -d > "$VNF_DNS_CONFIG_TEMP"
    else
        create_unbound_config > "$VNF_DNS_CONFIG_TEMP"
    fi

    # last crucial step
    msg info "Check validity of the unbound configuration"
    if unbound-checkconf "$VNF_DNS_CONFIG_TEMP" ; then
        msg info "Saving a new valid configuration: ${VNF_DNS_CONFIG}"
        mv -v "$VNF_DNS_CONFIG_TEMP" "$VNF_DNS_CONFIG"
    else
        exit 1
    fi

    # post step
    msg info "Configure /etc/resolv.conf to use our unbound nameserver"
    {
        echo "nameserver 127.0.0.1"
        echo "nameserver ::1"
    } > /etc/resolv.conf
}

return_dns_forward_zone()
(
    if is_true ONEAPP_VNF_DNS_USE_ROOTSERVERS ; then
        # we are using root servers so no forwarding to other nameservers
        return 0
    fi

    # populate nameservers variable
    _nameservers=
    if [ -n "$ONEAPP_VNF_DNS_NAMESERVERS" ] ; then
        _nameservers="$ONEAPP_VNF_DNS_NAMESERVERS"
    else
        for _eth in $(get_eths "$ONEAPP_VNF_DNS_INTERFACES_DISABLED") ; do
            _management_eth=$(eval "printf \"\$ONEAPP_VROUTER_$(geth3 ${_eth} 1)_MANAGEMENT\"")

            if is_true _management_eth ; then
                continue
            else
                _dns=$(eval "printf \"\$${_eth}_DNS\"")

                # do not forward to your own ip addresses - avoid the loop...
                if ! is_my_ip "$_dns" ; then
                    _nameservers="${_nameservers} ${_dns}"
                fi
            fi
        done
    fi

    cat <<EOF
forward-zone:
    name: "."
$(for _dns in ${_nameservers} ; do echo "    forward-addr: ${_dns}" ; done)

EOF
)

return_dns_root_hints()
(
    if is_true ONEAPP_VNF_DNS_USE_ROOTSERVERS ; then
        # use root servers
        cat <<EOF
root-hints: /usr/share/dns-root-hints/named.root
EOF
    else
        # do not use root servers
        cat <<EOF
# root-hints: /usr/share/dns-root-hints/named.root
EOF
    fi
)

return_listening_dns_interfaces()
(
    _ips=

    if [ -z "$ONEAPP_VNF_DNS_INTERFACES" ] ; then
        # build list of IPs
        for _eth in $(get_eths "$ONEAPP_VNF_DNS_INTERFACES_DISABLED") ; do
            _management_eth=$(eval "printf \"\$ONEAPP_VROUTER_$(geth3 ${_eth} 1)_MANAGEMENT\"")

            if is_true _management_eth ; then
                continue
            else
                # TODO: IPv6
                _ip=$(eval "printf \"\$${_eth}_IP\"")
                _ips="${_ips} ${_ip}"

                # aliases
                _aliases=$(env | \
                    sed -n "s/^${_eth}_\(ALIAS[0-9]\+\)_.*/\1/p" | sort -u)
                for _alias in ${_aliases} ; do
                    _ip=$(eval "printf \"\$${_eth}_${_alias}_IP\"")
                    _ips="${_ips} ${_ip}"
                done
            fi

            # add all VIPs
            for _ip in $(return_keepalived_vips "$(geth3 ${_eth} 1)") ; do
                _ips="${_ips} ${_ip}"
            done
        done
    else
        # user provided us with list of interfaces (<ip>[@<port>], eth0, eth0/<ip>[@<port>])
        for _iface in ${ONEAPP_VNF_DNS_INTERFACES} ; do
            # interface name must be ETH<num>
            _user_eth=$(echo "$_iface" | awk '
                BEGIN {
                    FS="/";
                }
                {
                    if (($1 ~ /^ETH[0-9]+$/) || ($1 == "LO"))
                        print $1;
                }')

            # ip can be ipv4 or ipv6 and with optional port via postfix: @<port>
            # so we just take the whole thing and leave it to unbound to parse
            # it...
            _ip=$(echo "$_iface" | awk 'BEGIN{FS="/"} {print $2}')

            if [ -z "$_user_eth" ] ; then
                # _eth is empty but _iface is not, so that means _iface is not
                # a name of an interface -> must be an IP
                _ips="${_ips} ${_iface}"
            else
                if [ -n "$_ip" ] ; then
                    # the simplest case
                    _ips="${_ips} ${_ip}"
                else
                    # we have only interface name
                    # TODO: IPv6
                    _user_eth=$(geth1 "$_user_eth" 1)

                    if [ -z "$_user_eth" ] ; then
                        msg warning "VNF DNS: Invalid network interface name: ${_iface} (SKIPPING)"
                        continue
                    elif [ "$_user_eth" = 'LO' ] ; then
                        # loopback is enabled by default
                        continue
                    fi

                    _ip=$(eval "printf \"\$$(geth1 ${_user_eth} 3)_IP\"")
                    _ips="${_ips} ${_ip}"

                    # aliases
                    _aliases=$(env | \
                        sed -n "s/^$(geth1 ${_user_eth} 3)_\(ALIAS[0-9]\+\)_.*/\1/p" | \
                        sort -u)
                    for _alias in ${_aliases} ; do
                        _ip=$(eval "printf \"\$$(geth1 ${_user_eth} 3)_${_alias}_IP\"")
                        _ips="${_ips} ${_ip}"
                    done

                    # add all VIPs
                    for _ip in $(return_keepalived_vips "$_user_eth") ; do
                        _ips="${_ips} ${_ip}"
                    done
                fi
            fi
        done
    fi

    # sort interfaces
    echo "$_ips" | sed 's/[[:space:]]\+/\n/g' | sort -u
)

# TODO: revert this:
#   we need to listen on interfaces which can be brought up later by
#   keepalived... so we comment out actual interfaces and provide *all*
return_dns_interfaces()
(
    _ips=$(return_listening_dns_interfaces)

    # we have list of IPs
    cat <<EOF
# LOCALHOST:
interface: 127.0.0.1
interface: ::1
# ALL:
# interface: 0.0.0.0
# interface: ::0
# WHITELIST:
$(for _ip in ${_ips} ; do echo "interface: ${_ip}" ; done)
EOF
)

return_dns_access_control()
(
    # in unbound parlance: we need list of netblocks (networks)
    _netblocks=

    if [ -n "$ONEAPP_VNF_DNS_ALLOWED_NETWORKS" ] ; then
        _netblocks="${ONEAPP_VNF_DNS_ALLOWED_NETWORKS}"
    else
        # 1. take ip and drop port portion (after '@')
        # 2. resolve ip to network address and subnet prefix
        _netblocks=$(return_listening_dns_interfaces | cut -d"@" -f1 | \
            sort -u | python3 -c '
import sys
import ipaddress
import psutil

myips = []
netblocks = []

for line in sys.stdin:
    myips.extend(line.strip().split(" "))

for iface_name, addrs in psutil.net_if_addrs().items():
    for addr in addrs:
        ip = {}
        # TODO: IPv6
        if addr.family.name == "AF_INET":
            if addr.address not in myips:
                continue

            ip["network"] = str(ipaddress.IPv4Interface(addr.address
              + "/" + addr.netmask).network.network_address)

            ip["prefix"] = str(ipaddress.IPv4Interface(addr.address
              + "/" + addr.netmask).network.prefixlen)

            netblocks.append(ip["network"] + "/" + ip["prefix"])

for netblock in netblocks:
    print(netblock)
                ' | sort -u)
    fi

    # TODO: IPv6
    # we allow access from these netblocks
    cat <<EOF
# DEFAULT RULES:
access-control: 0.0.0.0/0 refuse
access-control: ::0/0 refuse
access-control: 127.0.0.0/8 allow
access-control: ::1 allow
access-control: ::ffff:127.0.0.1 allow
# WHITELIST:
$(for _netblock in ${_netblocks} ; do \
    echo "access-control: ${_netblock} allow" ; \
done)
EOF
)

# TODO: not sure about this - I think it is best to leave it
return_dns_outgoing_interfaces()
(
    cat <<EOF
EOF
)

# arg: udp|tcp|udp-upstream|tcp-upstream
get_dns_protocol_yesno()
(
    if is_true ONEAPP_VNF_DNS_TCP_DISABLED && \
        is_true ONEAPP_VNF_DNS_UDP_DISABLED ;
    then
        msg error "VNF DNS: both protocols (TCP and UDP) are requested to be disabled..."
    fi

    if is_true ONEAPP_VNF_DNS_TCP_DISABLED ; then
        _tcp=no
    else
        _tcp=yes
    fi

    if is_true ONEAPP_VNF_DNS_UDP_DISABLED ; then
        _udp=no
    else
        _udp=yes
    fi

    case "$1" in
        udp|udp-upstream)
            printf "$_udp"
            ;;
        tcp)
            printf "$_tcp"
            ;;
        tcp-upstream)
            if is_true _udp ; then
                # udp is allowed so TCP only upstream will be no
                printf no
            else
                # udp is NOT allowed so upstream is TCP only
                printf yes
            fi
            ;;
    esac
)

create_unbound_config()
(
    cat <<EOF
server:
    # verbosity number, 0 is least verbose. 1 is default.
    verbosity: 1

    # specify the interfaces to answer queries from by ip-address.
    # The default is to listen to localhost (127.0.0.1 and ::1).
    # specify 0.0.0.0 and ::0 to bind to all available interfaces.
    # specify every interface[@port] on a new 'interface:' labelled line.
    # The listen interfaces are not changed on reload, only on restart.
    #
$(return_dns_interfaces | sed 's/.*/    &/')

    # port to answer queries from
    # port: 53

    # specify the interfaces to send outgoing queries to authoritative
    # server from by ip-address. If none, the default (all) interface
    # is used. Specify every interface on a 'outgoing-interface:' line.
    # outgoing-interface: 192.0.2.153
    # outgoing-interface: 2001:DB8::5
    # outgoing-interface: 2001:DB8::6
    #
$(return_dns_outgoing_interfaces | sed 's/.*/    &/')

    # msec for waiting for an unknown server to reply.  Increase if you
    # are behind a slow satellite link, to eg. 1128.
    unknown-server-time-limit: ${ONEAPP_VNF_DNS_UPSTREAM_TIMEOUT}

    # Enable IPv4, "yes" or "no".
    do-ip4: yes

    # Enable IPv6, "yes" or "no".
    do-ip6: yes

    # Enable UDP, "yes" or "no".
    do-udp: $(get_dns_protocol_yesno 'udp')

    # Enable TCP, "yes" or "no".
    do-tcp:  $(get_dns_protocol_yesno 'tcp')

    # upstream connections use TCP only (and no UDP), "yes" or "no"
    # useful for tunneling scenarios, default no.
    tcp-upstream: $(get_dns_protocol_yesno 'tcp-upstream')

    # upstream connections also use UDP (even if do-udp is no).
    # useful if if you want UDP upstream, but don't provide UDP downstream.
    udp-upstream-without-downstream: $(get_dns_protocol_yesno 'udp-upstream')

    # control which clients are allowed to make (recursive) queries
    # to this server. Specify classless netblocks with /size and action.
    # By default everything is refused, except for localhost.
    # Choose deny (drop message), refuse (polite error reply),
    # allow (recursive ok), allow_setrd (recursive ok, rd bit is forced on),
    # allow_snoop (recursive and nonrecursive ok)
    # deny_non_local (drop queries unless can be answered from local-data)
    # refuse_non_local (like deny_non_local but polite error reply).
$(return_dns_access_control | sed 's/.*/    &/')

    # the time to live (TTL) value lower bound, in seconds. Default 0.
    # If more than an hour could easily give trouble due to stale data.
    cache-min-ttl: 0

    # the time to live (TTL) value cap for RRsets and messages in the
    # cache. Items are not cached for longer. In seconds.
    cache-max-ttl: ${ONEAPP_VNF_DNS_MAX_CACHE_TTL}

    # TODO: chroot
    # if given, a chroot(2) is done to the given directory.
    # i.e. you can chroot to the working directory, for example,
    # for extra security, but make sure all files are in that directory.
    #
    # If chroot is enabled, you should pass the configfile (from the
    # commandline) as a full path from the original root. After the
    # chroot has been performed the now defunct portion of the config
    # file path is removed to be able to reread the config after a reload.
    #
    # All other file paths (working dir, logfile, roothints, and
    # key files) can be specified in several ways:
    #     o as an absolute path relative to the new root.
    #     o as a relative path to the working directory.
    #     o as an absolute path relative to the original root.
    # In the last case the path is adjusted to remove the unused portion.
    #
    # The pid file can be absolute and outside of the chroot, it is
    # written just prior to performing the chroot and dropping permissions.
    #
    # Additionally, unbound may need to access /dev/urandom (for entropy).
    # How to do this is specific to your OS.
    #
    # If you give "" no chroot is performed. The path must not end in a /.
    # chroot: ""

    # if given, user privileges are dropped (after binding port),
    # and the given username is assumed. Default is user "unbound".
    # If you give "" no privileges are dropped.
    # username: "unbound"

    # the working directory. The relative files in this config are
    # relative to this directory. If you give "" the working directory
    # is not changed.
    # If you give a server: directory: dir before include: file statements
    # then those includes can be relative to the working directory.
    # directory: ""

    # the log file, "" means log to stderr.
    # Use of this option sets use-syslog to "no".
    # logfile: ""

    # Log to syslog(3) if yes. The log facility LOG_DAEMON is used to
    # log to. If yes, it overrides the logfile.
    use-syslog: yes

    # Log identity to report. if empty, defaults to the name of argv[0]
    # (usually "unbound").
    log-identity: ""

    # print UTC timestamp in ascii to logfile, default is epoch in seconds.
    log-time-ascii: yes

    # print one line with time, IP, name, type, class for every query.
    log-queries: no

    # print one line per reply, with time, IP, name, type, class, rcode,
    # timetoresolve, fromcache and responsesize.
    log-replies: no

    # print log lines that say why queries return SERVFAIL to clients.
    log-servfail: yes

    # file to read root hints from.
    # get one from https://www.internic.net/domain/named.cache
$(return_dns_root_hints | sed 's/.*/    &/')

    # enable to not answer id.server and hostname.bind queries.
    hide-identity: yes

    # enable to not answer version.server and version.bind queries.
    hide-version: yes

    # Serve expired responses from cache, with TTL 0 in the response,
    # and then attempt to fetch the data afresh.
    serve-expired: no

# IMPORTANT:
# unbound service in Alpine is run as an open-rc service AND under
# supervisor-daemon (!) - so unbound process must be run in foreground...
#
# ...but due to the issue with supervise-daemon - one-contextd service never
# terminated... so we provide our own service 'one-unbound' which requires
# unbound process to properly daemonize itself...

    # we need to know where are pid file is stored
    pidfile: "${VNF_DNS_PIDFILE}"

    # Use systemd socket activation for UDP, TCP, and control sockets.
    use-systemd: no

    # Detach from the terminal, run in background, "yes" or "no".
    # Set the value to "no" when unbound runs as systemd service.
    do-daemonize: yes

# Remote control config section.
remote-control:
    control-enable: no

# Forward zones
# Create entries like below, to make all queries for 'example.com' and
# 'example.org' go to the given list of servers. These servers have to handle
# recursion to other nameservers. List zero or more nameservers by hostname
# or by ipaddress. Use an entry with name "." to forward all queries.
# If you enable forward-first, it attempts without the forward if it fails.
# forward-zone:
#     name: "example.com"
#     forward-addr: 192.0.2.68
#     forward-addr: 192.0.2.73@5355  # forward to port 5355.
#     forward-first: no
#     forward-tls-upstream: no
#     forward-no-cache: no
# forward-zone:
#     name: "example.org"
#     forward-host: fwd.example.com
$(return_dns_forward_zone)

EOF
)

is_running_dns()
{
    check_pidfile "${VNF_DNS_PIDFILE}"
}

enable_dns()
{
    rc-update add ${VNF_DNS_OPENRC_NAME}
}

start_dns()
{
    rc-service ${VNF_DNS_OPENRC_NAME} start
    msg info "Waiting for ${VNF_DNS_OPENRC_NAME} to start (pidfile: ${VNF_DNS_PIDFILE})..."
    wait_for_pidfile "${VNF_DNS_PIDFILE}"
}

restart_dns()
{
    stop_dns
    start_dns
}

reload_dns()
{
    # reload must be restart because unbound will not otherwise update
    # listening interfaces...
    restart_dns
}

disable_dns()
{
    rc-update del ${VNF_DNS_OPENRC_NAME} || true
    rc-update del ${VNF_DNS_OPENRC_NAME} boot default || true
}

stop_dns()
{
    rc-service ${VNF_DNS_OPENRC_NAME} stop || true

    while is_running_dns ; do
        sleep 1s
    done

    rm -f "${VNF_DNS_PIDFILE}"
}


### VNF ROUTER4 ###############################################################

# TODO: make router6 for IPv6
configure_router4()
{
    # configuration guard
    if ! to_be_configured ROUTER4 ; then
        return 0
    fi

    msg info "VNF ROUTER4: configure IPv4 forwarding"

    if is_in_list ROUTER4 "$ENABLED_VNF_LIST" ; then
        _ipv4_forwarding=1
    else
        _ipv4_forwarding=0
    fi

    setup_forwarding_sysctl_conf ${_ipv4_forwarding}
}

# arg: <0|1>
setup_forwarding_sysctl_conf()
(
    _ipv4_forwarding="$1"

    # build list of interfaces with disabled forwarding
    _enabled_forwarding=
    _disabled_forwarding=
    if [ -n "$ONEAPP_VNF_ROUTER4_INTERFACES" ] ; then
        for _eth in $(get_eths) ; do
            _to_disable="$_eth"
            _management_eth=$(eval "printf \"\$ONEAPP_VROUTER_$(geth3 ${_eth} 1)_MANAGEMENT\"")

            if ! is_true _management_eth ; then
                for _iface in ${ONEAPP_VNF_ROUTER4_INTERFACES} ; do
                    # interface name must be ETH<num>
                    _enabled_eth=$(geth1 "$_iface" 3)

                    if [ -z "$_enabled_eth" ] ; then
                        msg warning "VNF ROUTER4: Invalid network interface name: ${_iface} (SKIPPING)"
                        continue
                    elif [ "${_enabled_eth}" = "$_eth" ] ; then
                        # we will not disable _eth
                        _to_disable=
                        break
                    fi
                done
            fi

            if [ -n "$_to_disable" ] ; then
                _disabled_forwarding="${_disabled_forwarding} $(geth3 ${_to_disable} 2)"
            else
                _enabled_forwarding="${_enabled_forwarding} $(geth3 ${_eth} 2)"
            fi
        done
    else
        for _eth in $(get_eths) ; do
            _management_eth=$(eval "printf \"\$ONEAPP_VROUTER_$(geth3 ${_eth} 1)_MANAGEMENT\"")

            if is_true _management_eth ; then
                _disabled_forwarding="${_disabled_forwarding} $(geth3 ${_eth} 2)"
            elif is_disabled_eth "$(geth3 ${_eth} 1)" "$ONEAPP_VNF_ROUTER4_INTERFACES_DISABLED" ; then
                _disabled_forwarding="${_disabled_forwarding} $(geth3 ${_eth} 2)"
            else
                _enabled_forwarding="${_enabled_forwarding} $(geth3 ${_eth} 2)"
            fi
        done
    fi

    cat > "${VNF_ROUTER4_SYSCTL}" <<EOF
# VNF ROUTER4

net.ipv4.ip_forward = 0
net.ipv4.conf.all.forwarding = 0
net.ipv4.conf.default.forwarding = 0

# forwarding per interface:

$(for i in ${_enabled_forwarding} ; do
    echo "net.ipv4.conf.${i}.forwarding = ${_ipv4_forwarding}" ;
done ;
for i in ${_disabled_forwarding} ; do
    echo "net.ipv4.conf.${i}.forwarding = 0" ;
done ;
echo ;)
EOF

    chmod 0644 "${VNF_ROUTER4_SYSCTL}"
)

enable_router4()
{
    if [ -f "$VNF_ROUTER4_SYSCTL" ] ; then
        msg info "VNF ROUTER4: already enabled"
    else
        if [ -f "$VNF_ROUTER4_SYSCTL"-disabled ] ; then
            msg info "VNF ROUTER4: is about to be enabled"
            mv -v "$VNF_ROUTER4_SYSCTL"-disabled "$VNF_ROUTER4_SYSCTL"
        else
            msg error "VNF ROUTER4: no sysctl config file to be enabled (is the service configured?)..."
        fi
    fi
}

disable_router4()
{
    if [ -f "$VNF_ROUTER4_SYSCTL" ] ; then
        msg info "VNF ROUTER4: is about to be disabled"
        mv -v "$VNF_ROUTER4_SYSCTL" "$VNF_ROUTER4_SYSCTL"-disabled
    else
        msg info "VNF ROUTER4: already disabled"
    fi
}

# TODO: IPv6
reload_router4()
{
    # there is no process to reload, we just ensure that the
    # configuration is in place by setting sysctl again...

    if [ -f "$VNF_ROUTER4_SYSCTL" ] ; then
        sysctl -p "$VNF_ROUTER4_SYSCTL"
    fi
}

# TODO: IPv6
start_router4()
{
    # enable forwarding/routing feature on the system
    enable_router4
    reload_router4
}

# TODO: IPv6
stop_router4()
{
    # stop forwarding/routing on the system
    _sysctl_names=$(sysctl -a | \
        awk '/^net\.ipv4\.conf\.[^.]+\.forwarding/ {print $1}')

    for _sysctl_name in ${_sysctl_names} ; do
        sysctl -w "${_sysctl_name}=0"
    done
}


### VNF NAT ###################################################################

install_nat()
{
    # open-rc service
    install_nat_service

    # install empty NAT iptables rules
    install_nat_rules
}

fix_iptables_service()
{
    # run in subshell...
    (
        . /etc/conf.d/iptables
        touch "$IPTABLES_SAVE"
    )
}

install_nat_service()
{
    msg info "Install ${VNF_NAT4_OPENRC_NAME} service: /etc/init.d/${VNF_NAT4_OPENRC_NAME}"

    cat > "/etc/init.d/${VNF_NAT4_OPENRC_NAME}" <<EOF
#!/sbin/openrc-run

description="ONE-NAT4 is a provider of NAT iptables rules"

iptables_restore=$(command -v iptables-restore)

depend() {
    after firewall
    use logger
}

check_iptables_restore() {
    if ! [ -x "\${iptables_restore}" ] ; then
        eerror "Missing iptables-restore command!"
        eerror "'\${iptables_restore}' does not exist"
        eerror "or is not an executable"
        return 1
    fi
    return 0
}

start() {
    check_iptables_restore || return 1
    ebegin "Starting \${SVCNAME}"
    "\${iptables_restore}" --table=nat < "${VNF_NAT4_IPTABLES_RULES}-enabled"
    eend \$?
}

stop() {
    check_iptables_restore || return 1
    ebegin "Stopping \${SVCNAME}"
    "\${iptables_restore}" --table=nat < "${VNF_NAT4_IPTABLES_RULES}-disabled"
    eend \$?
}

EOF

    chmod 0755 "/etc/init.d/${VNF_NAT4_OPENRC_NAME}"
}

install_nat_rules()
{
    msg info "Install NAT rules files for ${VNF_NAT4_OPENRC_NAME} service"

    cat > "${VNF_NAT4_IPTABLES_RULES}-disabled" <<EOF
*nat
:PREROUTING ACCEPT
:INPUT ACCEPT
:OUTPUT ACCEPT
:POSTROUTING ACCEPT
COMMIT
EOF

    cp "${VNF_NAT4_IPTABLES_RULES}-disabled" "${VNF_NAT4_IPTABLES_RULES}-enabled"

    chmod 0644 "${VNF_NAT4_IPTABLES_RULES}-enabled"
    chmod 0644 "${VNF_NAT4_IPTABLES_RULES}-disabled"
}

configure_nat4()
{
    # configuration guard
    if ! to_be_configured NAT4 ; then
        return 0
    fi

    msg info "Configure NAT4 rules: ${VNF_NAT4_IPTABLES_RULES}-enabled"

    # prepare list of external interfaces
    _externals=
    _eths=

    if [ -z "${ONEAPP_VNF_NAT4_INTERFACES_OUT_DISABLED}" ] ; then
        # normal flow
        _eths="${ONEAPP_VNF_NAT4_INTERFACES_OUT}"
    else
        # we provided negated interface(s)
        _eths=
        _eths_tmp=$(get_eths "${ONEAPP_VNF_NAT4_INTERFACES_OUT_DISABLED}")

        for _eth in ${_eths_tmp} ; do
            _eths="${_eths} $(geth3 ${_eth} 1)"
        done
    fi

    for _iface in ${_eths} ; do
        # interface name must be ETH<num>
        _eth=$(geth1 "$_iface" 1)

        if [ -z "$_eth" ] ; then
            msg warning "VNF NAT4: Invalid network interface name: ${_iface} (SKIPPING)"
            continue
        elif [ "$_eth" = 'LO' ] ; then
            msg warning "VNF NAT4: Loopback serves now as of one the external interfaces for NAT..."
        fi

        # shellcheck disable=SC2034
        _management_eth=$(eval "printf \"\$ONEAPP_VROUTER_${_eth}_MANAGEMENT\"")
        if ! is_true _management_eth ; then
            _externals="${_externals} $(geth1 ${_eth} 2)"
        fi
    done

    cat > "${VNF_NAT4_IPTABLES_RULES}-enabled" <<EOF
*nat
:PREROUTING ACCEPT
:INPUT ACCEPT
:OUTPUT ACCEPT
:POSTROUTING ACCEPT
$(for _eth in ${_externals} ; do echo "-A POSTROUTING -o ${_eth} -j MASQUERADE" ; done)
COMMIT
EOF

    chmod 0644 "${VNF_NAT4_IPTABLES_RULES}-enabled"
}

# TODO: improve with a separate chain
# arg: <rules-file>
wait_for_nat_rules()
(
    _rules_file="$1"
    _timeout=60 # we abort after a minute at most...

    _desired_state=$(grep '^-A POSTROUTING .* -j MASQUERADE' "${_rules_file}" | \
        sha256sum | cut -d" " -f1)

    while [ "$_timeout" -gt 0 ] ; do
        _actual_state=$(iptables -4 -t nat -S POSTROUTING | \
            grep -v -e 'one-snat4' -e 'one-dnat4' | \
            grep '^-A POSTROUTING' | \
            sha256sum | cut -d" " -f1)

        if [ "$_desired_state" = "$_actual_state" ] ; then
            break
        fi

        sleep 1s
        _timeout=$(( _timeout - 1 ))
    done
)

# TODO: ip6tables
enable_nat4()
{
    rc-update add ${VNF_NAT4_OPENRC_NAME}
}

start_nat4()
{
    rc-service ${VNF_NAT4_OPENRC_NAME} start
    msg info "Waiting for NAT4 rules to be loaded..."
    wait_for_nat_rules "${VNF_NAT4_IPTABLES_RULES}-enabled"
}

restart_nat4()
{
    stop_nat4
    start_nat4
}

reload_nat4()
{
    # for simplicity...
    restart_nat4
}

disable_nat4()
{
    rc-update del ${VNF_NAT4_OPENRC_NAME} || true
    rc-update del ${VNF_NAT4_OPENRC_NAME} boot default || true
}

stop_nat4()
{
    rc-service ${VNF_NAT4_OPENRC_NAME} stop || true
    msg info "Waiting for NAT4 rules to be cleared..."
    wait_for_nat_rules "${VNF_NAT4_IPTABLES_RULES}-disabled"
}


### VNF SDNAT #################################################################

configure_sdnat4()
{
    # configuration guard
    if ! to_be_configured SDNAT4 ; then
        return 0
    fi

    msg info " VNF SDNAT4: Create SDNAT4 section in the configuration file: ${ONE_VNF_SERVICE_CONFIG}"

    # prepare list of external interfaces
    _externals=
    _eths=

    if [ -z "${ONEAPP_VNF_SDNAT4_INTERFACES_DISABLED}" ] ; then
        # normal flow
        _eths="${ONEAPP_VNF_SDNAT4_INTERFACES}"
    else
        # we provided negated interface(s)
        _eths=
        _eths_tmp=$(get_eths "${ONEAPP_VNF_SDNAT4_INTERFACES_DISABLED}")

        for _eth in ${_eths_tmp} ; do
            _eths="${_eths} $(geth3 ${_eth} 1)"
        done
    fi

    _interfaces=
    for _iface in ${_eths} ; do
        # interface name must be ETH<num>
        _eth=$(geth1 "$_iface" 1)

        if [ -z "$_eth" ] ; then
            msg warning "VNF SDNAT4: Invalid network interface name: ${_iface} (SKIPPING)"
            continue
        elif [ "$_eth" = 'LO' ] ; then
            # TODO: is this error??
            msg warning "VNF SDNAT4: Loopback serves now as of one the external interfaces for SNAT/DNAT..."
        fi

        # shellcheck disable=SC2034
        _management_eth=$(eval "printf \"\$ONEAPP_VROUTER_${_eth}_MANAGEMENT\"")
        if ! is_true _management_eth ; then
            _interface_pair="{
                \"one-name\": \"$(geth1 ${_eth} 3)\",
                \"real-name\": \"$(geth1 ${_eth} 2)\"
                }"
            _interfaces="${_interfaces}${_interfaces:+, }${_interface_pair}"
        fi
    done

    # inject the sdnat4 section into one-vnf service's config file
    if is_true ONEAPP_VNF_SDNAT4_ENABLED ; then
        _enabled="true"
    else
        _enabled="false"
    fi
    if is_true ONEAPP_VNF_SDNAT4_ONEGATE_ENABLED ; then
        _onegate="true"
    else
        _onegate="false"
    fi
    _current_config=$(cat "${ONE_VNF_SERVICE_CONFIG}")
    jq -s '.[0] + .[1]' > "${ONE_VNF_SERVICE_CONFIG}" <<EOF
${_current_config}
{
    "sdnat4": {
        "enabled": ${_enabled},
        "onegate": ${_onegate},
        "interfaces": [ ${_interfaces} ],
        "refresh-rate": ${ONEAPP_VNF_SDNAT4_REFRESH_RATE}
    }
}
EOF
}

is_running_sdnat4()
{
    # one-vnf service takes care of it

    _state=$("${ONE_VNF_SERVICE_SCRIPT}" -c "${ONE_VNF_SERVICE_CONFIG}" \
        get sdnat4)

    if [ "${_state}" = 'enabled' ] && check_pidfile "${ONE_VNF_PIDFILE}" ; then
        return 0
    else
        return 1
    fi
}

enable_sdnat4()
{
    # one-vnf service takes care of it
    "${ONE_VNF_SERVICE_SCRIPT}" -c "${ONE_VNF_SERVICE_CONFIG}" \
        set sdnat4 enabled
}

start_sdnat4()
{
    # one-vnf service takes care of it
    enable_sdnat4
    if is_running_sdnat4 ; then
        reload_sdnat4
    else
        rc-service ${ONE_VNF_OPENRC_NAME} start
    fi
}

restart_sdnat4()
{
    # one-vnf service takes care of it
    stop_sdnat4
    start_sdnat4
}

reload_sdnat4()
{
    # one-vnf service takes care of it
    rc-service ${ONE_VNF_OPENRC_NAME} reload
}

disable_sdnat4()
{
    # one-vnf service takes care of it
    "${ONE_VNF_SERVICE_SCRIPT}" -c "${ONE_VNF_SERVICE_CONFIG}" \
        set sdnat4 disabled
}

stop_sdnat4()
{
    # one-vnf service takes care of it
    if is_running_sdnat4 ; then
        disable_sdnat4
        reload_sdnat4
    fi
}


### VNF LB ####################################################################

configure_lb()
{
    # configuration guard
    if ! to_be_configured LB ; then
        return 0
    fi

    msg info "VNF LB: Create LB section in the configuration file: ${ONE_VNF_SERVICE_CONFIG}"

    # prepare list of external interfaces
    _eths=

    if [ -z "${ONEAPP_VNF_LB_INTERFACES_DISABLED}" ] ; then
        # normal flow
        _eths="${ONEAPP_VNF_LB_INTERFACES}"
    else
        # we provided negated interface(s)
        _eths=
        _eths_tmp=$(get_eths "${ONEAPP_VNF_LB_INTERFACES_DISABLED}")

        for _eth in ${_eths_tmp} ; do
            _eths="${_eths} $(geth3 ${_eth} 1)"
        done
    fi

    _interfaces=
    for _iface in ${_eths} ; do
        # interface name must be ETH<num>
        _eth=$(geth1 "$_iface" 1)

        if [ -z "$_eth" ] ; then
            msg warning "VNF LB: Invalid network interface name: ${_iface} (SKIPPING)"
            continue
        elif [ "$_eth" = 'LO' ] ; then
            # TODO: is this error??
            msg warning "VNF LB: Loopback serves now as of one the external interfaces for Loadbalancing..."
        fi

        # shellcheck disable=SC2034
        _management_eth=$(eval "printf \"\$ONEAPP_VROUTER_${_eth}_MANAGEMENT\"")
        if ! is_true _management_eth ; then
            _interface_pair="{
                \"one-name\": \"$(geth1 ${_eth} 3)\",
                \"real-name\": \"$(geth1 ${_eth} 2)\"
                }"
            _interfaces="${_interfaces}${_interfaces:+, }${_interface_pair}"
        fi
    done

    # create list of lb configs
    if [ -n "${ONEAPP_VNF_LB_CONFIG}" ] ; then
        msg info "VNF LB: Save LB(s) configuration provided by 'ONEAPP_VNF_LB_CONFIG'"
        if _lb_list=$(echo "$ONEAPP_VNF_LB_CONFIG" | base64 -d) ; then
            _lb_list="[ ${_lb_list} ]"
        else
            msg error "VNF LB: Value in 'ONEAPP_VNF_LB_CONFIG' must be a json encoded in BASE64 - ABORT"
            exit 1
        fi
    else
        _lb_list='[]'
        for i in $(return_all_loadbalancer_indices) ; do
            _lb=$(return_loadbalancer "${i}")
            _lb_list=$(echo "${_lb_list}" | \
                jq --argjson lb "${_lb}" '. += [$lb]')
        done
    fi

    # inject the loadbalancer section into one-vnf service's config file
    if is_true ONEAPP_VNF_LB_ENABLED ; then
        _enabled="true"
    else
        _enabled="false"
    fi
    if is_true ONEAPP_VNF_LB_ONEGATE_ENABLED ; then
        _onegate="true"
    else
        _onegate="false"
    fi
    _current_config=$(cat "${ONE_VNF_SERVICE_CONFIG}")
    jq -s '.[0] + .[1]' > "${ONE_VNF_SERVICE_CONFIG}" <<EOF
${_current_config}
{
    "loadbalancer": {
        "enabled": ${_enabled},
        "onegate": ${_onegate},
        "interfaces": [ ${_interfaces} ],
        "refresh-rate": ${ONEAPP_VNF_LB_REFRESH_RATE},
        "fwmark-offset": ${ONEAPP_VNF_LB_FWMARK_OFFSET},
        "lbs": ${_lb_list}
    }
}
EOF
}

return_all_loadbalancer_indices()
(
    env | \
        sed -n "s/^ONEAPP_VNF_LB\([0-9][0-9]*\)_.*/\1/p" | \
        sort -un
)

# arg: <lb-index>
return_all_real_server_indices()
(
    _lb_index="$1"
    env | \
        sed -n "s/^ONEAPP_VNF_LB${_lb_index}_SERVER\([0-9][0-9]*\)_.*/\1/p" | \
        sort -un
)

# arg: <lb-index>
return_loadbalancer()
(
    _lb_index="$1"
    _lb_config="{
        \"index\": ${_lb_index},
        \"real-servers\": []
    }"

    for _item in $(env | \
        sed -n "s/^ONEAPP_VNF_LB${_lb_index}_\(.*\)=.*/\1/p" | \
        sort -u) ;
    do
        # add new field to the lb object
        _key=''
        _item=$(echo "${_item}" | tr '[:lower:]' '[:upper:]')
        case "${_item}" in
            IP)
                _key='lb-address'
                ;;
            PROTOCOL)
                _key='lb-protocol'
                ;;
            PORT)
                _key='lb-port'
                ;;
            METHOD)
                _key='lb-method'
                ;;
            FWMARK)
                _key='lb-fwmark'
                ;;
            SCHEDULER)
                _key='lb-scheduler'
                ;;
            TIMEOUT)
                _key='lb-timeout'
                ;;
            *)
                continue
                ;;
        esac
        _value=$(eval "echo \"\$ONEAPP_VNF_LB${_lb_index}_${_item}\"")
        _lb_config=$(echo "${_lb_config}" | \
            jq --arg item_value "${_value}" ". + {\"${_key}\": \$item_value}")
    done

    # loop through all backends (real servers)
    for i in $(return_all_real_server_indices "${_lb_index}") ; do
        _real_server=$(return_real_server "${_lb_index}" "${i}")
        _lb_config=$(echo "${_lb_config}" | \
            jq --argjson server "${_real_server}" '."real-servers" += [$server]')
    done

    echo "${_lb_config}"
)

# arg: <lb-index> <server-index>
return_real_server()
(
    _lb_index="$1"
    _srv_index="$2"
    _real_server='{}'

    for _item in $(env | \
        sed -n "s/^ONEAPP_VNF_LB${_lb_index}_SERVER${_srv_index}_\(.*\)=.*/\1/p" | \
        sort -u) ;
    do
        # add new field to the real server object
        _key=''
        _item=$(echo "${_item}" | tr '[:lower:]' '[:upper:]')
        case "${_item}" in
            HOST)
                _key='server-host'
                ;;
            PORT)
                _key='server-port'
                ;;
            WEIGHT)
                _key='server-weight'
                ;;
            ULIMIT)
                _key='server-ulimit'
                ;;
            LLIMIT)
                _key='server-llimit'
                ;;
            *)
                continue
                ;;
        esac
        _value=$(eval "echo \"\$ONEAPP_VNF_LB${_lb_index}_SERVER${_srv_index}_${_item}\"")
        _real_server=$(echo "${_real_server}" | \
            jq --arg item_value "${_value}" ". + {\"${_key}\": \$item_value}")
    done
    echo "${_real_server}"
)

is_running_lb()
{
    # one-vnf service takes care of it

    _lb_state=$("${ONE_VNF_SERVICE_SCRIPT}" -c "${ONE_VNF_SERVICE_CONFIG}" \
        get loadbalancer)

    if [ "${_lb_state}" = 'enabled' ] && check_pidfile "${ONE_VNF_PIDFILE}" ; then
        return 0
    else
        return 1
    fi
}

enable_lb()
{
    # one-vnf service takes care of it
    "${ONE_VNF_SERVICE_SCRIPT}" -c "${ONE_VNF_SERVICE_CONFIG}" \
        set loadbalancer enabled
}

start_lb()
{
    # one-vnf service takes care of it
    enable_lb
    if is_running_lb ; then
        reload_lb
    else
        rc-service ${ONE_VNF_OPENRC_NAME} start
    fi
}

restart_lb()
{
    # one-vnf service takes care of it
    stop_lb
    start_lb
}

reload_lb()
{
    # one-vnf service takes care of it
    rc-service ${ONE_VNF_OPENRC_NAME} reload
}

disable_lb()
{
    # one-vnf service takes care of it
    "${ONE_VNF_SERVICE_SCRIPT}" -c "${ONE_VNF_SERVICE_CONFIG}" \
        set loadbalancer disabled
}

stop_lb()
{
    # one-vnf service takes care of it
    if is_running_lb ; then
        disable_lb
        reload_lb
    fi
}


### VNF HAPROXY ###############################################################

install_haproxy()
{
    apk add --no-cache haproxy
}

configure_haproxy()
{
    # configuration guard
    if ! to_be_configured HAPROXY ; then
        return 0
    fi

    msg info "VNF HAPROXY: Create HAPROXY section in the configuration file: ${ONE_VNF_SERVICE_CONFIG}"

    # prepare list of external interfaces
    _eths=

    if [ -z "${ONEAPP_VNF_HAPROXY_INTERFACES_DISABLED}" ] ; then
        # normal flow
        _eths="${ONEAPP_VNF_HAPROXY_INTERFACES}"
    else
        # we provided negated interface(s)
        _eths=
        _eths_tmp=$(get_eths "${ONEAPP_VNF_HAPROXY_INTERFACES_DISABLED}")

        for _eth in ${_eths_tmp} ; do
            _eths="${_eths} $(geth3 ${_eth} 1)"
        done
    fi

    _interfaces=
    for _iface in ${_eths} ; do
        # interface name must be ETH<num>
        _eth=$(geth1 "$_iface" 1)

        if [ -z "$_eth" ] ; then
            msg warning "VNF HAPROXY: Invalid network interface name: ${_iface} (SKIPPING)"
            continue
        elif [ "$_eth" = 'LO' ] ; then
            # TODO: is this error??
            msg warning "VNF HAPROXY: Loopback serves now as of one the external interfaces for Loadbalancing..."
        fi

        # shellcheck disable=SC2034
        _management_eth=$(eval "printf \"\$ONEAPP_VROUTER_${_eth}_MANAGEMENT\"")
        if ! is_true _management_eth ; then
            _interface_pair="{
                \"one-name\": \"$(geth1 ${_eth} 3)\",
                \"real-name\": \"$(geth1 ${_eth} 2)\"
                }"
            _interfaces="${_interfaces}${_interfaces:+, }${_interface_pair}"
        fi
    done

    # create list of lb configs
    if [ -n "${ONEAPP_VNF_HAPROXY_CONFIG}" ] ; then
        msg info "VNF HAPROXY: Save HAPROXY LB(s) configuration provided by 'ONEAPP_VNF_HAPROXY_CONFIG'"
        if _lb_list=$(echo "$ONEAPP_VNF_HAPROXY_CONFIG" | base64 -d) ; then
            _lb_list="[ ${_lb_list} ]"
        else
            msg error "VNF HAPROXY: Value in 'ONEAPP_VNF_HAPROXY_CONFIG' must be a json encoded in BASE64 - ABORT"
            exit 1
        fi
    else
        _lb_list='[]'
        for i in $(return_all_haproxy_loadbalancer_indices) ; do
            _lb=$(return_haproxy_loadbalancer "${i}")
            _lb_list=$(echo "${_lb_list}" | \
                jq --argjson lb "${_lb}" '. += [$lb]')
        done
    fi

    # inject the loadbalancer section into one-vnf service's config file
    if is_true ONEAPP_VNF_HAPROXY_ENABLED ; then
        _enabled="true"
    else
        _enabled="false"
    fi
    if is_true ONEAPP_VNF_HAPROXY_ONEGATE_ENABLED ; then
        _onegate="true"
    else
        _onegate="false"
    fi
    _current_config=$(cat "${ONE_VNF_SERVICE_CONFIG}")
    jq -s '.[0] + .[1]' > "${ONE_VNF_SERVICE_CONFIG}" <<EOF
${_current_config}
{
    "haproxy": {
        "enabled": ${_enabled},
        "onegate": ${_onegate},
        "interfaces": [ ${_interfaces} ],
        "refresh-rate": ${ONEAPP_VNF_HAPROXY_REFRESH_RATE},
        "lbs": ${_lb_list}
    }
}
EOF
}

return_all_haproxy_loadbalancer_indices()
(
    env | \
        sed -n "s/^ONEAPP_VNF_HAPROXY_LB\([0-9][0-9]*\)_.*/\1/p" | \
        sort -un
)

# arg: <lb-index>
return_all_haproxy_backend_server_indices()
(
    _lb_index="$1"
    env | \
        sed -n "s/^ONEAPP_VNF_HAPROXY_LB${_lb_index}_SERVER\([0-9][0-9]*\)_.*/\1/p" | \
        sort -un
)

# arg: <lb-index>
return_haproxy_loadbalancer()
(
    _lb_index="$1"
    _lb_config="{
        \"index\": ${_lb_index},
        \"backend-servers\": []
    }"

    for _item in $(env | \
        sed -n "s/^ONEAPP_VNF_HAPROXY_LB${_lb_index}_\(.*\)=.*/\1/p" | \
        sort -u) ;
    do
        # add new field to the lb object
        _key=''
        _item=$(echo "${_item}" | tr '[:lower:]' '[:upper:]')
        case "${_item}" in
            IP)
                _key='lb-address'
                ;;
            PORT)
                _key='lb-port'
                ;;
            *)
                continue
                ;;
        esac
        _value=$(eval "echo \"\$ONEAPP_VNF_HAPROXY_LB${_lb_index}_${_item}\"")
        _lb_config=$(echo "${_lb_config}" | \
            jq --arg item_value "${_value}" ". + {\"${_key}\": \$item_value}")
    done

    # loop through all backends (real servers)
    for i in $(return_all_haproxy_backend_server_indices "${_lb_index}") ; do
        _backend_server=$(return_haproxy_backend_server "${_lb_index}" "${i}")
        _lb_config=$(echo "${_lb_config}" | \
            jq --argjson server "${_backend_server}" '."backend-servers" += [$server]')
    done

    echo "${_lb_config}"
)

# arg: <lb-index> <server-index>
return_haproxy_backend_server()
(
    _lb_index="$1"
    _srv_index="$2"
    _backend_server='{}'

    for _item in $(env | \
        sed -n "s/^ONEAPP_VNF_HAPROXY_LB${_lb_index}_SERVER${_srv_index}_\(.*\)=.*/\1/p" | \
        sort -u) ;
    do
        # add new field to the real server object
        _key=''
        _item=$(echo "${_item}" | tr '[:lower:]' '[:upper:]')
        case "${_item}" in
            HOST)
                _key='server-host'
                ;;
            PORT)
                _key='server-port'
                ;;
            *)
                continue
                ;;
        esac
        _value=$(eval "echo \"\$ONEAPP_VNF_HAPROXY_LB${_lb_index}_SERVER${_srv_index}_${_item}\"")
        _backend_server=$(echo "${_backend_server}" | \
            jq --arg item_value "${_value}" ". + {\"${_key}\": \$item_value}")
    done
    echo "${_backend_server}"
)

is_running_haproxy()
{
    # one-vnf service takes care of it

    _haproxy_state=$("${ONE_VNF_SERVICE_SCRIPT}" -c "${ONE_VNF_SERVICE_CONFIG}" \
        get haproxy)

    if [ "${_haproxy_state}" = 'enabled' ] && check_pidfile "${ONE_VNF_PIDFILE}" ; then
        return 0
    else
        return 1
    fi
}

enable_haproxy()
{
    # one-vnf service takes care of it
    "${ONE_VNF_SERVICE_SCRIPT}" -c "${ONE_VNF_SERVICE_CONFIG}" \
        set haproxy enabled
}

start_haproxy()
{
    # one-vnf service takes care of it
    enable_haproxy
    if is_running_haproxy ; then
        reload_haproxy
    else
        rc-service ${ONE_VNF_OPENRC_NAME} start
    fi
}

restart_haproxy()
{
    # one-vnf service takes care of it
    stop_haproxy
    start_haproxy
}

reload_haproxy()
{
    # one-vnf service takes care of it
    rc-service ${ONE_VNF_OPENRC_NAME} reload
}

disable_haproxy()
{
    # one-vnf service takes care of it
    "${ONE_VNF_SERVICE_SCRIPT}" -c "${ONE_VNF_SERVICE_CONFIG}" \
        set haproxy disabled
}

stop_haproxy()
{
    # one-vnf service takes care of it
    if is_running_haproxy ; then
        disable_haproxy
        reload_haproxy
    fi
}

### VNF TOOLS #################################################################
install_tools()
{
    apk add nmap tcpdump net-tools
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


#
# report
#

report_config()
{
    msg info "Save context/config variables as a report in: ${ONE_SERVICE_REPORT}"

    cat > "$ONE_SERVICE_REPORT" <<EOF
[VNF]
$(env -i "${ONE_SERVICE_SETUP_DIR}/bin/context-helper" load -t shell \
    "$ONE_SERVICE_CONTEXTFILE" | sed -e "/=''/d" -e 's/=/ = /' | \
    sort)
EOF

    chmod 600 "$ONE_SERVICE_REPORT"
}

