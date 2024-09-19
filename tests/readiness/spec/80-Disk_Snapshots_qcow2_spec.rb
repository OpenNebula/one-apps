require 'init'

# ------------------------------------------------------------------------------
# Tests the delete operation for linear chains this tests are for:
#   - kvm-qcow2
#   - kvm-qcow2-ssh
#
# It needs to test 2 different operation modes:
#   - VMs running and poweroff (use different operations virsh and qemu-img)
#   - persistent and non-peristent images
#
# Note: qcow2_standalone mode (disk.0.snap/0 is not a snapshot) is equivalent
# to ssh transfer mode
# ------------------------------------------------------------------------------

################################################################################
################################################################################
# Tests for delete operations in poweroff
################################################################################
################################################################################
shared_examples "Delete snapshots in the backing chain" do |tmpl, pers|
    it "deploys the VMs" do
        @info[:vm_id] = cli_create("onetemplate instantiate '#{@info[tmpl]}'")
        @info[:vm]    = VM.new(@info[:vm_id])

        @info[:vm].running?
        @info[:vm].reachable?

        @info[:vm].ssh("rm s[0-9]*")
    end

    # b <-- 0 <-- 1 <-- 2 <-- 3 <-- 4 <-- 5 <-- (6)
    it "should create 6 snapshots" do
        6.times do |index|
            snap_and_file(@info[:vm], index)
        end

        6.times do |index|
            expect(file_exist?(@info[:vm], index)).to be(true)
        end
    end

    # b <-- 0 <-- 1 <-- 2 <-- 3 <-- 4 <-- (6: 5)
    it "should delete the active snapshot" do
        cli_action("onevm disk-snapshot-delete #{@info[:vm_id]} 0 5")
        @info[:vm].running?

        6.times do |index|
            expect(file_exist?(@info[:vm], index)).to be(true)
        end
    end

    # b <-- 0 <-- 1 <-- 2 <-- (4.current = 3: 4+3) <-- (6: 5)
    it "should delete in-the-middle snapshot" do
        cli_action("onevm disk-snapshot-delete #{@info[:vm_id]} 0 3")
        @info[:vm].running?

        6.times do |index|
            expect(file_exist?(@info[:vm], index)).to be(true)
        end
    end

    # SSH mode:  0 <-- 1 (0 is not an actual snapshot)
    #   (1.current = 0 + 1) <-- 2 <-- (4.current = 3: 4+3) <-- (6: 5)
    # SHARED mode: base <-- 0 <-- 1 (0 is an snapshot of base image)
    #   base <-- (1.current = 0 + 1) <-- 2 <-- (4.current = 3: 4+3) <-- (6: 5)
    it "should delete first snapshot" do
        cli_action("onevm disk-snapshot-delete #{@info[:vm_id]} 0 0", !pers)
        @info[:vm].running?

        6.times do |index|
            expect(file_exist?(@info[:vm], index)).to be(true)
        end
    end

    it "should revert to each snapshot and preserve state" do
        @info[:vm].poweroff

        cli_action("onevm disk-snapshot-revert #{@info[:vm_id]} 0 1")
        @info[:vm].state?('POWEROFF')

        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].reachable?

        [0,1].each do |index|
            expect(file_exist?(@info[:vm], index)).to be(true)
        end
        [2,3,4,5].each do |index|
            expect(file_exist?(@info[:vm], index)).to be(false)
        end

        @info[:vm].poweroff

        cli_action("onevm disk-snapshot-revert #{@info[:vm_id]} 0 2")
        @info[:vm].state?('POWEROFF')

        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].reachable?

        [0,1,2].each do |index|
            expect(file_exist?(@info[:vm], index)).to be(true)
        end
        [3,4,5].each do |index|
            expect(file_exist?(@info[:vm], index)).to be(false)
        end

        @info[:vm].poweroff

        cli_action("onevm disk-snapshot-revert #{@info[:vm_id]} 0 4")
        @info[:vm].state?('POWEROFF')

        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].reachable?

        [0,1,2,3,4].each do |index|
            expect(file_exist?(@info[:vm], index)).to be(true)
        end
        [5].each do |index|
            expect(file_exist?(@info[:vm], index)).to be(false)
        end
    end

    it "should delete all remaining snapshots" do
        cli_action("onevm disk-snapshot-delete #{@info[:vm_id]} 0 1")
        @info[:vm].running?
        cli_action("onevm disk-snapshot-delete #{@info[:vm_id]} 0 2")
        @info[:vm].running?
        cli_action("onevm disk-snapshot-delete #{@info[:vm_id]} 0 4")
        @info[:vm].running?

        [0,1,2,3,4].each do |index|
            expect(file_exist?(@info[:vm], index)).to be(true)
        end
    end

    # 6 <-- 7 <-- 8 <-- 9 <-- 10
    it "should create another 6 set of snapshots" do
        [6,7,8,9,10].each do |index|
            snap_and_file(@info[:vm], index)
        end

        [6,7,8,9,10].each do |index|
            expect(file_exist?(@info[:vm], index)).to be(true)
        end
    end

    # 6 <-- 7 <-- (8) <-- 9 <-- 10
    it "should revert to 8 and power on" do
        @info[:vm].poweroff

        cli_action("onevm disk-snapshot-revert #{@info[:vm_id]} 0 8")
        @info[:vm].state?('POWEROFF')

        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].reachable?
    end

    # 6 <-- 7 <-- (8) <-- 9 <-- 10
    #              \
    #               +-- 11
    it "should NOT allow to delete snapshot 8" do
    # it will break backing file of 9 (this cannot be implemented with
    # qemu-img rebase 9 to 11, as 11 could be discarded in other revert operation)
        cli_action("onevm disk-snapshot-delete #{@info[:vm_id]} 0 8", false)
    end

    # 6 <-- 7 <-- (8) <-- 9 <-- 10
    #              \
    #               +-- 11
    it "should NOT allow to delete snapshot 7" do
    # it will break backing file of 9 (this can be implemented with
    # qemu-img rebase 9 to 7, as 7 is 8.current, poweroff is ok)
        cli_action("onevm disk-snapshot-delete #{@info[:vm_id]} 0 7", false)
    end

    it "should delete snapshots outside of the disk <backingStore>" do
        # 6 <-- 7 <-- (8) <--  10: (9+10)
        cli_action("onevm disk-snapshot-delete #{@info[:vm_id]} 0 9")
        @info[:vm].running?

        # 6 <-- 7 <-- (8)
        cli_action("onevm disk-snapshot-delete #{@info[:vm_id]} 0 10")
        @info[:vm].running?
    end

    it "should delete snapshots within the <backingStore>" do
        # (7.current = 6: 6+7)  <-- (8)
        cli_action("onevm disk-snapshot-delete #{@info[:vm_id]} 0 6")
        @info[:vm].running?

        # (8.current = 6: 6+7+8)
        cli_action("onevm disk-snapshot-delete #{@info[:vm_id]} 0 7")
        @info[:vm].running?

        cli_action("onevm disk-snapshot-delete #{@info[:vm_id]} 0 8")
        @info[:vm].running?

        [0,1,2,3,4,6,7,8].each do |index|
            expect(file_exist?(@info[:vm], index)).to be(true)
        end
    end

    it "should terminate the VM" do
        @info[:vm].terminate_hard
    end
end

################################################################################
################################################################################
# Tests for delete operations in poweroff
#   NOTE; Persistent images preserve next snapshot ID to be consistent with
#   the filenames in the .snap folder
################################################################################
################################################################################
shared_examples "Delete snapshots in the backing chain (poweroff)" do |tmpl|
    it "deploys the VMs" do
        @info[:vmpoff_id] = cli_create("onetemplate instantiate '#{@info[tmpl]}'")
        @info[:vmpoff]    = VM.new(@info[:vmpoff_id])

        @info[:vmpoff].running?
        @info[:vmpoff].reachable?

        @info[:vmpoff].ssh("rm s[0-9]*")

        @info[:next] = 0

        xml = cli_action_xml("onevm show -x #{@info[:vmpoff_id]}")
        @info[:next] = xml["SNAPSHOTS/NEXT_SNAPSHOT"].to_i
    end

    # b <-- 0 <-- 1 <-- 2 <-- 3 <-- 4 <-- 5 <-- (6)
    it "should create 6 snapshots" do
        n = @info[:next]

        6.times do |index|
            snap_and_file(@info[:vmpoff], index + n)
        end

        6.times do |index|
            expect(file_exist?(@info[:vmpoff], index + n)).to be(true)
        end
    end

    # b <-- 0 <-- 1 <-- 2 <-- 3 <-- 4 <-- (6: 5)
    it "should delete the active snapshot" do
        n = @info[:next]

        @info[:vmpoff].poweroff
        cli_action("onevm disk-snapshot-delete #{@info[:vmpoff_id]} 0 #{5 + n}")
        @info[:vmpoff].state?('POWEROFF')

        cli_action("onevm resume #{@info[:vmpoff_id]}")
        @info[:vmpoff].reachable?

        6.times do |index|
            expect(file_exist?(@info[:vmpoff], index + n)).to be(true)
        end
    end

    # b <-- 0 <-- 1 <-- 2 <-- (4.current = 3: 4+3) <-- (6: 5)
    it "should delete in-the-middle snapshot" do
        n = @info[:next]

        @info[:vmpoff].poweroff
        cli_action("onevm disk-snapshot-delete #{@info[:vmpoff_id]} 0 #{3 + n}")
        @info[:vmpoff].state?('POWEROFF')

        cli_action("onevm resume #{@info[:vmpoff_id]}")
        @info[:vmpoff].reachable?

        6.times do |index|
            expect(file_exist?(@info[:vmpoff], index + n)).to be(true)
        end
    end

    # SSH mode:  0 <-- 1 (0 is not an actual snapshot)
    #   (1.current = 0 + 1) <-- 2 <-- (4.current = 3: 4+3) <-- (6: 5)
    # SHARED mode: base <-- 0 <-- 1 (0 is an snapshot of base image)
    #   base <-- (1.current = 0 + 1) <-- 2 <-- (4.current = 3: 4+3) <-- (6: 5)
    #
    # NOTE: for the persistent round we start in 11 so 0 is not deleted never
    it "should delete first snapshot" do
        n = @info[:next]

        @info[:vmpoff].poweroff
        cli_action("onevm disk-snapshot-delete #{@info[:vmpoff_id]} 0 #{0 + n}")
        @info[:vmpoff].state?('POWEROFF')

        cli_action("onevm resume #{@info[:vmpoff_id]}")
        @info[:vmpoff].reachable?

        6.times do |index|
            expect(file_exist?(@info[:vmpoff], index + n)).to be(true)
        end
    end

    it "should revert to each snapshot and preserve state" do
        n = @info[:next]

        @info[:vmpoff].poweroff

        cli_action("onevm disk-snapshot-revert #{@info[:vmpoff_id]} 0 #{1 + n}")
        @info[:vmpoff].state?('POWEROFF')

        cli_action("onevm resume #{@info[:vmpoff_id]}")
        @info[:vmpoff].reachable?

        [0,1].each do |index|
            expect(file_exist?(@info[:vmpoff], index + n)).to be(true)
        end
        [2,3,4,5].each do |index|
            expect(file_exist?(@info[:vmpoff], index + n)).to be(false)
        end

        @info[:vmpoff].poweroff

        cli_action("onevm disk-snapshot-revert #{@info[:vmpoff_id]} 0 #{2 + n}")
        @info[:vmpoff].state?('POWEROFF')

        cli_action("onevm resume #{@info[:vmpoff_id]}")
        @info[:vmpoff].reachable?

        [0,1,2].each do |index|
            expect(file_exist?(@info[:vmpoff], index + n)).to be(true)
        end
        [3,4,5].each do |index|
            expect(file_exist?(@info[:vmpoff], index + n)).to be(false)
        end

        @info[:vmpoff].poweroff

        cli_action("onevm disk-snapshot-revert #{@info[:vmpoff_id]} 0 #{4 + n}")
        @info[:vmpoff].state?('POWEROFF')

        cli_action("onevm resume #{@info[:vmpoff_id]}")
        @info[:vmpoff].reachable?

        [0,1,2,3,4].each do |index|
            expect(file_exist?(@info[:vmpoff], index + n)).to be(true)
        end

        [5].each do |index|
            expect(file_exist?(@info[:vmpoff], index + n)).to be(false)
        end
    end

    it "should delete all remaining snapshots" do
        n = @info[:next]

        @info[:vmpoff].poweroff
        cli_action("onevm disk-snapshot-delete #{@info[:vmpoff_id]} 0 #{1 + n}")
        @info[:vmpoff].state?('POWEROFF')
        cli_action("onevm disk-snapshot-delete #{@info[:vmpoff_id]} 0 #{2 + n}")
        @info[:vmpoff].state?('POWEROFF')
        cli_action("onevm disk-snapshot-delete #{@info[:vmpoff_id]} 0 #{4 + n}")
        @info[:vmpoff].state?('POWEROFF')

        cli_action("onevm resume #{@info[:vmpoff_id]}")
        @info[:vmpoff].reachable?

        [0,1,2,3,4].each do |index|
            expect(file_exist?(@info[:vmpoff], index + n)).to be(true)
        end
    end

    it "should terminate the VM" do
        @info[:vmpoff].terminate_hard
    end
end

################################################################################
################################################################################
# Main tests
################################################################################
################################################################################

RSpec.describe 'Snapshot delete tests for linear backing chains' do
    def snap_and_file(vm, index)
        vm.ssh("touch s#{index}; sync")

        cli_action("onevm disk-snapshot-create #{vm.id} 0 s#{index}")

        vm.running?
    end

    def file_exist?(vm, index)
        exec = vm.ssh("ls s#{index} >/dev/null 2>&1 && echo 1 || echo 0")

        !(exec.stdout =~ /1.*/).nil?
    end


    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {}

        @info[:template] = @defaults[:template]
        @info[:template_p] = @defaults[:template_p]
    end

    include_examples "Delete snapshots in the backing chain", :template, false

    include_examples "Delete snapshots in the backing chain", :template_p, true

    include_examples "Delete snapshots in the backing chain (poweroff)", :template

    include_examples "Delete snapshots in the backing chain (poweroff)", :template_p
end
