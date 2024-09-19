require 'init'

# Compare 2 images lists, return true if
#  - are same
#  - b-list only contents entries from a-list
#    or with extra suffix (.md5sum)
def img_list_diff(a, b, b_extra_suffix='.md5sum')
    return true if a == b

    return a - b if ( a - b ).length > 0

    ( b - a ).each do |extra_b|
        # different suffix
        return extra_b unless extra_b.end_with? b_extra_suffix

        # missing matching entry in a-list
        return extra_b unless a.include? extra_b.chomp(b_extra_suffix)
    end

    true
end

shared_examples_for 'basic_vm_tasks' do |persistent|

    before(:all) do
        @defaults = RSpec.configuration.defaults

        # switch to persistent if required
        orig_tmpl_id = cli_action_xml("onetemplate show -x '#{@defaults[:template]}'")['ID']

        if persistent
            cloned_tmpl_name = "#{@defaults[:template]}-basics-vm-pers-cloned"

            if cli_action("onetemplate show '#{cloned_tmpl_name}' >/dev/null", nil).fail?
                cloned_tmpl_id = cli_create("onetemplate clone --recursive " \
                                            "#{orig_tmpl_id} '#{cloned_tmpl_name}'")
                wait_image_ready(300, "#{cloned_tmpl_name}-disk-0")
                cli_action("oneimage persistent #{cloned_tmpl_name}-disk-0")
            else
                cloned_tmpl_id = cli_action_xml(
                    "onetemplate show -x '#{cloned_tmpl_name}'")['ID']
            end

            @tmpl_id = cloned_tmpl_id
        else
            @tmpl_id =  orig_tmpl_id
        end

        img_id = cli_action_xml("onetemplate show -x '#{@tmpl_id}'")['TEMPLATE/DISK/IMAGE']
        img_name = cli_action_xml("onetemplate show -x '#{@tmpl_id}'")['TEMPLATE/DISK/IMAGE_ID']
        # Used to pass info accross tests
        @info = {}

        @info[:os_img] = img_id || img_name

        # Deploy first VM, keep it on hold to save initial image list untouched
        @info[:vm_id] = cli_create("onetemplate instantiate #{@tmpl_id} --hold")
        @info[:vm]    = VM.new(@info[:vm_id])

        @info[:ds_id]     = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DATASTORE_ID']
        @info[:ds_driver] = DSDriver.get(@info[:ds_id])

        # Get the initial image list
        @info[:image_list] = @info[:ds_driver].image_list

        # Wait until image is downloaded VM goes CLONE -> LOCK
        # Increase the timeout as cloning the image may take some more time
        # if not in ready
        @info[:vm].state?('HOLD', :timeout => 360)

        # Relase the VM
        cli_action("onevm release #{@info[:vm_id]}")
    end

    it "deploys" do
        @info[:vm].running?
    end

    it "ssh and context" do
        @info[:vm].reachable?
    end

    it "uuid equals deploy_id" do
        xml = @info[:vm].xml

        uuid = xml['TEMPLATE/OS/UUID']

        expect(xml['DEPLOY_ID']).to eq(uuid)
    end

    it "poweroff" do
        @info[:vm].safe_poweroff
    end

    it 'onevm SSH should fail' do
        cli_action("onevm ssh --ssh-options '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null' #{@info[:vm_id]}", false)
    end

    it "create persistent datablock" do
        @info[:ds_id] = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DATASTORE_ID']
        prefix = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DEV_PREFIX']

        if (driver = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DRIVER'])
            @info[:datablock_opts] = "--format #{driver}"
        else
            @info[:datablock_opts] = ""
        end

        cmd = "oneimage create --name pers-datablock-#{@info[:vm_id]} " <<
                "--size 1 --type datablock " <<
                "-d #{@info[:ds_id]} #{@info[:datablock_opts]} --prefix #{prefix} " <<
                "--persistent"

        img_id = cli_create(cmd)

        wait_loop(:success => "READY", :break => "ERROR") {
            xml = cli_action_xml("oneimage show -x #{img_id}")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        }

        @info[:img_id] = img_id
        @info[:prefix] = prefix
    end

    it "create nonpersistent datablock" do
        cmd = "oneimage create --name nonpers-datablock-#{@info[:vm_id]} " <<
                "--size 1 --type datablock " <<
                "-d #{@info[:ds_id]} #{@info[:datablock_opts]} --prefix #{@info[:prefix]} "

        img_id = cli_create(cmd)

        wait_loop(:success => "READY", :break => "ERROR") {
            xml = cli_action_xml("oneimage show -x #{img_id}")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        }

        @info[:nonpers_img_id] = img_id
    end

    it "attach volatile and swap and persistent image" do
        prefix = @info[:prefix]

        disk_count_before = 0
        @info[:vm].xml.each("TEMPLATE/DISK"){ disk_count_before+=1 }

        # volatile

        disk_volatile_template = TemplateParser.template_like_str({:disk => {:size => 1, :type => "fs", :dev_prefix => prefix, :driver => "raw"}})

        disk_volatile = Tempfile.new('disk_volatile')
        disk_volatile.write(disk_volatile_template)
        disk_volatile.close

        cli_action("onevm disk-attach #{@info[:vm_id]} --file #{disk_volatile.path}")
        @info[:vm].state?("POWEROFF")

        disk_volatile.unlink

        # swap

        disk_swap_template = TemplateParser.template_like_str({:disk => {:size => 1, :type => "swap", :dev_prefix => prefix, :driver => "raw"}})

        disk_swap = Tempfile.new('disk_swap')
        disk_swap.write(disk_swap_template)
        disk_swap.close

        cli_action("onevm disk-attach #{@info[:vm_id]} --file #{disk_swap.path}")
        @info[:vm].state?("POWEROFF")

        disk_swap.unlink

        # persistent datablock
        cli_action("onevm disk-attach #{@info[:vm_id]} --image #{@info[:img_id]}")
        @info[:vm].state?("POWEROFF")

        @info[:target] = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:img_id]}']/TARGET"]

        # ensure

        disk_count = 0
        @info[:vm].xml.each("TEMPLATE/DISK"){ disk_count+=1 }

        expect(disk_count - disk_count_before).to eq(3)
    end

    it "resume" do
        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it 'onevm SSH should work' do
        touch_file = "/tmp/onevm_ssh_#{rand(36**8).to_s(36)}"
        cli_action("onevm ssh --ssh-options '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null' #{@info[:vm_id]} --cmd 'touch #{touch_file}'")
        expect(@info[:vm].ssh("cat #{touch_file}").success?).to be(true)
    end

    # Pausing VMs - Short term

    it "suspend" do
        cli_action("onevm suspend #{@info[:vm_id]}")
        @info[:vm].state?("SUSPENDED")

        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it "poweroff" do
        @info[:vm].safe_poweroff

        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it "poweroff --hard" do
        @info[:vm].halt
        cli_action("onevm poweroff --hard #{@info[:vm_id]}")
        @info[:vm].state?("POWEROFF")

        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    # Pausing VMs - Long term

    it "stop" do
        cli_action("onevm stop #{@info[:vm_id]}")
        @info[:vm].state?("STOPPED")

        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it "undeploy" do
        @info[:vm].safe_undeploy

        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it "undeploy --hard" do
        @info[:vm].halt
        cli_action("onevm undeploy --hard #{@info[:vm_id]}")
        @info[:vm].state?("UNDEPLOYED")

        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    # Other operations

    it "disk-saveas" do
        @info[:vm].running?

        # write to persistent image
        wait_loop do
            @info[:vm].ssh("echo PERSISTENT_IMAGE_CHECK_1 > /dev/#{@info[:target]}; sync")
            @info[:vm].ssh("head -n1 /dev/#{@info[:target]}").stdout.strip == "PERSISTENT_IMAGE_CHECK_1"
        end

        # Make sure disk are writtent before saveas
        host = Host.new(@info[:vm].host_id)
        rc = host.ssh('sync', true, { :timeout => 10 }, @defaults[:oneadmin])
        puts "Error in host sync: #{rc.stdout}\n#{rc.stderr}" unless rc.success?

        disk_snap = "#{@info[:vm]['NAME']}-4-disk-snap1"

        disk_snap_id = cli_create("onevm disk-saveas #{@info[:vm_id]} 4 '#{disk_snap}'")
        @info[:snaps] = [1]

        wait_loop(:success => "READY", :break => "ERROR") {
            xml   = cli_action_xml("oneimage show -x #{disk_snap_id}")
            state = xml['STATE'].to_i

            Image::IMAGE_STATES[state]
        }
    end

    it "disk-saveas on poweroff" do
        @info[:vm].running?

        # write to persistent image
        wait_loop do
            @info[:vm].ssh("echo PERSISTENT_IMAGE_CHECK_2 > /dev/#{@info[:target]}; sync")
            @info[:vm].ssh("head -n1 /dev/#{@info[:target]}").stdout.strip == "PERSISTENT_IMAGE_CHECK_2"
        end

        # Make sure disk are writtent before saveas
        host = Host.new(@info[:vm].host_id)
        rc = host.ssh('sync', true, { :timeout => 10 }, @defaults[:oneadmin])
        puts "Error in host sync: #{rc.stdout}\n#{rc.stderr}" unless rc.success?

        @info[:vm].safe_poweroff
        @info[:vm].state?("POWEROFF")

        disk_snap = "#{@info[:vm]['NAME']}-4-disk-snap2"
        disk_snap_id = cli_create("onevm disk-saveas #{@info[:vm_id]} 4 '#{disk_snap}'")
        @info[:snaps] << 2

        wait_loop(:success => "READY", :break => "ERROR") {
            xml   = cli_action_xml("oneimage show -x #{disk_snap_id}")
            state = xml['STATE'].to_i

            Image::IMAGE_STATES[state]
        }

        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
        @info[:vm].wait_context
    end

    it "disk-saveas on stopped" do
        skip "Skipping disk-saveas on FE" if @defaults[:skip_disk_save_as_on_fe]

        @info[:vm].running?

        # write to persistent image
        wait_loop do
            @info[:vm].ssh("echo PERSISTENT_IMAGE_CHECK_3 > /dev/#{@info[:target]}; sync")
            @info[:vm].ssh("head -n1 /dev/#{@info[:target]}").stdout.strip == "PERSISTENT_IMAGE_CHECK_3"
        end

        # Make sure disk are writtent before saveas
        host = Host.new(@info[:vm].host_id)
        rc = host.ssh('sync', true, { :timeout => 10 }, @defaults[:oneadmin])
        puts "Error host sync: #{rc.stdout}\n#{rc.stderr}" unless rc.success?

        cli_action("onevm stop #{@info[:vm_id]}")
        @info[:vm].state?("STOPPED")

        disk_snap = "#{@info[:vm]['NAME']}-4-disk-snap3"
        disk_snap_id = cli_create("onevm disk-saveas #{@info[:vm_id]} 4 '#{disk_snap}'")
        @info[:snaps] << 3

        wait_loop(:success => "READY", :break => "ERROR") {
            xml   = cli_action_xml("oneimage show -x #{disk_snap_id}")
            state = xml['STATE'].to_i

            Image::IMAGE_STATES[state]
        }

        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
        @info[:vm].wait_context
    end

    it "disk-saveas on undeploy" do
        skip "Skipping disk-saveas on FE" if @defaults[:skip_disk_save_as_on_fe]

        @info[:vm].running?

        # write to persistent image
        wait_loop do
            @info[:vm].ssh("echo PERSISTENT_IMAGE_CHECK_4 > /dev/#{@info[:target]}; sync")
            @info[:vm].ssh("head -n1 /dev/#{@info[:target]}").stdout.strip == "PERSISTENT_IMAGE_CHECK_4"
        end

        # Make sure disk are writtent before saveas
        host = Host.new(@info[:vm].host_id)
        rc = host.ssh('sync', true, { :timeout => 10 }, @defaults[:oneadmin])
        puts "Error in host sync: #{rc.stdout}\n#{rc.stderr}" unless rc.success?

        @info[:vm].safe_undeploy
        @info[:vm].state?("UNDEPLOYED")

        disk_snap = "#{@info[:vm]['NAME']}-4-disk-snap4"

        system('sync') # needed for kvm-lvm

        disk_snap_id = cli_create("onevm disk-saveas #{@info[:vm_id]} 4 '#{disk_snap}'")
        @info[:snaps] << 4

        wait_loop(:success => "READY", :break => "ERROR") {
            xml   = cli_action_xml("oneimage show -x #{disk_snap_id}")
            state = xml['STATE'].to_i

            Image::IMAGE_STATES[state]
        }

        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
        @info[:vm].wait_context
    end

    it "verify saved images" do
        # persistent datablock
        @info[:snaps].each do |img_num|
            img_name = "#{@info[:vm]['NAME']}-4-disk-snap#{img_num}"

            cli_action("onevm disk-attach #{@info[:vm_id]} --image '#{img_name}'")
            @info[:vm].state?("RUNNING")

            target = @info[:vm].xml["TEMPLATE/DISK[IMAGE='#{img_name}']/TARGET"]

            # ensure
            cmd = @info[:vm].ssh("head -n1 /dev/#{target}")
            expect(cmd.stdout.strip).to eq("PERSISTENT_IMAGE_CHECK_#{img_num}")
        end

        # delete the images
        @info[:snaps].each do |img_num|
            img_name = "#{@info[:vm]['NAME']}-4-disk-snap#{img_num}"
            disk_id = @info[:vm].xml["TEMPLATE/DISK[IMAGE='#{img_name}']/DISK_ID"]

            cli_action("onevm disk-detach #{@info[:vm_id]} #{disk_id}")
            @info[:vm].state?("RUNNING")

            cli_action("oneimage delete '#{img_name}'")
        end
    end

    it "attach nic" do
        # Check number of initial nics
        @info[:vm].reachable?
        pre_attach_cmd = @info[:vm].ssh('ls /sys/class/net', true)
        expect(pre_attach_cmd.success?).to be(true)
        @info[:pre_attach_ifaces] = pre_attach_cmd.stdout.split("\n").count
        @info[:pre_attach_nics] = @info[:vm].nic_ids.count

        # Attach new nic
        network_id = @info[:vm].xml['TEMPLATE/NIC[1]/NETWORK_ID']
        cli_action("onevm nic-attach #{@info[:vm_id]} --network #{network_id}")
        @info[:vm].running?
        @info[:vm].wait_context
    end

    it "nic appeared" do
        post_attach_cmd = @info[:vm].ssh('ls /sys/class/net', true)
        expect(post_attach_cmd.success?).to be(true)

        @info[:post_attach_ifaces] = post_attach_cmd.stdout.split("\n").count
        expect(@info[:post_attach_ifaces] - @info[:pre_attach_ifaces]).to eq(1)

        @info[:vm].info
        expect(@info[:vm].nic_ids.count - @info[:pre_attach_nics]).to eq(1)

        @info[:nic_attach_success] = true
    end

    it "detach nic" do
        skip "nic attach failed" unless @info[:nic_attach_success]

        last_nic_id = @info[:vm].xml['TEMPLATE/NIC[last()]/NIC_ID']
        cli_action("onevm nic-detach #{@info[:vm_id]} #{last_nic_id}")
        @info[:vm].running?
        @info[:vm].wait_context
    end

    it "nic disappeared" do
        skip "nic attach failed" unless @info[:nic_attach_success]

        post_detach_cmd = @info[:vm].ssh('ls /sys/class/net')

        expect(post_detach_cmd.success?).to be(true)
        post_detach_ifaces = post_detach_cmd.stdout.split("\n").count

        expect(post_detach_ifaces).to eq(@info[:pre_attach_ifaces])
    end

    it "write to persistent image" do
        @info[:vm].ssh("echo PERSISTENT_IMAGE_CHECK > /dev/#{@info[:target]}; sync")
    end

    it "update uuid" do
        cli_action("onevm poweroff #{@info[:vm_id]}")
        @info[:vm].stopped?

        uuid = "4f48c790-4bf5-419f-8641-5393ef2f0cc1"

        cli_update("onevm updateconf #{@info[:vm_id]}",
            "OS=[UUID=\"#{uuid}\"]",
            false)

        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?

        xml = @info[:vm].xml

        expect(xml['DEPLOY_ID']).to eq(uuid)
    end

    ############################################################################
    # Shutdown First VM
    ############################################################################

    it "terminate vm" do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?
    end

    ############################################################################
    # Launch Second VM
    ############################################################################

    it "deploy second vm" do
        @info[:vm_id] = cli_create("onetemplate instantiate #{@tmpl_id}")
        @info[:vm]    = VM.new(@info[:vm_id])
    end

    it "deploys" do
        @info[:vm].running?
    end

    it "ssh and context" do
        @info[:vm].reachable?
    end

    it "poweroff" do
        @info[:vm].safe_poweroff
    end

    it "attach persistent datablock" do
        disk_count_before = 0
        @info[:vm].xml.each("TEMPLATE/DISK"){ disk_count_before+=1 }

        # persistent datablock
        cli_action("onevm disk-attach #{@info[:vm_id]} --image #{@info[:img_id]}")
        @info[:vm].state?("POWEROFF")

        @info[:target] = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:img_id]}']/TARGET"]

        # ensure
        disk_count = 0
        @info[:vm].xml.each("TEMPLATE/DISK"){ disk_count+=1 }

        expect(disk_count - disk_count_before).to eq(1)
    end

    it "resume" do
        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it "verify persistent datablock" do
        cmd = @info[:vm].ssh("head -n1 /dev/#{@info[:target]}")
        expect(cmd.stdout.strip).to eq("PERSISTENT_IMAGE_CHECK")
    end

    ############################################################################
    # Shutdown Second VM
    ############################################################################

    it "terminate second vm" do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?
    end

    ############################################################################
    # Launch Third VM for hot disk attach/detach
    ############################################################################

    it "deploy third vm" do
        @info[:vm_id] = cli_create("onetemplate instantiate #{@tmpl_id}")
        @info[:vm]    = VM.new(@info[:vm_id])
    end

    it "deploys" do
        @info[:vm].running?
    end

    it "ssh and context" do
        @info[:vm].reachable?
    end

    it "hot attach persistent datablock" do
        disk_count_before = 0
        @info[:vm].xml.each("TEMPLATE/DISK"){ disk_count_before+=1 }

        # persistent datablock
        cli_action("onevm disk-attach #{@info[:vm_id]} --image #{@info[:img_id]}")
        @info[:vm].running?

        @info[:target] = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:img_id]}']/TARGET"]

        # ensure disk count check
        disk_count = 0
        @info[:vm].xml.each("TEMPLATE/DISK"){ disk_count+=1 }
        expect(disk_count - disk_count_before).to eq(1)
    end

    it "verify persistent datablock" do
        cmd = @info[:vm].ssh("head -n1 /dev/#{@info[:target]}")
        expect(cmd.stdout.strip).to eq("PERSISTENT_IMAGE_CHECK")
    end

    it "hot detach persistent datablock" do
        disk_count_before = 0
        @info[:vm].xml.each("TEMPLATE/DISK"){ disk_count_before+=1 }

        # detach disk
        disk_id = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:img_id]}']/DISK_ID"]
        cli_action("onevm disk-detach #{@info[:vm_id]} #{disk_id}")
        @info[:vm].running?

        # ensure disk count check
        disk_count = 0
        @info[:vm].xml.each("TEMPLATE/DISK"){ disk_count+=1 }
        expect(disk_count - disk_count_before).to eq(-1)
    end

    it "hot attach and detach nonpersistent datablock" do
        disk_count_before = 0
        @info[:vm].xml.each("TEMPLATE/DISK"){ disk_count_before+=1 }

        # attach nonpersistent datablock
        cli_action("onevm disk-attach #{@info[:vm_id]} --image #{@info[:nonpers_img_id]}")
        @info[:vm].running?

        # ensure disk count check
        disk_count = 0
        @info[:vm].xml.each("TEMPLATE/DISK"){ disk_count+=1 }
        expect(disk_count - disk_count_before).to eq(1)

        # check if disk appeared
        target = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:nonpers_img_id]}']/TARGET"]
        wait_loop do
            @info[:vm].ssh("test -b /dev/#{target}").success?
        end

        # detach
        disk_id = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:nonpers_img_id]}']/DISK_ID"]
        cli_action("onevm disk-detach #{@info[:vm_id]} #{disk_id}")
        @info[:vm].running?

        # ensure disk count check
        disk_count = 0
        @info[:vm].xml.each("TEMPLATE/DISK"){ disk_count+=1 }
        expect(disk_count - disk_count_before).to eq(0)
    end

    it "hot attach and detach volatile datablock" do
        disk_count_before = 0
        @info[:vm].xml.each("TEMPLATE/DISK"){ disk_count_before+=1 }

        # attach volatile
        disk_volatile_template = TemplateParser.template_like_str({:disk => {:size => 1, :type => "fs", :dev_prefix => @info[:prefix], :driver => "raw"}})
        disk_volatile = Tempfile.new('disk_volatile')
        disk_volatile.write(disk_volatile_template)
        disk_volatile.close

        cli_action("onevm disk-attach #{@info[:vm_id]} --file #{disk_volatile.path}")
        @info[:vm].running?
        disk_volatile.unlink

        # ensure disk count check
        disk_count = 0
        @info[:vm].xml.each("TEMPLATE/DISK"){ disk_count+=1 }
        expect(disk_count - disk_count_before).to eq(1)

        # check if disk appeared
        target = @info[:vm].xml['TEMPLATE/DISK[last()]/TARGET']
        wait_loop do
            @info[:vm].ssh("test -b /dev/#{target}").success?
        end

        # detach
        disk_id = @info[:vm].xml['TEMPLATE/DISK[last()]/DISK_ID']
        cli_action("onevm disk-detach #{@info[:vm_id]} #{disk_id}")
        @info[:vm].running?

        # ensure disk count check
        disk_count = 0
        @info[:vm].xml.each("TEMPLATE/DISK"){ disk_count+=1 }
        expect(disk_count - disk_count_before).to eq(0)
    end

    ############################################################################
    # Shutdown Third VM and datablocks
    ############################################################################

    it "terminate third vm and delete nonpersistent datablock" do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?

        # delete nonpersistent image
        img_id = @info[:nonpers_img_id]
        cli_action("oneimage delete #{img_id}")

        # wait for image to be deleted
        wait_loop(:success => true) {
            cmd = cli_action("oneimage show #{img_id} 2>/dev/null", nil)
            cmd.fail?
        }
    end

    it "datastore contents are unchanged" do
        # image epilog settles...
        sleep 10

        expect(img_list_diff(DSDriver.get(@info[:ds_id]).image_list.split("\n"),
                             @info[:image_list].split("\n"))).to be_truthy
    end

    ############################################################################
    # Deploy VM for terminate on UNDEPLOY
    ############################################################################

    it "deploy vm" do
        @info[:vm_id] = cli_create("onetemplate instantiate #{@tmpl_id}")
        @info[:vm]    = VM.new(@info[:vm_id])
    end

    it "deploys" do
        @info[:vm].running?
    end

    it "ssh and context" do
        @info[:vm].reachable?
    end

    it "undeploy --hard" do
        @info[:vm].halt
        cli_action("onevm undeploy --hard #{@info[:vm_id]}")
        @info[:vm].state?("UNDEPLOYED")
    end

    it "terminate vm" do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?
    end

    ############################################################################
    # Deploy VM for terminate on UNDEPLOY + Persistent
    ############################################################################

    it "deploy vm" do
        skip "Skipping disk-saveas on FE" if @defaults[:skip_disk_save_as_on_fe]

        @info[:vm_id] = cli_create("onetemplate instantiate #{@tmpl_id} \
                                   --disk #{@info[:os_img]},#{@info[:img_id]}")
        @info[:vm]    = VM.new(@info[:vm_id])

        @info[:target] = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:img_id]}']/TARGET"]
    end

    it "deploys" do
        skip "Skipping disk-saveas on FE" if @defaults[:skip_disk_save_as_on_fe]

        @info[:vm].running?
    end

    it "ssh and context" do
        skip "Skipping disk-saveas on FE" if @defaults[:skip_disk_save_as_on_fe]

        @info[:vm].reachable?
    end

    it "write to persistent image" do
        skip "Skipping disk-saveas on FE" if @defaults[:skip_disk_save_as_on_fe]

        @info[:vm].ssh("echo PERSISTENT_IMAGE_CHECK_UNDEPLOY > /dev/#{@info[:target]}; sync")
    end

    it "undeploy --hard" do
        skip "Skipping disk-saveas on FE" if @defaults[:skip_disk_save_as_on_fe]

        @info[:vm].halt
        cli_action("onevm undeploy --hard #{@info[:vm_id]}")
        @info[:vm].state?("UNDEPLOYED")
    end

    it "terminate vm" do
        skip "Skipping disk-saveas on FE" if @defaults[:skip_disk_save_as_on_fe]

        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?
    end

    it "deploy new vm" do
        skip "Skipping disk-saveas on FE" if @defaults[:skip_disk_save_as_on_fe]

        @info[:vm_id] = cli_create("onetemplate instantiate #{@tmpl_id} \
                                   --disk #{@info[:os_img]},#{@info[:img_id]}")
        @info[:vm]    = VM.new(@info[:vm_id])
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it "verify persistent datablock" do
        skip "Skipping disk-saveas on FE" if @defaults[:skip_disk_save_as_on_fe]

        cmd = @info[:vm].ssh("head -n1 /dev/#{@info[:target]}")
        expect(cmd.stdout.strip).to eq("PERSISTENT_IMAGE_CHECK_UNDEPLOY")
    end

    it "terminate vm" do
        skip "Skipping disk-saveas on FE" if @defaults[:skip_disk_save_as_on_fe]

        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?
    end

    ############################################################################
    # Deploy  VM for terminate on STOPPED
    ############################################################################

    it "deploy vm" do
        @info[:vm_id] = cli_create("onetemplate instantiate #{@tmpl_id}")
        @info[:vm]    = VM.new(@info[:vm_id])
    end

    it "deploys" do
        @info[:vm].running?
    end

    it "ssh and context" do
        @info[:vm].reachable?
    end

    it "stop" do
        cli_action("onevm stop #{@info[:vm_id]}")
        @info[:vm].state?("STOPPED")

        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it "terminate vm" do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?
    end

    ############################################################################
    # Deploy VM for terminate on STOPPED+Persistent
    ############################################################################

    it "deploy vm" do
        @info[:vm_id] = cli_create("onetemplate instantiate #{@tmpl_id} --disk #{@info[:os_img]},#{@info[:img_id]}")
        @info[:vm]    = VM.new(@info[:vm_id])

        @info[:target] = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:img_id]}']/TARGET"]
    end

    it "deploys" do
        @info[:vm].running?
    end

    it "ssh and context" do
        @info[:vm].reachable?
    end

    it "write to persistent image" do
        @info[:vm].ssh("echo PERSISTENT_IMAGE_CHECK_STOPPED > /dev/#{@info[:target]}; sync")
    end

    it "stop" do
        cli_action("onevm stop #{@info[:vm_id]}")
        @info[:vm].state?("STOPPED")

        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it "terminate vm" do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?
    end

    it "deploy new vm" do
        @info[:vm_id] = cli_create("onetemplate instantiate #{@tmpl_id} --disk #{@info[:os_img]},#{@info[:img_id]}")
        @info[:vm]    = VM.new(@info[:vm_id])
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it "verify persistent datablock" do
        cmd = @info[:vm].ssh("head -n1 /dev/#{@info[:target]}")
        expect(cmd.stdout.strip).to eq("PERSISTENT_IMAGE_CHECK_STOPPED")
    end

    it "terminate vm" do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?
    end

    ############################################################################
    # Create CDROM add it to cloned template, test in VM
    ############################################################################

    it 'Creates testing CD iso' do
        next if system('oneimage show test-cd > /dev/null 2>&1')

        Dir.mkdir('/var/tmp/test-cd') unless File.directory?('/var/tmp/test-cd')
        File.write('/var/tmp/test-cd/yolo.txt', 'yolo')

        if system('which mkisofs >/dev/null 2>&1')
            cmd = 'mkisofs -r /var/tmp/test-cd/ > /var/tmp/test-cd.iso'
        elsif system('which genisoimage >/dev/null 2>&1')
            cmd = 'genisoimage -o /var/tmp/test-cd.iso /var/tmp/test-cd/'
        else
            fail 'Missing mkisofs/genisoimage'
        end

        SafeExec.run(cmd).expect_success

        cli_create('oneimage create --type CDROM ' <<
                   '    --path /var/tmp/test-cd.iso ' <<
                   '    --name test-cd -d 1 --prefix hd')
    end

    it 'Clones default template' do
        next if system("onetemplate show '#{@defaults[:template]}-cd' >/dev/null 2>&1")

        # As `onetemplate update --append 'DISK=[]' always overwrites existing do this
        templ = SafeExec.run("onetemplate show '#{@defaults[:template]}'").stdout
        templ.gsub!(/.*TEMPLATE CONTENTS *\n/m, '')

        expect(templ).not_to be_empty

        templ += "DISK = [ IMAGE = test-cd ]\n"
        templ += "NAME = \"#{@defaults[:template]}-cd\"\n"

        cli_create('onetemplate create', templ)
    end

    it 'Deploy VM with additional CD' do
        @info[:vm_id] = cli_create("onetemplate instantiate \"#{@defaults[:template]}-cd\"")
        @info[:vm]    = VM.new(@info[:vm_id])
    end

    it 'Running' do
        @info[:vm].running?
    end

    it 'ssh and context' do
        @info[:vm].reachable?
    end

    it 'VM has 2 CDROMs' do
        cmd = @info[:vm].ssh('lsblk | grep sr | wc -l')
        expect(cmd.stdout.strip).to eq('2')
    end

    it 'Mount and verify CDROM content' do
        @info[:vm].ssh('mkdir /mnt/cdrom')
        @info[:vm].ssh('mount /dev/sr0 /mnt/cdrom')
        cmd = @info[:vm].ssh('cat /mnt/cdrom/yolo.txt')
        expect(cmd.stdout.strip).to eq('yolo')
    end

    it 'Terminates' do
        @info[:vm].terminate_hard
    end

    ############################################################################
    # Delete datablocks
    ############################################################################

    it "remove persisten datablock" do
        # delete persistent image
        img_id = @info[:img_id]
        cli_action("oneimage delete #{img_id}")

        # wait for image to be deleted
        wait_loop(:success => true) {
            cmd = cli_action("oneimage show #{img_id} 2>/dev/null", nil)
            cmd.fail?
        }
    end

end
