require 'init'
require 'VNetOVS'

# Test the Virtual Network Update for ovswitch_vxlan environments

RSpec.describe 'Virtual Network Update ovswitch_vxlan' do
    before(:all) do
        @info     = {}
        @defaults = RSpec.configuration.defaults

        # Create Virtual Network
        template=<<-EOF
            NAME    = "update_vnet"
            VN_MAD  = "ovswitch_vxlan"
            PHYDEV  = "tapup0"
            VLAN_ID = "111"
            OUTER_VLAN_ID = "222"
            MTU     = "1000"
            AR      = [ TYPE="IP4", SIZE="250", IP="192.168.0.1" ]
        EOF

        @info[:vn_id] = cli_create('onevnet create', template)

        # Create PHYDEV at Hosts
        @defaults[:hosts].each do |h|
            id   = Integer(h.match(/.*-(?<id>\d+)\.test/)[:id]) - 1
            host = Host.new(id)
            cmd  = 'sudo ip tuntap add tapup0 mode tap'
            cmd1 = 'sudo ip tuntap add tapup1 mode tap'

            host.ssh(cmd, true, { :timeout => 10 }, @defaults[:oneadmin])
            host.ssh(cmd1, true, { :timeout => 10 }, @defaults[:oneadmin])
        end
    end

    after(:all) do
        @info[:vm].terminate_hard

        cli_action("onevnet delete #{@info[:vn_id]}")
    end

    it 'creates a running VM in update network' do
        @info[:vm] = VM.new(cli_create("onevm create --mem 1 --cpu 1 --nic #{@info[:vn_id]}"))
        @info[:vm].running?

        @info[:vn]   = OVSNetwork.new(@info[:vn_id], @info[:vm].host_id, @defaults[:oneadmin])
        @info[:vnic] = "one-#{@info[:vm].id}-0"
    end

    it 'Update VLAN_ID' do
        info = @info[:vn].port_info(@info[:vnic])

        expect(info['tag']).to eq '111'

        template = <<-EOF
            VLAN_ID ="333"
        EOF

        @info[:vn].update(template)

        wait_loop(:timeout => 60) { @info[:vn].updated? }

        info = @info[:vn].port_info(@info[:vnic])

        expect(info['tag']).to eq '333'
    end

    it 'Update MTU' do
        info = @info[:vn].link_info(@info[:vnic])

        expect(info['mtu']).to eq 1000

        template = <<-EOF
            MTU="1450"
        EOF

        @info[:vn].update(template)

        wait_loop(:timeout => 60) { @info[:vn].updated? }

        info = @info[:vn].link_info(@info[:vnic])

        expect(info['mtu']).to eq 1450
    end

    it 'Update QoS' do
        template = <<-EOF
            INBOUND_AVG_BW="123"
            INBOUND_PEAK_BW="123"
            INBOUND_PEAK_KB="123"
            OUTBOUND_AVG_BW="123"
            OUTBOUND_PEAK_BW="123"
            OUTBOUND_PEAK_KB="123"
        EOF

        @info[:vn].update(template)

        wait_loop(:timeout => 60) { @info[:vn].updated? }

        info = @info[:vn].qos_info(@info[:vnic])

        info.each do |k, v|
            next if k == 'inbound.floor' # unsupported value

            expect(Integer(v)).to eq 123
        end
    end

    it 'Update PHYDEV' do
        ports = @info[:vn].list_ports

        expect(ports.include?('tapup0.222')).to be(true)
        expect(ports.include?('tapup1.444')).to be(false)

        template = <<-EOF
            PHYDEV="tapup1"
            OUTER_VLAN_ID = "444"
        EOF

        @info[:vn].update(template)

        wait_loop(:timeout => 60) { @info[:vn].updated? }

        ports = @info[:vn].list_ports

        expect(ports.include?('tapup0.222')).to be(false)
        expect(ports.include?('tapup1.444')).to be(true)
    end
end
