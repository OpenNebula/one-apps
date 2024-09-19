
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

describe "VirtualMachine deploy operation test" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    before(:all) do
        @info = {}

        mads = "TM_MAD=dummy\nDS_MAD=dummy"

        cli_update("onedatastore update system", mads, false)
        cli_update("onedatastore update default", mads, false)

        @info[:ds_id] = cli_create("onedatastore create", <<-EOT)
            NAME = "system_ds"
            TM_MAD = "dummy"
            TYPE = "SYSTEM_DS"
        EOT

        cli_create("onehost create host01 --im dummy --vm dummy")

    end

    it "should create a VirtualMachine and check its succesful creation" do
        @info[:id] = cli_create("onevm create --name testvm --cpu 1 --memory 1 ")
        @info[:vm] = VM.new(@info[:id])

        expect(cli_action("onevm list").stdout).to match("testvm")
        cli_action("onevm show testvm")
    end

    it "should deploy a VirtualMachine and check its state" do
        cli_action("onevm deploy testvm host01 0")

        @info[:vm].running?
    end

    it "should deploy a VirtualMachine and check its history" do
        xml = cli_action_xml("onevm show -x testvm")

        expect(xml['HISTORY_RECORDS/HISTORY[last()]/STIME'].to_i).to be > 0
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/ETIME'].to_i).to eql(0)
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/PSTIME'].to_i).to be > 0
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/PETIME'].to_i).to be >=
            xml['HISTORY_RECORDS/HISTORY[last()]/PSTIME'].to_i
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/RSTIME'].to_i).to be > 0
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/RETIME'].to_i).to eql(0)
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/ESTIME'].to_i).to eql(0)
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/EETIME'].to_i).to eql(0)
    end

    it "should deploy a VirtualMachine and check the Host capacity" do
        vmxml = cli_action_xml("onevm show -x testvm")
        hostxml = cli_action_xml("onehost show -x host01")

        expect(hostxml['HOST_SHARE/RUNNING_VMS'].to_i).to eql(1)
        expect(hostxml['HOST_SHARE/MEM_USAGE'].to_i).to eql vmxml['TEMPLATE/MEMORY'].to_i * 1024
        expect(hostxml['HOST_SHARE/CPU_USAGE'].to_i).to eql vmxml['TEMPLATE/CPU'].to_i * 100
    end

    it "should resume on the same datastore" do
        cli_action("onevm undeploy testvm")
        @info[:vm].undeployed?

        xml = @info[:vm].xml
        ds_id = xml['HISTORY_RECORDS/HISTORY[last()]/DS_ID'].to_i

        cli_action("onevm deploy testvm host01")

        @info[:vm].running?

        xml = @info[:vm].xml
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/DS_ID'].to_i).to eql(ds_id)
        expect(@info[:ds_id]).not_to eql(ds_id)
    end

    it "should resume VM to new datastore" do
        cli_action("onevm undeploy testvm")
        @info[:vm].undeployed?

        cli_action("onevm deploy testvm host01 #{@info[:ds_id]}")

        @info[:vm].running?

        xml = @info[:vm].xml
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/DS_ID'].to_i).to eql(@info[:ds_id])
    end

    it "should enforce capacity check prior to vm deployment" do
        cli_create("onevm create", <<-EOT)
            NAME = "testvm2"
            CPU = "100"
            MEMORY = "1"
        EOT

        cli_action("onevm deploy -e testvm2 host01", false)
    end
end

