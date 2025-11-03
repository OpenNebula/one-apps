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

    # KaaS Appliance
    module KaaS

        extend self

        DEPENDS_ON = []

        def install
            msg :info, 'KaaS::install'

            msg :info, "Download Clusterctl: #{KAAS_CLUSTERCTL_VERSION}"
            clusterctl_url = 'https://github.com/kubernetes-sigs/cluster-api/releases/download/' \
                            "v#{KAAS_CLUSTERCTL_VERSION}/clusterctl-linux-amd64"
            bash <<~SCRIPT
                curl -fsSL #{clusterctl_url} \
                | install -o 0 -g 0 -m u=rwx,go= -D /dev/fd/0 '/usr/local/bin/clusterctl'
            SCRIPT

            msg :info, "Download Kind: #{KAAS_KIND_VERSION}"
            kind_url = 'https://github.com/kubernetes-sigs/kind/releases/download/' \
                        "v#{KAAS_KIND_VERSION}/kind-linux-amd64"
            bash <<~SCRIPT
                curl -fsSL #{kind_url} \
                | install -o 0 -g 0 -m u=rwx,go= -D /dev/fd/0 '/usr/local/bin/kind'
            SCRIPT

            msg :info, "Download Kubectl: #{KAAS_KUBECTL_VERSION}"
            bash <<~SCRIPT
                curl -fsSL 'https://dl.k8s.io/release/v#{KAAS_KUBECTL_VERSION}/bin/linux/amd64/kubectl' \
                | install -o 0 -g 0 -m u=rwx,go= -D /dev/fd/0 '/usr/local/bin/kubectl'
            SCRIPT

            msg :info, 'Create management cluster with Kind'
            bash <<~SCRIPT
                kind create cluster
                kind get kubeconfig > #{KAAS_MGMT_KUBECONFIG_PATH}
            SCRIPT

            msg :info, 'Initialize management cluster'
            bash <<~SCRIPT
                clusterctl init \
                --bootstrap=rke2 \
                --control-plane=rke2 \
                --infrastructure=opennebula
            SCRIPT

            msg :info, 'Stop management cluster'
            bash <<~SCRIPT
                podman stop kind-control-plane
            SCRIPT
        end

        def configure
            msg :info, 'KaaS::configure'

            begin
                if KAAS_CLUSTER_SPEC.nil? || KAAS_CLUSTER_SPEC.strip.empty?
                    msg :error, 'KAAS_CLUSTER_SPEC is empty or not provided'
                    onegate_vm_update ["#{KAAS_STATE_KEY}=BOOTSTRAP_FAILURE"]
                    exit 1
                end

                msg :info, 'Start Management Cluster'
                onegate_vm_update ["#{KAAS_STATE_KEY}=PROVISIONING_MGMT"]
                unless bash <<~SCRIPT
                    podman start kind-control-plane
                SCRIPT
                    msg :error, 'Failed to start Management Cluster'
                    onegate_vm_update ["#{KAAS_STATE_KEY}=PROVISIONING_FAILURE"]
                    exit 1
                end

                msg :info, 'Deploy Workload Cluster'
                onegate_vm_update ["#{KAAS_STATE_KEY}=PROVISIONING_CP"]
                success = begin_retry?(30, 10) do
                    puts bash <<~SCRIPT
                        echo "#{KAAS_CLUSTER_SPEC}" | base64 -d | \
                        kubectl apply --kubeconfig #{KAAS_MGMT_KUBECONFIG_PATH}  -f -
                    SCRIPT
                end

                unless success
                    msg :error, 'Failed to deploy Workload Cluster'
                    onegate_vm_update ["#{KAAS_STATE_KEY}=PROVISIONING_FAILURE"]
                    exit 1
                end

                msg :info, 'Wait for Workload Cluster to be ready'
                unless bash <<~SCRIPT
                    kubectl wait \
                        --for=condition=Ready \
                        cluster/#{KAAS_CLUSTER_NAME} \
                        --timeout="$(( \
                        $(kubectl get RKE2ControlPlane #{KAAS_CLUSTER_NAME} \
                            -o jsonpath='{.spec.replicas}' \
                            --kubeconfig #{KAAS_MGMT_KUBECONFIG_PATH}) * 15 \
                        ))m" \
                        --kubeconfig #{KAAS_MGMT_KUBECONFIG_PATH}
                SCRIPT
                    msg :error, 'Workload Cluster is not ready'
                    onegate_vm_update ["#{KAAS_STATE_KEY}=PROVISIONING_FAILURE"]
                    exit 1
                end

                msg :info, 'Create backup directory'
                unless bash <<~SCRIPT
                    install -d backup
                SCRIPT
                    msg :error, 'Failed to create backup directory'
                    onegate_vm_update ["#{KAAS_STATE_KEY}=GATHERING_CONFIG_FAILED"]
                    exit 1
                end

                msg :info, 'Backup Management Cluster'
                success = begin_retry?(30, 10) do
                    puts bash <<~SCRIPT
                        clusterctl -v=4 move \
                        --to-directory=backup/ \
                        --kubeconfig #{KAAS_MGMT_KUBECONFIG_PATH}
                    SCRIPT
                end

                unless success
                    msg :error, 'Failed to backup Management Cluster'
                    onegate_vm_update ["#{KAAS_STATE_KEY}=PIVOTING_FAILURE"]
                    exit 1
                end

                msg :info, 'Retrieve Workload Cluster Kubeconfig'
                unless bash <<~SCRIPT
                    clusterctl get kubeconfig #{KAAS_CLUSTER_NAME} \
                    --kubeconfig #{KAAS_MGMT_KUBECONFIG_PATH} > #{KAAS_WKLD_KUBECONFIG_PATH}
                SCRIPT
                    msg :error, 'Failed to retrieve Workload Cluster Kubeconfig'
                    onegate_vm_update ["#{KAAS_STATE_KEY}=PIVOTING_FAILURE"]
                    exit 1
                end

                msg :info, 'Initialize CAPI on Workload Cluster'
                unless bash <<~SCRIPT
                    clusterctl init \
                    --bootstrap=rke2 \
                    --control-plane=rke2 \
                    --infrastructure=opennebula \
                    --kubeconfig #{KAAS_WKLD_KUBECONFIG_PATH}
                SCRIPT
                    msg :error, 'Failed to initialize CAPI on Workload Cluster'
                    onegate_vm_update ["#{KAAS_STATE_KEY}=PIVOTING_FAILURE"]
                    exit 1
                end

                msg :info, 'Move CAPI objects to Workload Cluster'
                unless bash <<~SCRIPT
                    export KUBECONFIG=#{KAAS_WKLD_KUBECONFIG_PATH}
                    clusterctl -v=4 move \
                    --from-directory=backup/
                SCRIPT
                    msg :error, 'Failed to move CAPI objects to Workload Cluster'
                    onegate_vm_update ["#{KAAS_STATE_KEY}=PIVOTING_FAILURE"]
                    exit 1
                end

                onegate_vm_update ["#{KAAS_STATE_KEY}=READY"]
            rescue StandardError => e
                msg :error, "Unexpected error: #{e.message}"
                onegate_vm_update ["#{KAAS_STATE_KEY}=PROVISIONING_FAILURE"]
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
