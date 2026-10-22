# frozen_string_literal: true

require 'rspec'
require_relative 'main'

RSpec.describe Service::GRE do
    it 'validates interface names' do
        %w[gre1 gre.1].each do |name|
            expect(described_class.validate_interface(name)).to eq(name)
        end
        %w[. .. all default gre0 -gre1 gre1;reboot].each do |name|
            expect { described_class.validate_interface(name) }
                .to raise_error(RuntimeError, /Invalid ONEAPP_VNF_GRE_INTERFACE/)
        end
    end

    it 'validates IPv4 addresses and CIDR prefixes' do
        expect(described_class.validate_ipv4('192.0.2.1', 'LOCAL')).to eq('192.0.2.1')
        expect(described_class.validate_ipv4('172.31.160.66/30', 'ADDRESS', cidr: true))
            .to eq('172.31.160.66/30')

        %w[2001:db8::1/64 192.0.2.1 192.0.2.1/33 192.0.2.1/255.255.255.0 192.0.2.1/].each do |address|
            expect { described_class.validate_ipv4(address, 'ADDRESS', cidr: true) }
                .to raise_error(RuntimeError, /Invalid ADDRESS/)
        end
        expect { described_class.validate_ipv4('192.0.2.1/24', 'LOCAL') }
            .to raise_error(RuntimeError, /Invalid LOCAL/)
    end

    it 'normalizes and deduplicates source networks and requires at least one' do
        expect(described_class.validate_networks("192.0.2.1/24,192.0.2.0/24\n198.51.100.0/24"))
            .to eq(%w[192.0.2.0/24 198.51.100.0/24])
        expect { described_class.validate_networks(nil) }
            .to raise_error(RuntimeError, /Missing ONEAPP_VNF_GRE_NETWORKS/)
    end

    it 'validates the TTL range' do
        expect(described_class.validate_ttl('255')).to eq('255')
        expect { described_class.validate_ttl('256') }
            .to raise_error(RuntimeError, /Invalid ONEAPP_VNF_GRE_TTL/)
    end

    it 'validates configuration before changing the system' do
        allow(described_class).to receive(:configuration).and_raise('Invalid configuration')
        expect(described_class).not_to receive(:bash)
        expect { described_class.execute }.to raise_error('Invalid configuration')
    end

    it 'enables forwarding and prefers non-default main routes over GRE for each source network' do
        networks = %w[198.51.100.0/24 203.0.113.0/24]
        allow(described_class).to receive(:configuration).and_return(
            interface: 'gre1', address: '172.31.160.66/30',
            local: '192.0.2.1', remote: '192.0.2.2',
            gateway: '172.31.160.65', networks: networks, ttl: '255'
        )
        scripts = []
        allow(described_class).to receive(:bash) { |script| scripts << script }

        described_class.execute

        output = scripts.join("\n")
        expect(output).to include('sysctl -w net/ipv4/conf/gre1/forwarding=1')
        expect(output).to match(/ip route replace default\s+via 172\.31\.160\.65\s+dev gre1\s+table 10000/)
        expect(output).to include('ip rule flush priority 9999 table main', 'ip rule flush table 10000')
        networks.each do |network|
            expect(output).to include("ip rule add priority 9999 from #{network} lookup main suppress_prefixlength 0")
            expect(output).to include("ip rule add priority 10000 from #{network} table 10000")
        end
        expect(output).not_to include('throw')
    end

    it 'removes both rule sets and the tunnel without needing the source networks' do
        stub_const('Service::GRE::ONEAPP_VNF_GRE_NETWORKS', nil)
        allow(described_class).to receive(:bash)

        described_class.cleanup

        expect(described_class).to have_received(:bash).with(
            a_string_including(
                'ip rule flush priority 9999 table main',
                'ip rule flush table 10000', 'ip route flush table 10000'
            )
        )
        expect(described_class).to have_received(:bash).with('ip tunnel del gre1 2>/dev/null || true')
    end
end
