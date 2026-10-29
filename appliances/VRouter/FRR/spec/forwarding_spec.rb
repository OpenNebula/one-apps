# frozen_string_literal: true

require_relative 'support/quiet_logs'
require 'tmpdir'
require 'fileutils'
require_relative '../forwarding'

RSpec.describe Service::FRR::Forwarding do
    let(:dir) { Dir.mktmpdir }

    after { FileUtils.remove_entry(dir) }

    def sysctl(name, value)
        path = File.join(dir, name)
        FileUtils.mkdir_p File.dirname(path)
        File.write(path, "#{value}\n")
        path
    end

    it 'writes 0 to every forwarding file that matches' do
        all  = sysctl('ipv4/conf/all/forwarding', 1)
        eth1 = sysctl('ipv4/conf/eth1/forwarding', 1)
        six  = sysctl('ipv6/conf/all/forwarding', 1)
        flat = sysctl('ipv4/ip_forward', 1)

        failed = described_class.off(paths: ["#{dir}/ipv4/ip_forward", "#{dir}/ipv4/conf/*/forwarding", "#{dir}/ipv6/conf/*/forwarding"])

        expect([all, eth1, six, flat].map { |path| File.read(path) }).to all(eq("0\n"))
        expect(failed).to be_empty
    end

    it 'does not touch other files in the same directories' do
        other = sysctl('ipv4/conf/eth1/rp_filter', 2)
        sysctl('ipv4/conf/eth1/forwarding', 1)

        described_class.off(paths: ["#{dir}/ipv4/conf/*/forwarding"])

        expect(File.read(other)).to eq "2\n"
    end

    it 'returns the paths it cannot write and keeps going' do
        locked = sysctl('ipv4/conf/eth0/forwarding', 1)
        open   = sysctl('ipv4/conf/eth1/forwarding', 1)
        allow(File).to receive(:write).and_call_original
        allow(File).to receive(:write).with(locked, "0\n").and_raise(Errno::EACCES)

        failed = described_class.off(paths: ["#{dir}/ipv4/conf/*/forwarding"])

        expect(failed).to eq [locked]
        expect(File.read(open)).to eq "0\n"
    end

    it 'does nothing and does not fail when no file matches' do
        expect(described_class.off(paths: ["#{dir}/missing/*/forwarding"])).to be_empty
    end

    it 'covers the IPv4 and IPv6 forwarding files that zebra and frr-reload change' do
        expect(described_class::PATHS).to include('/proc/sys/net/ipv4/ip_forward',
                                                  '/proc/sys/net/ipv4/conf/*/forwarding',
                                                  '/proc/sys/net/ipv6/conf/*/forwarding')
    end
end
