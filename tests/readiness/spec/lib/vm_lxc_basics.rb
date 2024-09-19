require 'init'
require 'tempfile'

module CLITester

    DEFAULT_TIMEOUT = 360

end

# Tests basic VM Operations

# Parameters:
# :template: VM that is tested is instantiated from this template
shared_examples_for 'basic_vm_lxc_tasks' do
    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {}

        # Use the same VM for all the tests in this example
        @info[:vm_id] =
            cli_create("onetemplate instantiate '#{@defaults[:template]}'")
        @info[:vm]    = VM.new(@info[:vm_id])

        @info[:ds_id]     =
            @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DATASTORE_ID']
        @info[:ds_driver] = DSDriver.get(@info[:ds_id])

        # Get image list
        @info[:image_list] = @info[:ds_driver].image_list
    end

    it 'deploys' do
        @info[:vm].running?
    end

    it 'ssh and context' do
        @info[:vm].reachable?
    end

    it 'reboot with network' do
        skip unless @info[:vm].networking?

        @info[:vm].reboot
    end

    it 'reboot --hard with network' do
        skip unless @info[:vm].networking?

        @info[:vm].hard_reboot
    end

    it 'poweroff' do
        @info[:vm].safe_poweroff
    end

    it 'create persistent datablock' do
        @info[:temp_image] = Tempfile.new
        `qemu-img create -f raw #{@info[:temp_image].path} 100M`
        `/sbin/mkfs.ext4 #{@info[:temp_image].path} 2>&1`

        cmd = "oneimage create --name pers-datablock-#{@info[:vm_id]} " \
              "--type datablock --path #{@info[:temp_image].path} " \
              "-d #{@info[:ds_id]} --persistent"

        img_id = cli_create(cmd)

        wait_loop(:success => 'READY', :break => 'ERROR') do
            xml = cli_action_xml("oneimage show -x #{img_id}")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        end

        @info[:img_id] = img_id
        # @info[:prefix] = prefix
    end

    it 'create nonpersistent datablock' do
        cmd = "oneimage create --name nonpers-datablock-#{@info[:vm_id]} " \
              "--type datablock --path #{@info[:temp_image].path} " \
              "-d #{@info[:ds_id]}"

        img_id = cli_create(cmd)

        wait_loop(:success => 'READY', :break => 'ERROR') do
            xml = cli_action_xml("oneimage show -x #{img_id}")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        end

        @info[:nonpers_img_id] = img_id
    end

    it 'attach datablocks' do
        disk_count_before = 0
        @info[:vm].xml.each('TEMPLATE/DISK') { disk_count_before += 1 }

        # persistent datablock
        cli_action("onevm disk-attach #{@info[:vm_id]} --image #{@info[:img_id]}")
        @info[:vm].state?('POWEROFF')

        @info[:target] =
            @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:img_id]}']/TARGET"]

        # ensure
        disk_count = 0
        @info[:vm].xml.each('TEMPLATE/DISK') { disk_count += 1 }

        expect(disk_count - disk_count_before).to eq(1)
    end

    it 'resume' do
        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    # Pausing VMs - Short term

    it 'poweroff' do
        @info[:vm].safe_poweroff

        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it 'poweroff --hard' do
        # @info[:vm].halt
        cli_action("onevm poweroff --hard #{@info[:vm_id]}")
        @info[:vm].state?('POWEROFF')

        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    # Pausing VMs - Long term

    it 'undeploy' do
        @info[:vm].safe_undeploy

        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it 'undeploy --hard' do
        # @info[:vm].halt
        cli_action("onevm undeploy --hard #{@info[:vm_id]}")
        @info[:vm].state?('UNDEPLOYED')

        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    # Other operations

    it 'disk-saveas on poweroff' do
        @info[:vm].poweroff

        disk_snap = "#{@info[:vm]['NAME']}-0-disk-snap1"
        disk_snap_id = cli_create("onevm disk-saveas #{@info[:vm_id]} 0 '#{disk_snap}'")

        wait_loop(:success => 'READY', :break => 'ERROR') do
            xml   = cli_action_xml("oneimage show -x #{disk_snap_id}")
            state = xml['STATE'].to_i

            Image::IMAGE_STATES[state]
        end

        cli_action("oneimage delete #{disk_snap_id}")
        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it 'hot attach and detach nic' do
        skip 'Hotplug not supported for LXC yet'

        # Check number of initial nics
        cmd = 'ls /sys/class/net'
        pre_attach_cmd = @info[:vm].ssh(cmd)
        expect(pre_attach_cmd.success?).to be(true)

        pre_attach_ifaces = pre_attach_cmd.stdout.split("\n").count

        # Attach new nic

        network_id = @info[:vm].xml['TEMPLATE/NIC[1]/NETWORK_ID']
        cli_action("onevm nic-attach #{@info[:vm_id]} --network #{network_id}")
        @info[:vm].running?
        @info[:vm].reachable?

        # Check the new nic appeared
        post_attach_cmd = @info[:vm].ssh(cmd)
        expect(post_attach_cmd.success?).to be(true)

        post_attach_ifaces = post_attach_cmd.stdout.split("\n").count
        expect(post_attach_ifaces - pre_attach_ifaces).to be(1)

        # Detach nic

        last_nic_id = @info[:vm].xml['TEMPLATE/NIC[last()]/NIC_ID']

        cli_action("onevm nic-detach #{@info[:vm_id]} #{last_nic_id}")
        @info[:vm].running?
        @info[:vm].reachable?

        # Check the nic was detached

        post_detach_cmd = @info[:vm].ssh(cmd)
        expect(post_detach_cmd.success?).to be(true)
        post_detach_ifaces = post_detach_cmd.stdout.split("\n").count

        expect(post_detach_ifaces).to eq(pre_attach_ifaces)
    end

    it 'reboot without network' do
        if @info[:vm].networking?
            @info[:vm].nic_ids.each do |nic_id|
                @info[:vm].nic_detach(nic_id)
            end
        end

        @info[:vm].reboot
    end

    it 'reboot hard without network' do
        @info[:vm].hard_reboot
    end

    ############################################################################
    # Shutdown First VM
    ############################################################################

    it 'terminate vm' do
        @info[:vm].terminate_hard
    end

    ############################################################################
    # Launch Second VM
    ############################################################################

    it 'deploy second vm' do
        @info[:vm_id] =
            cli_create("onetemplate instantiate '#{@defaults[:template]}'")
        @info[:vm]    = VM.new(@info[:vm_id])
    end

    it 'deploys' do
        @info[:vm].running?
    end

    it 'ssh and context' do
        @info[:vm].reachable?
    end

    it 'poweroff' do
        @info[:vm].safe_poweroff
    end

    it 'attach persistent datablock' do
        disk_count_before = 0
        @info[:vm].xml.each('TEMPLATE/DISK') { disk_count_before += 1 }

        # persistent datablock
        cli_action("onevm disk-attach #{@info[:vm_id]} --image #{@info[:img_id]}")
        @info[:vm].state?('POWEROFF')

        @info[:target] =
            @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:img_id]}']/TARGET"]

        # ensure
        disk_count = 0
        @info[:vm].xml.each('TEMPLATE/DISK') { disk_count += 1 }

        expect(disk_count - disk_count_before).to eq(1)
    end

    it 'resume' do
        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    ############################################################################
    # Shutdown Second VM
    ############################################################################

    it 'terminate second vm' do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?
    end

    ############################################################################
    # Launch Third VM for hot disk attach/detach
    ############################################################################

    it 'deploy third vm' do
        @info[:vm_id] =
            cli_create("onetemplate instantiate '#{@defaults[:template]}'")
        @info[:vm]    = VM.new(@info[:vm_id])
    end

    it 'deploys' do
        @info[:vm].running?
    end

    it 'ssh and context' do
        @info[:vm].reachable?
    end

    it 'hot attach persistent datablock' do
        skip 'Hotplug not supported for LXC yet'

        disk_count_before = 0
        @info[:vm].xml.each('TEMPLATE/DISK') { disk_count_before += 1 }

        # persistent datablock
        cli_action("onevm disk-attach #{@info[:vm_id]} --image #{@info[:img_id]}")
        @info[:vm].running?

        @info[:target] =
            @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:img_id]}']/TARGET"]

        # ensure disk count check
        disk_count = 0
        @info[:vm].xml.each('TEMPLATE/DISK') { disk_count += 1 }
        expect(disk_count - disk_count_before).to eq(1)
    end

    it 'hot detach persistent datablock' do
        skip 'Hotplug not supported for LXC yet'

        disk_count_before = 0
        @info[:vm].xml.each('TEMPLATE/DISK') { disk_count_before += 1 }

        # detach disk
        disk_id = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:img_id]}']/DISK_ID"]
        cli_action("onevm disk-detach #{@info[:vm_id]} #{disk_id}")
        @info[:vm].running?

        # ensure disk count check
        disk_count = 0
        @info[:vm].xml.each('TEMPLATE/DISK') { disk_count += 1 }
        expect(disk_count - disk_count_before).to eq(-1)
    end

    it 'hot attach and detach nonpersistent datablock' do
        skip 'Hotplug not supported for LXC yet'

        disk_count_before = 0
        @info[:vm].xml.each('TEMPLATE/DISK') { disk_count_before += 1 }

        # attach nonpersistent datablock
        cli_action("onevm disk-attach #{@info[:vm_id]} --image #{@info[:nonpers_img_id]}")
        @info[:vm].running?

        # ensure disk count check
        disk_count = 0
        @info[:vm].xml.each('TEMPLATE/DISK') { disk_count += 1 }
        expect(disk_count - disk_count_before).to eq(1)

        # detach
        disk_id = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:nonpers_img_id]}']/DISK_ID"]
        cli_action("onevm disk-detach #{@info[:vm_id]} #{disk_id}")
        @info[:vm].running?

        # ensure disk count check
        disk_count = 0
        @info[:vm].xml.each('TEMPLATE/DISK') { disk_count += 1 }
        expect(disk_count - disk_count_before).to eq(0)
    end

    ############################################################################
    # Shutdown Third VM and datablocks
    ############################################################################

    it 'terminate third vm and delete datablocks' do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?

        # delete persistent image
        img_id = @info[:img_id]
        cli_action("oneimage delete #{img_id}")

        # wait for image to be deleted
        wait_loop(:success => true) do
            cmd = cli_action("oneimage show #{img_id} 2>/dev/null", nil)
            cmd.fail?
        end

        # delete nonpersistent image
        img_id = @info[:nonpers_img_id]
        cli_action("oneimage delete #{img_id}")

        # wait for image to be deleted
        wait_loop(:success => true) do
            cmd = cli_action("oneimage show #{img_id} 2>/dev/null", nil)
            cmd.fail?
        end
    end

    it 'datastore contents are unchanged' do
        # image epilog settles...
        sleep 10

        expect(DSDriver.get(@info[:ds_id]).image_list).to eq(@info[:image_list])
    end
end
