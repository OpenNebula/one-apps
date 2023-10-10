# frozen_string_literal: true

require 'base64'
require 'yaml'

require_relative 'config.rb'
require_relative 'helpers.rb'

def configure_multus(manifest_dir = K8S_MANIFEST_DIR)
    msg :info, 'Configure Multus'

    if ONEAPP_K8S_MULTUS_CONFIG.nil?
        msg :info, 'Create Multus CRD config from user-provided ranges'

        documents = YAML.load_stream <<~MANIFEST
        ---
        apiVersion: helm.cattle.io/v1
        kind: HelmChartConfig
        metadata:
          name: rke2-multus
          namespace: kube-system
        spec:
          valuesContent: |-
            rke2-whereabouts:
              enabled: true
        MANIFEST
    else
        msg :info, 'Use Multus user-provided config'
        documents = YAML.load_stream Base64.decode64 ONEAPP_K8S_MULTUS_CONFIG
    end

    msg :info, 'Generate Multus config manifest'
    manifest = YAML.dump_stream *documents
    file "#{manifest_dir}/rke2-multus-config.yaml", manifest, overwrite: true
end
