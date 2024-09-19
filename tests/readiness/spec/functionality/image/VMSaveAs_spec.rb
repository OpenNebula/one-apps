#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Using save_as on a VirtualMachine" do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        mads = "TM_MAD=dummy\nDS_MAD=dummy\nDATASTORE_CAPACITY_CHECK=NO"

        cli_update("onedatastore update system", mads, false)
        cli_update("onedatastore update default", mads, false)

        @host_id = cli_create("onehost create dummy -i dummy -v dummy")

        cli_create_user("uA", "abc")

        @iid = -1

        as_user("uA") do
            @iid = cli_create("oneimage create -d default --type OS"\
                " --name test_img --size 100 --persistent")
        end

        wait_loop() {
            xml = cli_action_xml("oneimage show -x #{@iid}")
            xml['STATE'] == '1'
        }

        as_user("uA") do
            @vmid = cli_create("onevm create --name test_vm --cpu 1 --memory 128"\
                          " --disk test_img")
        end

        cli_action("onevm deploy #{@vmid} #{@host_id}")

        @vm = VM.new(@vmid)
        @vm.running?
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should save a VirtualMachine disk into a new Image" do
        cli_action("onevm disk-saveas test_vm 0 newimage")

        img_xml = cli_action_xml("oneimage show newimage -x")

        expect(img_xml["SAVE_AS_HOT"]).to be_nil
    end

    it "should  try to use the disk-saveas command" <<
        " on a non existing VirtualMachine's disk and check the failure" do

        cli_action("onevm disk-saveas test_vm 10 newimage2", false)
        cli_action("oneimage show newimage2", false)
    end

    it "should prepare an existing VirtualMachine's" <<
        " disk to be saved in a new Image and set type" do

        cli_action("onevm disk-saveas test_vm 0 newimage2 --type DATABLOCK")

        img_xml = cli_action_xml("oneimage show newimage2 -x")
        expect(Image::IMAGE_TYPES[img_xml["TYPE"].to_i]).to eq("DATABLOCK")
    end

    it "should save a poweroff VirtualMachine disk in into a new Image" do
        @vm.running?

        cli_action("onevm poweroff test_vm")

        @vm.poweroff?

        cli_action("onevm disk-saveas test_vm 0 image_poweroff")

        @vm.poweroff?

        cli_action("oneimage show image_poweroff")
    end

    it "should save a suspended VirtualMachine disk into a new Image" do
        cli_action("onevm resume test_vm")

        @vm.running?

        cli_action("onevm suspend test_vm")

        @vm.state?('SUSPENDED')

        cli_action("onevm disk-saveas test_vm 0 image_suspended")

        cli_action("oneimage show image_suspended")
    end

    it "should save a undeployed VirtualMachine disk into a new Image" do
        @vm.state?('SUSPENDED')

        cli_action("onevm resume test_vm")

        @vm.running?

        cli_action("onevm undeploy test_vm")

        @vm.state?('UNDEPLOYED')

        cli_action("onevm disk-saveas test_vm 0 image_undeployed")

        cli_action("oneimage show image_undeployed")
    end

    it "should save a stopped VirtualMachine disk into a new Image" do
        @vm.state?('UNDEPLOYED')

        cli_action("onevm deploy #{@vmid} #{@host_id}")

        @vm.running?

        cli_action("onevm stop test_vm")

        @vm.state?('STOPPED')

        cli_action("onevm disk-saveas test_vm 0 image_stopped")

        cli_action("oneimage show image_stopped")
    end
end

