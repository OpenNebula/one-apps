
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Scheduling user priority tests" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults_user.yaml')
    end

    #---------------------------------------------------------------------------
    # Helper functions for the tests
    #---------------------------------------------------------------------------
    def build_template(up)
        template = <<-EOF
            NAME = testvm
            CPU  = 0.1
            MEMORY = 64
            USER_PRIORITY = #{up}
        EOF

        return template
    end

    def vm_with_up(up)
        vmid = cli_create("onevm create --hold", build_template(up))

        vm = VM.new(vmid)

        return vmid, vm
    end

    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        i = cli_create("onehost create host0 --im dummy --vm dummy")

        host = Host.new(i)
        host.monitored?


        mads = "TM_MAD=dummy\nDS_MAD=dummy"

        cli_update("onedatastore update system", mads, false)
        cli_update("onedatastore update default", mads, false)
    end

    after(:all) do
        cli_action("onehost delete host0")
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should allocate a VMs using USER_PRIORITY" do
        vmid1, vm1 = vm_with_up(1.5)
        vmid2, vm2 = vm_with_up(2.5)
        vmid3, vm3 = vm_with_up(0.5)
        vmid4, vm4 = vm_with_up(-1)
        vmid5, vm5 = vm_with_up(5)

        @one_test.stop_sched()
        cli_action("onevm release #{vmid1}..#{vmid5}")
        @one_test.start_sched()

        vm4.running?

        vm1.info
        vm2.info
        vm3.info
        vm4.info
        vm5.info

        expect(vm5.stime.to_i).to be < vm2.stime.to_i
        expect(vm2.stime.to_i).to be < vm1.stime.to_i
        expect(vm1.stime.to_i).to be < vm3.stime.to_i
        expect(vm3.stime.to_i).to be < vm4.stime.to_i

        vm1.terminate
        vm2.terminate
        vm3.terminate
        vm4.terminate
        vm5.terminate
    end
end
