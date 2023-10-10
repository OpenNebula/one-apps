# frozen_string_literal: true

require 'base64'
require 'yaml'

require_relative 'config.rb'
require_relative 'helpers.rb'

def configure_calico(manifest_dir = K8S_MANIFEST_DIR)
    msg :info, 'Configure Calico'

    if ONEAPP_K8S_CNI_CONFIG.nil?
        msg :info, 'Create Calico CRD config from user-provided ranges'

        documents = YAML.load_stream <<~MANIFEST
        ---
        apiVersion: helm.cattle.io/v1
        kind: HelmChartConfig
        metadata:
          name: rke2-calico
          namespace: kube-system
        spec:
          valuesContent: |-
        MANIFEST
    else
        msg :info, 'Use Calico user-provided config'
        documents = YAML.load_stream Base64.decode64 ONEAPP_K8S_CNI_CONFIG
    end

    msg :info, 'Generate Calico config manifest'
    manifest = YAML.dump_stream *documents
    file "#{manifest_dir}/rke2-calico-config.yaml", manifest, overwrite: true
end
