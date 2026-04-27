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

ONEKS_CLUSTERCTL_VERSION = env :ONEAPP_ONEKS_CLUSTERCTL_VERSION, '1.9.6'
ONEKS_KIND_VERSION       = env :ONEAPP_ONEKS_KIND_VERSION, '0.25.0'
ONEKS_KUBECTL_VERSION    = env :ONEAPP_ONEKS_KUBECTL_VERSION, '1.34.1'
ONEKS_HELM_VERSION       = env :ONEAPP_ONEKS_HELM_VERSION, '3.17.3'
ONEKS_CAPONE_VERSION     = env :ONEAPP_ONEKS_CAPONE_VERSION, '0.1.7'

ONEKS_CLUSTER_NAME = env :ONEAPP_ONEKS_CLUSTER_NAME, ''
ONEKS_CLUSTER_SPEC = env :ONEAPP_ONEKS_CLUSTER_SPEC, ''

ONEKS_APPLIANCE_PATH = '/etc/one-appliance/service.d/OneKS'
ONEKS_MGMT_KUBECONFIG_PATH = "#{ONEKS_APPLIANCE_PATH}/mgmt"
ONEKS_WKLD_KUBECONFIG_PATH = "#{ONEKS_APPLIANCE_PATH}/wkld"
ONEKS_STATE_KEY = 'ONEKS_STATE'
