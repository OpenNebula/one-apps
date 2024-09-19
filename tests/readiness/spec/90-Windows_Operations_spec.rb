require 'init'

# Tests basic VM Operations (Windows)

# Parameters:
# :template: VM that is tested is instantiated from this template
RSpec.describe "Basic VM Tasks" do
    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {}

        # Use the same VM for all the tests in this example
        @info[:vm_id] = cli_create("onetemplate instantiate '#{@defaults[:template]}'")
        @info[:vm]    = VM.new(@info[:vm_id])

        @info[:ds_id]     = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DATASTORE_ID']
        @info[:ds_driver] = DSDriver.get(@info[:ds_id])

        # Get image list
        @info[:image_list] = @info[:ds_driver].image_list
    end

    it "deploys" do
        @info[:vm].running?
    end

    it "context" do
        @info[:vm].wait_ping
    end

    it "poweroff" do
        @info[:vm].safe_poweroff
    end

    it "resume" do
        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].wait_ping
    end

    # Pausing VMs - Short term

    it "suspend" do
        cli_action("onevm suspend #{@info[:vm_id]}")
        @info[:vm].state?("SUSPENDED")

        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].wait_ping
    end

    it "poweroff" do
        @info[:vm].safe_poweroff

        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].wait_ping
    end

    # Pausing VMs - Long term

    it "stop" do
        cli_action("onevm stop #{@info[:vm_id]}")
        @info[:vm].state?("STOPPED")

        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].wait_ping
    end

    it "undeploy" do
        @info[:vm].safe_undeploy

        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].wait_ping
    end

    # Other operations

    it "disk-saveas" do
        @info[:vm].running?

        disk_snap = "#{@info[:vm]['NAME']}-0-disk-snap"
        disk_snap_id = cli_create("onevm disk-saveas #{@info[:vm_id]} 0 #{disk_snap}")

        wait_loop(:success => "READY", :break => "ERROR") {
            xml   = cli_action_xml("oneimage show -x #{disk_snap_id}")
            state = xml['STATE'].to_i

            Image::IMAGE_STATES[state]
        }

        cli_action("oneimage delete #{disk_snap_id}")
    end
end
