# frozen_string_literal: true

require 'base64'
require 'yaml'

require_relative 'config.rb'
require_relative 'helpers.rb'

def configure_canal(manifest_dir = K8S_MANIFEST_DIR)
    msg :info, 'Configure Canal'

    if ONEAPP_K8S_CNI_CONFIG.nil?
        msg :info, 'Create Canal CRD config from user-provided ranges'

        documents = YAML.load_stream <<~MANIFEST
        ---
        apiVersion: helm.cattle.io/v1
        kind: HelmChartConfig
        metadata:
          name: rke2-canal
          namespace: kube-system
        spec:
          valuesContent: |-
        MANIFEST
    else
        msg :info, 'Use Canal user-provided config'
        documents = YAML.load_stream Base64.decode64 ONEAPP_K8S_CNI_CONFIG
    end

    msg :info, 'Generate Canal config manifest'
    manifest = YAML.dump_stream *documents
    file "#{manifest_dir}/rke2-canal-config.yaml", manifest, overwrite: true
end
