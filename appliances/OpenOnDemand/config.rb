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
OOD_VERSION = env :ONEAPP_OOD_VERSION, '4.2'

# Portal name and certificate.
OOD_PORTAL_HOST_NAME          = env :ONEAPP_PORTAL_HOST_NAME, ''
OOD_PORTAL_LETSENCRYPT        = env :ONEAPP_PORTAL_LETSENCRYPT_ENABLED, 'NO'
OOD_PORTAL_CERTIFICATE        = env :ONEAPP_PORTAL_CERTIFICATE_ENABLED, 'NO'
OOD_PORTAL_CERTIFICATE_CHAIN  = env :ONEAPP_PORTAL_CERTIFICATE_CHAIN, ''
OOD_PORTAL_CERTIFICATE_KEY    = env :ONEAPP_PORTAL_CERTIFICATE_KEY, ''

# LDAP directory of the users, the one the OneSlurm clusters use. The domain works as
# ONEAPP_LDAP_DOMAIN of OneSlurm, a DNS style domain or a base DN.
OOD_LDAP_URL           = env :ONEAPP_LDAP_SERVER_URL, ''
OOD_LDAP_DOMAIN        = env :ONEAPP_LDAP_SERVER_DOMAIN, 'slurm.local'
OOD_LDAP_BIND_USER     = env :ONEAPP_LDAP_BIND_USER, ''
OOD_LDAP_BIND_PASSWORD = env :ONEAPP_LDAP_BIND_PASSWORD, ''

# NFS export with the user homes, host:/export, as ONEAPP_SLURM_NFS_HOME of OneSlurm.
OOD_HOME_NFS_EXPORT = env :ONEAPP_HOME_NFS_EXPORT, ''

# Slurm clusters of the portal, "name:host" pairs separated by spaces.
OOD_SLURM_CLUSTERS = env :ONEAPP_SLURM_CLUSTERS_LIST, ''

OOD_NFS_MOUNT_OPTIONS = 'sec=sys,_netdev'
OOD_SLURM_COMMANDS    = %w[sbatch squeue scancel scontrol sinfo sacct sacctmgr].freeze

OOD_PORTAL_YML   = '/etc/ood/config/ood_portal.yml'
OOD_CLUSTERS_DIR = '/etc/ood/config/clusters.d'
OOD_CERT_DIR     = '/etc/ood/ssl'
OOD_BIN_DIR      = '/opt/one-appliance/OpenOnDemand'
# Apache and the web servers of the users run with /etc/ssh hidden (InaccessiblePaths in
# the apache2 units of Ubuntu and of Open OnDemand), so the SSH client files live here.
OOD_SSH_DIR      = '/etc/ood/ssh'
OOD_KNOWN_HOSTS  = '/etc/ood/ssh/known_hosts'
OOD_SSH_CONFIG   = '/etc/ood/ssh/ssh_config'
OOD_MANAGED_MARK = 'Managed by the OpenNebula Open OnDemand appliance'
