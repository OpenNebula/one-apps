# frozen_string_literal: true

require 'base64'
require 'rspec'
require 'tmpdir'
require 'yaml'

require_relative 'metallb.rb'

RSpec.describe 'extract_metallb_ranges' do
    it 'should extract and return all ranges (positive)' do
        input = [
            '10.11.12.13',
            '10.11.12.13-',
            '10.11.12.13-10.11.12.31',
            ' 10.11.12.13-10.11.12.31',
            '10.11.12.13-10.11.12.31 ',
            '10.11.12.13 -10.11.12.31',
            '10.11.12.13- 10.11.12.31'
        ]
        output = [
            %w[10.11.12.13 10.11.12.13],
            %w[10.11.12.13 10.11.12.13],
            %w[10.11.12.13 10.11.12.31],
            %w[10.11.12.13 10.11.12.31],
            %w[10.11.12.13 10.11.12.31],
            %w[10.11.12.13 10.11.12.31],
            %w[10.11.12.13 10.11.12.31]
        ]
        expect(extract_metallb_ranges(input)).to eq output
    end

    it 'should extract and return no ranges (negative)' do
        input = [
            '',
            '-10.11.12.13',
            'asd.11.12.13-10.11.12.31',
            '10.11.12.13-10.11.12.31-10.11.12.123'
        ]
        output = []
        expect(extract_metallb_ranges(input)).to eq output
    end
end

RSpec.describe 'configure_metallb' do
    it 'should apply user-defined ranges (empty)' do
        stub_const 'ONEAPP_K8S_METALLB_CONFIG', nil
        stub_const 'ONEAPP_K8S_METALLB_RANGES', []
        output = YAML.load_stream <<~MANIFEST
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
          ipAddressPools:
          - default
        MANIFEST
        Dir.mktmpdir do |temp_dir|
            configure_metallb temp_dir
            result = YAML.load_stream File.read "#{temp_dir}/one-metallb-config.yaml"
            expect(result).to eq output
        end
    end

    it 'should apply user-defined ranges' do
        stub_const 'ONEAPP_K8S_METALLB_CONFIG', nil
        stub_const 'ONEAPP_K8S_METALLB_RANGES', ['192.168.150.87-192.168.150.88']
        output = YAML.load_stream <<~MANIFEST
        ---
        apiVersion: metallb.io/v1beta1
        kind: IPAddressPool
        metadata:
          name: default
          namespace: metallb-system
        spec:
          addresses:
          - 192.168.150.87-192.168.150.88
        ---
        apiVersion: metallb.io/v1beta1
        kind: L2Advertisement
        metadata:
          name: default
          namespace: metallb-system
        spec:
          ipAddressPools:
          - default
        MANIFEST
        Dir.mktmpdir do |temp_dir|
            configure_metallb temp_dir
            result = YAML.load_stream File.read "#{temp_dir}/one-metallb-config.yaml"
            expect(result).to eq output
        end
    end

    it 'should apply user-defined config manifest (and ignore user-defined ranges)' do
        manifest = <<~MANIFEST
        ---
        apiVersion: metallb.io/v1beta1
        kind: IPAddressPool
        metadata:
          name: default
          namespace: metallb-system
        spec:
          addresses:
          - 192.168.150.87-192.168.150.88
        ---
        apiVersion: metallb.io/v1beta1
        kind: L2Advertisement
        metadata:
          name: default
          namespace: metallb-system
        spec:
          ipAddressPools:
          - default
        MANIFEST
        stub_const 'ONEAPP_K8S_METALLB_CONFIG', Base64.encode64(manifest)
        stub_const 'ONEAPP_K8S_METALLB_RANGES', ['1.2.3.4-1.2.3.4']
        output = YAML.load_stream manifest
        Dir.mktmpdir do |temp_dir|
            configure_metallb temp_dir
            result = YAML.load_stream File.read "#{temp_dir}/one-metallb-config.yaml"
            expect(result).to eq output
        end
    end

end
