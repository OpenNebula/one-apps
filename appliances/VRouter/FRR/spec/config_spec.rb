# frozen_string_literal: true

require_relative 'support/quiet_logs'
require_relative 'support/bgp_config'
require_relative '../config'

RSpec.describe Service::FRR::Config do
    let(:p) { Service::FRR::Attributes::PREFIX }

    let(:attrs) do
        {
            "#{p}ASN" => '65010',
            "#{p}ROUTER_ID" => '10.99.37.2',
            "#{p}NEIGHBOR0_ADDRESS" => '10.99.37.1',
            "#{p}NEIGHBOR0_ASN" => '65100'
        }
    end

    # NOTE: no keyword arguments here, otherwise Ruby 3 treats a braceless
    #       string-key hash as keywords.
    def parse_all(extra = {})
        parse_bgp(attrs.merge(extra))
    end

    # The BGP settings of the config.
    def parse(extra = {})
        parse_all(extra).section(:bgp)
    end

    def error_for(extra)
        parse(extra)
        nil
    rescue Service::FRR::ConfigError => e
        e.message
    end

    it 'parses a minimal config with defaults' do
        config = parse

        expect(parse_all.poll_interval).to eq 30
        expect(config).to have_attributes(asn: 65_010, router_id: '10.99.37.2',
                                          backup_prepend: 3, backup_med: 200, networks: [], redistribute: [])
        expect(config.neighbors.first).to have_attributes(
            index: 0, address: '10.99.37.1', asn: 65_100, bfd: false, bfd_timers: '3 300 300',
            prepend: 0, import_prefixes: [], export_prefixes: []
        )
    end

    it 'parses all neighbor options' do
        config = parse(
            "#{p}NEIGHBOR0_DESCRIPTION" => 'MCCP uplink', "#{p}NEIGHBOR0_PASSWORD" => 's3cret',
            "#{p}NEIGHBOR0_BFD" => 'YES', "#{p}NEIGHBOR0_BFD_TIMERS" => '5 200 200',
            "#{p}NEIGHBOR0_TIMERS" => '10 30', "#{p}NEIGHBOR0_UPDATE_SOURCE" => 'eth1',
            "#{p}NEIGHBOR0_MAX_PREFIX" => '1000', "#{p}NEIGHBOR0_LOCAL_PREF" => '200',
            "#{p}NEIGHBOR0_MED" => '50', "#{p}NEIGHBOR0_PREPEND" => '2'
        )

        expect(config.neighbors.first).to have_attributes(
            description: 'MCCP uplink', password: 's3cret', bfd: true, bfd_timers: '5 200 200', timers: '10 30',
            update_source: 'eth1', max_prefix: 1000, local_pref: 200, med: 50, prepend: 2
        )
    end

    it 'normalizes prefix lists and networks' do
        config = parse(
            "#{p}NETWORKS" => '10.41.1.0/24, 10.41.2.0/24',
            "#{p}NEIGHBOR0_IMPORT_PREFIXES" => '0.0.0.0/0, 10.0.0.0/8 le 24,172.16.0.0/12 ge 16 le 24',
            "#{p}REDISTRIBUTE" => 'connected,static'
        )

        expect(config.networks).to eq %w[10.41.1.0/24 10.41.2.0/24]
        expect(config.neighbors.first.import_prefixes).to eq ['0.0.0.0/0', '10.0.0.0/8 le 24', '172.16.0.0/12 ge 16 le 24']
        expect(config.redistribute).to eq %w[connected static]
    end

    it 'finds several neighbors in index order' do
        config = parse("#{p}NEIGHBOR2_ADDRESS" => '10.99.37.9', "#{p}NEIGHBOR2_ASN" => '65200')

        expect(config.neighbors.map(&:index)).to eq [0, 2]
    end

    it 'uses the IPv4 of the lowest routed NIC as default router-id' do
        env = { 'ETH0_IP' => '10.0.0.5', 'ETH1_IP' => '10.1.0.5', 'ETH0_VROUTER_MANAGEMENT' => 'YES' }

        expect(described_class.default_router_id(env)).to eq '10.1.0.5'
    end

    it 'falls back to the default router-id when none is set' do
        config = parse_bgp(attrs.reject { |k, _| k.end_with?('ROUTER_ID') }, default_router_id: '10.0.0.5').section(:bgp)

        expect(config.router_id).to eq '10.0.0.5'
    end

    it 'reports every problem at once' do
        message = error_for("#{p}ASN" => 'abc', "#{p}NEIGHBOR0_ASN" => '0')

        expect(message).to include("#{p}ASN must be an integer", "#{p}NEIGHBOR0_ASN must be between 1")
    end

    it 'requires the local ASN, a router-id and neighbor address and ASN' do
        expect { parse_bgp({ "#{p}NEIGHBOR0_BFD" => 'YES' }) }.to raise_error(Service::FRR::ConfigError) do |e|
            expect(e.errors).to include("#{p}ASN is required")
            expect(e.errors.join).to include('neighbor slot 0 is incomplete', "#{p}NEIGHBOR0_ADDRESS", "#{p}NEIGHBOR0_ASN")
            expect(e.errors.join).to include('ROUTER_ID')
        end
    end

    it 'rejects unknown attributes, so typos are not silently ignored' do
        expect(error_for("#{p}NEIGHBOR0_ADRESS" => '10.0.0.1')).to include("unknown attribute #{p}NEIGHBOR0_ADRESS")
        expect(error_for("#{p}ASNN" => '1')).to include("unknown attribute #{p}ASNN")
    end

    it 'rejects duplicate neighbor addresses' do
        message = error_for("#{p}NEIGHBOR1_ADDRESS" => '10.99.37.1', "#{p}NEIGHBOR1_ASN" => '65200')

        expect(message).to include('duplicate neighbor address: 10.99.37.1')
    end

    it 'rejects malformed prefixes and non-address neighbors' do
        expect(error_for("#{p}NEIGHBOR0_ADDRESS" => 'nope')).to include('must be an IPv4 or IPv6 address')
        expect(error_for("#{p}NETWORKS" => '10.0.0.1/8')).to include('invalid prefix')
        expect(error_for("#{p}NEIGHBOR0_IMPORT_PREFIXES" => '10.0.0.0/8 le 7')).to include('invalid prefix')
        expect(error_for("#{p}NETWORKS" => '10.0.0.0/8 le 24')).to include('invalid prefix')
        expect(error_for("#{p}NETWORKS" => '2001:db8::1/32')).to include('invalid prefix')
    end

    describe 'IPv6' do
        let(:v6) do
            { "#{p}NEIGHBOR1_ADDRESS" => 'FD77:0:0:0::21', "#{p}NEIGHBOR1_ASN" => '65200' }
        end

        it 'accepts an IPv6 neighbor next to an IPv4 one and stores the canonical address' do
            config = parse(v6)

            expect(config.neighbors.map(&:address)).to eq %w[10.99.37.1 fd77::21]
            expect(config.neighbors.map(&:family)).to eq %i[ipv4 ipv6]
        end

        it 'detects a duplicate IPv6 neighbor written in two spellings' do
            message = error_for(v6.merge("#{p}NEIGHBOR2_ADDRESS" => 'fd77::21', "#{p}NEIGHBOR2_ASN" => '65300'))

            expect(message).to include('duplicate neighbor address: fd77::21')
        end

        it 'keeps mixed prefix lists, canonical, in the order given' do
            config = parse(v6.merge("#{p}NETWORKS" => '10.99.0.0/24,2001:DB8:99::/48',
                                    "#{p}NEIGHBOR1_IMPORT_PREFIXES" => '2001:db8:a::/48 le 56, 10.1.0.0/16'))

            expect(config.networks).to eq %w[10.99.0.0/24 2001:db8:99::/48]
            expect(config.neighbors.last.import_prefixes).to eq ['2001:db8:a::/48 le 56', '10.1.0.0/16']
        end

        it 'rejects a link-local neighbor and zone ids' do
            expect(error_for(v6.merge("#{p}NEIGHBOR1_ADDRESS" => 'fe80::1'))).to include('link-local')
            expect(error_for(v6.merge("#{p}NEIGHBOR1_ADDRESS" => 'fe80::1%eth0'))).to include('IPv4 or IPv6 address')
            expect(error_for(v6.merge("#{p}NEIGHBOR1_ADDRESS" => '::ffff:1.2.3.4x'))).to include('IPv4 or IPv6 address')
            expect(error_for(v6.merge("#{p}NEIGHBOR1_ADDRESS" => '::ffff:1.2.3.4'))).to include('IPv4 or IPv6 address')
            expect(error_for(v6.merge("#{p}NEIGHBOR1_ADDRESS" => '::1.2.3.4'))).to include('IPv4 or IPv6 address')
        end

        it 'takes the update source of the neighbor family, or an interface' do
            ok = parse(v6.merge("#{p}NEIGHBOR1_UPDATE_SOURCE" => 'fd77::10'))
            expect(ok.neighbors.last.update_source).to eq 'fd77::10'
            expect(parse(v6.merge("#{p}NEIGHBOR1_UPDATE_SOURCE" => 'eth1')).neighbors.last.update_source).to eq 'eth1'

            expect(error_for(v6.merge("#{p}NEIGHBOR1_UPDATE_SOURCE" => '10.77.0.10'))).to include('UPDATE_SOURCE')
            expect(error_for("#{p}NEIGHBOR0_UPDATE_SOURCE" => 'fd77::10')).to include('UPDATE_SOURCE')
        end

        it 'needs an IPv4 router-id: an IPv6 one is rejected, and a missing one is reported' do
            expect(error_for("#{p}ROUTER_ID" => 'fd77::1')).to include('must be an IPv4 address')

            attrs = { "#{p}ASN" => '65010', "#{p}NEIGHBOR0_ADDRESS" => 'fd77::21', "#{p}NEIGHBOR0_ASN" => '65100' }
            expect { parse_bgp(attrs) }.to raise_error(Service::FRR::ConfigError, /ROUTER_ID is required/)
        end
    end

    it 'rejects values that could inject FRR commands' do
        expect(error_for("#{p}NEIGHBOR0_DESCRIPTION" => "x\nneighbor 1.1.1.1 shutdown")).to include('DESCRIPTION must match')
        expect(error_for("#{p}NEIGHBOR0_PASSWORD" => "pw\nrouter bgp 1")).to include('PASSWORD must match')
    end

    it 'never echoes a password in an error message' do
        message = error_for("#{p}NEIGHBOR0_PASSWORD" => 'has space', "#{p}ASN" => 'x')

        expect(message).not_to include('has space')
    end

    it 'rejects zero-padded neighbor indices instead of silently dropping them' do
        message = error_for("#{p}NEIGHBOR1_ADDRESS" => '10.99.37.9', "#{p}NEIGHBOR1_ASN" => '65200',
                            "#{p}NEIGHBOR01_ADDRESS" => '10.99.37.10', "#{p}NEIGHBOR01_ASN" => '65300')

        expect(message).to include("unknown attribute #{p}NEIGHBOR01_ADDRESS")
        expect(message).to include("unknown attribute #{p}NEIGHBOR01_ASN")
    end

    it 'treats a blank router-id as unset and falls back to the default' do
        config = parse_bgp(attrs.merge("#{p}ROUTER_ID" => '  '), default_router_id: '10.0.0.5').section(:bgp)

        expect(config.router_id).to eq '10.0.0.5'
    end

    it 'ignores blank optional attributes' do
        config = parse("#{p}NEIGHBOR0_PASSWORD" => '', "#{p}NEIGHBOR0_MED" => '', "#{p}NEIGHBOR0_TIMERS" => ' ',
                       "#{p}POLL_INTERVAL" => '', "#{p}NETWORKS" => '', "#{p}REDISTRIBUTE" => ' ')

        expect(config.neighbors.first).to have_attributes(password: nil, med: nil, timers: nil)
        expect(config).to have_attributes(networks: [], redistribute: [])
        expect(parse_all("#{p}POLL_INTERVAL" => '').poll_interval).to eq 30
    end

    it 'reports a blank required attribute as required' do
        expect(error_for("#{p}ASN" => '')).to include("#{p}ASN is required")
    end

    it 'returns frozen, immutable results' do
        config = parse

        expect(config).to be_frozen
        expect(config.neighbors).to be_frozen
    end

    describe 'an unused neighbor slot that carries only defaults' do
        it 'is ignored (BFD=NO, PREPEND=0, as a template with defaults would send)' do
            extra = { "#{p}NEIGHBOR1_BFD" => 'NO', "#{p}NEIGHBOR1_PREPEND" => '0' }

            expect(error_for(extra)).to be_nil
            expect(parse(extra).neighbors.map(&:index)).to eq [0]
        end

        it 'is still incomplete when a value that does something is set' do
            expect(error_for("#{p}NEIGHBOR1_BFD" => 'YES')).to include('neighbor slot 1 is incomplete')
            expect(error_for("#{p}NEIGHBOR1_PREPEND" => '2')).to include('neighbor slot 1 is incomplete')
        end
    end

    describe 'an incomplete neighbor slot' do
        it 'names the slot and the keys that created it, instead of two required errors' do
            error = error_for("#{p}NEIGHBOR1_BFD" => 'NO', "#{p}NEIGHBOR1_MED" => '5')

            expect(error).to include('neighbor slot 1 is incomplete', "#{p}NEIGHBOR1_BFD", "#{p}NEIGHBOR1_MED")
            expect(error).not_to include('NEIGHBOR1_ADDRESS is required')
        end

        it 'still reports a missing ASN when only the address is set' do
            expect(error_for("#{p}NEIGHBOR1_ADDRESS" => '10.0.0.9')).to include("#{p}NEIGHBOR1_ASN is required")
        end
    end

    describe 'duplicate prefixes' do
        it 'collapses an exact IPv4 duplicate and two spellings of an IPv6 prefix, keeping the order' do
            config = parse("#{p}NETWORKS" => '10.1.0.0/16, 2001:db8::/32, 10.1.0.0/16, 2001:DB8:0::/32, 10.0.0.0/8',
                           "#{p}NEIGHBOR0_IMPORT_PREFIXES" => '2001:db8::/32, 2001:DB8:0::/32 le 48, 2001:db8:0::/32',
                           "#{p}NEIGHBOR0_EXPORT_PREFIXES" => '10.0.0.0/8 le 24,10.0.0.0/8 le 24')

            expect(config.networks).to eq %w[10.1.0.0/16 2001:db8::/32 10.0.0.0/8]
            expect(config.neighbors.first.import_prefixes).to eq ['2001:db8::/32', '2001:db8::/32 le 48']
            expect(config.neighbors.first.export_prefixes).to eq ['10.0.0.0/8 le 24']
        end
    end

    describe 'unusable IPv4 peer addresses' do
        %w[0.0.0.0 127.0.0.1 224.0.0.5 255.255.255.255].each do |addr|
            it "rejects #{addr} as a neighbor" do
                expect(error_for("#{p}NEIGHBOR0_ADDRESS" => addr)).to match(/must be an IPv4 or IPv6 address.*not usable/)
            end
        end
    end

    describe 'timers' do
        it 'accepts what FRR accepts: keepalive and hold 0..65535, hold 0 or at least 3' do
            ['3 9', '0 0', '30 10', '60 180', '65535 65535'].each do |timers|
                expect(error_for("#{p}NEIGHBOR0_TIMERS" => timers)).to be_nil, timers
            end
        end

        it 'rejects values FRR refuses, naming the attribute and the rule' do
            ['1 2', '70000 9', '10 1'].each do |timers|
                expect(error_for("#{p}NEIGHBOR0_TIMERS" => timers)).to include("#{p}NEIGHBOR0_TIMERS", 'hold time'), timers
            end
        end

        it 'accepts a BFD profile within FRR limits: multiplier 2..255, intervals 10..60000 ms' do
            ['2 10 10', '3 300 300', '255 60000 60000'].each do |timers|
                expect(error_for("#{p}NEIGHBOR0_BFD" => 'YES', "#{p}NEIGHBOR0_BFD_TIMERS" => timers)).to be_nil, timers
            end
        end

        it 'rejects a BFD profile outside them' do
            ['1 5 5', '3 9 300', '3 300 60001', '256 300 300'].each do |timers|
                expect(error_for("#{p}NEIGHBOR0_BFD" => 'YES', "#{p}NEIGHBOR0_BFD_TIMERS" => timers))
                    .to include("#{p}NEIGHBOR0_BFD_TIMERS", 'multiplier'), timers
            end
        end
    end

    describe 'unusable IPv6 peer addresses' do
        let(:routes) { 'ONEAPP_VNF_STATIC_ROUTES' }

        %w[:: ::1 ff02::1].each do |addr|
            it "rejects #{addr} as neighbor address, update source and static route gateway" do
                expect(error_for("#{p}NEIGHBOR0_ADDRESS" => addr)).to match(/must be an IPv4 or IPv6 address.*not usable/)
                expect(error_for("#{p}NEIGHBOR0_ADDRESS" => 'fd77::21', "#{p}NEIGHBOR0_UPDATE_SOURCE" => addr)).to include('UPDATE_SOURCE')
                expect(error_for(routes => "2001:db8::/32 via #{addr}")).to match(/invalid gateway.*not usable/)
            end
        end

        it 'keeps accepting ::/0 as a prefix' do
            expect(parse("#{p}NETWORKS" => '::/0').networks).to eq ['::/0']
        end
    end

    describe 'static routes' do
        let(:routes) { 'ONEAPP_VNF_STATIC_ROUTES' }

        def routes_of(value)
            parse_all(routes => value).section(:static).routes.map { |route| [route.prefix, route.gateway] }
        end

        def routes_error(value)
            error_for(routes => value)
        end

        it 'defaults to no routes' do
            expect(parse_all.section(:static)).to be_nil
        end

        it 'parses a comma-separated list, tolerating whitespace' do
            expect(routes_of(" 1.1.1.1/32  via 172.16.100.1 ,9.9.9.9/32 via   172.16.100.1,\t10.0.0.0/8 via 10.1.1.1 "))
                .to eq [%w[10.0.0.0/8 10.1.1.1], %w[1.1.1.1/32 172.16.100.1], %w[9.9.9.9/32 172.16.100.1]]
        end

        it 'normalizes a zero-padded length' do
            expect(routes_of('10.0.0.0/08 via 10.1.1.1')).to eq [%w[10.0.0.0/8 10.1.1.1]]
        end

        it 'allows an explicit static default route' do
            expect(routes_of('0.0.0.0/0 via 172.16.100.1')).to eq [%w[0.0.0.0/0 172.16.100.1]]
        end

        it 'treats NONE, in any case, as an empty list' do
            %w[NONE none None].each { |word| expect(routes_of(word)).to eq [] }
        end

        it 'returns frozen routes' do
            expect(parse_all(routes => '1.1.1.1/32 via 10.0.0.1').section(:static).routes).to be_frozen
        end

        it 'names the attribute in every error' do
            ['1.1.1.1/32', '1.1.1.1 via 10.0.0.1', '1.1.1.1/33 via 10.0.0.1', '1.1.1.1/24 via 10.0.0.1',
             '1.1.1.1/32 via 10.0.0.256', '1.1.1.1/32 via', 'via 10.0.0.1', '1.1.1.1/32 via 10.0.0.1,',
             ',1.1.1.1/32 via 10.0.0.1', '1.1.1.1/32 via 10.0.0.1,,2.2.2.2/32 via 10.0.0.1', 'NONE, 1.1.1.1/32 via 10.0.0.1'
            ].each do |value|
                expect(routes_error(value)).to include('ONEAPP_VNF_STATIC_ROUTES'), "no error for #{value.inspect}"
            end
        end

        it 'rejects host bits in the prefix' do
            expect(routes_error('10.0.0.1/24 via 10.0.0.2')).to include('invalid prefix')
        end

        it 'rejects a bad gateway' do
            expect(routes_error('10.0.0.0/24 via 10.0.0.300')).to include('invalid gateway')
        end

        it 'rejects duplicate prefixes, even with different gateways' do
            expect(routes_error('1.1.1.1/32 via 10.0.0.1, 1.1.1.1/32 via 10.0.0.2')).to include('duplicate prefix 1.1.1.1/32')
        end

        it 'says that dev, blackhole and metrics are not supported yet' do
            ['1.1.1.1/32 dev eth0', '1.1.1.1/32 blackhole', '1.1.1.1/32 via 10.0.0.1 dev eth0',
             '1.1.1.1/32 via 10.0.0.1 metric 5', '1.1.1.1/32 via 10.0.0.1 distance 5'].each do |value|
                expect(routes_error(value)).to include('not supported yet'), "wrong error for #{value.inspect}"
            end
        end

        it 'accepts IPv6 routes and sorts IPv4 first, then by length and address' do
            parsed = parse_all(routes => '2001:db8:2::/48 via fd77::1, 9.9.9.9/32 via 10.0.0.1, 2001:DB8::/32 via FD77::1, 1.1.1.0/24 via 10.0.0.1')
                     .section(:static).routes

            expect(parsed.map(&:prefix)).to eq %w[1.1.1.0/24 9.9.9.9/32 2001:db8::/32 2001:db8:2::/48]
            expect(parsed.map(&:family)).to eq %i[ipv4 ipv4 ipv6 ipv6]
            expect(parsed.last.gateway).to eq 'fd77::1'
        end

        it 'detects duplicate IPv6 prefixes in two spellings' do
            expect(routes_error('2001:db8::/32 via fd77::1, 2001:DB8:0::/32 via fd77::2')).to include('duplicate prefix 2001:db8::/32')
        end

        it 'rejects a gateway of the other family, link-local gateways and host bits' do
            expect(routes_error('1.1.1.1/32 via 2001:db8::1')).to include('mixes IPv4 and IPv6')
            expect(routes_error('2001:db8::/32 via 10.0.0.1')).to include('mixes IPv4 and IPv6')
            expect(routes_error('2001:db8::/32 via fe80::1')).to include('link-local')
            expect(routes_error('2001:db8::1/32 via fd77::1')).to include('invalid prefix')
            expect(routes_error('2001:db8::/129 via fd77::1')).to include('invalid prefix')
        end

        it 'reports every problem at once' do
            error = routes_error('1.1.1.1/33 via 10.0.0.1, 2.2.2.2/32 via nope')

            expect(error).to include('1.1.1.1/33', 'nope')
        end

        it 'does not make the key an unknown attribute' do
            expect { parse(routes => 'NONE') }.not_to raise_error
        end
    end

    describe '.parse_frr' do
        let(:routes) { 'ONEAPP_VNF_STATIC_ROUTES' }
        let(:enabled) { { "#{p}ENABLED" => 'YES' } }

        it 'parses BGP and routes together when BGP is enabled' do
            config = described_class.parse_frr(attrs.merge(enabled).merge(routes => '1.1.1.1/32 via 10.0.0.1'))

            expect(config.section(:bgp)).to have_attributes(asn: 65_010)
            expect(config.section(:static).routes).to match([have_attributes(prefix: '1.1.1.1/32')])
        end

        it 'still requires the BGP attributes when BGP is enabled' do
            expect { described_class.parse_frr(enabled.merge(routes => '1.1.1.1/32 via 10.0.0.1')) }
                .to raise_error(Service::FRR::ConfigError, /ASN is required/)
        end

        it 'returns a config without BGP when BGP is disabled but there are routes' do
            config = described_class.parse_frr({ routes => '1.1.1.1/32 via 10.0.0.1' })

            expect(config.section(:bgp)).to be_nil
            expect(config.poll_interval).to eq 30
            expect(config.section(:static).routes.map(&:prefix)).to eq ['1.1.1.1/32']
        end

        it 'treats ENABLED=NO like an unset ENABLED' do
            config = described_class.parse_frr(attrs.merge("#{p}ENABLED" => 'NO', routes => '1.1.1.1/32 via 10.0.0.1'))

            expect(config.section(:bgp)).to be_nil
        end

        it 'does not validate the BGP attributes while BGP is disabled' do
            config = described_class.parse_frr({ "#{p}ASN" => 'abc', routes => '1.1.1.1/32 via 10.0.0.1' })

            expect(config.section(:static).routes.size).to eq 1
        end

        it 'still validates the routes while BGP is disabled' do
            expect { described_class.parse_frr({ routes => '1.1.1.1/99 via 10.0.0.1' }) }
                .to raise_error(Service::FRR::ConfigError, /ONEAPP_VNF_STATIC_ROUTES/)
        end

        it 'honors the poll interval without BGP' do
            config = described_class.parse_frr({ routes => 'NONE', "#{p}POLL_INTERVAL" => '10' })

            expect(config.poll_interval).to eq 10
        end

        it 'does not enable BGP for ENABLED=TRUE (only YES and 1, as everywhere else in the appliance)' do
            config = described_class.parse_frr({ "#{p}ENABLED" => 'TRUE', routes => '1.1.1.1/32 via 10.0.0.1' })

            expect(config.section(:bgp)).to be_nil
        end

        it 'uses ONEAPP_VNF_FRR_ROUTER_ID for BGP when ONEAPP_VNF_BGP_ROUTER_ID is not set' do
            no_id  = attrs.reject { |key, _| key.end_with?('BGP_ROUTER_ID') }
            config = parse_bgp(no_id.merge('ONEAPP_VNF_FRR_ROUTER_ID' => '10.9.9.9'), default_router_id: '10.0.0.5')

            expect(config.section(:bgp).router_id).to eq '10.9.9.9'
        end

        it 'lets the BGP router-id win over the shared one' do
            both = parse_bgp(attrs.merge('ONEAPP_VNF_FRR_ROUTER_ID' => '10.9.9.9'), default_router_id: '10.0.0.5')

            expect(both.section(:bgp).router_id).to eq attrs["#{p}ROUTER_ID"]
        end

        it 'does not look at the shared router-id when no protocol that uses it is enabled' do
            expect { described_class.parse_frr({ routes => '1.1.1.1/32 via 10.0.0.1', 'ONEAPP_VNF_FRR_ROUTER_ID' => 'bogus' }) }
                .not_to raise_error
        end

        it 'validates the shared router-id when OSPF is enabled and BGP is not' do
            ospf = { 'ONEAPP_VNF_OSPF_ENABLED' => 'YES', 'ONEAPP_VNF_OSPF_INTERFACE0_NAME' => 'eth1',
                     'ONEAPP_VNF_FRR_ROUTER_ID' => 'bogus' }

            expect { described_class.parse_frr(ospf) }
                .to raise_error(Service::FRR::ConfigError, /ONEAPP_VNF_FRR_ROUTER_ID must be an IPv4 address/)
        end

        it 'reports an invalid shared router-id by its name' do
            expect { parse_bgp(attrs.merge('ONEAPP_VNF_FRR_ROUTER_ID' => 'fd77::1')) }
                .to raise_error(Service::FRR::ConfigError, /ONEAPP_VNF_FRR_ROUTER_ID must be an IPv4 address/)
        end

        it 'ignores every BGP key, without errors, when BGP is not enabled' do
            config = described_class.parse_frr({ "#{p}ENABLED" => 'NO', "#{p}ASN" => 'not-a-number', "#{p}TYPO" => '1',
                                                 routes => '1.1.1.1/32 via 172.16.100.1' })

            expect(config.section(:bgp)).to be_nil
            expect(config.section(:static).routes.map(&:prefix)).to eq ['1.1.1.1/32']
        end

        it 'reports the errors of both sections in one error, BGP first, and never echoes a password' do
            error = begin
                described_class.parse_frr({ "#{p}ENABLED" => 'YES', "#{p}ASN" => 'x', "#{p}NEIGHBOR0_ADDRESS" => '10.0.0.1',
                                            "#{p}NEIGHBOR0_ASN" => '65001', "#{p}NEIGHBOR0_PASSWORD" => 'bad pass word',
                                            routes => 'nonsense' })
            rescue Service::FRR::ConfigError => e
                e
            end

            expect(error.errors.first).to include('ASN must be an integer')
            expect(error.errors.last).to include('ONEAPP_VNF_STATIC_ROUTES')
            expect(error.message).not_to include('bad pass word')
        end

        it 'has a static section for NONE and none when the attribute is absent' do
            expect(described_class.parse_frr({ routes => 'NONE' }).section(:static).routes).to eq []
            expect(described_class.parse_frr({}).section(:static)).to be_nil
        end

        it 'reports an invalid poll interval even when BGP is not enabled' do
            expect { described_class.parse_frr({ "#{p}POLL_INTERVAL" => '1' }) }
                .to raise_error(Service::FRR::ConfigError, /POLL_INTERVAL must be between 5 and 3600/)
        end

        it 'has no routes and no BGP for an empty configuration' do
            config = described_class.parse_frr({})

            expect(config.section(:bgp)).to be_nil
            expect(config.section(:static)).to be_nil
        end
    end
end
