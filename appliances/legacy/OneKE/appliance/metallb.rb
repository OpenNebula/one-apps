# frozen_string_literal: true

require 'base64'
require 'tmpdir'
require 'yaml'

require_relative 'config.rb'
require_relative 'helpers.rb'

def install_metallb(addon_dir = ONE_ADDON_DIR)
    msg :info, 'Install MetalLB'
    fetch_metallb addon_dir
end

def configure_metallb(addon_dir = ONE_ADDON_DIR)
    msg :info, 'Configure MetalLB'

    if ONEAPP_K8S_METALLB_CONFIG.nil?
        msg :info, 'Create MetalLB CRD config from user-provided ranges'

        documents = YAML.load_stream <<~MANIFEST
        ---
        apiVersion: metallb.io/v1beta1
        kind: IPAddressPool
        metadata:
          name: default
          namespace: metallb-system
        spec:
          addresses: []
        ---
        apiVersion: metallb.io/v1beta1
        kind: L2Advertisement
        metadata:
          name: default
          namespace: metallb-system
        spec:
          ipAddressPools: [default]
        MANIFEST

        unless ONEAPP_K8S_METALLB_RANGES.empty?
            ip_address_pool = documents.find do |doc|
                doc['kind'] == 'IPAddressPool' && doc.dig('metadata', 'name') == 'default'
            end
            ip_address_pool['spec']['addresses'] = extract_metallb_ranges.map { |item| item.join('-') }
        end
    else
        msg :info, 'Use MetalLB user-provided config'
        documents = YAML.load_stream Base64.decode64 ONEAPP_K8S_METALLB_CONFIG
    end

    msg :info, 'Generate MetalLB config manifest'
    manifest = YAML.dump_stream *documents
    file "#{addon_dir}/one-metallb-config.yaml", manifest, overwrite: true
end

def fetch_metallb(addon_dir = ONE_ADDON_DIR)
    bash <<~SCRIPT
    helm repo add metallb https://metallb.github.io/metallb
    helm repo update
    SCRIPT

    manifest = <<~MANIFEST
    ---
    apiVersion: v1
    kind: Namespace
    metadata:
      name: metallb-system
    ---
    apiVersion: helm.cattle.io/v1
    kind: HelmChart
    metadata:
      name: one-metallb
      namespace: kube-system
    spec:
      bootstrap: false
      targetNamespace: metallb-system
      chartContent: "%<chart_b64>s"
      valuesContent: |
        controller:
          image:
            pullPolicy: IfNotPresent
        speaker:
          image:
            pullPolicy: IfNotPresent
    MANIFEST

    msg :info, "Generate MetalLB addon manifest: #{ONEAPP_K8S_METALLB_CHART_VERSION}"
    Dir.mktmpdir do |temp_dir|
        bash <<~SCRIPT
        cd #{temp_dir}/
        helm pull metallb/metallb --version '#{ONEAPP_K8S_METALLB_CHART_VERSION}'
        SCRIPT

        manifest %= { chart_b64: slurp("#{temp_dir}/metallb-#{ONEAPP_K8S_METALLB_CHART_VERSION}.tgz") }

        file "#{addon_dir}/one-metallb.yaml", manifest, overwrite: true
    end
end

def extract_metallb_ranges(ranges = ONEAPP_K8S_METALLB_RANGES)
    ranges.compact
          .map(&:strip)
          .reject(&:empty?)
          .map { |item| item.split('-').map(&:strip) }
          .reject { |item| item.length > 2 }
          .map { |item| item.length == 1 ? [item.first, item.first] : item }
          .reject { |item| item.map(&:empty?).any? }
          .reject { |item| !(ipv4?(item.first) && ipv4?(item.last)) }
end
