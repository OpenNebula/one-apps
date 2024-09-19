require 'init'

# Tests DS Operations with attribute SPARSE = NO
# on Local Datastore (TM_MAD = ssh)

# Description:
# - Sets DS_MONITOR_VM_DISK = 1 on oned.conf so the monitor updates faster
# - Restarts opennebula to apply changes
# - Sets SPARSE = NO on image datastore
# - Sets QCOW2_STANDALONE = YES on image datastore
# - Creates new raw image
# - Deploys VM
# - Attaches image to instantiated VM
# - Checks that attached disk is using all reserved space
# - Undeploys VM
# - Sets SPARSE = YES on image datastore
# - Sets QCOW2_STANDALONE = NO on image datastore
# - Restores DS_MONITOR_VM_DISK to its original value
# - Restarts opennebula to apply changes
# - Deletes VM and image

RSpec.describe "DS Operations TM_MAD = ssh with SPARSE = NO" do
    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {}

        @info[:vm_id] = cli_create("onetemplate instantiate --hold '#{@defaults[:template]}'")
        @info[:vm]    = VM.new(@info[:vm_id])

        @info[:ds_id]  = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DATASTORE_ID']
        @info[:prefix] = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DEV_PREFIX']

        @info[:img_size] = 256

        # Sets DS_MONITOR_VM_DISK = 1 on oned.conf
        @info[:ds_monitor_vm_disk] = cli_action("sudo augtool get /files/etc/one/oned.conf/DS_MONITOR_VM_DISK").stdout.delete("/files/etc/one/oned.conf/DS_MONITOR_VM_DISK = ").strip
        cli_action("sudo augtool set /files/etc/one/oned.conf/DS_MONITOR_VM_DISK 1")

        # Restart monitoring service
        cmd = 'sudo systemctl restart opennebula'
        SafeExec.run(cmd)
        wait_loop(:success => true) {
            cmd = cli_action("oneimage show #{@info[:img_raw_id]} 2>/dev/null", nil)
            cmd.fail?
        }
    end

    after(:all) do
        # Terminate VM
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?

        # Delete image
        cli_action("oneimage delete #{@info[:img_raw_id]}")
        wait_loop(:success => true) {
            cmd = cli_action("oneimage show #{@info[:img_raw_id]} 2>/dev/null", nil)
            cmd.fail?
        }

        # Restore previous DS_MONITOR_VM_DISK value on oned.conf
        if @info[:ds_monitor_vm_disk] == "()"
            cli_action("sudo augtool rm /files/etc/one/oned.conf/DS_MONITOR_VM_DISK")
        else
            cli_action("sudo augtool set /files/etc/one/oned.conf/DS_MONITOR_VM_DISK #{@info[:ds_monitor_vm_disk]}")
        end

        # Restart monitoring service
        cmd = 'sudo systemctl restart opennebula'
        SafeExec.run(cmd)
        wait_loop(:success => true) {
            cmd = cli_action("oneimage show #{@info[:img_raw_id]} 2>/dev/null", nil)
            cmd.fail?
        }
    end

    it "sets SPARSE = NO on image datastore" do
        cli_update('onedatastore update 1', "SPARSE=NO", true)
    end

    it "sets QCOW2_STANDALONE = YES on system datastore" do
        cli_update('onedatastore update 1', "QCOW2_STANDALONE=YES", true)
    end

    it "creates 256MB raw DATABLOCK image" do
        cmd = "oneimage create " <<
              "--name rawimage_#{@info[:vm_id]} " <<
              "--type DATABLOCK " <<
              "--format raw " <<
              "--size #{@info[:img_size]} " <<
              "-d #{@info[:ds_id]}"

        @info[:img_raw_id] = cli_create(cmd)

        wait_loop(:success => "READY", :break => "ERROR") {
            xml = cli_action_xml("oneimage show -x #{@info[:img_raw_id]}")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        }
    end

    it "deploys VM" do
        cli_action("onevm release #{@info[:vm_id]}")
        @info[:vm].running?
    end

    it "attachs raw DATABLOCK image to VM" do
        cli_action("onevm disk-attach #{@info[:vm_id]} --image #{@info[:img_raw_id]} --prefix #{@info[:prefix]}")
        @info[:vm].running?
    end

    it "checks usage of raw disk on created VM is same as assigned" do
        real_size = 0

        wait_loop(:timeout => 240, :success => true) {
            real_size = @info[:vm].xml["MONITORING/DISK_SIZE[ID=\"2\"]/SIZE"]

            if ! real_size.nil?
                var = (real_size.to_i >= @info[:img_size])
            end
        }

        expect(real_size).to be >= (@info[:img_size].to_s)
    end

    it "undeploys VM" do
        cli_action("onevm undeploy --hard #{@info[:vm_id]}")
        @info[:vm].state?('UNDEPLOYED')
    end

    it "sets SPARSE = YES on image datastore" do
        cli_update('onedatastore update 1', "SPARSE=YES", true)
    end

    it "sets QCOW2_STANDALONE = NO on system datastore" do
        cli_update('onedatastore update 1', "QCOW2_STANDALONE=NO", true)
    end
end
