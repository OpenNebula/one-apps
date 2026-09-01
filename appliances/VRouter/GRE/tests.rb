# frozen_string_literal: true

require 'rspec'
require_relative 'main'

RSpec.describe Service::GRE do
  describe '.validate_interface' do
    it 'accepts Linux interface names' do
      expect(described_class.validate_interface('gre1')).to eq('gre1')
    end

    it 'rejects reserved names and option-like input' do
      %w[. .. all default gre0 -gre1].each do |name|
        expect { described_class.validate_interface(name) }
          .to raise_error(RuntimeError, /Invalid ONEAPP_VNF_GRE_INTERFACE/)
      end
    end

    it 'accepts dotted interface names' do
      expect(described_class.validate_interface('gre.1')).to eq('gre.1')
    end

    it 'rejects shell input' do
      expect { described_class.validate_interface('gre1;reboot') }
        .to raise_error(RuntimeError, /Invalid ONEAPP_VNF_GRE_INTERFACE/)
    end
  end

  describe '.validate_ipv4' do
    it 'accepts IPv4 CIDRs' do
      expect(described_class.validate_ipv4('172.31.160.66/30', 'ADDRESS', cidr: true))
        .to eq('172.31.160.66/30')
    end

    it 'rejects IPv6 and missing CIDR prefixes' do
      expect { described_class.validate_ipv4('2001:db8::1/64', 'ADDRESS', cidr: true) }
        .to raise_error(RuntimeError, /expected IPv4/)
      expect { described_class.validate_ipv4('172.31.160.66', 'ADDRESS', cidr: true) }
        .to raise_error(RuntimeError, /expected IPv4\/CIDR/)
    end

    it 'rejects malformed prefixes and dotted netmasks' do
      %w[192.0.2.1/33 192.0.2.1/255.255.255.0 192.0.2.1/].each do |address|
        expect { described_class.validate_ipv4(address, 'ADDRESS', cidr: true) }
          .to raise_error(RuntimeError, /Invalid ADDRESS/)
      end
    end

    it 'rejects CIDR prefixes for tunnel endpoints' do
      expect { described_class.validate_ipv4('192.0.2.1/24', 'LOCAL') }
        .to raise_error(RuntimeError, /expected IPv4/)
    end
  end

  describe '.validate_networks' do
    it 'parses and validates multiple networks' do
      expect(described_class.validate_networks('10.0.0.0/24, 192.0.2.0/24'))
        .to eq(%w[10.0.0.0/24 192.0.2.0/24])
    end

    it 'normalizes and deduplicates networks across whitespace separators' do
      expect(described_class.validate_networks("192.0.2.1/24\n192.0.2.0/24\t198.51.100.0/24"))
        .to eq(%w[192.0.2.0/24 198.51.100.0/24])
    end

    it 'requires at least one network' do
      expect { described_class.validate_networks(nil) }
        .to raise_error(RuntimeError, /Missing ONEAPP_VNF_GRE_NETWORKS/)
    end
  end

  describe '.validate_ttl' do
    it 'accepts TTL values in range' do
      expect(described_class.validate_ttl('255')).to eq('255')
    end

    it 'rejects TTL values outside the range' do
      expect { described_class.validate_ttl('256') }
        .to raise_error(RuntimeError, /expected 1\.\.255/)
    end
  end

  describe '.execute' do
    it 'validates configuration before changing the system' do
      allow(described_class).to receive(:configuration).and_raise('Invalid configuration')
      expect(described_class).not_to receive(:bash)
      expect { described_class.execute }.to raise_error('Invalid configuration')
    end

    it 'enables IPv4 forwarding on the GRE interface after creating it' do
      allow(described_class).to receive(:configuration).and_return(
        interface: 'gre1',
        address: '172.31.160.66/30',
        local: '192.0.2.1',
        remote: '192.0.2.2',
        gateway: '172.31.160.65',
        networks: ['198.51.100.0/24'],
        ttl: '255'
      )
      allow(described_class).to receive(:bash)

      described_class.execute

      expect(described_class).to have_received(:bash).with(
        a_string_including('ip link set gre1 up')
      ).ordered
      expect(described_class).to have_received(:bash).with(
        'sysctl -w net/ipv4/conf/gre1/forwarding=1'
      ).ordered
    end
  end

  it 'implements every appliance lifecycle step' do
    expect(described_class).to respond_to(:install, :configure, :bootstrap)
  end
end
