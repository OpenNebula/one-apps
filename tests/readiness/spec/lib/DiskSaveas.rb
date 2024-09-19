shared_examples_for "DiskSaveas" do |livesnap|
    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {}

        # Use the same VM for all the tests in this example
        @info[:vm_id] = cli_create("onetemplate instantiate --hold '#{@defaults[:template]}'")
        @info[:vm]    = VM.new(@info[:vm_id])

        @info[:ds_id]  = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DATASTORE_ID']
        @info[:prefix] = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DEV_PREFIX']

        if (driver = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DRIVER'])
            @info[:datablock_opts] = "--format #{driver}"
        else
            @info[:datablock_opts] = ""
        end

        # TODO: have proper datastore content wait/change in MP tests
        # image epilog settles...
        sleep 10

        # Get image list
        @info[:image_list] = DSDriver.get(@info[:ds_id]).image_list
    end

    it "deploys" do
        cli_action("onevm release #{@info[:vm_id]}")
        @info[:vm].running?
    end

    it "ssh and context" do
        @info[:vm].reachable?
    end

    it "create non-pers datablock" do
        cmd = "oneimage create --name non_pers_#{@info[:vm_id]} " <<
                "--size 1 --type datablock -d #{@info[:ds_id]} " <<
                "--prefix #{@info[:prefix]} #{@info[:datablock_opts]}"

        img_id = cli_create(cmd)

        wait_loop(:success => "READY", :break => "ERROR") {
            xml = cli_action_xml("oneimage show -x #{img_id}")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        }

        @info[:img_id] = img_id
    end

    it "create datablock" do
        cmd = "oneimage create --name pers_#{@info[:vm_id]} " <<
                "--size 1 --type datablock -d #{@info[:ds_id]} " <<
                "--prefix #{@info[:prefix]} #{@info[:datablock_opts]} --persistent"

        img_id = cli_create(cmd)

        wait_loop(:success => "READY", :break => "ERROR") {
            xml = cli_action_xml("oneimage show -x #{img_id}")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        }

        @info[:img_id_pers] = img_id
    end

    it "poweroff" do
        @info[:vm].safe_poweroff
    end

    it "attach non-pers datablock" do
        cli_action("onevm disk-attach #{@info[:vm_id]} --image #{@info[:img_id]} --prefix #{@info[:prefix]}")
        @info[:vm].state?("POWEROFF")
        @info[:disk_id] = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:img_id]}']/DISK_ID"].to_i
        @info[:target]  = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:img_id]}']/TARGET"]
    end

    it "attach pers datablock" do
        cli_action("onevm disk-attach #{@info[:vm_id]} --image #{@info[:img_id_pers]} --prefix #{@info[:prefix]}")
        @info[:vm].state?("POWEROFF")
        @info[:disk_id_pers] = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:img_id_pers]}']/DISK_ID"].to_i
        @info[:target_pers]  = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:img_id_pers]}']/TARGET"]
    end

    it "resume" do
        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    ############################################################################
    # create snaps
    ############################################################################

    it "create snap non-pers" do
        @info[:vm].ssh("echo s1 > /dev/#{@info[:target]}; sync")

        snap_action = "onevm disk-snapshot-create #{@info[:vm_id]} #{@info[:disk_id]} s1"
        if livesnap
            cli_action(snap_action)
        else
            @info[:vm].safe_poweroff

            cli_action(snap_action)
            @info[:vm].state?("POWEROFF")

            cli_action("onevm resume #{@info[:vm_id]}")
            @info[:vm].running?
            @info[:vm].reachable?
        end

        @info[:vm].state?("RUNNING")
    end

    it "create snap pers" do
        @info[:vm].ssh("echo s1_pers > /dev/#{@info[:target_pers]}; sync")

        snap_action = "onevm disk-snapshot-create #{@info[:vm_id]} #{@info[:disk_id_pers]} s1_pers"
        if livesnap
            cli_action(snap_action)
        else
            @info[:vm].safe_poweroff

            cli_action(snap_action)
            @info[:vm].state?("POWEROFF")

            cli_action("onevm resume #{@info[:vm_id]}")
            @info[:vm].running?
            @info[:vm].reachable?
        end

        @info[:vm].state?("RUNNING")
    end

    ############################################################################
    # modify current state
    ############################################################################

    it "modify current state" do
        @info[:vm].ssh("echo current > /dev/#{@info[:target]}; sync")
        @info[:vm].ssh("echo current_pers > /dev/#{@info[:target_pers]}; sync")
    end

    ############################################################################
    # save disks from snapshots
    ############################################################################

    it "save snap non-pers" do
        action = "onevm disk-saveas #{@info[:vm_id]} #{@info[:disk_id]} #{@info[:vm_id]}_s1 -s 0"

        if livesnap
            @info[:img_id_save_s1] = cli_create(action)
        else
            @info[:vm].safe_poweroff

            @info[:img_id_save_s1] = cli_create(action)
            @info[:vm].state?("POWEROFF")

            cli_action("onevm resume #{@info[:vm_id]}")
            @info[:vm].running?
            @info[:vm].reachable?
        end

        @info[:vm].state?("RUNNING")

        wait_loop(:success => "READY", :break => "ERROR") {
            xml = cli_action_xml("oneimage show -x #{@info[:img_id_save_s1]}")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        }
    end

    it "save snap pers" do
        action = "onevm disk-saveas #{@info[:vm_id]} #{@info[:disk_id_pers]} #{@info[:vm_id]}_pers_s1 -s 0"

        if livesnap
            @info[:img_id_pers_save_s1] = cli_create(action)
        else
            @info[:vm].safe_poweroff

            @info[:img_id_pers_save_s1] = cli_create(action)
            @info[:vm].state?("POWEROFF")

            cli_action("onevm resume #{@info[:vm_id]}")
            @info[:vm].running?
            @info[:vm].reachable?
        end

        @info[:vm].state?("RUNNING")

        wait_loop(:success => "READY", :break => "ERROR") {
            xml = cli_action_xml("oneimage show -x #{@info[:img_id_pers_save_s1]}")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        }
    end

    ############################################################################
    # save disks from current
    ############################################################################

    it "save current non-pers" do
        action = "onevm disk-saveas #{@info[:vm_id]} #{@info[:disk_id]} #{@info[:vm_id]}_current"

        if livesnap
            @info[:img_id_save_current] = cli_create(action)
        else
            @info[:vm].safe_poweroff

            @info[:img_id_save_current] = cli_create(action)
            @info[:vm].state?("POWEROFF")

            cli_action("onevm resume #{@info[:vm_id]}")
            @info[:vm].running?
            @info[:vm].reachable?
        end

        @info[:vm].state?("RUNNING")

        wait_loop(:success => "READY", :break => "ERROR") {
            xml = cli_action_xml("oneimage show -x #{@info[:img_id_save_current]}")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        }
    end

    it "save current pers" do
        action = "onevm disk-saveas #{@info[:vm_id]} #{@info[:disk_id_pers]} #{@info[:vm_id]}_current_pers"

        if livesnap
            @info[:img_id_save_current_pers] = cli_create(action)
        else
            @info[:vm].safe_poweroff

            @info[:img_id_save_current_pers] = cli_create(action)
            @info[:vm].state?("POWEROFF")

            cli_action("onevm resume #{@info[:vm_id]}")
            @info[:vm].running?
            @info[:vm].reachable?
        end

        @info[:vm].state?("RUNNING")

        wait_loop(:success => "READY", :break => "ERROR") {
            xml = cli_action_xml("oneimage show -x #{@info[:img_id_save_current_pers]}")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        }
    end

    ############################################################################
    # Delete VM and datablocks
    ############################################################################

    it "terminate vm and datablocks" do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?

        cli_action("oneimage delete #{@info[:img_id]}")
        wait_loop(:success => true) {
            cmd = cli_action("oneimage show #{@info[:img_id]} 2>/dev/null", nil)
            cmd.fail?
        }

        cli_action("oneimage delete #{@info[:img_id_pers]}")
        wait_loop(:success => true) {
            cmd = cli_action("oneimage show #{@info[:img_id_pers]} 2>/dev/null", nil)
            cmd.fail?
        }
    end

    ############################################################################
    # New VM
    ############################################################################

    it "deploy new vm" do
        # Use the same VM for all the tests in this example
        @info[:vm_id] = cli_create("onetemplate instantiate '#{@defaults[:template]}'")
        @info[:vm]    = VM.new(@info[:vm_id])

        @info[:vm].running?
        @info[:vm].reachable?
    end

    ############################################################################
    # Attach images
    ############################################################################

    it "poweroff" do
        @info[:vm].safe_poweroff
    end

    it "attach saved images" do
        cli_action("onevm disk-attach #{@info[:vm_id]} --image #{@info[:img_id_save_s1]} --prefix #{@info[:prefix]}")
        @info[:vm].state?("POWEROFF")

        cli_action("onevm disk-attach #{@info[:vm_id]} --image #{@info[:img_id_pers_save_s1]} --prefix #{@info[:prefix]}")
        @info[:vm].state?("POWEROFF")

        cli_action("onevm disk-attach #{@info[:vm_id]} --image #{@info[:img_id_save_current]} --prefix #{@info[:prefix]}")
        @info[:vm].state?("POWEROFF")

        cli_action("onevm disk-attach #{@info[:vm_id]} --image #{@info[:img_id_save_current_pers]} --prefix #{@info[:prefix]}")
        @info[:vm].state?("POWEROFF")
    end

    it "resume" do
        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    ############################################################################
    # Verify contents
    ############################################################################

    it "verify s1" do
        target = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:img_id_save_s1]}']/TARGET"]

        cmd = @info[:vm].ssh("head -n1 /dev/#{target}")
        expect(cmd.stdout.strip).to eq("s1")
    end

    it "verify s1 pers" do
        target = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:img_id_pers_save_s1]}']/TARGET"]

        cmd = @info[:vm].ssh("head -n1 /dev/#{target}")
        expect(cmd.stdout.strip).to eq("s1_pers")
    end

    it "verify current" do
        target = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:img_id_save_current]}']/TARGET"]

        cmd = @info[:vm].ssh("head -n1 /dev/#{target}")
        expect(cmd.stdout.strip).to eq("current")
    end

    it "verify current pers" do
        target = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:img_id_save_current_pers]}']/TARGET"]

        cmd = @info[:vm].ssh("head -n1 /dev/#{target}")
        expect(cmd.stdout.strip).to eq("current_pers")
    end

    ############################################################################
    # Shutdown and verify no stray images in datastore
    ############################################################################

    it "terminate vm and datablocks" do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?

        [
            :img_id_save_s1,
            :img_id_pers_save_s1,
            :img_id_save_current,
            :img_id_save_current_pers
        ].each do |img_id|
            cli_action("oneimage delete #{@info[img_id]}")
            wait_loop(:success => true) {
                cmd = cli_action("oneimage show #{@info[img_id]} 2>/dev/null", nil)
                cmd.fail?
            }
        end
    end

    it "datastore contents are unchanged" do
        wait_loop(:success => @info[:image_list], :timeout => 30) do
            DSDriver.get(@info[:ds_id]).image_list
        end
    end
end
