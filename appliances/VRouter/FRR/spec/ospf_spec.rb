# frozen_string_literal: true

require_relative 'support/quiet_logs'
require_relative 'support/bgp_config'
require_relative '../config'

RSpec.describe Service::FRR::Sections::Ospf do
    let(:o) { 'ONEAPP_VNF_OSPF_' }
    let(:base) { { "#{o}ENABLED" => 'YES', "#{o}ROUTER_ID" => '10.0.0.1', "#{o}INTERFACE0_NAME" => 'eth1' } }

    def parse_ospf(attrs, default_router_id: nil)
        Service::FRR::Config.parse_frr(attrs, default_router_id: default_router_id).section(:ospf)
    end

    def errors_of(attrs)
        Service::FRR::Config.parse_frr(attrs)
        []
    rescue Service::FRR::ConfigError => e
        e.errors
    end

    it 'parses a minimal interface with the documented defaults' do
        settings = parse_ospf(base)

        expect(settings).to have_attributes(router_id: '10.0.0.1', default_originate: :no, redistribute: [], backup_cost: 100)
        expect(settings.interfaces.size).to eq 1
        expect(settings.interfaces.first).to have_attributes(
            index: 0, name: 'eth1', area: 0, cost: 10, passive: false, network_type: 'broadcast',
            hello_interval: 10, dead_interval: 40, password: nil, bfd: false
        )
    end

    it 'parses every option' do
        settings = parse_ospf(base.merge(
                                  "#{o}DEFAULT_ORIGINATE" => 'always', "#{o}REDISTRIBUTE" => 'static, connected',
                                  "#{o}BACKUP_COST" => '200', "#{o}INTERFACE0_AREA" => '0.0.0.5',
                                  "#{o}INTERFACE0_COST" => '30', "#{o}INTERFACE0_PASSIVE" => 'YES',
                                  "#{o}INTERFACE0_NETWORK_TYPE" => 'Point-To-Point', "#{o}INTERFACE0_HELLO_INTERVAL" => '5',
                                  "#{o}INTERFACE0_DEAD_INTERVAL" => '20', "#{o}INTERFACE0_PASSWORD" => 'sekret',
                                  "#{o}INTERFACE0_BFD" => '1'
                              ))

        expect(settings).to have_attributes(default_originate: :always, redistribute: %w[connected static], backup_cost: 200)
        expect(settings.interfaces.first).to have_attributes(
            area: 5, cost: 30, passive: true, network_type: 'point-to-point', hello_interval: 5, dead_interval: 20,
            password: 'sekret', bfd: true
        )
    end

    it 'reads several interface slots in index order' do
        settings = parse_ospf(base.merge("#{o}INTERFACE2_NAME" => 'eth3', "#{o}INTERFACE1_NAME" => 'eth2'))

        expect(settings.interfaces.map { |i| [i.index, i.name] }).to eq [[0, 'eth1'], [1, 'eth2'], [2, 'eth3']]
    end

    it 'accepts an area as a number or a dotted quad and stores the number' do
        expect(parse_ospf(base.merge("#{o}INTERFACE0_AREA" => '10')).interfaces.first.area).to eq 10
        expect(parse_ospf(base.merge("#{o}INTERFACE0_AREA" => '0.0.0.0')).interfaces.first.area).to eq 0
        expect(parse_ospf(base.merge("#{o}INTERFACE0_AREA" => '4294967295')).interfaces.first.area).to eq 4_294_967_295
    end

    [
        ['ONEAPP_VNF_OSPF_INTERFACE0_AREA', '4294967296', 'AREA'],
        ['ONEAPP_VNF_OSPF_INTERFACE0_AREA', '0.0.0', 'AREA'],
        ['ONEAPP_VNF_OSPF_INTERFACE0_COST', '0', 'COST'],
        ['ONEAPP_VNF_OSPF_INTERFACE0_COST', '65536', 'COST'],
        ['ONEAPP_VNF_OSPF_INTERFACE0_HELLO_INTERVAL', '0', 'HELLO_INTERVAL'],
        ['ONEAPP_VNF_OSPF_INTERFACE0_DEAD_INTERVAL', '65536', 'DEAD_INTERVAL'],
        ['ONEAPP_VNF_OSPF_INTERFACE0_NETWORK_TYPE', 'nbma', 'NETWORK_TYPE'],
        ['ONEAPP_VNF_OSPF_INTERFACE0_PASSIVE', 'TRUE', 'PASSIVE'],
        ['ONEAPP_VNF_OSPF_INTERFACE0_NAME', 'lo', 'NAME'],
        ['ONEAPP_VNF_OSPF_INTERFACE0_NAME', 'eth1; reboot', 'NAME'],
        ['ONEAPP_VNF_OSPF_DEFAULT_ORIGINATE', 'maybe', 'DEFAULT_ORIGINATE'],
        ['ONEAPP_VNF_OSPF_REDISTRIBUTE', 'kernel', 'REDISTRIBUTE'],
        ['ONEAPP_VNF_OSPF_REDISTRIBUTE', 'bgp', 'REDISTRIBUTE'],
        ['ONEAPP_VNF_OSPF_BACKUP_COST', '65536', 'BACKUP_COST'],
        ['ONEAPP_VNF_OSPF_ROUTER_ID', 'fd77::1', 'ROUTER_ID']
    ].each do |key, value, label|
        it "rejects #{label}=#{value.inspect} and names the attribute" do
            errors = errors_of(base.merge(key => value))

            expect(errors.join).to include(key)
        end
    end

    it 'requires the dead interval to be greater than the hello interval' do
        errors = errors_of(base.merge("#{o}INTERFACE0_HELLO_INTERVAL" => '20', "#{o}INTERFACE0_DEAD_INTERVAL" => '20'))

        expect(errors.join).to include('DEAD_INTERVAL must be greater than')
    end

    it 'takes the dead interval default (40) against a hello interval above it as an error too' do
        errors = errors_of(base.merge("#{o}INTERFACE0_HELLO_INTERVAL" => '50'))

        expect(errors.join).to include('DEAD_INTERVAL must be greater than')
    end

    it 'limits the MD5 key to 16 characters without whitespace, quotes or backslash, and never echoes it' do
        ['a' * 17, 'two words', "it's", 'back\\slash'].each do |bad|
            errors = errors_of(base.merge("#{o}INTERFACE0_PASSWORD" => bad))

            expect(errors.join).to include("#{o}INTERFACE0_PASSWORD"), bad
            expect(errors.join).not_to include(bad), bad
        end
        expect(parse_ospf(base.merge("#{o}INTERFACE0_PASSWORD" => 'a' * 16)).interfaces.first.password).to eq 'a' * 16
    end

    it 'ignores an unused interface slot that carries only defaults (PASSIVE=NO, BFD=NO)' do
        attrs = base.merge("#{o}INTERFACE1_PASSIVE" => 'NO', "#{o}INTERFACE1_BFD" => 'NO')

        expect(errors_of(attrs)).to eq []
        expect(parse_ospf(attrs).interfaces.map(&:index)).to eq [0]
        expect(errors_of(base.merge("#{o}INTERFACE1_BFD" => 'YES')).join).to match(/interface slot 1 is incomplete/)
    end

    it 'says that the dead interval is the default one when only the hello interval is too large' do
        errors = errors_of(base.merge("#{o}INTERFACE0_HELLO_INTERVAL" => '50'))

        expect(errors.join).to include("#{o}INTERFACE0_DEAD_INTERVAL", 'default', '50')
        expect(errors_of(base.merge("#{o}INTERFACE0_HELLO_INTERVAL" => '50', "#{o}INTERFACE0_DEAD_INTERVAL" => '40')).join)
            .not_to include('default')
    end

    it 'reports a slot with options but no NAME, naming the slot' do
        errors = errors_of(base.merge("#{o}INTERFACE1_COST" => '20'))

        expect(errors.join).to match(/interface slot 1 is incomplete/)
    end

    it 'reports a duplicate interface name' do
        errors = errors_of(base.merge("#{o}INTERFACE1_NAME" => 'eth1'))

        expect(errors.join).to include('duplicate OSPF interface: eth1')
    end

    it 'reports an unknown OSPF attribute' do
        expect(errors_of(base.merge("#{o}TYPO" => '1')).join).to include("unknown attribute #{o}TYPO")
        expect(errors_of(base.merge("#{o}INTERFACE0_TYPO" => '1')).join).to include("unknown attribute #{o}INTERFACE0_TYPO")
    end

    it 'sorts the redistribute list and drops duplicates' do
        expect(parse_ospf(base.merge("#{o}REDISTRIBUTE" => 'static connected static')).redistribute).to eq %w[connected static]
    end

    it 'resolves the router-id: own attribute, then the shared one, then the NIC default' do
        own    = base.reject { |key, _| key.end_with?('ROUTER_ID') }
        shared = own.merge('ONEAPP_VNF_FRR_ROUTER_ID' => '10.9.9.9')

        expect(parse_ospf(base, default_router_id: '10.0.0.5').router_id).to eq '10.0.0.1'
        expect(parse_ospf(shared, default_router_id: '10.0.0.5').router_id).to eq '10.9.9.9'
        expect(parse_ospf(own, default_router_id: '10.0.0.5').router_id).to eq '10.0.0.5'
        expect(errors_of(own).join).to include("#{o}ROUTER_ID is required")
    end

    it 'is not enabled for TRUE (only YES and 1), and then ignores every OSPF key without errors' do
        stale = { "#{o}ENABLED" => 'TRUE', "#{o}INTERFACE0_COST" => 'not-a-number', "#{o}TYPO" => '1' }

        expect(errors_of(stale)).to eq []
        expect(parse_ospf(stale)).to be_nil
        expect(parse_ospf({ "#{o}ENABLED" => 'NO', "#{o}INTERFACE0_COST" => 'x' })).to be_nil
        expect(parse_ospf({})).to be_nil
    end

    it 'accepts an enabled OSPF with no interface yet' do
        expect(parse_ospf({ "#{o}ENABLED" => 'YES', "#{o}ROUTER_ID" => '10.0.0.1' }).interfaces).to eq []
    end

    describe 'as a section' do
        let(:frr_config) { Service::FRR::Config.parse_frr(base.merge("#{o}INTERFACE0_PASSWORD" => 'sekret')) }
        let(:settings)   { frr_config.section(:ospf) }

        it 'owns the OSPF prefix, is in the context for YES/1, lists its flags and daemon' do
            expect(described_class.owns?("#{o}ANYTHING")).to be true
            expect(described_class.owns?('ONEAPP_VNF_BGP_ASN')).to be false
            expect(described_class.in_context?({ "#{o}ENABLED" => 'yes' })).to be true
            expect(described_class.in_context?({ "#{o}ENABLED" => 'TRUE' })).to be false
            expect(described_class.enabled_keys).to eq ["#{o}ENABLED"]
            expect(described_class.boot_only_keys).to eq ["#{o}ROUTER_ID"]
            expect(described_class.daemons).to eq ['ospfd']
        end

        it 'pins the router-id under a name that cannot collide with BGP' do
            expect(described_class.pin_values(settings)).to eq('ospf_router_id' => '10.0.0.1')
            expect(described_class.pinned(frr_config, 'ospf_router_id' => '10.0.0.7').section(:ospf).router_id).to eq '10.0.0.7'
            expect(described_class.pinned(frr_config, {}).section(:ospf).router_id).to eq '10.0.0.1'
        end

        it 'names the interface keys as secrets and has nothing to refresh' do
            expect(described_class.secrets(settings)).to eq ['sekret']
            expect(described_class.soft_refresh_commands(settings)).to eq []
        end
    end
end
