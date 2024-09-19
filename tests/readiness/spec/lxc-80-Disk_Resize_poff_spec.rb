require 'init'
require 'lib_lxd/DiskResize'

include DiskResize

# Test the disk resize operation

# Description:
# - VM is deployed
# - SSH is configured (contextualization)
# - Disk size is measured
# - VM is deleted
# - New VM is deployed with a new size
# - Disk size is measured again
# - VM is deleted
# - Check datastore contents
# Parameters:
# :template: VM that is tested is instantiated from this template
RSpec.describe 'Disk Resize PowerOff' do
    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {}

        # Use the same VM for all the tests in this example
        @info[:vm_id] = cli_create("onetemplate instantiate '#{@defaults[:template]}'")
        @info[:vm]    = VM.new(@info[:vm_id])
    end

    it 'deploys' do
        @info[:vm].running?
    end

    it 'ssh and context' do
        @info[:vm].reachable?
    end

    it 'can poweroff' do
        @info[:vm].safe_poweroff
    end

    it 'is able to resize disk #1' do
        cli_action("onevm disk-resize #{@info[:vm_id]} 0 11G")
        @info[:vm].state?('POWEROFF')
    end

    it 'resumes' do
        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it 'has the correct disk size #1' do
        xml_size = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/SIZE']
        expect(xml_size).to eq((11 * 1024).to_s)
    end

    it 'can poweroff' do
        @info[:vm].safe_poweroff
    end

    it 'is able to resize disk #2' do
        cli_action("onevm disk-resize #{@info[:vm_id]} 0 15G")
        @info[:vm].state?('POWEROFF')
    end

    it 'resumes' do
        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it 'has the correct disk size #2' do
        xml_size = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/SIZE']
        expect(xml_size).to eq((15 * 1024).to_s)
    end

    it 'terminate vm' do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?
    end
end
