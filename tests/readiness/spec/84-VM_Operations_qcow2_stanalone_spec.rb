require 'init'
require 'lib/vm_basics'

RSpec.describe 'QCOW2 standalone tasks' do

    before(:all) do
        @defaults = RSpec.configuration.defaults
        @info = {}
    end

    it 'Deploys' do
        @info[:vm_id] = cli_create("onetemplate instantiate '#{@defaults[:template]}'")
        @info[:vm] = VM.new(@info[:vm_id])
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it 'Check VM disk.0 is qcow2 chain' do
        disk_id = @info[:vm].disks.first['DISK_ID']
        disk_path = "/var/lib/one/datastores/0/#{@info[:vm_id]}/disk.#{disk_id}"

        cmd = "file `readlink -f #{disk_path}`"

        host = Host.new(@info[:vm].host_id)
        ret = host.ssh(cmd, true, { :timeout => 10 }, @defaults[:oneadmin])

        expect(ret.stdout).to match(/QEMU QCOW2? Image/)
        expect(ret.stdout).to match(/has backing file/)
    end

    it 'Terminates' do
        @info[:vm].terminate
    end

    it 'Add QCOW2_STANDALONE=YES to default datastore' do
        cli_update('onedatastore update 1', "QCOW2_STANDALONE=YES", true)
    end

    it 'Deploys' do
        @info[:vm_id] = cli_create("onetemplate instantiate '#{@defaults[:template]}'")
        @info[:vm] = VM.new(@info[:vm_id])
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it 'Check VM disk.0 is qcow2 standalone' do
        disk_id = @info[:vm].disks.first['DISK_ID']
        disk_path = "/var/lib/one/datastores/0/#{@info[:vm_id]}/disk.#{disk_id}"

        cmd = "file `readlink -f #{disk_path}`"

        host = Host.new(@info[:vm].host_id)
        ret = host.ssh(cmd, true, { :timeout => 10 }, @defaults[:oneadmin])

        expect(ret.stdout).to match(/QEMU QCOW2? Image/)
        expect(ret.stdout).not_to match(/has backing file/)
    end

    it 'Terminates' do
        @info[:vm].terminate
    end
end

# with the QCOW2_STANDALONE="YES" now run basic_vm_tasks + basic_vm_tasks on pers img

RSpec.describe "Basic VM Tasks with QCOW2_STANDALONE" do
    include_examples "basic_vm_tasks", false
end

RSpec.describe "Basic VM Tasks with QCOW2_STANDALONE (persistent image)" do
    @defaults = RSpec.configuration.defaults
    if @defaults[:basic_vm_task_peristent]
        include_examples "basic_vm_tasks", true
    end
end

RSpec.describe 'Restore datastore settings' do
    it 'Set QCOW2_STANDALONE=NO on default datastore' do
        cli_update('onedatastore update 1', "QCOW2_STANDALONE=NO", true)
    end
end
