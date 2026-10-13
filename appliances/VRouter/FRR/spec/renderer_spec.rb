# frozen_string_literal: true

require_relative 'support/quiet_logs'
require_relative 'support/bgp_config'
require_relative '../renderer'

RSpec.describe Service::FRR::Renderer do
    let(:p) { Service::FRR::Attributes::PREFIX }

    let(:attrs) do
        {
            "#{p}ASN" => '65010', "#{p}ROUTER_ID" => '10.99.37.2',
            "#{p}NEIGHBOR0_ADDRESS" => '10.99.37.1', "#{p}NEIGHBOR0_ASN" => '65100'
        }
    end

    # NOTE: ha_state is positional so a braceless string-key hash stays a plain hash in Ruby 3.
    def render(extra = {}, ha_state = :master)
        config = parse_bgp(attrs.merge(extra))
        described_class.render(config, hostname: 'vr1', ha_state: ha_state)
    end

    describe '.header' do
        it 'is the start of every rendered config, so the fallback config cannot drift from it' do
            expect(render).to start_with(described_class.header(hostname: 'vr1'))
            expect(described_class.header(hostname: 'vr1')).to eq(
                "frr defaults traditional\nhostname vr1\nlog syslog informational\nservice integrated-vtysh-config\n"
            )
        end

        it 'leaves the hostname line out when there is no usable hostname' do
            expect(described_class.header(hostname: nil)).to eq(
                "frr defaults traditional\nlog syslog informational\nservice integrated-vtysh-config\n"
            )
        end
    end

    describe 'the MED of the VRRP backup' do
        it 'is BACKUP_MED when the neighbor has no MED of its own' do
            expect(render({ "#{p}BACKUP_MED" => '200' }, :backup)).to include(" set metric 200\n")
        end

        it 'is raised above the neighbor MED instead of replacing it, so the backup never wins' do
            out = render({ "#{p}NEIGHBOR0_MED" => '300', "#{p}BACKUP_MED" => '200' }, :backup)

            expect(out).to include(" set metric 500\n")
            expect(render({ "#{p}NEIGHBOR0_MED" => '300', "#{p}BACKUP_MED" => '200' }, :master)).to include(" set metric 300\n")
        end

        it 'stays within 32 bits' do
            out = render({ "#{p}NEIGHBOR0_MED" => '4294967295', "#{p}BACKUP_MED" => '200' }, :backup)

            expect(out).to include(" set metric 4294967295\n")
        end

        it 'sets no metric on the backup when BACKUP_MED is 0 and the neighbor has none' do
            expect(render({ "#{p}BACKUP_MED" => '0' }, :backup)).not_to include('set metric')
        end
    end

    it 'renders the global section and a plain neighbor' do
        out = render

        expect(out).to include("hostname vr1\n", "log syslog informational\n", "router bgp 65010\n",
                               " bgp router-id 10.99.37.2\n", " no bgp default ipv4-unicast\n",
                               " neighbor 10.99.37.1 remote-as 65100\n", "  neighbor 10.99.37.1 activate\n",
                               "  neighbor 10.99.37.1 route-map BGP-N0-IN in\n",
                               "  neighbor 10.99.37.1 route-map BGP-N0-OUT out\n")
    end

    it 'accepts everything when no prefix list is configured' do
        out = render

        expect(out).to include("route-map BGP-N0-IN permit 10\nexit\n", "route-map BGP-N0-OUT permit 10\nexit\n")
        expect(out).not_to include('prefix-list')
    end

    it 'permits only the listed prefixes when a list is configured' do
        out = render("#{p}NEIGHBOR0_IMPORT_PREFIXES" => '0.0.0.0/0,10.0.0.0/8 le 24',
                     "#{p}NEIGHBOR0_EXPORT_PREFIXES" => '10.41.0.0/16 le 24')

        expect(out).to include("ip prefix-list BGP-N0-IN seq 10 permit 0.0.0.0/0\n",
                               "ip prefix-list BGP-N0-IN seq 20 permit 10.0.0.0/8 le 24\n",
                               "route-map BGP-N0-IN permit 10\n match ip address prefix-list BGP-N0-IN\n",
                               "ip prefix-list BGP-N0-OUT seq 10 permit 10.41.0.0/16 le 24\n",
                               "route-map BGP-N0-OUT permit 10\n match ip address prefix-list BGP-N0-OUT\n")
    end

    it 'renders the optional neighbor settings only when set' do
        out = render("#{p}NEIGHBOR0_DESCRIPTION" => 'MCCP', "#{p}NEIGHBOR0_PASSWORD" => 'pw',
                     "#{p}NEIGHBOR0_BFD" => 'YES', "#{p}NEIGHBOR0_TIMERS" => '10 30',
                     "#{p}NEIGHBOR0_UPDATE_SOURCE" => 'eth1', "#{p}NEIGHBOR0_MAX_PREFIX" => '1000',
                     "#{p}NEIGHBOR0_LOCAL_PREF" => '200')

        expect(out).to include(" neighbor 10.99.37.1 description MCCP\n", " neighbor 10.99.37.1 password pw\n",
                               " neighbor 10.99.37.1 bfd\n", " neighbor 10.99.37.1 timers 10 30\n",
                               " neighbor 10.99.37.1 update-source eth1\n",
                               "  neighbor 10.99.37.1 maximum-prefix 1000\n", " set local-preference 200\n")
        expect(render).not_to include('password', 'bfd', 'timers', 'update-source', 'maximum-prefix', 'local-preference')
    end

    it 'renders plain bfd for the default timers, which is how FRR prints them' do
        out = render("#{p}NEIGHBOR0_BFD" => 'YES', "#{p}NEIGHBOR0_BFD_TIMERS" => '3 300 300')

        expect(out).to include(" neighbor 10.99.37.1 bfd\n")
        expect(out).not_to include('bfd 3 300 300')
    end

    it 'treats zero padded default bfd timers as the defaults' do
        out = render("#{p}NEIGHBOR0_BFD" => 'YES', "#{p}NEIGHBOR0_BFD_TIMERS" => '03 0300 300')

        expect(out).to include(" neighbor 10.99.37.1 bfd\n")
    end

    it 'puts non-default bfd timers in a profile, because FRR never prints them on the neighbor line' do
        out = render("#{p}NEIGHBOR0_BFD" => 'YES', "#{p}NEIGHBOR0_BFD_TIMERS" => '5 200 200')

        expect(out).to include("bfd\n profile BGP-N0\n  detect-multiplier 5\n  receive-interval 200\n  transmit-interval 200\n exit\nexit\n",
                               " neighbor 10.99.37.1 bfd\n neighbor 10.99.37.1 bfd profile BGP-N0\n")
        expect(out).not_to include('bfd 5 200 200')
    end

    it 'renders no bfd profile for default timers or without bfd' do
        expect(render("#{p}NEIGHBOR0_BFD" => 'YES')).not_to include('profile')
        expect(render("#{p}NEIGHBOR0_BFD_TIMERS" => '5 200 200')).not_to include('bfd')
    end

    it 'renders networks and redistribution under the IPv4 address family' do
        out = render("#{p}NETWORKS" => '10.41.1.0/24', "#{p}REDISTRIBUTE" => 'connected')

        expect(out).to include(" address-family ipv4 unicast\n  network 10.41.1.0/24\n  redistribute connected\n")
    end

    it 'uses the configured attributes on the master' do
        out = render("#{p}NEIGHBOR0_MED" => '10', "#{p}NEIGHBOR0_PREPEND" => '1')

        expect(out).to include(" set metric 10\n", " set as-path prepend 65010\n")
    end

    it 'prepends and raises the MED on the backup' do
        out = render({ "#{p}NEIGHBOR0_MED" => '10', "#{p}NEIGHBOR0_PREPEND" => '1' }, :backup)

        expect(out).to include(" set metric 210\n", " set as-path prepend 65010 65010 65010 65010\n")
    end

    it 'does not touch the export policy of a master without MED or prepend' do
        expect(render).not_to include('set metric', 'as-path prepend')
    end

    it 'rejects an unknown HA state and an unsafe hostname' do
        config = parse_bgp(attrs)

        expect { described_class.render(config, hostname: 'vr1', ha_state: :standby) }.to raise_error(ArgumentError)
        expect { described_class.render(config, hostname: "vr1\nrouter bgp 1") }.to raise_error(ArgumentError)
    end

    it 'accepts the hostnames FRR accepts: underscores and up to 64 characters' do
        config = parse_bgp(attrs)

        expect(described_class.render(config, hostname: 'vr_1')).to include("hostname vr_1\n")
        expect(described_class.render(config, hostname: 'a' * 64)).to include("hostname #{'a' * 64}\n")
    end

    it 'rejects a hostname longer than 64 characters or with whitespace or control characters' do
        config = parse_bgp(attrs)

        ['a' * 65, 'vr 1', "vr1\tx", "vr1\r", ''].each do |bad|
            expect { described_class.render(config, hostname: bad) }.to raise_error(ArgumentError)
        end
    end

    describe 'static routes' do
        let(:routes) { 'ONEAPP_VNF_STATIC_ROUTES' }

        it 'renders one top-level ip route line per route' do
            out = render(routes => '9.9.9.9/32 via 172.16.100.1, 1.1.1.1/32 via 172.16.100.1')

            expect(out).to include("\nip route 1.1.1.1/32 172.16.100.1\nip route 9.9.9.9/32 172.16.100.1\n")
        end

        it 'orders the routes the way FRR prints them (length, then address), whatever the input order' do
            a = render(routes => '10.0.0.0/8 via 10.1.1.1, 9.0.0.0/8 via 10.1.1.1, 10.0.0.0/16 via 10.1.1.1')
            b = render(routes => '10.0.0.0/16 via 10.1.1.1, 10.0.0.0/8 via 10.1.1.1, 9.0.0.0/8 via 10.1.1.1')

            expect(a).to eq b
            expect(render(routes => '1.1.1.1/32 via 10.1.1.1, 192.0.2.0/24 via 10.1.1.1').lines.grep(/^ip route/))
                .to eq ["ip route 192.0.2.0/24 10.1.1.1\n", "ip route 1.1.1.1/32 10.1.1.1\n"]
            expect(a.lines.grep(/^ip route/)).to eq ["ip route 9.0.0.0/8 10.1.1.1\n", "ip route 10.0.0.0/8 10.1.1.1\n",
                                                     "ip route 10.0.0.0/16 10.1.1.1\n"]
        end

        it 'renders a static default route' do
            expect(render(routes => '0.0.0.0/0 via 10.1.1.1')).to include("\nip route 0.0.0.0/0 10.1.1.1\n")
        end

        it 'renders nothing when there are no routes' do
            expect(render).not_to include('ip route')
            expect(render(routes => 'NONE')).not_to include('ip route')
        end

        it 'puts the routes before the router bgp block' do
            out = render(routes => '1.1.1.1/32 via 10.1.1.1')

            expect(out.index('ip route 1.1.1.1/32')).to be < out.index('router bgp')
        end

        it 'renders the same routes on the master and on the backup' do
            value = { routes => '1.1.1.1/32 via 10.1.1.1, 9.9.9.9/32 via 10.1.1.1' }

            expect(render(value, :master).lines.grep(/^ip route/)).to eq render(value, :backup).lines.grep(/^ip route/)
        end

        it 'renders only the routes when BGP is disabled' do
            config = Service::FRR::Config.parse_frr({ routes => '1.1.1.1/32 via 10.1.1.1' })
            out    = described_class.render(config, hostname: 'vr1')

            expect(out).to eq "frr defaults traditional\nhostname vr1\nlog syslog informational\n" \
                              "service integrated-vtysh-config\nip route 1.1.1.1/32 10.1.1.1\n"
        end

        it 'renders the same routes without BGP on the backup' do
            config = Service::FRR::Config.parse_frr({ routes => '1.1.1.1/32 via 10.1.1.1' })

            expect(described_class.render(config, hostname: 'vr1', ha_state: :backup))
                .to eq described_class.render(config, hostname: 'vr1', ha_state: :master)
        end
    end

    describe 'IPv6' do
        let(:v6) { { "#{p}NEIGHBOR1_ADDRESS" => 'fd77::21', "#{p}NEIGHBOR1_ASN" => '65200' } }

        it 'renders an IPv6 neighbor in its own address family and leaves the IPv4 one alone' do
            out = render(v6)

            expect(out).to include(" neighbor fd77::21 remote-as 65200\n", " address-family ipv6 unicast\n",
                                   "  neighbor fd77::21 activate\n", "  neighbor fd77::21 route-map BGP-N1-IN in\n",
                                   "  neighbor fd77::21 route-map BGP-N1-OUT out\n")
            v4 = out[/ address-family ipv4 unicast\n.*? exit-address-family\n/m]
            v6_block = out[/ address-family ipv6 unicast\n.*? exit-address-family\n/m]
            expect(v4).to be_a(String)
            expect(v6_block).to be_a(String)
            expect(v4).to include('neighbor 10.99.37.1 activate')
            expect(v4).not_to include('fd77::21')
            expect(v6_block).not_to include('10.99.37.1')
        end

        it 'renders nothing new for an IPv4-only config' do
            expect(render).not_to include('ipv6')
        end

        it 'uses ipv6 prefix-lists and matches for an IPv6 neighbor, with entries of its own family only' do
            out = render(v6.merge("#{p}NEIGHBOR1_IMPORT_PREFIXES" => '10.1.0.0/16,2001:db8:a::/48 le 56'))

            expect(out).to include("ipv6 prefix-list BGP-N1-IN seq 10 permit 2001:db8:a::/48 le 56\n",
                                   "route-map BGP-N1-IN permit 10\n match ipv6 address prefix-list BGP-N1-IN\n")
            expect(out).not_to include('prefix-list BGP-N1-IN seq 20')
            expect(out).not_to include('ip prefix-list BGP-N1-IN')
        end

        it 'denies everything when the list has no entry of the neighbor family, and accepts all when it is empty' do
            out = render(v6.merge("#{p}NEIGHBOR1_IMPORT_PREFIXES" => '10.1.0.0/16',
                                  "#{p}NEIGHBOR0_EXPORT_PREFIXES" => '2001:db8:a::/48'))

            expect(out).to include("route-map BGP-N1-IN deny 10\nexit\n")
            expect(out).to include("route-map BGP-N0-OUT deny 10\nexit\n")
            expect(out).to include("route-map BGP-N1-OUT permit 10\nexit\n")
            expect(out).to include("route-map BGP-N0-IN permit 10\nexit\n")
        end

        it 'splits networks and redistribution by family' do
            out = render(v6.merge("#{p}NETWORKS" => '10.99.0.0/24,2001:db8:99::/48', "#{p}REDISTRIBUTE" => 'static'))

            v4 = out[/ address-family ipv4 unicast\n.*? exit-address-family\n/m]
            v6_block = out[/ address-family ipv6 unicast\n.*? exit-address-family\n/m]
            expect(v4).to be_a(String)
            expect(v6_block).to be_a(String)
            expect(v4).to include("  network 10.99.0.0/24\n", "  redistribute static\n")
            expect(v6_block).to include("  network 2001:db8:99::/48\n", "  redistribute static\n")
        end

        it 'omits the empty ipv4 block of an IPv6-only config, which FRR does not print back' do
            only6 = { "#{p}NEIGHBOR0_ADDRESS" => 'fd77::21', "#{p}NEIGHBOR0_ASN" => '65200' }
            out = render(only6)

            expect(out).not_to include('address-family ipv4')
            expect(out).to include(" address-family ipv6 unicast\n  neighbor fd77::21 activate\n")
            expect(render(only6.merge("#{p}REDISTRIBUTE" => 'kernel'))).to include(" address-family ipv4 unicast\n  redistribute kernel\n")
        end

        it 'keeps the ipv4 block of an IPv6-only neighbor config that has an IPv4 network' do
            out = render({ "#{p}NEIGHBOR0_ADDRESS" => 'fd77::21', "#{p}NEIGHBOR0_ASN" => '65200',
                           "#{p}NETWORKS" => '10.99.0.0/24' })

            expect(out).to include(" address-family ipv4 unicast\n  network 10.99.0.0/24\n exit-address-family\n")
        end

        it 'keeps the ipv4 block when an IPv4 neighbor sits beside an IPv6 one, without networks or redistribution' do
            out = render(v6)

            expect(out).to include(" address-family ipv4 unicast\n  neighbor 10.99.37.1 activate\n")
        end

        it 'renders an ipv6 block and no ipv4 block for IPv6 networks without any neighbor' do
            out = parse_bgp({ "#{p}ASN" => '65010', "#{p}ROUTER_ID" => '10.99.37.2',
                                               "#{p}NETWORKS" => '2001:db8:99::/48' })
                                      .then { |config| described_class.render(config, hostname: 'vr1') }

            expect(out).not_to include('address-family ipv4')
            expect(out).to include(" address-family ipv6 unicast\n  network 2001:db8:99::/48\n exit-address-family\n")
        end

        it 'adds no ipv6 block for a redistribute-only config without IPv6 neighbors or networks' do
            expect(render("#{p}REDISTRIBUTE" => 'static')).not_to include('address-family ipv6')
        end

        it 'applies the backup profile to IPv6 neighbors too' do
            out = render(v6, :backup)

            expect(out).to include("route-map BGP-N1-OUT permit 10\n set metric 200\n set as-path prepend 65010 65010 65010\nexit\n")
        end

        it 'renders IPv6 static routes as ipv6 route, after the IPv4 ones' do
            config = Service::FRR::Config.parse_frr({ 'ONEAPP_VNF_STATIC_ROUTES' => '2001:db8::/32 via fd77::1, 1.1.1.1/32 via 10.0.0.1' })
            out = described_class.render(config, hostname: 'vr1')

            expect(out).to include("ip route 1.1.1.1/32 10.0.0.1\nipv6 route 2001:db8::/32 fd77::1\n")
        end

        it 'renders update-source and a bfd profile for an IPv6 neighbor' do
            out = render(v6.merge("#{p}NEIGHBOR1_UPDATE_SOURCE" => 'fd77::10', "#{p}NEIGHBOR1_BFD" => 'YES'))

            expect(out).to include(" neighbor fd77::21 update-source fd77::10\n", " neighbor fd77::21 bfd\n")
        end

        it 'adds the ipv6 block for an IPv6 network alone, with only IPv4 neighbors' do
            out = render("#{p}NETWORKS" => '2001:db8:99::/48')

            block = out[/ address-family ipv6 unicast\n.*? exit-address-family\n/m]
            expect(block).to be_a(String)
            expect(block).to include("  network 2001:db8:99::/48\n")
            expect(block).not_to include('neighbor')
        end

        it 'renders a bfd profile for an IPv6 neighbor with non-default timers' do
            out = render(v6.merge("#{p}NEIGHBOR1_BFD" => 'YES', "#{p}NEIGHBOR1_BFD_TIMERS" => '5 200 200'))

            expect(out).to include(" neighbor fd77::21 bfd profile BGP-N1\n", " profile BGP-N1\n  detect-multiplier 5\n")
        end

        it 'renders maximum-prefix inside the ipv6 block' do
            out = render(v6.merge("#{p}NEIGHBOR1_MAX_PREFIX" => '100'))

            block = out[/ address-family ipv6 unicast\n.*? exit-address-family\n/m]
            expect(block).to be_a(String)
            expect(block).to include("  neighbor fd77::21 maximum-prefix 100\n")
        end

        describe 'deny route-maps' do
            let(:deny_out) do
                v6.merge("#{p}NEIGHBOR1_EXPORT_PREFIXES" => '10.1.0.0/16',
                         "#{p}NEIGHBOR1_MED" => '20', "#{p}NEIGHBOR1_PREPEND" => '2')
            end

            it 'sets neither metric nor prepend on a deny export route-map' do
                out = render(deny_out)

                expect(out).to include("route-map BGP-N1-OUT deny 10\nexit\n")
            end

            it 'sets no local-preference on a deny import route-map' do
                out = render(v6.merge("#{p}NEIGHBOR1_IMPORT_PREFIXES" => '10.1.0.0/16',
                                      "#{p}NEIGHBOR1_LOCAL_PREF" => '150'))

                expect(out).to include("route-map BGP-N1-IN deny 10\nexit\n")
            end

            it 'sets neither backup metric nor prepend on a deny export route-map' do
                out = render(deny_out, :backup)

                expect(out).to include("route-map BGP-N1-OUT deny 10\nexit\n")
            end
        end
    end
end
