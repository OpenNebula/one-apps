# frozen_string_literal: true

require 'rspec'
require 'tmpdir'

def clear_env
    ENV.delete_if { |name| name.include?('_ROUTER4_') }
end

RSpec.describe self do
    it 'should enable forwarding (legacy)' do
        clear_env

        ENV['VROUTER_ID'] = '86'
        ENV['ONEAPP_VNF_ROUTER4_INTERFACES'] = 'eth0 eth1 eth2'

        load './main.rb'; include Service::Router4

        allow(Service::Router4).to receive(:detect_nics).and_return(%w[eth0 eth1 eth2 eth3])
        allow(Service::Router4).to receive(:toggle).and_return(nil)

        output = <<~'SYSCTL'
            net.ipv4.ip_forward = 0
            net.ipv4.conf.all.forwarding = 0
            net.ipv4.conf.default.forwarding = 0
            net.ipv4.conf.eth0.forwarding = 1
            net.ipv4.conf.eth1.forwarding = 1
            net.ipv4.conf.eth2.forwarding = 1
            net.ipv4.conf.eth3.forwarding = 0
        SYSCTL

        Dir.mktmpdir do |dir|
            Service::Router4.execute basedir: dir
            result = File.read "#{dir}/98-Router4.conf"
            expect(result.strip).to eq output.strip
        end
    end

    it 'should enable forwarding' do
        clear_env

        ENV['ONEAPP_VNF_ROUTER4_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_ROUTER4_INTERFACES'] = 'eth0 eth1'

        load './main.rb'; include Service::Router4

        allow(Service::Router4).to receive(:detect_nics).and_return(%w[eth0 eth1 eth2 eth3])
        allow(Service::Router4).to receive(:toggle).and_return(nil)

        output = <<~'SYSCTL'
            net.ipv4.ip_forward = 0
            net.ipv4.conf.all.forwarding = 0
            net.ipv4.conf.default.forwarding = 0
            net.ipv4.conf.eth0.forwarding = 1
            net.ipv4.conf.eth1.forwarding = 1
            net.ipv4.conf.eth2.forwarding = 0
            net.ipv4.conf.eth3.forwarding = 0
        SYSCTL

        Dir.mktmpdir do |dir|
            Service::Router4.execute basedir: dir
            result = File.read "#{dir}/98-Router4.conf"
            expect(result.strip).to eq output.strip
        end
    end

    it 'should disable forwarding' do
        clear_env

        ENV['ONEAPP_VNF_ROUTER4_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_ROUTER4_INTERFACES'] = 'eth0 eth1'

        load './main.rb'; include Service::Router4

        allow(Service::Router4).to receive(:detect_nics).and_return(%w[eth0 eth1 eth2 eth3])
        allow(Service::Router4).to receive(:toggle).and_return(nil)

        output = <<~'SYSCTL'
            net.ipv4.ip_forward = 0
            net.ipv4.conf.all.forwarding = 0
            net.ipv4.conf.default.forwarding = 0
            net.ipv4.conf.eth0.forwarding = 0
            net.ipv4.conf.eth1.forwarding = 0
            net.ipv4.conf.eth2.forwarding = 0
            net.ipv4.conf.eth3.forwarding = 0
        SYSCTL

        Dir.mktmpdir do |dir|
            Service::Router4.cleanup basedir: dir
            result = File.read "#{dir}/98-Router4.conf"
            expect(result.strip).to eq output.strip
        end
    end
end
