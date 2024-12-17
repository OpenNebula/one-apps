# frozen_string_literal: true

require 'base64'
require 'uri'
require 'yaml'

require_relative 'config.rb'
require_relative 'helpers.rb'

# NOTE: We added the ONEAPP_K8S_CILIUM_ENABLE_BGP flag for being able to disable
# BGP control plane and CiliumLoadBalancerIPPool CRD creation in order to avoid
# conflicts with other LB controllers managing services without LBClass set.
# From cilium v1.17, we will be able to add `defaultLBServiceIPAM: none` in the
# HelmChartConfig for letting cilium ignoring services without LBClass set.
# More info: https://github.com/cilium/cilium/pull/33351
# and https://docs.cilium.io/en/latest/network/lb-ipam/#loadbalancerclass

def configure_cilium(manifest_dir = K8S_MANIFEST_DIR, endpoint = ONEAPP_K8S_CONTROL_PLANE_EP)
    msg :info, 'Configure Cilium'

    ep = URI.parse "https://#{endpoint}"

    if ONEAPP_K8S_CNI_CONFIG.nil?
        msg :info, 'Create Cilium CRD config from user-provided ranges'

        enable_bgp = ONEAPP_K8S_CILIUM_ENABLE_BGP \
            || (ONEAPP_K8S_CILIUM_ENABLE_BGP.nil? && !ONEAPP_K8S_CILIUM_RANGES.empty?)

        documents = YAML.load_stream <<~MANIFEST
        ---
        apiVersion: helm.cattle.io/v1
        kind: HelmChartConfig
        metadata:
          name: rke2-cilium
          namespace: kube-system
        spec:
          valuesContent: |-
            kubeProxyReplacement: true
            k8sServiceHost: "#{ep.host}"
            k8sServicePort: #{ep.port}
            cni:
              chainingMode: "none"
              exclusive: false
            bgpControlPlane:
              enabled: #{enable_bgp}
        MANIFEST

        if enable_bgp
            documents += YAML.load_stream <<~MANIFEST
            ---
            apiVersion: cilium.io/v2alpha1
            kind: CiliumLoadBalancerIPPool
            metadata:
                name: default
                namespace: kube-system
            spec:
                blocks: {}
                allowFirstLastIPs: "No"
            MANIFEST
            unless ONEAPP_K8S_CILIUM_RANGES.empty?
                ip_address_pool = documents.find do |doc|
                    doc['kind'] == 'CiliumLoadBalancerIPPool' && doc.dig('metadata', 'name') == 'default'
                end
                ip_address_pool['spec']['blocks'] = extract_cilium_ranges.map do |item|
                    { 'cidr' => item.join('/') }
                end
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
          .map { |item| item.split(%[/]).map(&:strip) }
          .reject { |item| item.length > 2 }
          .reject { |item| item.map(&:empty?).any? }
          .reject { |item| !(ipv4?(item.first) && integer?(item.last)) }
end
