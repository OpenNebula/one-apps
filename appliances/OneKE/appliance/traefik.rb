# frozen_string_literal: true

require 'base64'
require 'tmpdir'

require_relative 'config.rb'
require_relative 'helpers.rb'

def install_traefik(addon_dir = ONE_ADDON_DIR)
    msg :info, 'Install Traefik'
    fetch_traefik addon_dir
end

def fetch_traefik(addon_dir = ONE_ADDON_DIR)
    bash <<~SCRIPT
    helm repo add traefik https://helm.traefik.io/traefik
    helm repo update
    SCRIPT

    manifest = <<~MANIFEST
    ---
    apiVersion: v1
    kind: Namespace
    metadata:
      name: traefik-system
    ---
    apiVersion: helm.cattle.io/v1
    kind: HelmChart
    metadata:
      name: one-traefik
      namespace: kube-system
    spec:
      bootstrap: false
      targetNamespace: traefik-system
      chartContent: "%<chart_b64>s"
      valuesContent: |
        deployment:
          replicas: 2
        affinity:
          podAntiAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              - topologyKey: kubernetes.io/hostname
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/name: traefik
        service:
          type: NodePort
        ports:
          web:
            nodePort: 32080
          websecure:
            nodePort: 32443
    MANIFEST

    msg :info, "Generate Traefik addon manifest: #{ONEAPP_K8S_TRAEFIK_CHART_VERSION}"
    Dir.mktmpdir do |temp_dir|
        bash <<~SCRIPT
        cd #{temp_dir}/
        helm pull traefik/traefik --version '#{ONEAPP_K8S_TRAEFIK_CHART_VERSION}'
        SCRIPT

        manifest %= { chart_b64: slurp("#{temp_dir}/traefik-#{ONEAPP_K8S_TRAEFIK_CHART_VERSION}.tgz") }

        file "#{addon_dir}/one-traefik.yaml", manifest, overwrite: true
    end
end
