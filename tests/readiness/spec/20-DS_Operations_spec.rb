require 'init'

# Tests DS Operations

RSpec.describe "DS Operations" do
    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {}

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

        @info[:data] = "ds_operations #{Time.now}"
        @info[:data_file] = Tempfile.new('one-readiness')
        @info[:data_file].write(@info[:data])
        @info[:data_file].close

        # Resize to 512 bytes (needed for lvm)
        cli_action("qemu-img resize #{@info[:data_file].path} 512")
    end

    after(:all) do
        @info[:data_file].unlink
    end

    ############################################################################
    # CP
    ############################################################################

    it "deploys" do
        cli_action("onevm release #{@info[:vm_id]}")
        @info[:vm].running?
    end

    it "ssh and context" do
        @info[:vm].reachable?
    end

    it "poweroff" do
        @info[:vm].safe_poweroff
    end

    it "cp" do
         cmd = "oneimage create " <<
                "--name ds_ops_#{@info[:vm_id]} " <<
                "--path #{@info[:data_file].path} " <<
                "--prefix #{@info[:prefix]} " <<
                "-d #{@info[:ds_id]}"

        @info[:img_cp_id] = cli_create(cmd)

        wait_loop(:success => "READY", :break => "ERROR") {
            xml = cli_action_xml("oneimage show -x #{@info[:img_cp_id]}")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        }
    end

    it "attach disk created with cp" do
        cli_action("onevm disk-attach #{@info[:vm_id]} --image #{@info[:img_cp_id]} --prefix #{@info[:prefix]}")
        @info[:vm].state?("POWEROFF")
    end

    it "clone" do
        cmd = "oneimage clone #{@info[:img_cp_id]} ds_ops_clone_#{@info[:vm_id]} "
        @info[:img_clone_id] = cli_create(cmd)

        wait_loop(:success => "READY", :break => "ERROR") {
            xml = cli_action_xml("oneimage show -x #{@info[:img_clone_id]}")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        }
    end

    it "attach disk created with clone" do
        cli_action("onevm disk-attach #{@info[:vm_id]} --image #{@info[:img_clone_id]} --prefix #{@info[:prefix]}")
        @info[:vm].state?("POWEROFF")
    end

    it "mkfs" do
        cmd = "oneimage create --name snapshot_cycle_with_attach_detach_#{@info[:vm_id]} " <<
                "--size 100 --type datablock " <<
                "-d #{@info[:ds_id]} #{@info[:datablock_opts]} --prefix #{@info[:prefix]}"

        @info[:img_mkfs_id] = cli_create(cmd)

        wait_loop(:success => "READY", :break => "ERROR") {
            xml = cli_action_xml("oneimage show -x #{@info[:img_mkfs_id]}")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        }
    end

    it "attach disk created with mkfs" do
        cli_action("onevm disk-attach #{@info[:vm_id]} --image #{@info[:img_mkfs_id]} --prefix #{@info[:prefix]}")
        @info[:vm].state?("POWEROFF")
    end

    it "attach swap" do
        cli_update("onevm disk-attach  #{@info[:vm_id]} -f ", <<-EOT, false, true)
DISK = [
  FORMAT = "raw",
  SIZE = "100",
  TARGET = "vdx",
  TYPE = "swap" ]
EOT
        @info[:vm].state?("POWEROFF")
    end

    it "resume" do
        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it "verify disk created with cp" do
        target = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:img_cp_id]}']/TARGET"]

        cmd = @info[:vm].ssh("cat /dev/#{target}")
        expect(cmd.stdout.strip).to eq(@info[:data])
    end

    it "verify disk created with clone" do
        target = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:img_clone_id]}']/TARGET"]

        cmd = @info[:vm].ssh("cat /dev/#{target}")
        expect(cmd.stdout.strip).to eq(@info[:data])
    end

    it "verify disk created with mkfs" do
        target = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:img_mkfs_id]}']/TARGET"]

        cmd = @info[:vm].ssh("ls /dev/#{target}")
        expect(cmd.success?).to be(true)
    end

    it "verify swap" do
        cmd = @info[:vm].ssh("blkid | grep swap | grep '/dev/vd'")
        expect(cmd.success?).to be(true)
    end

    it "terminate vm and datablocks" do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?

        [
            :img_cp_id,
            :img_clone_id,
            :img_mkfs_id
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
