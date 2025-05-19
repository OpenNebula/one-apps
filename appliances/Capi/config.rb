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

CAPI_K3S_VERSION = env :ONEAPP_CAPI_K3S_VERSION, 'v1.31.7+k3s1'

CAPI_CERT_MANAGER_VERSION = env :ONEAPP_CAPI_CERT_MANAGER_VERSION, 'v1.17.2'
CAPI_RANCHER_VERSION      = env :ONEAPP_CAPI_RANCHER_VERSION, '2.11.1'
CAPI_TURTLES_VERSION      = env :ONEAPP_CAPI_TURTLES_VERSION, '0.19.0'
CAPI_CAPONE_VERSION       = env :ONEAPP_CAPI_CAPONE_VERSION, 'v0.1.5'

ETH0_IP = env :ETH0_IP, nil

CAPI_RANCHER_HOSTNAME = env :ONEAPP_CAPI_RANCHER_HOSTNAME, nil
CAPI_RANCHER_PASSWORD = env :ONEAPP_CAPI_RANCHER_PASSWORD, 'capi1234'

MANIFESTS_DIR = '/var/lib/rancher/k3s/server/manifests/'
KUBECONFIG    = '/etc/rancher/k3s/k3s.yaml'
