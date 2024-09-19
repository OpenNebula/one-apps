require 'init'

# Tests VM snapshot and revert

# Parameters:
# :template: VM that is tested is instantiated from this template
RSpec.describe 'VM snapshots' do
    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {}

        # Use the same VM for all the tests in this example
        @info[:vm_id] = cli_create('onetemplate instantiate '\
                                   "'#{@defaults[:template]}'")
        @info[:vm]    = VM.new(@info[:vm_id])
    end

    it 'deploys' do
        @info[:vm].running?
    end

    it 'ssh and context' do
        @info[:vm].reachable?
    end

    it 'creates 4 system snapshots' do
        @info[:vm].ssh('sync') # avoid SSH keys corruption

        (0..3).each do |snap_id|
            snap_name = "my-snapshot-#{snap_id}"

            # WARNING: don't call sync here due to a NFS problems with
            # Ubuntu 17.04; VM gets blocked by pending NFS operation and
            # KVM gets into delayed state after some time, anyway we are doing a
            # complete VM snapshot, so it doesn't matter if the data are still
            # in cache
            @info[:vm].ssh("echo #{snap_id} >/root/snap").expect_success

            # create snapshot
            cli_action("onevm snapshot-create #{@info[:vm_id]} #{snap_name}")
            @info[:vm].state?('RUNNING', /FAIL|^POWEROFF|UNKNOWN/)

            # check it was created, it has hypervisor ID
            cmd = cli_action("onevm show #{@info[:vm_id]} | " \
                             "grep #{snap_name} | awk '{print $5}'")
            expect(cmd.stdout.strip).not_to eq('')
        end
    end

    it 'deletes snapshot 0' do
        cli_action("onevm snapshot-delete #{@info[:vm_id]} my-snapshot-0")
        @info[:vm].state?('RUNNING', /FAIL|^POWEROFF|UNKNOWN/)
    end

    it 'power-off and resume again' do
        # lame detect of Ubuntu 14.04, not supported there yet
        skip "Too old platform - Ruby #{RUBY_VERSION}" \
            if Gem::Version.new(RUBY_VERSION.dup) < Gem::Version.new('2.0')

        cli_action("onevm poweroff --hard #{@info[:vm_id]}")
        @info[:vm].state?('POWEROFF')

        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it 'reverts 1,2 system snapshots' do
        (1..2).each do |snap_id|
            # revert
            cli_action("onevm snapshot-revert #{@info[:vm_id]} #{snap_id}")
            @info[:vm].state?('RUNNING', /FAIL|^POWEROFF|UNKNOWN/)

            # check it reverted to expected snapshot
            cmd = @info[:vm].ssh('cat /root/snap')
            cmd.expect_success
            expect(cmd.stdout.strip).to eq(snap_id.to_s)
        end
    end

    it 'suspend and resume again' do
        # lame detect of Ubuntu 14.04, not supported there yet
        skip "Too old platform - Ruby #{RUBY_VERSION}" \
            if Gem::Version.new(RUBY_VERSION.dup) < Gem::Version.new('2.0')

        cli_action("onevm suspend  #{@info[:vm_id]}")
        @info[:vm].state?('SUSPENDED')

        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it 'reverts 4th system snapshot' do
        cli_action("onevm snapshot-revert #{@info[:vm_id]} 3")
        @info[:vm].state?('RUNNING', /FAIL|^POWEROFF|UNKNOWN/)

        # check it reverted to expected snapshot
        cmd = @info[:vm].ssh('cat /root/snap')
        cmd.expect_success
        expect(cmd.stdout.strip).to eq('3')
    end

    it 'deletes all 3 snapshots' do
        (1..3).each do |snap_id|
            snap_name = "my-snapshot-#{snap_id}"

            # delete snapshot, check it's gone
            cli_action("onevm snapshot-delete #{@info[:vm_id]} #{snap_name}")
            @info[:vm].state?('RUNNING', /FAIL|^POWEROFF|UNKNOWN/)
            cmd = cli_action("onevm show #{@info[:vm_id]} | " \
                             "grep #{snap_name} | awk '{print $5}'")
            expect(cmd.stdout.strip).to eq('')
        end
    end

    it 'terminate vm' do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?
    end
end
