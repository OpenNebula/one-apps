require 'init'

# ------------------------------------------------------------------------------
# Tests the creation and deletion of snapshots and the resize of ceph and qcow2 
#  disks
#   - kvm-ceph
#   - kvm-qcow2
#
# It needs to test:
#   - VMs running and poweroff (use different operations virsh and qemu-img)
# ------------------------------------------------------------------------------

RSpec.describe 'Disk resize after snapshots' do

    def snap_and_file(vm, index)
        vm.reachable?
        vm.ssh("touch s#{index}; sync")
        cli_action("onevm disk-snapshot-create #{vm.id} 0 s#{index}")
        vm.running?
    end

    def file_exist?(vm, index)
        exec = vm.ssh("ls s#{index} >/dev/null 2>&1 && echo 1 || echo 0")
        !(exec.stdout =~ /1.*/).nil?
    end

    def resize_disk(vm, disk, size)
        cli_action("onevm disk-resize #{vm.id} #{disk} #{size}")
    end

    def check_disk_size(vm, size, dev = '/dev/vda')
        vm.reachable?
        expect(vm.ssh("lsblk -n -d -o SIZE #{dev} | sed 's/[[:space:]]//g' | tr -d '\n'").stdout).to eql(size)
        vm.running?
    end

    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {}

        @info[:template] = @defaults[:template]
    end

    it 'deploys the VMs' do
        @info[:vm_id] = cli_create("onetemplate instantiate '#{@info[:template]}'")
        @info[:vm]    = VM.new(@info[:vm_id])

        @info[:vm].running?
        @info[:vm].reachable?
    end

    # b <-- 0 <-- 1 <-- 2 <-- 3 <-- 4 <-- 5 <-- (6)
    it 'should create 6 snapshots' do
        6.times do |index|
            snap_and_file(@info[:vm], index)
        end

        6.times do |index|
            expect(file_exist?(@info[:vm], index)).to be(true)
        end
    end

    it 'should live-resize the disk to 5G' do
        resize_disk(@info[:vm], 0, '5G')
        @info[:vm].running?
    end

    it 'disk size should be 5G' do
        check_disk_size(@info[:vm],'5G')
        @info[:vm].running?
    end

    it 'vm should be turned off' do
        @info[:vm].poweroff
        @info[:vm].state?('POWEROFF')
    end

    it 'should cold-resize the disk to 6G' do
        resize_disk(@info[:vm], 0, '6G')
        @info[:vm].state?('POWEROFF')
    end

    it 'vm should be turned on' do
        @info[:vm].resume
        @info[:vm].running?
    end

    it 'disk size should be 6G' do
        check_disk_size(@info[:vm], '6G')
    end

    it 'terminate the VMs' do
        @info[:vm].terminate_hard
        @info[:vm].done?
    end
end
