# frozen_string_literal: true

require 'base64'
require 'rspec'
require 'tmpdir'
require 'yaml'

require_relative 'cilium.rb'

RSpec.describe 'extract_cilium_ranges' do
    it 'should extract and return all ranges (positive)' do
        input = [
            '10.11.12.0/24',
            '10.11.0.0/16'
        ]
        output = [
            %w[10.11.12.0 24],
            %w[10.11.0.0 16]
        ]
        expect(extract_cilium_ranges(input)).to eq output
    end

    it 'should extract and return no ranges (negative)' do
        input = [
            '',
            '10.11.12.0',
            '10.11.12.0/',
            'asd.11.12.0/24',
            '10.11.12.0/asd'
        ]
        output = []
        expect(extract_cilium_ranges(input)).to eq output
    end
end

RSpec.describe 'configure_cilium' do
    it 'should apply user-defined ranges (empty)' do
        stub_const 'K8S_CONTROL_PLANE_EP', '192.168.150.86:6443'
        stub_const 'ONEAPP_K8S_CNI_PLUGIN', 'cilium'
        stub_const 'ONEAPP_K8S_CNI_CONFIG', nil
        stub_const 'ONEAPP_K8S_CILIUM_RANGES', []
        output = YAML.load_stream <<~MANIFEST
        ---
        apiVersion: helm.cattle.io/v1
        kind: HelmChartConfig
        metadata:
          name: rke2-cilium
          namespace: kube-system
        spec:
          valuesContent: |-
            kubeProxyReplacement: strict
            k8sServiceHost: "192.168.150.86"
            k8sServicePort: 6443
            cni:
              chainingMode: "none"
              exclusive: false
            bgpControlPlane:
              enabled: true
        ---
        apiVersion: cilium.io/v2alpha1
        kind: CiliumLoadBalancerIPPool
        metadata:
          name: default
          namespace: kube-system
        spec:
          cidrs: {}
        MANIFEST
        Dir.mktmpdir do |temp_dir|
            configure_cilium temp_dir
            result = YAML.load_stream File.read "#{temp_dir}/rke2-cilium-config.yaml"
            expect(result).to eq output
        end
    end

    it 'should apply user-defined ranges' do
        stub_const 'K8S_CONTROL_PLANE_EP', '192.168.150.86:6443'
        stub_const 'ONEAPP_K8S_CNI_PLUGIN', 'cilium'
        stub_const 'ONEAPP_K8S_CILIUM_RANGES', ['192.168.150.128/25', '10.11.12.0/24']
        output = YAML.load_stream <<~MANIFEST
        ---
        apiVersion: helm.cattle.io/v1
        kind: HelmChartConfig
        metadata:
          name: rke2-cilium
          namespace: kube-system
        spec:
          valuesContent: |-
            kubeProxyReplacement: strict
            k8sServiceHost: "192.168.150.86"
            k8sServicePort: 6443
            cni:
              chainingMode: "none"
              exclusive: false
            bgpControlPlane:
              enabled: true
        ---
        apiVersion: cilium.io/v2alpha1
        kind: CiliumLoadBalancerIPPool
        metadata:
          name: default
          namespace: kube-system
        spec:
          cidrs:
          - cidr: 192.168.150.128/25
          - cidr: 10.11.12.0/24
        MANIFEST
        Dir.mktmpdir do |temp_dir|
            configure_cilium temp_dir
            result = YAML.load_stream File.read "#{temp_dir}/rke2-cilium-config.yaml"
            expect(result).to eq output
        end
    end

    it 'should apply user-defined config manifest (and ignore user-defined ranges)' do
        manifest = <<~MANIFEST
        ---
        apiVersion: helm.cattle.io/v1
        kind: HelmChartConfig
        metadata:
          name: rke2-cilium
          namespace: kube-system
        spec:
          valuesContent: |-
            kubeProxyReplacement: strict
            k8sServiceHost: "192.168.150.86"
            k8sServicePort: 6443
            cni:
              chainingMode: "none"
              exclusive: false
            bgpControlPlane:
              enabled: true
        ---
        apiVersion: cilium.io/v2alpha1
        kind: CiliumLoadBalancerIPPool
        metadata:
          name: default
          namespace: kube-system
        spec:
          cidrs:
          - cidr: 192.168.150.128/25
          - cidr: 10.11.12.0/24
        MANIFEST
        stub_const 'ONEAPP_K8S_CNI_PLUGIN', 'cilium'
        stub_const 'ONEAPP_K8S_CNI_CONFIG', Base64.encode64(manifest)
        stub_const 'ONEAPP_K8S_CILIUM_RANGES', ['1.2.3.4/5', '6.7.8.9/10']
        output = YAML.load_stream manifest
        Dir.mktmpdir do |temp_dir|
            configure_cilium temp_dir
            result = YAML.load_stream File.read "#{temp_dir}/rke2-cilium-config.yaml"
            expect(result).to eq output
        end
    end

end
