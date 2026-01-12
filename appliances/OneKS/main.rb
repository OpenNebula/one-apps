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

begin
    require '/etc/one-appliance/lib/helpers'
rescue LoadError
    require_relative '../lib/helpers'
end

require_relative 'config'
require 'base64'
require 'open3'

# Base module for OpenNebula services
module Service

    # OneKS Appliance
    module OneKS

        extend self

        DEPENDS_ON = []

        def install
            msg :info, 'OneKS::install'

            msg :info, "Download Clusterctl: #{ONEKS_CLUSTERCTL_VERSION}"
            clusterctl_url = 'https://github.com/kubernetes-sigs/cluster-api/releases/download/' \
                            "v#{ONEKS_CLUSTERCTL_VERSION}/clusterctl-linux-amd64"
            bash <<~SCRIPT
                curl -fsSL #{clusterctl_url} \
                | install -o 0 -g 0 -m u=rwx,go= -D /dev/fd/0 '/usr/local/bin/clusterctl'
            SCRIPT

            msg :info, "Download Kind: #{ONEKS_KIND_VERSION}"
            kind_url = 'https://github.com/kubernetes-sigs/kind/releases/download/' \
                        "v#{ONEKS_KIND_VERSION}/kind-linux-amd64"
            bash <<~SCRIPT
                curl -fsSL #{kind_url} \
                | install -o 0 -g 0 -m u=rwx,go= -D /dev/fd/0 '/usr/local/bin/kind'
            SCRIPT

            msg :info, "Download Kubectl: #{ONEKS_KUBECTL_VERSION}"
            bash <<~SCRIPT
                curl -fsSL 'https://dl.k8s.io/release/v#{ONEKS_KUBECTL_VERSION}/bin/linux/amd64/kubectl' \
                | install -o 0 -g 0 -m u=rwx,go= -D /dev/fd/0 '/usr/local/bin/kubectl'
            SCRIPT

            msg :info, 'Create management cluster with Kind'
            bash <<~SCRIPT
                kind create cluster
                kind get kubeconfig > #{ONEKS_MGMT_KUBECONFIG_PATH}
            SCRIPT

            msg :info, 'Initialize management cluster'
            bash <<~SCRIPT
                clusterctl init \
                --bootstrap=rke2 \
                --control-plane=rke2 \
                --infrastructure=opennebula:v#{ONEKS_CAPONE_VERSION}
            SCRIPT

            msg :info, 'Stop management cluster'
            bash <<~SCRIPT
                podman stop kind-control-plane
            SCRIPT
        end

        def configure
            msg :info, 'OneKS::configure'

            begin
                if ONEKS_CLUSTER_SPEC.nil? || ONEKS_CLUSTER_SPEC.strip.empty?
                    msg :error, 'ONEKS_CLUSTER_SPEC is empty or not provided'
                    onegate_vm_update ["#{ONEKS_STATE_KEY}=BOOTSTRAP_FAILURE"]
                    exit 1
                end

                msg :info, 'Start Management Cluster'
                onegate_vm_update ["#{ONEKS_STATE_KEY}=PROVISIONING_MGMT"]
                unless bash <<~SCRIPT
                    podman start kind-control-plane
                SCRIPT
                    msg :error, 'Failed to start Management Cluster'
                    onegate_vm_update ["#{ONEKS_STATE_KEY}=PROVISIONING_FAILURE"]
                    exit 1
                end

                msg :info, 'Deploy Workload Cluster'
                onegate_vm_update ["#{ONEKS_STATE_KEY}=PROVISIONING_CP"]
                success = begin_retry?(30, 10) do
                    puts bash <<~SCRIPT
                        echo "#{ONEKS_CLUSTER_SPEC}" | base64 -d | \
                        kubectl apply --kubeconfig #{ONEKS_MGMT_KUBECONFIG_PATH}  -f -
                    SCRIPT
                end

                unless success
                    msg :error, 'Failed to deploy Workload Cluster'
                    onegate_vm_update ["#{ONEKS_STATE_KEY}=PROVISIONING_FAILURE"]
                    exit 1
                end

                msg :info, 'Wait for Workload Cluster to be ready'
                unless bash <<~SCRIPT
                    kubectl wait \
                        --for=condition=ControlPlaneReady \
                        cluster/#{ONEKS_CLUSTER_NAME} \
                        --timeout="$(( \
                        $(kubectl get RKE2ControlPlane #{ONEKS_CLUSTER_NAME} \
                            -o jsonpath='{.spec.replicas}' \
                            --kubeconfig #{ONEKS_MGMT_KUBECONFIG_PATH}) * 15 \
                        ))m" \
                        --kubeconfig #{ONEKS_MGMT_KUBECONFIG_PATH}
                SCRIPT
                    msg :error, 'Workload Cluster is not ready'
                    onegate_vm_update ["#{ONEKS_STATE_KEY}=PROVISIONING_FAILURE"]
                    exit 1
                end
            rescue StandardError => e
                msg :error, "Unexpected error: #{e.message}"
                onegate_vm_update ["#{ONEKS_STATE_KEY}=PROVISIONING_FAILURE"]
                exit 1
            end

            begin
                onegate_vm_update ["#{ONEKS_STATE_KEY}=PIVOTING_CLUSTER"]
                msg :info, 'Retrieve Workload Cluster Kubeconfig'
                unless bash <<~SCRIPT
                    clusterctl get kubeconfig #{ONEKS_CLUSTER_NAME} \
                    --kubeconfig #{ONEKS_MGMT_KUBECONFIG_PATH} > #{ONEKS_WKLD_KUBECONFIG_PATH}
                SCRIPT
                    msg :error, 'Failed to retrieve Workload Cluster Kubeconfig'
                    onegate_vm_update ["#{ONEKS_STATE_KEY}=PIVOTING_FAILURE"]
                    exit 1
                end

                msg :info, 'Initialize CAPI on Workload Cluster'
                unless bash <<~SCRIPT
                    clusterctl init \
                    --bootstrap=rke2 \
                    --control-plane=rke2 \
                    --infrastructure=opennebula:v#{ONEKS_CAPONE_VERSION} \
                    --kubeconfig #{ONEKS_WKLD_KUBECONFIG_PATH}
                SCRIPT
                    msg :error, 'Failed to initialize CAPI on Workload Cluster'
                    onegate_vm_update ["#{ONEKS_STATE_KEY}=PIVOTING_FAILURE"]
                    exit 1
                end

                msg :info, 'Move CAPI objects to Workload Cluster'
                success = begin_retry?(30, 10) do
                    puts bash <<~SCRIPT
                        clusterctl -v=4 move \
                        --kubeconfig #{ONEKS_MGMT_KUBECONFIG_PATH} \
                        --to-kubeconfig #{ONEKS_WKLD_KUBECONFIG_PATH}
                    SCRIPT
                end

                unless success
                    msg :error, 'Failed to move CAPI objects to Workload Cluster'
                    onegate_vm_update ["#{ONEKS_STATE_KEY}=PIVOTING_FAILURE"]
                    exit 1
                end
                onegate_vm_update ["#{ONEKS_STATE_KEY}=RUNNING"]
            rescue StandardError => e
                msg :error, "Unexpected error: #{e.message}"
                onegate_vm_update ["#{ONEKS_STATE_KEY}=PIVOTING_FAILURE"]
                exit 1
            end
        end

        def bootstrap
            msg :info, 'Capi::bootstrap'
        end

    end

    def begin_retry?(max_retries, delay)
        max_retries.downto(0).each do |_retry_num|
            yield
            return true
        rescue StandardError => e
            puts "Error: #{e.message}"
            sleep delay
        end
        return false
    end

    def onegate_vm_update(data)
        bash "onegate vm update --data \"#{data.join('\n')}\""
    end

end
