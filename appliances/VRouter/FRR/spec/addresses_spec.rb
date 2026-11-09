# frozen_string_literal: true

require_relative 'support/quiet_logs'
require_relative '../addresses'

RSpec.describe Service::FRR::Addresses do
    describe '.parse / .family / .canonical' do
        it 'accepts IPv4 and IPv6 and gives the canonical form' do
            expect(described_class.family('10.0.0.1')).to eq :ipv4
            expect(described_class.family('2001:DB8:0:0::1')).to eq :ipv6
            expect(described_class.canonical('2001:DB8:0:0::1')).to eq '2001:db8::1'
            expect(described_class.canonical('FD77:0:0:0:0:0:0:1')).to eq 'fd77::1'
        end

        it 'rejects everything that is not a bare address' do
            ['', 'nope', '1.2.3', '01.2.3.4', '1.2.3.4/24', 'fe80::1%eth0', '[fd77::1]', 'fd77::1 ', "fd77::1\nfoo",
             'fd77::1; reboot', 'fd77::g', '1::2::3', ':::', '::ffff:1.2.3.4', '::1.2.3.4', '::ffff:0102:0304'].each do |raw|
                expect(described_class.parse(raw)).to be_nil, "accepted #{raw.inspect}"
            end
        end

        it 'knows link-local IPv6 addresses' do
            expect(described_class.link_local?('fe80::1')).to be true
            expect(described_class.link_local?('fd77::1')).to be false
            expect(described_class.link_local?('febf::1')).to be true
            expect(described_class.link_local?('fec0::1')).to be false
            expect(described_class.link_local?('169.254.1.1')).to be false
        end
    end

    describe '.prefix_parts' do
        def parts(entry, ranges: true) = described_class.prefix_parts(entry, ranges: ranges)

        it 'canonicalizes IPv4 and IPv6 prefixes with ge/le' do
            expect(parts('10.0.0.0/8 le 24')).to eq ['10.0.0.0/8', nil, 24]
            expect(parts('2001:DB8::/32 ge 40 le 48')).to eq ['2001:db8::/32', 40, 48]
            expect(parts('::1/128 le 128')).to eq ['::1/128', nil, 128]
            expect(parts('2001:db8::/128')).to eq ['2001:db8::/128', nil, nil]
            expect(parts('::/0')).to eq ['::/0', nil, nil]
        end

        it 'rejects host bits, lengths above the family maximum, bad ranges and range words when not allowed' do
            ['10.0.0.1/8', '10.0.0.0/33', '2001:db8::1/32', '2001:db8::/129', '2001:db8::/32 le 31', '2001:db8::/32 ge 31', '10.0.0.0/8 ge 7',
             '10.0.0.0/8 le 33', '2001:db8::/32 le 129', 'fe80::/10%eth0', '2001:db8::', '/32'].each do |entry|
                expect(parts(entry)).to be_nil, "accepted #{entry.inspect}"
            end
            expect(parts('10.0.0.0/8 le 24', ranges: false)).to be_nil
        end
    end

    describe '.unusable_peer?' do
        it 'names the reason for an unspecified, loopback or multicast IPv6 address' do
            expect(described_class.unusable_peer?('::')).to eq 'the unspecified address'
            expect(described_class.unusable_peer?('0:0::0')).to eq 'the unspecified address'
            expect(described_class.unusable_peer?('::1')).to eq 'a loopback address'
            expect(described_class.unusable_peer?('ff02::1')).to eq 'a multicast address'
            expect(described_class.unusable_peer?('FF00::1')).to eq 'a multicast address'
        end

        it 'rejects the same kinds of IPv4 addresses' do
            expect(described_class.unusable_peer?('0.0.0.0')).to eq 'the unspecified address'
            expect(described_class.unusable_peer?('127.0.0.1')).to eq 'a loopback address'
            expect(described_class.unusable_peer?('127.9.9.9')).to eq 'a loopback address'
            expect(described_class.unusable_peer?('224.0.0.5')).to eq 'a multicast address'
            expect(described_class.unusable_peer?('239.1.1.1')).to eq 'a multicast address'
            expect(described_class.unusable_peer?('255.255.255.255')).to eq 'the broadcast address'
        end

        it 'accepts global and ULA IPv6 addresses, ordinary IPv4 addresses and leaves non-addresses alone' do
            ['2001:db8::1', 'fd77::1', 'fe7f::1', '10.0.0.1', '192.0.2.1', '223.255.255.255', '240.0.0.1', 'nope'].each do |addr|
                expect(described_class.unusable_peer?(addr)).to be_nil, "rejected #{addr.inspect}"
            end
        end

        it 'does not affect prefix parsing of ::/0' do
            expect(described_class.prefix_parts('::/0', ranges: false)).to eq ['::/0', nil, nil]
        end
    end

    describe '.entry_family' do
        it 'tells the family of a prefix entry' do
            expect(described_class.entry_family('10.0.0.0/8 le 24')).to eq :ipv4
            expect(described_class.entry_family('2001:db8::/32')).to eq :ipv6
        end
    end
end
