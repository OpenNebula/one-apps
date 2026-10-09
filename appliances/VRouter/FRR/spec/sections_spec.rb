# frozen_string_literal: true

require_relative 'support/quiet_logs'
require_relative 'support/bgp_config'
require_relative '../config'
require_relative '../sections'

# What the core asks of every section (see sections.rb).
SECTION_CONTRACT = %i[owns? in_context? parse config_of partial render_context daemons enabled_keys boot_only_keys
                      pin_values pinned secrets soft_refresh_commands status].freeze

RSpec.shared_examples 'a section' do
    it 'answers the whole section contract' do
        expect(described_class).to respond_to(*SECTION_CONTRACT)
    end

    it 'has a symbol name' do
        expect(described_class::NAME).to be_a(Symbol)
    end

    it 'has no status or a complete one' do
        status = described_class.status

        expect(status).to be_nil.or(include(:key, :command, :text))
    end
end

RSpec.describe Service::FRR::Sections do
    let(:p) { Service::FRR::Attributes::PREFIX }
    let(:bgp_attrs) do
        { "#{p}ASN" => '65010', "#{p}ROUTER_ID" => '10.99.37.2',
          "#{p}NEIGHBOR0_ADDRESS" => '10.99.37.1', "#{p}NEIGHBOR0_ASN" => '65100',
          "#{p}NEIGHBOR0_PASSWORD" => 's3cret' }
    end

    it 'activates Bgp for a BGP config and nothing for a static-only one' do
        bgp    = parse_bgp(bgp_attrs)
        static = Service::FRR::Config.parse_frr({ 'ONEAPP_VNF_STATIC_ROUTES' => 'NONE' })

        expect(described_class.active(bgp).map(&:first)).to eq [Service::FRR::Sections::Bgp]
        expect(described_class.active(static).map(&:first)).to eq [Service::FRR::Sections::Static]
        expect(described_class.pinned?(bgp)).to be true
        expect(described_class.pinned?(static)).to be false
    end
end

RSpec.describe Service::FRR::Sections::Bgp do
    it_behaves_like 'a section'

    let(:p) { Service::FRR::Attributes::PREFIX }
    let(:frr_config) do
        parse_bgp(
            {
                "#{p}ASN" => '65010', "#{p}ROUTER_ID" => '10.99.37.2',
                "#{p}NEIGHBOR0_ADDRESS" => '10.99.37.1', "#{p}NEIGHBOR0_ASN" => '65100',
                "#{p}NEIGHBOR0_PASSWORD" => 's3cret'
            }
        )
    end
    let(:config) { frr_config.section(:bgp) }

    it 'pins the ASN and the router-id' do
        expect(described_class.pin_values(config).keys).to eq %w[asn router_id]
        expect(described_class.pin_values(config)).to eq('asn' => 65_010, 'router_id' => '10.99.37.2')
    end

    it 'replaces the pinned values in a config' do
        pinned = described_class.pinned(frr_config, 'asn' => 65_011, 'router_id' => '10.99.37.9')

        expect(pinned.section(:bgp)).to have_attributes(asn: 65_011, router_id: '10.99.37.9')
    end

    it 'names the neighbor passwords as secrets' do
        expect(described_class.secrets(config)).to eq ['s3cret']
    end

    it 'soft-refreshes both address families' do
        expect(described_class.soft_refresh_commands(config)).to eq [
            ['vtysh', '-c', 'clear bgp ipv4 unicast * soft'],
            ['vtysh', '-c', 'clear bgp ipv6 unicast * soft']
        ]
    end

    it 'reads the BGP summary and formats the neighbors' do
        status = described_class.status

        expect(status[:key]).to eq 'BGP_STATE'
        expect(status[:command]).to eq ['vtysh', '-c', 'show bgp summary json']
        expect(status[:text].call('{}')).to eq 'no neighbors'
    end
end

RSpec.describe Service::FRR::Sections::Static do
    it_behaves_like 'a section'

    it 'owns only the static routes attribute' do
        expect(described_class.owns?('ONEAPP_VNF_STATIC_ROUTES')).to be true
        expect(described_class.owns?('ONEAPP_VNF_BGP_ASN')).to be false
    end

    it 'is in the context when the attribute is not blank (NONE counts)' do
        expect(described_class.in_context?({ 'ONEAPP_VNF_STATIC_ROUTES' => 'NONE' })).to be true
        expect(described_class.in_context?({ 'ONEAPP_VNF_STATIC_ROUTES' => ' ' })).to be false
        expect(described_class.in_context?({})).to be false
    end

    it 'has nothing to pin, scrub, refresh or report' do
        expect([described_class.daemons, described_class.enabled_keys, described_class.boot_only_keys]).to all(eq [])
        expect(described_class.pin_values(nil)).to eq({})
        expect(described_class.status).to be_nil
    end
end

RSpec.describe Service::FRR::Sections::Bgp do
    it 'owns everything under its prefix, including the poll interval' do
        expect(described_class.owns?('ONEAPP_VNF_BGP_POLL_INTERVAL')).to be true
        expect(described_class.owns?('ONEAPP_VNF_STATIC_ROUTES')).to be false
    end

    it 'is in the context for YES and 1 only (the environment helper treats TRUE as NO)' do
        expect(described_class.in_context?({ 'ONEAPP_VNF_BGP_ENABLED' => 'yes' })).to be true
        expect(described_class.in_context?({ 'ONEAPP_VNF_BGP_ENABLED' => '1' })).to be true
        expect(described_class.in_context?({ 'ONEAPP_VNF_BGP_ENABLED' => 'no' })).to be false
    end

    it 'is enabled for YES and 1 only, like every stock boolean attribute (TRUE is not accepted)' do
        %w[YES yes 1].each do |value|
            expect(described_class.enabled?({ 'ONEAPP_VNF_BGP_ENABLED' => value })).to be(true), value
        end
        %w[NO 0 TRUE true].each do |value|
            expect(described_class.enabled?({ 'ONEAPP_VNF_BGP_ENABLED' => value })).to be(false), value
        end
    end

    it 'keeps its enabled flag and the boot-only keys out of runtime overrides' do
        expect(described_class.enabled_keys).to eq ['ONEAPP_VNF_BGP_ENABLED']
        expect(described_class.boot_only_keys).to eq %w[ONEAPP_VNF_BGP_ASN ONEAPP_VNF_BGP_ROUTER_ID]
        expect(described_class.daemons).to eq ['bgpd']
    end
end

RSpec.describe Service::FRR::Sections do
    it 'lists Bgp before Static (the parse order)' do
        expect(described_class::ALL).to eq [Service::FRR::Sections::Bgp, Service::FRR::Sections::Static, Service::FRR::Sections::Ospf]
    end
end

RSpec.describe 'section rendering' do
    let(:p) { Service::FRR::Attributes::PREFIX }

    def bgp_config(neighbor_address)
        parse_bgp(
            { "#{p}ASN" => '65010', "#{p}ROUTER_ID" => '10.0.0.1',
              "#{p}NEIGHBOR0_ADDRESS" => neighbor_address, "#{p}NEIGHBOR0_ASN" => '65002' }
        )
    end

    it 'renders static routes before the BGP block' do
        expect(Service::FRR::Sections::RENDER_ORDER.first).to eq Service::FRR::Sections::Static
        expect(Service::FRR::Sections::RENDER_ORDER.last).to eq Service::FRR::Sections::Bgp
    end

    it 'gives the static partial the routes of each family' do
        config  = Service::FRR::Config.parse_frr(
            { 'ONEAPP_VNF_STATIC_ROUTES' => '2001:db8::/32 via fd77::1, 1.1.1.1/32 via 172.16.100.1' }
        )
        context = Service::FRR::Sections::Static.render_context(config.section(:static), ha_state: :master)

        expect(context[:static_v4].map(&:prefix)).to eq ['1.1.1.1/32']
        expect(context[:static_v6].map(&:prefix)).to eq ['2001:db8::/32']
    end

    it 'renders the IPv4 block only when it has content (an IPv6-only config has none)' do
        context = Service::FRR::Sections::Bgp.render_context(bgp_config('fd77::21').section(:bgp), ha_state: :master)

        expect([context[:v4], context[:v6]]).to eq [false, true]
    end

    it 'renders the IPv4 block for an IPv4 neighbor and no IPv6 block' do
        context = Service::FRR::Sections::Bgp.render_context(bgp_config('10.0.0.2').section(:bgp), ha_state: :master)

        expect([context[:v4], context[:v6]]).to eq [true, false]
    end

    it 'applies the HA backup profile in the neighbor view' do
        settings = bgp_config('10.0.0.2').section(:bgp)
        master   = Service::FRR::Sections::Bgp.render_context(settings, ha_state: :master)
        backup   = Service::FRR::Sections::Bgp.render_context(settings, ha_state: :backup)

        expect(master[:neighbors].first).to include(med: nil, prepend: [])
        expect(backup[:neighbors].first).to include(med: 200, prepend: %w[65010 65010 65010])
    end

    it 'names the partial of each section' do
        expect([Service::FRR::Sections::Static.partial, Service::FRR::Sections::Bgp.partial]).to eq %w[static bgp]
    end
end

RSpec.describe 'OSPF rendering' do
    let(:o) { 'ONEAPP_VNF_OSPF_' }
    let(:base) { { "#{o}ENABLED" => 'YES', "#{o}ROUTER_ID" => '10.0.0.1', "#{o}INTERFACE0_NAME" => 'eth1' } }

    def context_for(extra = {}, ha_state = :master)
        settings = Service::FRR::Config.parse_frr(base.merge(extra)).section(:ospf)
        Service::FRR::Sections::Ospf.render_context(settings, ha_state: ha_state)
    end

    it 'renders after the static routes and before BGP' do
        expect(Service::FRR::Sections::RENDER_ORDER).to eq(
            [Service::FRR::Sections::Static, Service::FRR::Sections::Ospf, Service::FRR::Sections::Bgp]
        )
        expect(Service::FRR::Sections::Ospf.partial).to eq 'ospf'
    end

    it 'leaves the values FRR does not print back out of the interface view' do
        interface = context_for[:interfaces].first

        expect(interface).to include(name: 'eth1', area: 0, cost: 10, network_type: nil, hello: nil, dead: nil,
                                     password: nil, bfd: false, passive: false)
    end

    it 'keeps non-default values' do
        extra = { "#{o}INTERFACE0_NETWORK_TYPE" => 'point-to-point', "#{o}INTERFACE0_HELLO_INTERVAL" => '5',
                  "#{o}INTERFACE0_DEAD_INTERVAL" => '20' }

        expect(context_for(extra)[:interfaces].first).to include(network_type: 'point-to-point', hello: 5, dead: 20)
    end

    it 'adds the backup cost on the VRRP backup only, capped at 65535' do
        extra = { "#{o}INTERFACE0_COST" => '65500', "#{o}BACKUP_COST" => '100' }

        expect(context_for({ "#{o}INTERFACE0_COST" => '20' }, :master)[:interfaces].first[:cost]).to eq 20
        expect(context_for({ "#{o}INTERFACE0_COST" => '20' }, :backup)[:interfaces].first[:cost]).to eq 120
        expect(context_for(extra, :backup)[:interfaces].first[:cost]).to eq 65_535
    end

    it 'maps DEFAULT_ORIGINATE and passes the redistribute list on' do
        expect(context_for[:default_originate]).to be_nil
        expect(context_for({ "#{o}DEFAULT_ORIGINATE" => 'yes' })[:default_originate]).to eq :yes
        expect(context_for({ "#{o}DEFAULT_ORIGINATE" => 'always', "#{o}REDISTRIBUTE" => 'static' }))
            .to include(default_originate: :always, redistribute: [{ source: 'static', metric: nil }])
    end

    it 'gives the originated and redistributed routes a higher metric on the VRRP backup, so peers prefer the master' do
        extra  = { "#{o}DEFAULT_ORIGINATE" => 'always', "#{o}REDISTRIBUTE" => 'connected static', "#{o}BACKUP_COST" => '150' }
        master = context_for(extra, :master)
        backup = context_for(extra, :backup)

        expect(master).to include(default_metric: nil)
        expect(master[:redistribute]).to eq [{ source: 'connected', metric: nil }, { source: 'static', metric: nil }]
        expect(backup).to include(default_metric: 151)
        expect(backup[:redistribute]).to eq [{ source: 'connected', metric: 170 }, { source: 'static', metric: 170 }]
    end

    it 'adds no metric on the backup when the backup cost is 0, and the largest backup cost stays in the metric range' do
        none = context_for({ "#{o}DEFAULT_ORIGINATE" => 'yes', "#{o}REDISTRIBUTE" => 'static', "#{o}BACKUP_COST" => '0' }, :backup)
        huge = context_for({ "#{o}DEFAULT_ORIGINATE" => 'yes', "#{o}REDISTRIBUTE" => 'static', "#{o}BACKUP_COST" => '65535' }, :backup)

        expect(none).to include(default_metric: nil)
        expect(none[:redistribute]).to eq [{ source: 'static', metric: nil }]
        expect(huge).to include(default_metric: 65_536)
    end

    it 'has no default metric when no default route is originated' do
        expect(context_for({}, :backup)).to include(default_metric: nil)
    end
end

RSpec.describe Service::FRR::Sections::Ospf do
    it_behaves_like 'a section'

    let(:fixture) { File.read(File.join(__dir__, 'fixtures', 'ospf_neighbor.json')) }
    let(:status)  { described_class.status }

    it 'asks vtysh for the OSPF neighbors under the key OSPF_STATE' do
        expect(status[:key]).to eq 'OSPF_STATE'
        expect(status[:command]).to eq ['vtysh', '-c', 'show ip ospf neighbor json']
    end

    it 'formats the neighbors FRR reports (state and interface without the local address)' do
        expect(status[:text].call(fixture)).to eq '10.0.0.2: Full/DR eth1'
    end

    it 'lists several neighbors sorted and several adjacencies of one router' do
        json = JSON.generate('neighbors' => {
                                 '10.0.0.9' => [{ 'nbrState' => 'Init/DROther', 'ifaceName' => 'eth2:10.1.0.1' }],
                                 '10.0.0.2' => [{ 'nbrState' => 'Full/DR', 'ifaceName' => 'eth1:10.0.0.1' },
                                                { 'nbrState' => 'Full/Backup', 'ifaceName' => 'eth3:10.2.0.1' }]
                             })

        expect(status[:text].call(json)).to eq '10.0.0.2: Full/Backup eth3; 10.0.0.2: Full/DR eth1; 10.0.0.9: Init/DROther eth2'
    end

    it 'says no neighbors for anything that is not a neighbor list' do
        ['', '{}', 'not json', '[]', 'null', '{"neighbors":[]}', '{"neighbors":{"10.0.0.2":"x"}}', nil].each do |output|
            expect(status[:text].call(output)).to eq('no neighbors'), output.inspect
        end
    end
end
