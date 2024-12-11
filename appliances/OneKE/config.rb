# frozen_string_literal: true

begin
    require '/etc/one-appliance/lib/helpers.rb'
rescue LoadError
    require_relative '../lib/helpers.rb'
end

ONE_SERVICE_VERSION   = env :ONE_SERVICE_VERSION, '1.31'
ONE_SERVICE_AIRGAPPED = env :ONE_SERVICE_AIRGAPPED, 'NO'
ONE_SERVICE_SETUP_DIR = env :ONE_SERVICE_SETUP_DIR, '/opt/one-appliance'

ONE_SERVICE_RKE2_RELEASE = env :ONE_SERVICE_RKE2_RELEASE, "#{ONE_SERVICE_VERSION}.3"
ONE_SERVICE_RKE2_VERSION = env :ONE_SERVICE_RKE2_VERSION, "v#{ONE_SERVICE_RKE2_RELEASE}+rke2r1"
ONE_SERVICE_HELM_VERSION = env :ONE_SERVICE_HELM_VERSION, '3.16.3'

ONEAPP_K8S_MULTUS_ENABLED = env :ONEAPP_K8S_MULTUS_ENABLED, 'NO'
ONEAPP_K8S_MULTUS_CONFIG  = env :ONEAPP_K8S_MULTUS_CONFIG, nil

ONEAPP_K8S_CNI_PLUGIN    = env :ONEAPP_K8S_CNI_PLUGIN, 'cilium'
ONEAPP_K8S_CNI_CONFIG    = env :ONEAPP_K8S_CNI_CONFIG, nil
ONEAPP_K8S_CILIUM_RANGES = ENV.select { |key, _| key.start_with? 'ONEAPP_K8S_CILIUM_RANGE' } .values

ONEAPP_K8S_LONGHORN_CHART_VERSION = env :ONEAPP_K8S_LONGHORN_CHART_VERSION, '1.7.2'
ONEAPP_K8S_LONGHORN_ENABLED       = env :ONEAPP_K8S_LONGHORN_ENABLED, 'NO'

ONEAPP_STORAGE_DEVICE     = env :ONEAPP_STORAGE_DEVICE, nil # for example '/dev/vdb'
ONEAPP_STORAGE_FILESYSTEM = env :ONEAPP_STORAGE_FILESYSTEM, 'xfs'
ONEAPP_STORAGE_MOUNTPOINT = env :ONEAPP_STORAGE_MOUNTPOINT, '/var/lib/longhorn'

ONEAPP_K8S_METALLB_CHART_VERSION = env :ONEAPP_K8S_METALLB_CHART_VERSION, '0.14.8'
ONEAPP_K8S_METALLB_ENABLED       = env :ONEAPP_K8S_METALLB_ENABLED, 'NO'
ONEAPP_K8S_METALLB_CONFIG        = env :ONEAPP_K8S_METALLB_CONFIG, nil
ONEAPP_K8S_METALLB_RANGES        = ENV.select { |key, _| key.start_with? 'ONEAPP_K8S_METALLB_RANGE' } .values

ONEAPP_K8S_TRAEFIK_CHART_VERSION = env :ONEAPP_K8S_TRAEFIK_CHART_VERSION, '28.0.0'
ONEAPP_K8S_TRAEFIK_ENABLED       = env :ONEAPP_K8S_TRAEFIK_ENABLED, 'NO'

ONEAPP_K8S_RUBY_VERSION = env :ONEAPP_K8S_RUBY_VERSION, '3.3-alpine3.18'

ONEAPP_K8S_CUSTOM_CLOUD_CONTROLLER = env :ONEAPP_K8S_CUSTOM_CLOUD_CONTROLLER, 'NO'

ONEAPP_VROUTER_ETH0_VIP0 = env :ONEAPP_VROUTER_ETH0_VIP0, nil
ONEAPP_VROUTER_ETH1_VIP0 = env :ONEAPP_VROUTER_ETH1_VIP0, nil

ONEAPP_VNF_HAPROXY_LB0_IP   = env :ONEAPP_VNF_HAPROXY_LB0_IP, ONEAPP_VROUTER_ETH0_VIP0
ONEAPP_VNF_HAPROXY_LB0_PORT = env :ONEAPP_VNF_HAPROXY_LB0_PORT, '9345'
ONEAPP_VNF_HAPROXY_LB1_IP   = env :ONEAPP_VNF_HAPROXY_LB1_IP, ONEAPP_VROUTER_ETH0_VIP0
ONEAPP_VNF_HAPROXY_LB1_PORT = env :ONEAPP_VNF_HAPROXY_LB1_PORT, '6443'
ONEAPP_VNF_HAPROXY_LB2_IP   = env :ONEAPP_VNF_HAPROXY_LB2_IP, ONEAPP_VROUTER_ETH0_VIP0
ONEAPP_VNF_HAPROXY_LB2_PORT = env :ONEAPP_VNF_HAPROXY_LB2_PORT, '443'
ONEAPP_VNF_HAPROXY_LB3_IP   = env :ONEAPP_VNF_HAPROXY_LB3_IP, ONEAPP_VROUTER_ETH0_VIP0
ONEAPP_VNF_HAPROXY_LB3_PORT = env :ONEAPP_VNF_HAPROXY_LB3_PORT, '80'

ONEAPP_VNF_DNS_ENABLED = env :ONEAPP_VNF_DNS_ENABLED, 'YES'

ONEAPP_RKE2_SUPERVISOR_EP   = env :ONEAPP_RKE2_SUPERVISOR_EP, "#{ONEAPP_VROUTER_ETH0_VIP0}:#{ONEAPP_VNF_HAPROXY_LB0_PORT}"
ONEAPP_K8S_CONTROL_PLANE_EP = env :ONEAPP_K8S_CONTROL_PLANE_EP, "#{ONEAPP_VROUTER_ETH0_VIP0}:#{ONEAPP_VNF_HAPROXY_LB1_PORT}"
ONEAPP_K8S_EXTRA_SANS       = env :ONEAPP_K8S_EXTRA_SANS, 'localhost,127.0.0.1'

# Proxy config for RKE2: https://docs.rke2.io/advanced#configuring-an-http-proxy
ONEAPP_K8S_HTTP_PROXY = env :ONEAPP_K8S_HTTP_PROXY, nil
ONEAPP_K8S_HTTPS_PROXY = env :ONEAPP_K8S_HTTPS_PROXY, nil
ONEAPP_K8S_NO_PROXY = env :ONEAPP_K8S_NO_PROXY, nil

FALLBACK_GW  = env :FALLBACK_GW, nil
FALLBACK_DNS = env :FALLBACK_DNS, nil

ONE_ADDON_DIR  = env :ONE_ADDON_DIR, "#{ONE_SERVICE_SETUP_DIR}/addons"
ONE_AIRGAP_DIR = env :ONE_AIRGAP_DIR, "#{ONE_SERVICE_SETUP_DIR}/airgap"

K8S_MANIFEST_DIR = env :K8S_MANIFEST_DIR, '/var/lib/rancher/rke2/server/manifests'
K8S_IMAGE_DIR    = env :K8S_IMAGE_DIR, '/var/lib/rancher/rke2/agent/images'

RETRIES = 86
SECONDS = 5

PACKAGES = %w[
    curl
    gawk
    gnupg
    lsb-release
    openssl
    skopeo
    zstd
].freeze

KUBECONFIG = %w[/etc/rancher/rke2/rke2.yaml].freeze
