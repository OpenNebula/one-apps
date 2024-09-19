
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

describe "VirtualMachine shutdown operation test" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    before(:all) do
        cli_update("onedatastore update system", "TM_MAD=dummy", false)

        cli_create("onehost create host01 --im dummy --vm dummy")
        cli_action("onehost show host01")

        @vm_id = cli_create("onevm create --name vm --memory 1 --cpu 1")
        @vm = VM.new(@vm_id)

        cli_action("onevm deploy vm host01")
        @vm.running?
    end

    it "should shutdown a running VirtualMachine and then, check its state" <<
        " and history" do
        @vm.terminate

        xml = @vm.info
        expect(xml["HISTORY_RECORDS/HISTORY/ACTION"]).to eq("27") # terminate

        stime = xml["HISTORY_RECORDS/HISTORY/STIME"].to_i
        etime = xml["HISTORY_RECORDS/HISTORY/ETIME"].to_i
        pstime = xml["HISTORY_RECORDS/HISTORY/PSTIME"].to_i
        petime = xml["HISTORY_RECORDS/HISTORY/PETIME"].to_i
        rstime = xml["HISTORY_RECORDS/HISTORY/RSTIME"].to_i
        retime = xml["HISTORY_RECORDS/HISTORY/RETIME"].to_i
        estime = xml["HISTORY_RECORDS/HISTORY/ESTIME"].to_i
        eetime = xml["HISTORY_RECORDS/HISTORY/EETIME"].to_i

        expect(stime).to be > 0
        expect(etime).to be >= stime
        expect(pstime).to be > 0
        expect(petime).to be >= pstime
        expect(rstime).to be > 0
        expect(retime).to be >= rstime
        expect(estime).to be > 0
        expect(eetime).to be >= estime
    end
end