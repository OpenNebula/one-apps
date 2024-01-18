# frozen_string_literal: true

require_relative 'config.rb'
require_relative 'helpers.rb'
require_relative 'onegate.rb'

def install_cleaner(addon_dir = ONE_ADDON_DIR)
    msg :info, 'Install One-Cleaner'
    fetch_cleaner addon_dir
end

def fetch_cleaner(addon_dir = ONE_ADDON_DIR, cron = '*/2 * * * *', ttl = 180)
    msg :info, 'Generate One-Cleaner manifest'

    file "#{addon_dir}/one-cleaner.yaml", <<~MANIFEST, overwrite: true
    apiVersion: batch/v1
    kind: CronJob
    metadata:
      name: one-cleaner
      namespace: kube-system
    spec:
      schedule: "#{cron}"
      jobTemplate:
        spec:
          ttlSecondsAfterFinished: #{ttl}
          template:
            spec:
              hostNetwork: true
              tolerations:
              - key: node-role.kubernetes.io/master
                effect: NoSchedule
              - key: CriticalAddonsOnly
                operator: Equal
                value: "true"
                effect: NoExecute
              nodeSelector:
                node-role.kubernetes.io/master: "true"
              containers:
              - name: one-cleaner
                image: ruby:2.7-alpine3.16
                imagePullPolicy: IfNotPresent
                command:
                - /usr/local/bin/ruby
                - /etc/one-appliance/service.d/OneKE/cleaner.rb
                volumeMounts:
                - name: kubectl
                  mountPath: /var/lib/rancher/rke2/bin/kubectl
                - name: kubeconfig
                  mountPath: /etc/rancher/rke2/rke2.yaml
                - name: context
                  mountPath: /var/run/one-context/one_env
                - name: onegate
                  mountPath: /usr/bin/onegate
                - name: onegaterb
                  mountPath: /usr/bin/onegate.rb
                - name: lib
                  mountPath: /etc/one-appliance/lib/
                - name: appliance
                  mountPath: /etc/one-appliance/service.d/OneKE/
              volumes:
              - name: kubectl
                hostPath:
                  path: /var/lib/rancher/rke2/bin/kubectl
                  type: File
              - name: kubeconfig
                hostPath:
                  path: /etc/rancher/rke2/rke2.yaml
                  type: File
              - name: context
                hostPath:
                  path: /var/run/one-context/one_env
                  type: File
              - name: onegate
                hostPath:
                  path: /usr/bin/onegate
                  type: File
              - name: onegaterb
                hostPath:
                  path: /usr/bin/onegate.rb
                  type: File
              - name: lib
                hostPath:
                  path: /etc/one-appliance/lib/
                  type: Directory
              - name: appliance
                hostPath:
                  path: /etc/one-appliance/service.d/OneKE/
                  type: Directory
              restartPolicy: Never
    MANIFEST
end

def detect_invalid_nodes
    kubernetes_nodes = kubectl_get_nodes.dig 'items'
    if kubernetes_nodes.nil? || kubernetes_nodes.empty?
        msg :error, 'No Kubernetes nodes found'
        exit 1
    end

    onegate_vms = all_vms_show
    if onegate_vms.nil? || onegate_vms.empty?
        msg :error, 'No Onegate VMs found'
        exit 1
    end

    kubernetes_node_names = kubernetes_nodes
        .map { |item| item.dig 'metadata', 'name' }
        .reject(&:nil?)
        .select { |item| item.start_with? 'oneke-ip-' }

    onegate_node_names = onegate_vms
        .map { |item| item.dig 'VM', 'USER_TEMPLATE', 'ONEGATE_K8S_NODE_NAME' }
        .reject(&:nil?)
        .select { |item| item.start_with? 'oneke-ip-' }

    kubernetes_node_names - onegate_node_names
end

if caller.empty?
    # The ruby / alpine container does not have bash pre-installed,
    # but busybox / ash seems to be somewhat compatible, at least usable..
    # It cannot be a simple symlink, because busybox is a multi-call binary..
    file '/bin/bash', <<~SCRIPT, mode: 'u=rwx,go=rx', overwrite: false
    #!/bin/ash
    exec /bin/ash "$@"
    SCRIPT

    detect_invalid_nodes.each do |name|
        puts kubectl "delete node '#{name}'"
    end
end
