require 'init'
require 'lib_lxd/xfs'
require 'lib_lxd/containerhost'
require 'lib_lxd/lxc_shift'
require 'lib_lxd/qcow2'
require 'yaml'

RSpec.describe 'LXC Specifics' do
    before(:all) do
        @defaults = RSpec.configuration.defaults
        @info = {}
        @info[:wild] = "ubuntu-#{rand 1000000}"

        @info[:tm_mad] = cli_action_xml('onedatastore show -x 0')['TM_MAD']
    end

    it 'deploys' do
        cmd = "onetemplate instantiate #{@defaults[:template]}"
        @info[:vm] = VM.new(cli_create(cmd))

        @info[:vm].running?

        @info[:net_id] = @info[:vm].vnet_id(0)
        @info[:host]   = @info[:vm].host
    end

    ############################################################################
    # VNC
    ############################################################################

    # TODO: Check only one process is up
    it 'runs svncterm_server' do
        cmd = 'ps -C svncterm_server'

        cmd = SafeExec.run("ssh #{@info[:host]} #{cmd}")
        expect(cmd.success?).to be(true)
    end

    it 'vnc port open' do
        cmd = 'netstat -tpln'
        cmd = SafeExec.run("ssh #{@info[:host]} #{cmd}")

        if cmd.fail?
            cmd = 'ss -atln'
            cmd = SafeExec.run("ssh #{@info[:host]} #{cmd}")
        end

        expect(cmd.success?).to be(true)

        vnc_port = @info[:vm].xml['TEMPLATE/GRAPHICS/PORT']
        expect(cmd.stdout).to include("0.0.0.0:#{vnc_port}")
    end

    it 'terminate vm' do
        @info[:vm].terminate
    end

    ############################################################################
    # Raw section
    ############################################################################

    it 'add changes to raw section' do
        raw = <<-EOT
        RAW = [
            type = "lxc",
            data = "lxc.idmap = random_map
                    lxc.signal.reboot = 9"
        ]
        EOT

        cli_action("onetemplate clone #{@defaults[:template]} #{@defaults[:template]}-raw")
        cli_update("onetemplate update #{@defaults[:template]}-raw", raw, true)

        vm_id = cli_create("onetemplate instantiate #{@defaults[:template]}-raw")

        # Wait for the hook event
        wait_loop do
            xml = cli_action_xml("onevm show #{vm_id} -x")
            OpenNebula::VirtualMachine::LCM_STATE[xml['LCM_STATE'].to_i] == 'RUNNING'
        end

        cmd = "cat /var/lib/one/datastores/0/#{vm_id}/deployment.file"
        cmd = SafeExec.run("ssh #{@info[:host]} #{cmd}")

        expect(cmd.stdout).to match(/lxc.signal.reboot = '9'/)
        expect(cmd.stdout).not_to match(/lxc.idmap = 'random_map'/)

        cli_action("onevm terminate --hard #{vm_id}")
    end

    ############################################################################
    # Profiles
    ############################################################################

    it 'use unexisting profile' do
        # Make sure profile does not exists
        profile_path = '/var/lib/one/remotes/etc/vmm/lxc/profiles/profile-1'
        File.delete(profile_path) if File.exist?(profile_path)
        cli_action('onehost sync -f')

        @info[:profile_tmpl] =
            "#{@defaults[:template]}-profiles-#{rand(36**8).to_s(36)}"
        tmpl = 'LXC_PROFILES = "profile-1"'

        cli_action("onetemplate clone #{@defaults[:template]} #{@info[:profile_tmpl]}")
        cli_update("onetemplate update #{@info[:profile_tmpl]}", tmpl, true)

        vm_id = cli_create("onetemplate instantiate #{@info[:profile_tmpl]}")

        # Wait for the hook event
        wait_loop do
            xml = cli_action_xml("onevm show #{vm_id} -x")
            OpenNebula::VirtualMachine::LCM_STATE[xml['LCM_STATE'].to_i] == 'RUNNING'
        end

        vm = VM.new(vm_id)

        cmd = "grep -q \"profile-1\" /var/lib/one/datastores/0/#{vm_id}/deployment.file"
        cmd = SafeExec.run("ssh #{vm.host} #{cmd}")

        expect(cmd.success?).to eq(false)

        cmd = "grep -q 'Cannot find profile: \"profile-1\".' /var/log/one/#{vm_id}.log"
        cmd = SafeExec.run(cmd)

        expect(cmd.success?).to eq(true)

        vm.terminate_hard
    end

    it 'use existing profile' do
        profiles_path = '/var/lib/one/remotes/etc/vmm/lxc/profiles'
        FileUtils.mkdir_p(profiles_path)

        File.open("#{profiles_path}/profile-1", 'w') do |f|
            f.write("lxc.environment = PROFILE1=true\n")
        end

        cli_action('onehost sync -f')

        vm_id = cli_create("onetemplate instantiate #{@info[:profile_tmpl]}")
        vm = VM.new(vm_id)

        vm.running?

        cmd = "grep -q \"lxc.include = '/var/tmp/one/etc/vmm/lxc/profiles/profile-1'\" /var/lib/one/datastores/0/#{vm_id}/deployment.file"
        cmd = SafeExec.run("ssh #{vm.host} #{cmd}")

        expect(cmd.success?).to eq(true)

        vm.terminate_hard
    end

    ############################################################################
    # Device Mapper (make sure raw mapper is not used)
    ############################################################################

    it 'check DeviceMapper is used' do
        skip 'Only needed for LVM' unless %w[fs_lvm
                                             fs_lvm_ssh].include?(@info[:tm_mad])

        cmd = "onetemplate instantiate #{@defaults[:template]}"
        vm = VM.new(cli_create(cmd))

        vm.running?

        cmd = SafeExec.run("ssh #{vm.host} lsblk")

        ds_id = vm['//HISTORY/DS_ID']
        regex = %r{vg--one--#{ds_id}-lv--one--#{vm.id}--0.*/var/lib/one/datastores/#{ds_id}/#{vm.id}/mapper/disk.0$}

        expect(cmd.stdout).to match(regex)

        vm.terminate_hard
    end

    describe 'qcow2 cache mode LXC' do
        it_behaves_like 'qcow2_cache'
    end

    ############################################################################
    # Mount options
    ############################################################################

    # by default LXC driver should mount xfs devices with nouid option
    describe 'XFS LXC' do
        it_behaves_like 'XFS_LX'
    end

    # bindfs mount options
    it 'bindfs uses suid by default' do
        cmd = "onetemplate instantiate #{@defaults[:template]}"
        vm = VM.new(cli_create(cmd))
        vm.running?

        host = CLITester::Host.new(vm.host_id)
        host = ContainerHost.new_host(host)

        host.container_mounts(vm.name)

        # nosuid is missing if suid is passed to bindfs
        expect(host.mount_has_opt?(vm.name, 0, :bindfs, 'nosuid')).to be(false)

        vm.terminate_hard
    end

    describe 'unprivileged unshifted' do
        it_should_behave_like 'LXC idmap checks', true, false
    end

    describe 'privileged unshifted' do
        it_should_behave_like 'LXC idmap checks', false, false
    end

    describe 'unprivileged shifted' do
        it_should_behave_like 'LXC idmap checks', true, true
    end

    describe 'privileged shifted' do
        it_should_behave_like 'LXC idmap checks', false, true
    end

    # VM Template mount options
    it 'deploy VM with custom template mount options' do
        cmd = "onevm create --cpu 1 --memory 128 \
        --disk 0:readonly=yes,0:target=/mnt:readonly=yes"

        @info[:vm_id] = cli_create(cmd)
        vm = VM.new(@info[:vm_id])
        vm.running?

        host = CLITester::Host.new(vm.host_id)
        host = ContainerHost.new_host(host)
        host.container_mounts(vm.name)

        @info[:host] = host
        @info[:vm] = vm
    end

    [0, 1].each do |disk_id|
        it "disk.#{disk_id} is read only" do
            expect(@info[:host].ro_disk?(@info[:vm].name, disk_id)).to be(true)
        end
    end

    it 'extra disk has custom path inside container' do
        mountpoint = @info[:vm]['TEMPLATE/DISK[DISK_ID="1"]/TARGET']

        expect(@info[:host].path_okay?(@info[:vm].name, 1,
                                       mountpoint)).to be(true)
    end

    it 'terminate VM with custom template mount options' do
        @info[:vm].terminate_hard
    end

    # lxcrc config file
    it 'create custom lxcrc' do
        lxcrc_path = '/var/lib/one/remotes/etc/vmm/lxc/lxcrc'

        # save original config
        FileUtils.cp(lxcrc_path, "#{lxcrc_path}.save")

        # write options to lxcrc
        lxcrc = YAML.load_file(lxcrc_path)

        CUSTOM_OPTS = {
            :disk       => 'rbind',
            # Ubuntu2004:
            # lxc-start one-49 20220628141729.414 ERROR    conf - conf.c:lxc_rootfs_prepare_parent:632 - Operation not supported - Kernel does not support the new mount api
            # :rootfs     => 'idmap=container',
            :ext4        => 'noatime',
            :xfs        => 'discard',
            :bindfs     => 'suid,dev',
            :mountpoint => 'mnt'
        }

        lxcrc[:mountopts][:disk]        = CUSTOM_OPTS[:disk]
        lxcrc[:mountopts][:rootfs]      = CUSTOM_OPTS[:rootfs]
        lxcrc[:mountopts][:dev_xfs]     = CUSTOM_OPTS[:xfs]
        lxcrc[:mountopts][:dev_ext4]    = CUSTOM_OPTS[:ext4]
        lxcrc[:mountopts][:bindfs]      = CUSTOM_OPTS[:bindfs]
        lxcrc[:mountopts][:mountpoint]  = CUSTOM_OPTS[:mountpoint]

        File.open(lxcrc_path, 'w') {|f| f.write lxcrc.to_yaml }

        # sync
        cli_action('onehost sync --force')

        @info[:lxcrc_path] = lxcrc_path
        @info[:lxcrc] = lxcrc
        @info[:lxc_cmopts] = CUSTOM_OPTS
    end

    it 'reads options from lxcrc' do
        # nginx --> ext4 alpine_xfs --> xfs
        cmd = 'onevm create --cpu 1 --memory 128 --disk nginx,alpine_xfs'
        vm = VM.new(cli_create(cmd))
        vm.running?

        @info[:vm] = vm

        host = CLITester::Host.new(vm.host_id)
        host = ContainerHost.new_host(host)

        host.container_mounts(vm.name)

        [0, 1].each do |disk_id|
            expect(host.mount_has_opt?(vm.name, disk_id, :bindfs,
                                       'nodev')).to be(false)
        end

        expect(host.mount_has_opt?(vm.name, 0, :mapper,
                                   @info[:lxc_cmopts][:ext4])).to be(true)
        expect(host.mount_has_opt?(vm.name, 1, :mapper,
                                   @info[:lxc_cmopts][:xfs])).to be(true)
        expect(host.path_okay?(vm.name, 1,
                               "/#{@info[:lxc_cmopts][:mountpoint]}")).to be(true)

        cconf = host.container_conf(vm.name)

        expected_conf = []
        # expected_conf << "lxc.rootfs.options = '#{@info[:lxc_cmopts][:rootfs]}'"
        expected_conf << "lxc.mount.entry = '/var/lib/lxc-one/#{vm.id}/disk.1 #{@info[:lxc_cmopts][:mountpoint]} none #{@info[:lxc_cmopts][:disk]} 0 0'"

        expected_conf.each do |expected_entry|
            expect(cconf.include?(expected_entry)).to be(true)
        end
    end

    it 'delete vm with custom config' do
        @info[:vm].terminate_hard
    end

    it 'restore config file' do
        # restore config
        FileUtils.cp("#{@info[:lxcrc_path]}.save", @info[:lxcrc_path])

        # sync
        cli_action('onehost sync --force')
    end

    describe 'qcow2 cache mode LXC' do
        it_behaves_like 'qcow2_cache'
    end

    ############################################################################
    # Pinning
    ############################################################################

    it 'set host 0 to PINNED' do
        host = Host.new(0)
        host.pin
    end

    it 'creates pinned CPU templates' do
        @info[:cpu] =
            cli_create("onetemplate clone #{@defaults[:template]} cpu")

        ['TOPOLOGY=[PIN_POLICY="thread"]', 'VCPU=1'].each do |t|
            cli_update("onetemplate update #{@info[:cpu]}", t, true)
        end
    end

    # TODO: Compare NUMA_NODE VM Template vs lxc conf file
    it 'deploys 1 pinned CPU container' do
        deploy(@info[:cpu])
        @info[:vm].terminate_hard
    end

    it 'deletes CPU Pinning templates' do
        cli_action("onetemplate delete #{@info[:cpu]}")
    end

    it 'set host 0 to NONE' do
        host = Host.new(0)
        host.unpin
    end

    # TODO: Move to lib. cli_create fails on CLITester:VM
    def deploy(template)
        cmd = "onetemplate instantiate #{template}"

        @info[:vm] = VM.new(cli_create(cmd))
        @info[:vm].running?
    end

    ############################################################################
    # Wild container
    ############################################################################

    #     it 'creates wild container' do
    #         cmd = "lxc-create -t download -n #{@info[:wild]} -- -d ubuntu -r bionic -a amd64"
    #
    #         cmd = SafeExec.run("ssh #{@info[:host]} #{cmd}")
    #         expect(cmd.success?).to be(true)
    #
    #         # force wild VM probe execution
    #         cli_action("onehost forceupdate #{@info[:vm].host_id}")
    #     end
    #
    #     it 'imports wild container' do
    #         cmd = "onehost show #{@info[:vm].host_id} -x"
    #         wild = "<WILDS><![CDATA[#{@info[:wild]}]]></WILDS>"
    #
    #         wait_loop({ :timeout => 15 }) do
    #             cli_action(cmd).stdout.include?(wild)
    #         end
    #
    #         cmd = "onehost importvm #{@info[:vm].host_id} #{@info[:wild]}"
    #         cli_action(cmd)
    #         @info[:vm] = VM.new(@info[:vm].id + 1)
    #
    #         @info[:vm].running?
    #     end
    #
    #     it 'poweroff wild container' do
    #         @info[:vm].poweroff
    #         @info[:vm].resume
    #     end
    #
    #     it 'poweroff --hard wild container' do
    #         @info[:vm].poweroff_hard
    #     end
    #
    #     it 'resume with attached nic' do
    #         @info[:vm].nic_attach(@info[:net_id])
    #
    #         @info[:vm].resume
    #         @info[:vm].poweroff
    #
    #         @info[:vm].nic_detach(0)
    #     end
    #
    #     it 'nic hotplug' do
    #         @info[:vm].resume
    #
    #         @info[:vm].nic_attach(@info[:net_id])
    #         @info[:vm].nic_detach(0)
    #     end
    #
    #     it 'deletes wild container' do
    #         @info[:vm].terminate_hard
    #
    #         cmd = "lxc delete #{@info[:wild]} -f"
    #         cmd = @info[:host].lxc(cmd)
    #
    #         expect(cmd.success?).to be(true)
    #     end
end
