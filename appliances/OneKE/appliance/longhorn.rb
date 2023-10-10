# frozen_string_literal: true

require 'base64'
require 'tmpdir'

require_relative 'config.rb'
require_relative 'helpers.rb'

def install_longhorn(addon_dir = ONE_ADDON_DIR)
    msg :info, 'Install Longhorn'
    fetch_longhorn addon_dir
    pull_longhorn_images if ONE_SERVICE_AIRGAPPED
end

def prepare_dedicated_storage
    msg :info, 'Setup dedicated storage and populate /etc/fstab'

    # Previously executed in a start script, moved here because the start script was causing race condition issues.
    puts bash <<~SCRIPT
    # Silently abort when there is no disk attached.
    if ! lsblk -n -o name '#{ONEAPP_STORAGE_DEVICE}'; then exit 0; fi

    # Make sure mountpoint exists.
    install -o 0 -g 0 -m u=rwx,go=rx -d '#{ONEAPP_STORAGE_MOUNTPOINT}'

    # Silently abort when mountpoint is taken.
    if mountpoint '#{ONEAPP_STORAGE_MOUNTPOINT}'; then exit 0; fi

    # Create new filesystem if the device does not contain any.
    if ! blkid -s TYPE -o value '#{ONEAPP_STORAGE_DEVICE}'; then
        'mkfs.#{ONEAPP_STORAGE_FILESYSTEM}' '#{ONEAPP_STORAGE_DEVICE}'
    fi

    export STORAGE_UUID=$(blkid -s UUID -o value '#{ONEAPP_STORAGE_DEVICE}')
    # Assert that the detected UUID is not empty.
    if [[ -z "$STORAGE_UUID" ]]; then exit 1; fi

    # Update fstab if necessary.
    gawk -i inplace -f- /etc/fstab <<EOF
    BEGIN { insert = "UUID=${STORAGE_UUID} #{ONEAPP_STORAGE_MOUNTPOINT} #{ONEAPP_STORAGE_FILESYSTEM} defaults 0 1" }
    /UUID=${STORAGE_UUID}/ { found = 1 }
    { print }
    ENDFILE { if (!found) print insert }
    EOF

    # Mount the device using fstab.
    mount '#{ONEAPP_STORAGE_MOUNTPOINT}'
    SCRIPT
end

def fetch_longhorn(addon_dir = ONE_ADDON_DIR)
    bash <<~SCRIPT
    helm repo add longhorn https://charts.longhorn.io
    helm repo update
    SCRIPT

    manifest = <<~MANIFEST
    ---
    apiVersion: v1
    kind: Namespace
    metadata:
      name: longhorn-system
    ---
    apiVersion: helm.cattle.io/v1
    kind: HelmChart
    metadata:
      name: one-longhorn
      namespace: kube-system
    spec:
      bootstrap: false
      targetNamespace: longhorn-system
      chartContent: "%<chart_b64>s"
      valuesContent: |
        defaultSettings:
          createDefaultDiskLabeledNodes: true
          taintToleration: "node.longhorn.io/create-default-disk=true:NoSchedule"
        longhornManager:
          tolerations:
            - key: node.longhorn.io/create-default-disk
              value: "true"
              operator: Equal
              effect: NoSchedule
        longhornDriver:
          tolerations:
            - key: node.longhorn.io/create-default-disk
              value: "true"
              operator: Equal
              effect: NoSchedule
          nodeSelector:
            node.longhorn.io/create-default-disk: "true"
        longhornUI:
          tolerations:
            - key: node.longhorn.io/create-default-disk
              value: "true"
              operator: Equal
              effect: NoSchedule
          nodeSelector:
            node.longhorn.io/create-default-disk: "true"
    ---
    # Please note, changing default storage class is discouraged: https://longhorn.io/docs/1.3.0/best-practices/#storageclass
    kind: StorageClass
    apiVersion: storage.k8s.io/v1
    metadata:
      name: longhorn-retain
    provisioner: driver.longhorn.io
    allowVolumeExpansion: true
    reclaimPolicy: Retain
    volumeBindingMode: Immediate
    parameters:
      fsType: "ext4"
      numberOfReplicas: "3"
      staleReplicaTimeout: "2880"
      fromBackup: ""
    MANIFEST

    msg :info, "Generate Longhorn addon manifest: #{ONEAPP_K8S_LONGHORN_CHART_VERSION}"
    Dir.mktmpdir do |temp_dir|
        bash <<~SCRIPT
        cd #{temp_dir}/
        helm pull longhorn/longhorn --version '#{ONEAPP_K8S_LONGHORN_CHART_VERSION}'
        SCRIPT

        manifest %= { chart_b64: slurp("#{temp_dir}/longhorn-#{ONEAPP_K8S_LONGHORN_CHART_VERSION}.tgz") }

        file "#{addon_dir}/one-longhorn.yaml", manifest, overwrite: true
    end
end

def pull_longhorn_images(airgap_dir = ONE_AIRGAP_DIR)
    # https://longhorn.io/docs/1.3.0/advanced-resources/deploy/airgap/

    msg :info, "Pull Longhorn images: #{ONEAPP_K8S_LONGHORN_CHART_VERSION}"

    images = bash <<~SCRIPT, chomp: true
    curl -fsSL 'https://raw.githubusercontent.com/longhorn/longhorn/v#{ONEAPP_K8S_LONGHORN_CHART_VERSION}/deploy/longhorn-images.txt'
    SCRIPT

    images = images.lines
        .map(&:strip)
        .reject(&:empty?)

    pull_docker_images images, "#{airgap_dir}/one-longhorn/"
end
