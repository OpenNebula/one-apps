# frozen_string_literal: true

require_relative 'support/quiet_logs'
require_relative 'support/bgp_config'
require_relative '../config'
require_relative '../renderer'

RSpec.describe 'BGP multipath' do
    let(:p) { Service::FRR::Attributes::PREFIX }

    let(:attrs) do
        {
            "#{p}ASN" => '65010', "#{p}ROUTER_ID" => '10.99.37.2',
            "#{p}NEIGHBOR0_ADDRESS" => '10.99.37.1', "#{p}NEIGHBOR0_ASN" => '65100',
            "#{p}NEIGHBOR1_ADDRESS" => 'fd77::21', "#{p}NEIGHBOR1_ASN" => '65002'
        }
    end

    def parse(extra = {}) = parse_bgp(attrs.merge(extra)).section(:bgp)

    def error_for(extra)
        parse(extra)
        nil
    rescue Service::FRR::ConfigError => e
        e.message
    end

    def render(extra = {}) = Service::FRR::Renderer.render(parse_bgp(attrs.merge(extra)), hostname: 'vr1')

    describe 'parsing' do
        it 'defaults to a single path and no relax' do
            expect(parse).to have_attributes(maximum_paths: 1, maximum_paths_ibgp: 1, multipath_relax: false)
        end

        it 'reads the three attributes' do
            config = parse("#{p}MAXIMUM_PATHS" => '4', "#{p}MAXIMUM_PATHS_IBGP" => '2', "#{p}MULTIPATH_RELAX" => 'yes')

            expect(config).to have_attributes(maximum_paths: 4, maximum_paths_ibgp: 2, multipath_relax: true)
        end

        it 'checks the range 1..64' do
            expect(error_for("#{p}MAXIMUM_PATHS" => '0')).to include("#{p}MAXIMUM_PATHS must be between 1 and 64")
            expect(error_for("#{p}MAXIMUM_PATHS_IBGP" => '65')).to include("#{p}MAXIMUM_PATHS_IBGP must be between 1 and 64")
            expect(error_for("#{p}MAXIMUM_PATHS" => '64', "#{p}MAXIMUM_PATHS_IBGP" => '1')).to be_nil
        end

        it 'rejects a non-integer and a bad boolean' do
            expect(error_for("#{p}MAXIMUM_PATHS" => 'many')).to include("#{p}MAXIMUM_PATHS must be an integer")
            expect(error_for("#{p}MULTIPATH_RELAX" => 'maybe')).to include("#{p}MULTIPATH_RELAX must be YES or NO")
        end
    end

    describe 'rendering' do
        it 'renders nothing by default' do
            expect(render).not_to include('maximum-paths')
            expect(render).not_to include('multipath-relax')
        end

        it 'renders eBGP maximum-paths in both address families' do
            out = render("#{p}MAXIMUM_PATHS" => '4')

            expect(out.scan("  maximum-paths 4\n").size).to eq 2
            expect(out).not_to include('maximum-paths ibgp')
        end

        it 'renders maximum-paths ibgp only above 1' do
            expect(render("#{p}MAXIMUM_PATHS_IBGP" => '3').scan("  maximum-paths ibgp 3\n").size).to eq 2
        end

        it 'renders the relax option once, globally' do
            expect(render("#{p}MULTIPATH_RELAX" => 'YES').scan(" bgp bestpath as-path multipath-relax\n").size).to eq 1
        end

        it 'renders it only in the address families that exist' do
            ipv6_only = attrs.reject { |key, _| key.include?('NEIGHBOR0') }.merge("#{p}MAXIMUM_PATHS" => '2')
            out = Service::FRR::Renderer.render(parse_bgp(ipv6_only), hostname: 'vr1')

            expect(out.scan('maximum-paths 2').size).to eq 1
        end

        it 'renders no line after a live change back to the defaults, so that frr-reload removes the old one' do
            out = render("#{p}MAXIMUM_PATHS" => '1', "#{p}MAXIMUM_PATHS_IBGP" => '1', "#{p}MULTIPATH_RELAX" => 'NO')

            expect(out).not_to include('maximum-paths')
            expect(out).not_to include('multipath-relax')
        end

        it 'accepts the relax option when both maximum-paths stay at 1, where it has no effect' do
            expect(error_for("#{p}MULTIPATH_RELAX" => 'YES')).to be_nil
            expect(render("#{p}MULTIPATH_RELAX" => 'YES')).to include(" bgp bestpath as-path multipath-relax\n")
        end

        it 'is the same on the HA backup node' do
            config = parse_bgp(attrs.merge("#{p}MAXIMUM_PATHS" => '4'))

            expect(Service::FRR::Renderer.render(config, hostname: 'vr1', ha_state: :backup)).to include("  maximum-paths 4\n")
        end
    end

    describe 'static gateway order' do
        def static_lines(routes)
            config = Service::FRR::Config.parse_frr({ 'ONEAPP_VNF_STATIC_ROUTES' => routes })
            Service::FRR::Renderer.render(config, hostname: 'vr1').lines.grep(/route /).map(&:chomp)
        end

        it 'sorts the gateways of one prefix numerically, as FRR 10.2.1 prints them' do
            out = static_lines('10.50.0.0/16 via 10.0.0.10, 10.50.0.0/16 via 10.0.0.2, 10.50.0.0/16 via 10.0.0.9')

            expect(out).to eq ['ip route 10.50.0.0/16 10.0.0.2', 'ip route 10.50.0.0/16 10.0.0.9', 'ip route 10.50.0.0/16 10.0.0.10']
        end

        it 'sorts IPv6 gateways numerically too (::a before ::10)' do
            out = static_lines('2001:db8:50::/48 via fd77::10, 2001:db8:50::/48 via fd77::a, 2001:db8:50::/48 via fd77::2')

            expect(out).to eq ['ipv6 route 2001:db8:50::/48 fd77::2', 'ipv6 route 2001:db8:50::/48 fd77::a',
                               'ipv6 route 2001:db8:50::/48 fd77::10']
        end

        it 'puts every IPv4 route before every IPv6 route, whatever the order of the attribute' do
            out = static_lines('2001:db8:50::/48 via fd77::2, 10.50.0.0/16 via 10.0.0.2, 2001:db8:50::/48 via fd77::1, 10.50.0.0/16 via 10.0.0.1')

            expect(out).to eq ['ip route 10.50.0.0/16 10.0.0.1', 'ip route 10.50.0.0/16 10.0.0.2',
                               'ipv6 route 2001:db8:50::/48 fd77::1', 'ipv6 route 2001:db8:50::/48 fd77::2']
        end
    end

    describe 'new keys while BGP is disabled' do
        let(:disabled) do
            { 'ONEAPP_VNF_STATIC_ROUTES' => '10.50.0.0/16 via 10.0.0.1', "#{p}ENABLED" => 'NO', "#{p}GRACEFUL_RESTART" => 'MAYBE',
              "#{p}GR_RESTART_TIME" => '9999', "#{p}MAXIMUM_PATHS" => '0', "#{p}MULTIPATH_RELAX" => 'maybe' }
        end

        it 'does not validate them' do
            expect { Service::FRR::Config.parse_frr(disabled) }.not_to raise_error
            expect(Service::FRR::Config.parse_frr(disabled).section(:bgp)).to be_nil
        end

        it 'does not render them' do
            out = Service::FRR::Renderer.render(Service::FRR::Config.parse_frr(disabled), hostname: 'vr1')

            expect(out).not_to match(/graceful|maximum-paths|multipath/)
            expect(out).to include('ip route 10.50.0.0/16 10.0.0.1')
        end
    end
end
