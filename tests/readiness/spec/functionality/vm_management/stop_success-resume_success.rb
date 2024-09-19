
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

def history(vmxml, elem)
    return vmxml["HISTORY_RECORDS/HISTORY[last()]/#{elem}"]
end

describe "VirtualMachine stop and resume operations test" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    before(:all) do
        cli_update("onedatastore update system", "TM_MAD=dummy", false)
        cli_create("onehost create host01 --im dummy --vm dummy")

        @vm_id = cli_create("onevm create --name testvm --cpu 1 --memory 1")
        @vm = VM.new(@vm_id)

        cli_action("onevm deploy testvm host01")

        @vm.running?
    end

    it "should stop a running VirtualMachine and then, check its state" <<
        " and history" do

        cli_action("onevm stop testvm")

        @vm.state?("STOPPED")

        vmxml = cli_action_xml("onevm show -x testvm")

        expect(history(vmxml, 'ACTION').to_i).to eql(9) # Stop/Resume
        expect(history(vmxml, 'STIME').to_i).to be > 0
        expect(history(vmxml, 'ETIME').to_i).to be >= history(vmxml, 'STIME').to_i
        expect(history(vmxml, 'PSTIME').to_i).not_to eql(0)
        expect(history(vmxml, 'PETIME').to_i).to be >= history(vmxml, 'PSTIME').to_i
        expect(history(vmxml, 'RSTIME').to_i).not_to eql(0)
        expect(history(vmxml, 'RETIME').to_i).to be >= history(vmxml, 'RSTIME').to_i
        expect(history(vmxml, 'ESTIME').to_i).not_to eql(0)
        expect(history(vmxml, 'EETIME').to_i).to be >= history(vmxml, 'ESTIME').to_i
    end

    it "should check the Host capacity with a stopped VirtualMachine" do
        hostxml = cli_action_xml("onehost show -x host01")

        expect(hostxml['HOST_SHARE/RUNNING_VMS'].to_i).to eql(0)
        expect(hostxml['HOST_SHARE/MEM_USAGE'].to_i).to eql 0
        expect(hostxml['HOST_SHARE/CPU_USAGE'].to_i).to eql 0
    end

    it "should resume a stopped VirtualMachine and then, check its state" <<
        " and history" do
        cli_action("onevm resume testvm")
        cli_action("onevm deploy testvm host01")

        @vm.running?

        vmxml = cli_action_xml("onevm show -x testvm")

        expect(history(vmxml, 'ACTION').to_i).to eql(0)
        expect(history(vmxml, 'STIME').to_i).to be > 0
        expect(history(vmxml, 'ETIME').to_i).to eql(0)
        expect(history(vmxml, 'PSTIME').to_i).to be > 0
        expect(history(vmxml, 'PETIME').to_i).to be > 0
        expect(history(vmxml, 'RSTIME').to_i).to be > 0
        expect(history(vmxml, 'RETIME').to_i).to eql(0)
        expect(history(vmxml, 'ESTIME').to_i).to eql(0)
        expect(history(vmxml, 'EETIME').to_i).to eql(0)
    end

    it "should check the Host capacity with a resumed VirtualMachine" do
        vmxml = cli_action_xml("onevm show -x testvm")
        hostxml = cli_action_xml("onehost show -x host01")

        expect(hostxml['HOST_SHARE/RUNNING_VMS'].to_i).to eql(1)
        expect(hostxml['HOST_SHARE/MEM_USAGE'].to_i).to eql vmxml['TEMPLATE/MEMORY'].to_i * 1024
        expect(hostxml['HOST_SHARE/CPU_USAGE'].to_i).to eql vmxml['TEMPLATE/CPU'].to_i * 100
    end
end