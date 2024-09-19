
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

describe "VirtualMachine information test" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    before(:all) do
        vm_id = cli_create("onevm create", <<-EOT)
            CPU = 1
            MEMORY = 256
            OS = [
                KERNEL = "/vmlinuz",
                INITRD = "/initrd.img",
                ROOT = "hda"
            ]
        EOT

        @vm = VM.new(vm_id)

        cli_create("onehost create host01 --im dummy --vm dummy")

        cli_action("onevm deploy #{vm_id} host01")
        @vm.running?
    end

    it "should check the VirtualMachine information" do
        xml = @vm.info

        expect(xml["TEMPLATE/CPU"]).to eq "1"
        expect(xml["TEMPLATE/MEMORY"]).to eq "256"
        expect(xml["TEMPLATE/OS/INITRD"]).to eq "/initrd.img"
        expect(xml["TEMPLATE/OS/KERNEL"]).to eq "/vmlinuz"
        expect(xml["TEMPLATE/OS/ROOT"]).to eq "hda"
    end

    it "should check the VirtualMachine monitoring" do
        @vm.wait_monitoring_info("CPU")

        xml = @vm.info

        expect(xml["MONITORING/TIMESTAMP"].to_i).to be > 0
        expect(xml["MONITORING/CPU"].to_i).to be > 0
        expect(xml["MONITORING/MEMORY"].to_i).to be > 0
        expect(xml["MONITORING/DISKRDBYTES"].to_i).to be > 0
        expect(xml["MONITORING/DISKRDIOPS"].to_i).to be > 0
        expect(xml["MONITORING/DISKWRBYTES"].to_i).to be > 0
        expect(xml["MONITORING/DISKWRIOPS"].to_i).to be > 0
        expect(xml["MONITORING/NETRX"].to_i).to be > 0
        expect(xml["MONITORING/NETTX"].to_i).to be > 0
    end
end