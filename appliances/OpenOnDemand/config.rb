# frozen_string_literal: true

# ---------------------------------------------------------------------------- #
# Copyright 2026, OpenNebula Project, OpenNebula Systems                       #
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

load_env if File.exist?('/run/one-context/one_env')

# Open OnDemand release installed at build time.
OOD_VERSION = '4.2'

# The wizard of Sunstone shows every input as a text area, so a value may end with a newline.

# LDAP directory of the users, the one the OneSlurm clusters use. The domain works as
# ONEAPP_LDAP_DOMAIN of OneSlurm, a DNS style domain or a base DN.
OOD_LDAP_URL    = env(:ONEAPP_LDAP_SERVER_URL, '').strip
OOD_LDAP_DOMAIN = env(:ONEAPP_LDAP_SERVER_DOMAIN, 'slurm.local').strip

# NFS export with the homes of the users, host:/export, as ONEAPP_SLURM_NFS_HOME of OneSlurm.
OOD_HOME_NFS_EXPORT = env(:ONEAPP_HOME_NFS_EXPORT, '').strip

# Slurm clusters of the portal, "name:IP" pairs with the IP of each controller, separated by
# spaces or one per line.
OOD_SLURM_CLUSTERS = env(:ONEAPP_SLURM_CLUSTERS_LIST, '').strip

# The same mount options as OneSlurm (appliances/OneSlurm/scripts/net-12-mount-nfs).
OOD_NFS_MOUNT_OPTIONS = 'sec=sys,_netdev'

OOD_PORTAL_YML   = '/etc/ood/config/ood_portal.yml'
OOD_CLUSTERS_DIR = '/etc/ood/config/clusters.d'
OOD_SHELL_ENV    = '/etc/ood/config/apps/shell/env'
OOD_CERT_DIR     = '/etc/ood/ssl'
OOD_KNOWN_HOSTS  = '/etc/ood/ssh/known_hosts'
OOD_BIN_DIR      = '/opt/one-appliance/OpenOnDemand/bin'
OOD_MANAGED_MARK = 'Managed by the OpenNebula Open OnDemand appliance'
