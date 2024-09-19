require 'init'
require 'lib/DiskResize'

include DiskResize

# Test the disk resize operation

# Description:
# - VM is deployed
# - SSH is configured (contextualization)
# - Disk size is measured
# - VM is deleted
# - New VM is deployed with a new size
# - Disk size is measured again
# - VM is deleted
# - Check datastore contents
# Parameters:
# :template: VM that is tested is instantiated from this template
RSpec.describe "Disk Resize " do
    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {}

        # Use the same VM for all the tests in this example
        @info[:vm_id] = cli_create("onetemplate instantiate --hold '#{@defaults[:template]}'")
        @info[:vm]    = VM.new(@info[:vm_id])

        @info[:ds_id]    = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DATASTORE_ID']
        @info[:prefix]   = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DEV_PREFIX']
        @info[:image_id] = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/IMAGE_ID']

        # Get image list
        @info[:image_list] = DSDriver.get(@info[:ds_id]).image_list

        # Disable LVM DD zeroing
        system("sed -i 's/ZERO_LVM_ON_CREATE=.*/ZERO_LVM_ON_CREATE=no/' "<<
               "/var/lib/one/remotes/etc/tm/fs_lvm/fs_lvm.conf")
        system("sed -i 's/ZERO_LVM_ON_DELTE=.*/ZERO_LVM_ON_DELTE=no/' "<<
               "/var/lib/one/remotes/etc/tm/fs_lvm/fs_lvm.conf")
    end

    after(:all) do
        # Enable LVM DD zeroing
        system("sed -i 's/ZERO_LVM_ON_CREATE=.*/ZERO_LVM_ON_CREATE=yes/' "<<
               "/var/lib/one/remotes/etc/tm/fs_lvm/fs_lvm.conf")
        system("sed -i 's/ZERO_LVM_ON_DELTE=.*/ZERO_LVM_ON_DELTE=yes/' "<<
               "/var/lib/one/remotes/etc/tm/fs_lvm/fs_lvm.conf")
    end

    it "deploys" do
        cli_action("onevm release #{@info[:vm_id]}")
        @info[:vm].running?
    end

    it "ssh and context" do
        @info[:vm].reachable?
    end

    it "measure disk size" do
        @info[:disk_size] = get_disk_size(@info[:vm])
    end

    it "measure fs size" do
        @info[:fs_size] = get_fs_size(@info[:vm])
    end

    it "terminate vm" do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?
    end

    it "deploy new vm with disk resize" do
        @info[:disk_resize] = (@info[:disk_size] / (1024*1024)) + 1024
        template_opts = "--disk #{@info[:image_id]}:size=#{@info[:disk_resize]}"
        @info[:vm_id] = cli_create("onetemplate instantiate '#{@defaults[:template]}' #{template_opts}")
        @info[:vm]    = VM.new(@info[:vm_id])
    end

    it "ssh and context" do
        @info[:vm].reachable?
    end

    it "measure disk size" do
        new_disk_size = nil
        expected = @info[:disk_resize]*1024*1024

        new_disk_size = again(expected) do
            get_disk_size(@info[:vm])
        end

        expect(new_disk_size).to eq(expected)
    end


    it "measure fs size" do
        new_fs_size = nil

        again(true) do
            new_fs_size = get_fs_size(@info[:vm])
            new_fs_size > @info[:fs_size]
        end

        expect(new_fs_size).to be > (@info[:fs_size])
        expect(new_fs_size).to be <= (@info[:disk_resize]*1024)
    end

    it "terminate vm" do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?
    end

    it "datastore contents are unchanged" do
        # image epilog settles...
        wait_loop(:success => true, :timeout => 20) do
            DSDriver.get(@info[:ds_id]).image_list == @info[:image_list]
        end
    end
end
