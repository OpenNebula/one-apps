#!/usr/bin/env bash

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

ONE_SERVICE_PARAMS=(
    'ONEAPP_CAPI_K3S_VERSION' 'configure' 'K3S version <1.32' 'O|text'
    'ONEAPP_CAPI_RANCHER_HOSTNAME' 'configure' 'Rancher Hostname' 'O|text'
    'ONEAPP_CAPI_RANCHER_PASSWORD' 'configure' 'Rancher Password' 'O|text'
    'ONEAPP_CAPI_RANCHER_TURTLES_VERSION' 'configure' 'Rancher Turtles version' 'O|text'
    'ONEAPP_CAPI_OPENNEBULA_VERSION' 'configure' 'CAPONE version' 'O|text'
)

CAPI_K3S_VERSION="${ONEAPP_CAPI_K3S_VERSION:-v1.31.7+k3s1}"
CAPI_RANCHER_HOSTNAME="${ONEAPP_CAPI_RANCHER_HOSTNAME:-capi}"
CAPI_RANCHER_PASSWORD="${ONEAPP_CAPI_RANCHER_PASSWORD:-admin}"
CAPI_RANCHER_TURTLES_VERSION="${ONEAPP_CAPI_RANCHER_TURTLES_VERSION:-0.18.0}"
CAPI_OPENNEBULA_VERSION="${ONEAPP_CAPI_OPENNEBULA_VERSION:-v0.1.1}"

service_install() {
    msg info "Checking internet access..."

    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$CAPI_K3S_VERSION" sh -
    # Set bash as script uses [[ ]]
    curl -sfL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash -

    msg info "Installation phase finished"
}


service_configure() {
    msg info "Starting configuration..."

    helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
    helm repo add jetstack https://charts.jetstack.io
    helm repo add turtles https://rancher.github.io/turtles
    helm repo update

    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

    helm install cert-manager jetstack/cert-manager \
    --namespace cert-manager   \
    --create-namespace  \
    --set crds.enabled=true

    kubectl create namespace cattle-system
    helm install rancher rancher-stable/rancher  \
    --namespace cattle-system \
    --set hostname="$CAPI_RANCHER_HOSTNAME" \
    --set bootstrapPassword="$CAPI_RANCHER_PASSWORD"

    kubectl -n cattle-system rollout status deploy/rancher

    kubectl apply -f- <<EOF
---
apiVersion: management.cattle.io/v3
kind: Setting
metadata:
  name: first-login
value: "false"
---
apiVersion: management.cattle.io/v3
kind: Setting
metadata:
  name: eula-agreed
value: "$(date -Iseconds)"
---
apiVersion: management.cattle.io/v3
kind: Feature
metadata:
  name: embedded-cluster-api
spec:
  value: false
EOF

    kubectl delete \
    mutatingwebhookconfiguration.admissionregistration.k8s.io \
    mutating-webhook-configuration

    kubectl delete \
    validatingwebhookconfigurations.admissionregistration.k8s.io \
    validating-webhook-configuration

    helm install rancher-turtles turtles/rancher-turtles \
    --version "$CAPI_RANCHER_TURTLES_VERSION" \
    -n rancher-turtles-system \
    --dependency-update \
    --create-namespace \
    --set turtlesUI.enabled=true \
    --wait

    msg info "Configuration phase finished"
}


service_bootstrap() {
    msg info "Starting bootstrap..."

    kubectl apply -f- <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: capone-system
---
apiVersion: turtles-capi.cattle.io/v1alpha1
kind: CAPIProvider
metadata:
  name: opennebula
  namespace: capone-system
spec:
  features:
    clusterResourceSet: true
    clusterTopology: true
    machinePool: true
  fetchConfig:
    url: https://github.com/OpenNebula/cluster-api-provider-opennebula/releases/download/"$CAPI_OPENNEBULA_VERSION"/infrastructure-components.yaml
  name: opennebula
  type: infrastructure
  version: "$CAPI_OPENNEBULA_VERSION"
EOF

    msg info "Bootstrap phase finished"
}