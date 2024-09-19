require 'init'
require 'VNetOVS'

# Test the snapshot effects on Open vSwitch network

RSpec.describe 'Snapshots with Open vSwitch network' do
    before(:all) do
        @info     = {}
        @defaults = RSpec.configuration.defaults

        @info[:vm_id] = cli_create('onetemplate instantiate '\
                                   "'#{@defaults[:template_isolated_1]}'")
        @info[:vm]    = VM.new(@info[:vm_id])
    end

    after(:all) do
        @info[:vm].terminate_hard
    end

    it 'deploys' do
        @info[:vm].running?
    end

    it 'creates a snapshot' do
        snap_name = 'ovs-snap-0'
        cli_action("onevm snapshot-create #{@info[:vm_id]} #{snap_name}")
        @info[:vm].running?

        cmd = cli_action("onevm show #{@info[:vm_id]} | " \
                         "grep #{snap_name} | awk '{print $1}'")

        @info[:snap_id] = cmd.stdout.strip
        expect(@info[:snap_id]).not_to eq('')
    end

    it 'reverts the snapshot and checks network status' do
        cli_action("onevm snapshot-revert #{@info[:vm_id]} #{@info[:snap_id]}")
        @info[:vm].running?

        vm_nic_id = 1

        @info[:vnid] = @info[:vm].vnet_id(vm_nic_id)
        @info[:vn]   = OVSNetwork.new(@info[:vnid], @info[:vm].host_id, @defaults[:oneadmin])
        @info[:vnic] = "one-#{@info[:vm_id]}-#{vm_nic_id}"
        @info[:vnet] = cli_action_xml("onevnet show -x #{@info[:vnid]}")

        info = @info[:vn].port_info(@info[:vnic])

        expect(info['tag']).to eq @info[:vnet]['TEMPLATE/VLAN_ID']
    end
end