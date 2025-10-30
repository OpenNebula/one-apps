# frozen_string_literal: true

# ---------------------------------------------------------------------------- #
# Copyright 2025, OpenNebula Project, OpenNebula Systems                       #
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

load_env

KAAS_CLUSTERCTL_VERSION = env :ONEAPP_KAAS_CLUSTERCTL_VERSION, '1.9.6'
KAAS_KIND_VERSION       = env :ONEAPP_KAAS_KIND_VERSION, '0.25.0'
KAAS_KUBECTL_VERSION    = env :ONEAPP_KAAS_KUBECTL_VERSION, '1.34.1'
KAAS_HELM_VERSION       = env :ONEAPP_KAAS_HELM_VERSION, '3.17.3'

KAAS_CLUSTER_NAME = env :ONEAPP_KAAS_CLUSTER_NAME, ''
KAAS_CLUSTER_SPEC = env :ONEAPP_KAAS_CLUSTER_SPEC, ''

KAAS_APPLIANCE_PATH = '/etc/one-appliance/service.d/KaaS'
KAAS_MGMT_KUBECONFIG_PATH = "#{KAAS_APPLIANCE_PATH}/mgmt"
KAAS_WKLD_KUBECONFIG_PATH = "#{KAAS_APPLIANCE_PATH}/wkld"
