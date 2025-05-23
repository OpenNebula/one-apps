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

require 'time'

begin
    require '/etc/one-appliance/lib/helpers.rb'
rescue LoadError
    require_relative '../lib/helpers.rb'
end

require_relative 'config.rb'

module Service
module Capi
    extend self

    DEPENDS_ON = %w[]

    def install(manifests_dir: MANIFESTS_DIR)
        msg :info, 'Capi::install'

        msg :info, "Install K3s: #{CAPI_K3S_VERSION}"
        puts bash <<~SCRIPT
        export INSTALL_K3S_SKIP_ENABLE='true'
        export INSTALL_K3S_SKIP_START='true'
        export INSTALL_K3S_VERSION='#{CAPI_K3S_VERSION}'
        curl -fsSL https://get.k3s.io | $SHELL -
        SCRIPT

        msg :info, 'Create /etc/profile.d/98-k3s.sh'
        file '/etc/profile.d/98-k3s.sh', <<~SCRIPT, mode: 'u=rw,go=r'
        export KUBECONFIG='#{KUBECONFIG}'
        SCRIPT
    end

    def configure(manifests_dir: MANIFESTS_DIR)
        msg :info, 'Capi::configure'

        msg :info, 'Enable/Start K3s'
        puts bash <<~SCRIPT
        systemctl enable --now k3s.service
        SCRIPT

        msg :info, "Install Cert Manager: #{CAPI_CERT_MANAGER_VERSION}"
        (manifests = []) << <<~MANIFEST
        apiVersion: helm.cattle.io/v1
        kind: HelmChart
        metadata:
          name: cert-manager
          namespace: kube-system
        spec:
          targetNamespace: cert-manager
          createNamespace: true
          repo: 'https://charts.jetstack.io'
          chart: cert-manager
          version: '#{CAPI_CERT_MANAGER_VERSION}'
          valuesContent: |-
            crds:
              enabled: true
        MANIFEST
        file "#{manifests_dir}/cert-manager.yaml", manifests.join("\n---\n"), mode: 'u=rw,go=r', overwrite: true

        msg :info, "Install Rancher: #{CAPI_RANCHER_VERSION}"
        (manifests = []) << <<~MANIFEST
        apiVersion: helm.cattle.io/v1
        kind: HelmChart
        metadata:
          name: rancher
          namespace: kube-system
        spec:
          targetNamespace: cattle-system
          createNamespace: true
          repo: 'https://releases.rancher.com/server-charts/stable'
          chart: rancher
          version: '#{CAPI_RANCHER_VERSION}'
          valuesContent: |-
            replicas: 1
            hostname: '#{CAPI_RANCHER_HOSTNAME || (ETH0_IP + '.sslip.io')}'
            bootstrapPassword: '#{CAPI_RANCHER_PASSWORD}'
        MANIFEST
        manifests << <<~MANIFEST
        apiVersion: management.cattle.io/v3
        kind: Setting
        metadata:
          name: first-login
        value: 'false'
        MANIFEST
        manifests << <<~MANIFEST
        apiVersion: management.cattle.io/v3
        kind: Setting
        metadata:
          name: eula-agreed
        value: '#{Time.now.iso8601}'
        MANIFEST
        manifests << <<~MANIFEST
        apiVersion: management.cattle.io/v3
        kind: Setting
        metadata:
          name: server-url
        value: https://#{CAPI_RANCHER_HOSTNAME || (ETH0_IP + '.sslip.io')}
        MANIFEST
        manifests << <<~MANIFEST
        apiVersion: management.cattle.io/v3
        kind: Feature
        metadata:
          name: embedded-cluster-api
        spec:
          value: false
        MANIFEST
        file "#{manifests_dir}/rancher.yaml", manifests.join("\n---\n"), mode: 'u=rw,go=r', overwrite: true

        msg :info, "Install Turtles: #{CAPI_TURTLES_VERSION}"
        (manifests = []) << <<~MANIFEST
        apiVersion: helm.cattle.io/v1
        kind: HelmChart
        metadata:
          name: rancher-turtles
          namespace: kube-system
        spec:
          targetNamespace: rancher-turtles-system
          createNamespace: true
          repo: 'https://rancher.github.io/turtles'
          chart: rancher-turtles
          version: '#{CAPI_TURTLES_VERSION}'
          valuesContent: |-
            turtlesUI:
              enabled: true
        MANIFEST
        file "#{manifests_dir}/rancher-turtles.yaml", manifests.join("\n---\n"), mode: 'u=rw,go=r', overwrite: true

        msg :info, "Install Capone: #{CAPI_CAPONE_VERSION}"
        (manifests = []) << <<~MANIFEST
        apiVersion: v1
        kind: Namespace
        metadata:
          name: capone-system
        MANIFEST
        manifests << <<~MANIFEST
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
            url: '#{CAPI_CAPONE_FETCH_URL}'
          name: opennebula
          type: infrastructure
          version: '#{CAPI_CAPONE_VERSION}'
        MANIFEST
        manifests << <<~MANIFEST
        apiVersion: catalog.cattle.io/v1
        kind: ClusterRepo
        metadata:
          name: capone
        spec:
          url: https://opennebula.github.io/cluster-api-provider-opennebula/charts/
        MANIFEST
        file "#{manifests_dir}/capone.yaml", manifests.join("\n---\n"), mode: 'u=rw,go=r', overwrite: true

        msg :info, "Install Kubeadm"
        (manifests = []) << <<~MANIFEST
        apiVersion: v1
        kind: Namespace
        metadata:
          name: capi-kubeadm-bootstrap-system
        MANIFEST
        manifests << <<~MANIFEST
        apiVersion: turtles-capi.cattle.io/v1alpha1
        kind: CAPIProvider
        metadata:
          name: kubeadm-bootstrap
          namespace: capi-kubeadm-bootstrap-system
        spec:
          name: kubeadm
          type: bootstrap
        MANIFEST
        manifests << <<~MANIFEST
        apiVersion: v1
        kind: Namespace
        metadata:
          name: capi-kubeadm-control-plane-system
        MANIFEST
        manifests << <<~MANIFEST
        apiVersion: turtles-capi.cattle.io/v1alpha1
        kind: CAPIProvider
        metadata:
          name: kubeadm-control-plane
          namespace: capi-kubeadm-control-plane-system
        spec:
          name: kubeadm
          type: controlPlane
        MANIFEST
        file "#{manifests_dir}/kubeadm.yaml", manifests.join("\n---\n"), mode: 'u=rw,go=r', overwrite: true
    end

    def bootstrap
        msg :info, 'Capi::bootstrap'

        msg :info, 'Wait for Rancher'
        60.downto(0).each do |retry_num|
            puts bash <<~SCRIPT
            curl -fsSkL https://#{CAPI_RANCHER_HOSTNAME || (ETH0_IP + '.sslip.io')}/healthz
            SCRIPT
            break !retry_num.zero?
        rescue RuntimeError
            sleep 10
        end.then do |ok|
            if !ok
                msg :error, 'Rancher not ready'
                next
            end
        rescue RuntimeError
        end

        msg :info, 'Mark namespaces to be auto-imported'
        puts bash <<~SCRIPT
        kubectl label namespace default cluster-api.cattle.io/rancher-auto-import=true
        SCRIPT
    end
end
end
