require 'init'

# This is sparate test set then VM_Live_Migration because
#
# * it only work with shared storage, but not with ssh TM
#   because with ssh `virsh migrate --copy-storage-all does
#   not copy the disk snapshts
#
# * VM snapshots doesn't work with raw disks but we test them
#   with the other VM_Live_Migration tests

RSpec.describe 'Live Migration with VM snapshots' do
    before(:all) do
        @defaults = RSpec.configuration.defaults

        skip 'Unsupported system' if
            @defaults[:microenv].start_with?('kvm-ssh') &&
            ['centos7', 'rhel7'].include?(@defaults[:platform]) &&
            !@defaults[:flavours].include?('ev')

        skip 'Issue #4695' if @defaults[:platform] == 'fedora32'

        # Used to pass info accross tests
        @info = {}

        # Use the same VM for all the tests in this example
        @info[:vm_id] = cli_create("onetemplate instantiate #{@defaults[:template]}")
        @info[:vm]    = VM.new(@info[:vm_id])

        @info[:ds_id]     = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DATASTORE_ID']
        @info[:ds_driver] = DSDriver.get(@info[:ds_id])

        # Get image list
        @info[:image_list] = @info[:ds_driver].image_list
    end

    def create_snapshots(t)
        (0..1).each do |snap_id|
            snap_name = "my-snapshot-#{snap_id * (t+1)}"

            # SSH debug code
            #rc = @info[:vm].ssh("echo #{snap_name} >/root/snap && sync")
            #require 'pp'
            #puts "LAP: #{t}"
            #pp rc
            #rc.expect_success

            @info[:vm].ssh("echo #{snap_name} >/root/snap && sync").expect_success

            # create snapshot
            cli_action("onevm snapshot-create #{@info[:vm_id]} #{snap_name}")
            @info[:vm].state?('RUNNING', /FAIL|^POWEROFF|UNKNOWN/)

            # 2nd iteration run the rest of the tests with a resume -> poweroff -> resume transition
            if t == 1
                @info[:vm].poweroff
                @info[:vm].resume
            end

            # check it was created, it has hypervisor ID
            cmd = cli_action("onevm show #{@info[:vm_id]} | " \
                             "grep #{snap_name} | awk '{print $5}'")

            expect(cmd.stdout.strip).not_to eq('')
        end
    end

    def live_migrate
        @info[:target_hosts].each do |target_host|
            puts "\tlive-migrate to #{target_host}"

            cli_action("onevm migrate --live #{@info[:vm_id]} #{target_host}")
            @info[:vm].running?

            cmd = "ssh #{HOST_SSH_OPTS} #{target_host} virsh -c qemu:///system list"
            post_migrate_cmd = SafeExec.run(cmd)
            expect(post_migrate_cmd.success?).to be(true)
            expect(post_migrate_cmd.stdout).to match(/\Wone-#{@info[:vm_id]}\W/)
        end
    end

    def verify(t)
        # in ONED
        (0..1).each do |snap_id|
            snap_name = "my-snapshot-#{snap_id * (t+1)}"
            cmd = cli_action("onevm show #{@info[:vm_id]} | " \
                             "grep #{snap_name} | awk '{print $5}'")
            expect(cmd.stdout.strip).not_to eq('')
        end

        # one hypervisor
        cmd = "virsh -c qemu:///system snapshot-list one-#{@info[:vm_id]} --name"
        cmd = SafeExec.run("ssh #{@info[:vm].hostname} '#{cmd}'")
        expect(cmd.stdout.strip).to eq("snap-0\nsnap-1")

        # present metadata snapshot files in datastore
        cmd = "virsh -c qemu:///system domblklist one-#{@info[:vm_id]}"
        cmd = SafeExec.run("ssh #{@info[:vm].hostname} '#{cmd}'")

        begin
            disk_path = cmd.stdout.split("\n").last.split(/  */).last
            vm_dir = File.dirname(disk_path)
        rescue StandardError
            raise "Can not parse `virsh domblklist`: #{cmd.stdout} output"
        end

        cmd = "ls #{vm_dir}/snap*.xml"
        cmd = SafeExec.run("ssh #{@info[:vm].hostname} '#{cmd}'")
        expect(cmd.stdout.strip).to \
            eq("#{vm_dir}/snap-0.xml\n#{vm_dir}/snap-1.xml")
    end
    def revert(t)
        (0..1).each do |snap_id|
            # revert
            cli_action("onevm snapshot-revert #{@info[:vm_id]} #{snap_id}")
            @info[:vm].state?('RUNNING', /FAIL|^POWEROFF|UNKNOWN/)
            @info[:vm].reachable?

            # check it reverted to expected snapshot
            cmd = @info[:vm].ssh('cat /root/snap')
            cmd.expect_success
            snap_name = "my-snapshot-#{snap_id * (t+1)}"
            expect(cmd.stdout.strip).to eq(snap_name.to_s)
        end
    end

    it 'deploys' do
        @info[:vm].running?
    end

    it 'ssh and context' do
        @info[:vm].reachable?
    end

    it 'get hosts info' do
        # Get Cluster and Host list
        cluster_id = @info[:vm]['HISTORY_RECORDS/HISTORY[last()]/CID']
        current_host = @info[:vm]['HISTORY_RECORDS/HISTORY[last()]/HOSTNAME']

        @info[:target_hosts] = []
        onehost_list = cli_action_xml('onehost list -x')
        onehost_list.each("/HOST_POOL/HOST[CLUSTER_ID='#{cluster_id}']") do |h|
            next if h['NAME'] == current_host

            state = h['STATE'].to_i
            next if state != 1 && state != 2

            @info[:target_hosts] << h['NAME']
        end
        @info[:target_hosts] << current_host
    end

    it 'create 2 VM snapshots' do
        create_snapshots(0)
    end

    it 'live migration' do
        live_migrate
    end

    it 'verify snapshots are present' do
        verify(0)
    end

    it 'reverts snapshots' do
        revert(0)
    end

    it 'delete snapshots' do
        (0..1).each do |snap_id|
            @info[:vm].snapshot_delete(snap_id)
            @info[:vm].running?
        end
    end

    it 'create 2 VM snapshots' do
        create_snapshots(2)
    end

    it 'live migration' do
        live_migrate
    end

    it 'verify snapshots are present' do
        verify(2)
    end

    it 'reverts snapshots' do
        revert(2)
    end

    it 'delete snapshots' do
        (0..1).each do |snap_id|
            @info[:vm].snapshot_delete(snap_id)
            @info[:vm].running?
        end
    end

    ############################################################################
    # Delete VM
    ############################################################################

    it 'terminate vm ' do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?
    end

    it 'datastore contents are unchanged' do
        # image epilog settles...
        sleep 10

        expect(DSDriver.get(@info[:ds_id]).image_list).to eq(@info[:image_list])
    end

    it 'verify lvm cleanup' do
        tm_mad = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/TM_MAD']
        skip 'Only applicable for LVM microenvs' unless ['fs_lvm', 'fs_lvm_ssh'].include?(tm_mad)

        @info[:target_hosts].each do |target_host|
            cmd = "ssh #{target_host} sudo /sbin/dmsetup ls"
            dmsetup_cmd = SafeExec.run(cmd)
            expect(dmsetup_cmd.success?).to be(true)
            expect(dmsetup_cmd.stdout.strip).not_to include('one')
        end
    end
end
