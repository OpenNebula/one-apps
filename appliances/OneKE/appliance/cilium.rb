# frozen_string_literal: true

require 'base64'
require 'uri'
require 'yaml'

require_relative 'config.rb'
require_relative 'helpers.rb'

def configure_cilium(manifest_dir = K8S_MANIFEST_DIR, endpoint = K8S_CONTROL_PLANE_EP)
    msg :info, 'Configure Cilium'

    ep = URI.parse "https://#{endpoint}"

    if ONEAPP_K8S_CNI_CONFIG.nil?
        msg :info, 'Create Cilium CRD config from user-provided ranges'

        documents = YAML.load_stream <<~MANIFEST
        ---
        apiVersion: helm.cattle.io/v1
        kind: HelmChartConfig
        metadata:
          name: rke2-cilium
          namespace: kube-system
        spec:
          valuesContent: |-
            kubeProxyReplacement: strict
            k8sServiceHost: "#{ep.host}"
            k8sServicePort: #{ep.port}
            cni:
              chainingMode: "none"
              exclusive: false
            bgpControlPlane:
              enabled: true
        ---
        apiVersion: cilium.io/v2alpha1
        kind: CiliumLoadBalancerIPPool
        metadata:
          name: default
          namespace: kube-system
        spec:
          cidrs: {}
        MANIFEST

        unless ONEAPP_K8S_CILIUM_RANGES.empty?
            ip_address_pool = documents.find do |doc|
                doc['kind'] == 'CiliumLoadBalancerIPPool' && doc.dig('metadata', 'name') == 'default'
            end
            ip_address_pool['spec']['cidrs'] = extract_cilium_ranges.map do |item|
                { 'cidr' => item.join('/') }
            end
        end
    else
        msg :info, 'Use Cilium user-provided config'
        documents = YAML.load_stream Base64.decode64 ONEAPP_K8S_CNI_CONFIG
    end

    msg :info, 'Generate Cilium config manifest'
    manifest = YAML.dump_stream *documents
    file "#{manifest_dir}/rke2-cilium-config.yaml", manifest, overwrite: true
end

def extract_cilium_ranges(ranges = ONEAPP_K8S_CILIUM_RANGES)
    ranges.compact
          .map(&:strip)
          .reject(&:empty?)
          .map { |item| item.split('/').map(&:strip) }
          .reject { |item| item.length > 2 }
          .reject { |item| item.map(&:empty?).any? }
          .reject { |item| !(ipv4?(item.first) && integer?(item.last)) }
end
