require 'init'
require 'VNetVLAN'

# Test the Virtual Network Update for vxlan environments
RSpec.describe 'Virtual Network Update vxlan' do
    before(:all) do
        @info     = {}
        @defaults = RSpec.configuration.defaults

        # Create Virtual Network
        template=<<-EOF
            NAME    = "update_vnet"
            VN_MAD  = "fw"
            PHYDEV  = "tapup0"
            BRIDGE  = "onebr.up"
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

        @info[:vn]   = VLANNetwork.new(@info[:vn_id], @info[:vm].host_id, @defaults[:oneadmin])
        @info[:vnic] = "one-#{@info[:vm].id}-0"
    end

    it 'Update PHYDEV' do
        ports = @info[:vn].list_ports

        expect(ports.include?('tapup0')).to be(true)
        expect(ports.include?('tapup1')).to be(false)

        template = <<-EOF
            PHYDEV="tapup1"
        EOF

        @info[:vn].update(template)

        wait_loop(:timeout => 60) { @info[:vn].updated? }

        ports = @info[:vn].list_ports

        expect(ports.include?('tapup0')).to be(false)
        expect(ports.include?('tapup1')).to be(true)
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
end
