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

require 'time'

begin
    require '/etc/one-appliance/lib/helpers.rb'
rescue LoadError
    require_relative '../lib/helpers.rb'
end

require_relative 'config.rb'

module Service
module Capi
    extend self

    DEPENDS_ON = %w[]

    def install
        msg :info, 'Capi::install'

        msg :info, "Install K3s: #{CAPI_K3S_VERSION}"
        puts bash <<~SCRIPT
        export INSTALL_K3S_SKIP_ENABLE='true'
        export INSTALL_K3S_SKIP_START='true'
        export INSTALL_K3S_VERSION='#{CAPI_K3S_VERSION}'
        curl -fsSL https://get.k3s.io | $SHELL -
        SCRIPT

        msg :info, 'Create /etc/profile.d/98-k3s.sh'
        file '/etc/profile.d/98-k3s.sh', <<~SCRIPT, mode: 'u=rw,go=r'
        export KUBECONFIG='#{KUBECONFIG}'
        SCRIPT
    end

    def configure(manifests_dir: MANIFESTS_DIR)
        msg :info, 'Capi::configure'

        msg :info, 'Enable/Start K3s'
        puts bash <<~SCRIPT
        systemctl enable --now k3s.service
        SCRIPT

        msg :info, "Install/Upgrade Cert Manager: #{CAPI_CERT_MANAGER_VERSION}"
        (manifests = []) << <<~MANIFEST
        apiVersion: helm.cattle.io/v1
        kind: HelmChart
        metadata:
          name: cert-manager
          namespace: kube-system
        spec:
          targetNamespace: cert-manager
          createNamespace: true
          repo: 'https://charts.jetstack.io'
          chart: cert-manager
          version: '#{CAPI_CERT_MANAGER_VERSION}'
          valuesContent: |-
            crds:
              enabled: true
        MANIFEST
        manifests << <<~MANIFEST
        apiVersion: cert-manager.io/v1
        kind: ClusterIssuer
        metadata:
          name: default-issuer
        spec:
          selfSigned: {}
        MANIFEST
        file "#{manifests_dir}/cert-manager.yaml", manifests.join("\n---\n"), mode: 'u=rw,go=r', overwrite: true

        msg :info, "Install/Upgrade Rancher: #{CAPI_RANCHER_VERSION}"
        (manifests = []) << <<~MANIFEST
        apiVersion: helm.cattle.io/v1
        kind: HelmChart
        metadata:
          name: rancher
          namespace: kube-system
        spec:
          targetNamespace: cattle-system
          createNamespace: true
          repo: 'https://releases.rancher.com/server-charts/stable'
          chart: rancher
          version: '#{CAPI_RANCHER_VERSION}'
          valuesContent: |-
            replicas: 1
            bootstrapPassword: '#{CAPI_RANCHER_PASSWORD}'
            ingress:
              enabled: false
            tls: external
        MANIFEST
        manifests << <<~MANIFEST
        apiVersion: management.cattle.io/v3
        kind: Setting
        metadata:
          name: first-login
        value: 'false'
        MANIFEST
        manifests << <<~MANIFEST
        apiVersion: management.cattle.io/v3
        kind: Setting
        metadata:
          name: eula-agreed
        value: '#{Time.now.iso8601}'
        MANIFEST
        manifests << <<~MANIFEST
        apiVersion: management.cattle.io/v3
        kind: Feature
        metadata:
          name: embedded-cluster-api
        spec:
          value: false
        MANIFEST
        manifests << <<~MANIFEST
        apiVersion: traefik.io/v1alpha1
        kind: Middleware
        metadata:
          name: rancher-headers
          namespace: cattle-system
        spec:
          headers:
            customRequestHeaders:
              X-Forwarded-Proto: https
        MANIFEST
        if CAPI_RANCHER_HOSTNAME.nil?
            manifests << <<~MANIFEST
            apiVersion: networking.k8s.io/v1
            kind: Ingress
            metadata:
              name: rancher-ingress
              namespace: cattle-system
              annotations:
                traefik.ingress.kubernetes.io/router.middlewares: cattle-system-rancher-headers@kubernetescrd
            spec:
              rules:
                - http:
                    paths:
                      - path: /
                        pathType: Prefix
                        backend:
                          service:
                            name: rancher
                            port: { number: 80 }
            MANIFEST
        else
            manifests << <<~MANIFEST
            apiVersion: networking.k8s.io/v1
            kind: Ingress
            metadata:
              name: rancher-ingress
              namespace: cattle-system
              annotations:
                cert-manager.io/cluster-issuer: default-issuer
            spec:
              tls:
                - hosts: ['#{CAPI_RANCHER_HOSTNAME}']
                  secretName: rancher-cert
              rules:
                - host: '#{CAPI_RANCHER_HOSTNAME}'
                  http:
                    paths:
                      - path: /
                        pathType: Prefix
                        backend:
                          service:
                            name: rancher
                            port: { number: 80 }
            MANIFEST
        end
        file "#{manifests_dir}/rancher.yaml", manifests.join("\n---\n"), mode: 'u=rw,go=r', overwrite: true

        msg :info, "Install/Upgrade Turtles: #{CAPI_TURTLES_VERSION}"
        (manifests = []) << <<~MANIFEST
        apiVersion: helm.cattle.io/v1
        kind: HelmChart
        metadata:
          name: rancher-turtles
          namespace: kube-system
        spec:
          targetNamespace: rancher-turtles-system
          createNamespace: true
          repo: 'https://rancher.github.io/turtles'
          chart: rancher-turtles
          version: '#{CAPI_TURTLES_VERSION}'
          valuesContent: |-
            turtlesUI:
              enabled: true
        MANIFEST
        file "#{manifests_dir}/rancher-turtles.yaml", manifests.join("\n---\n"), mode: 'u=rw,go=r', overwrite: true

        msg :info, "Install/Upgrade Capone: #{CAPI_CAPONE_VERSION}"
        (manifests = []) << <<~MANIFEST
        apiVersion: v1
        kind: Namespace
        metadata:
          name: capone-system
        MANIFEST
        manifests << <<~MANIFEST
        apiVersion: turtles-capi.cattle.io/v1alpha1
        kind: CAPIProvider
        metadata:
          name: opennebula
          namespace: capone-system
        spec:
          features:
            clusterResourceSet: true
            clusterTopology: true
            machinePool: true
          fetchConfig:
            url: 'https://github.com/OpenNebula/cluster-api-provider-opennebula/releases/download/#{CAPI_CAPONE_VERSION}/infrastructure-components.yaml'
          name: opennebula
          type: infrastructure
          version: '#{CAPI_CAPONE_VERSION}'
        MANIFEST
        file "#{manifests_dir}/capone.yaml", manifests.join("\n---\n"), mode: 'u=rw,go=r', overwrite: true

        msg :info, "Install/Upgrade Gitea: #{CAPI_GITEA_VERSION}"
        (manifests = []) << <<~MANIFEST
        apiVersion: helm.cattle.io/v1
        kind: HelmChart
        metadata:
          name: gitea
          namespace: kube-system
        spec:
          targetNamespace: gitea
          createNamespace: true
          repo: 'https://dl.gitea.com/charts'
          chart: gitea
          version: '#{CAPI_GITEA_VERSION}'
          valuesContent: |-
            postgresql-ha: { enabled: false }
            redis-cluster: { enabled: false }
            postgresql:    { enabled: true }
            redis:         { enabled: true }
            gitea:
              admin:
                username: admin
                password: '#{CAPI_GITEA_PASSWORD}'
              config:
                server:
                  DOMAIN: '#{CAPI_GITEA_DOMAIN || ETH0_IP}'
                  ROOT_URL: '#{CAPI_GITEA_ROOT_URL}'
            ingress:
              enabled: false
        MANIFEST
        manifests << <<~MANIFEST
        apiVersion: traefik.io/v1alpha1
        kind: Middleware
        metadata:
          name: gitea-stripprefix
          namespace: gitea
        spec:
          stripPrefix:
            prefixes: [/gitea]
        MANIFEST
        if CAPI_GITEA_DOMAIN.nil?
            manifests << <<~MANIFEST
            apiVersion: networking.k8s.io/v1
            kind: Ingress
            metadata:
              name: gitea-ingress
              namespace: gitea
              annotations:
                traefik.ingress.kubernetes.io/router.middlewares: gitea-gitea-stripprefix@kubernetescrd
            spec:
              rules:
                - http:
                    paths:
                      - path: /gitea
                        pathType: Prefix
                        backend:
                          service:
                            name: gitea-http
                            port: { number: 3000 }
            MANIFEST
        else
            manifests << <<~MANIFEST
            apiVersion: networking.k8s.io/v1
            kind: Ingress
            metadata:
              name: gitea-ingress
              namespace: gitea
              annotations:
                cert-manager.io/cluster-issuer: default-issuer
                traefik.ingress.kubernetes.io/router.middlewares: gitea-gitea-stripprefix@kubernetescrd
            spec:
              tls:
                - hosts: ['#{CAPI_GITEA_DOMAIN}']
                  secretName: gitea-cert
              rules:
                - host: '#{CAPI_GITEA_DOMAIN}'
                  http:
                    paths:
                      - path: /gitea
                        pathType: Prefix
                        backend:
                          service:
                            name: gitea-http
                            port: { number: 3000 }
            MANIFEST
        end
        file "#{manifests_dir}/gitea.yaml", manifests.join("\n---\n"), mode: 'u=rw,go=r', overwrite: true
    end

    def bootstrap
        msg :info, 'Capi::bootstrap'

        msg :info, 'Mark namespaces to be auto-imported'
        puts bash <<~SCRIPT
        kubectl label namespace default cluster-api.cattle.io/rancher-auto-import=true
        SCRIPT
    end
end
end
