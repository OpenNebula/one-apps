
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

describe "VirtualMachine cancel operation test" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    before(:all) do
        cli_update("onedatastore update system", "TM_MAD=dummy", false)

        host_id = cli_create("onehost create host0 --im dummy --vm dummy")

        @id = cli_create("onevm create", <<-EOT)
            NAME = "test_vm"
            MEMORY = "1024"
            CPU    = "1"
        EOT

        @vm = VM.new(@id)

        cli_action("onevm deploy #{@id} #{host_id}")
        @vm.running?
    end

    it "should cancel a running VirtualMachine and then, check its state and" <<
        " history" do

        @vm.terminate_hard

        xml = @vm.info
        expect(xml["HISTORY_RECORDS/HISTORY/ACTION"]).to eq("28") # terminate-hard

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