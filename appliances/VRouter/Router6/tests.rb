# frozen_string_literal: true

require 'rspec'
require 'tmpdir'

def clear_env
    ENV.delete_if { |name| name.start_with?('ETH') || name.include?('VROUTER_') || name.include?('_VNF_') }
end

RSpec.describe self do
    before do
        clear_env

        load './main.rb'; include Service::Router6

        allow(Service::Router6).to receive(:detect_nics).and_return(%w[eth0 eth1 eth2])
        allow(Service::Router6).to receive(:detect_mgmt_nics).and_return(%w[eth0])
        allow(Service::Router6).to receive(:toggle).and_return(nil)
    end

    it 'should be disabled by default' do
        expect(Service::Router6::ONEAPP_VNF_ROUTER6_ENABLED).to be false
    end

    it 'should enable forwarding between the routed NICs and isolate the management NICs' do
        output = <<~'SYSCTL'
            net.ipv6.conf.eth1.accept_ra = 2
            net.ipv6.conf.eth2.accept_ra = 2
            net.ipv6.conf.eth0.accept_ra = 2
            net.ipv6.conf.default.forwarding = 0
            net.ipv6.conf.all.forwarding = 1
            net.ipv6.conf.eth0.forwarding = 0
        SYSCTL

        Dir.mktmpdir do |dir|
            Service::Router6.execute basedir: dir
            result = File.read "#{dir}/98-Router6.conf"
            expect(result.strip).to eq output.strip
        end
    end

    it 'should set accept_ra before the global switch, which turns it off where it is 1' do
        out = Service::Router6.render(routed: %w[eth1], others: %w[eth0]).lines.map(&:chomp)

        expect(out.index('net.ipv6.conf.eth0.accept_ra = 2')).to be < out.index('net.ipv6.conf.all.forwarding = 1')
        expect(out.index('net.ipv6.conf.eth1.accept_ra = 2')).to be < out.index('net.ipv6.conf.all.forwarding = 1')
    end

    it 'should switch the global forwarding on (a per-NIC write alone does not forward)' do
        out = Service::Router6.render(routed: %w[eth1], others: %w[eth0])

        expect(out).to include("net.ipv6.conf.all.forwarding = 1\n")
        expect(out).not_to include('net.ipv6.conf.all.forwarding = 0')
    end

    it 'should disable forwarding everywhere at cleanup' do
        output = <<~'SYSCTL'
            net.ipv6.conf.all.forwarding = 0
            net.ipv6.conf.default.forwarding = 0
            net.ipv6.conf.eth0.forwarding = 0
            net.ipv6.conf.eth1.forwarding = 0
            net.ipv6.conf.eth2.forwarding = 0
        SYSCTL

        Dir.mktmpdir do |dir|
            Service::Router6.cleanup basedir: dir
            result = File.read "#{dir}/98-Router6.conf"
            expect(result.strip).to eq output.strip
        end
    end

    it 'should stop and disable the service when it is not enabled' do
        expect(Service::Router6).to receive(:toggle).with(%i[stop disable])

        Service::Router6.configure
    end

    it 'should leave the service alone when it is enabled' do
        ENV['ONEAPP_VNF_ROUTER6_ENABLED'] = 'YES'
        load './main.rb'

        expect(Service::Router6).not_to receive(:toggle)

        Service::Router6.configure
    end
end
