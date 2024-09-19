#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Create a VirtualMachine using an Image test" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        mads = "TM_MAD=dummy\nDS_MAD=dummy\nDATASTORE_CAPACITY_CHECK=NO"

        cli_update("onedatastore update system", mads, false)
        cli_update("onedatastore update default", mads, false)

        @iid_raw = cli_create("oneimage create -d default --type DATABLOCK "\
            "--format raw --name image_pers1 --size 1 --persistent")
        @iid_dummy = cli_create("oneimage create -d default --type DATABLOCK "\
            "--format dummy --name image_pers2 --size 1 --persistent")

        cli_update("oneimage update image_pers1",
            "PERSISTENT_TYPE=\"shareable\"", true)

        cli_update("oneimage update image_pers2",
            "PERSISTENT_TYPE=\"shareable\"", true)

        wait_loop() {
            xml1 = cli_action_xml("oneimage show -x #{@iid_raw}")
            xml2 = cli_action_xml("oneimage show -x #{@iid_dummy}")
            ( xml1['STATE'] == '1' ) && ( xml2['STATE'] == '1' )
        }

        @hid = cli_create("onehost create dummy -i dummy -v dummy")

        @vmid = cli_create("onevm create --name test --cpu 1 --memory 128"\
                           " --disk #{@iid_raw}")
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should deploy a VM with shareable disk" do
        cli_action("onevm deploy #{@vmid} #{@hid}")
        vm = VM.new(@vmid)
        vm.running?
    end

    it "should deploy a second VM with the same shareable disk" do
        vmid2 = cli_create("onevm create --name test --cpu 1 --memory 128"\
                   " --disk #{@iid_raw}")

        cli_action("onevm deploy #{vmid2} #{@hid}")
        vm = VM.new(vmid2)
        vm.running?

        cli_action("onevm terminate #{vmid2}")
    end

    it "should attach an used shareable disk" do
        cli_action("onevm disk-attach #{@vmid} --image #{@iid_raw}")

        vm = VM.new(@vmid)
        vm.running?

        cli_action("onevm terminate #{@vmid}")
    end
end

