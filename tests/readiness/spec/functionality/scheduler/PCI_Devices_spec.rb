
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "PCI devices scheduling tests" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    #---------------------------------------------------------------------------
    # Helper functions for the tests
    #---------------------------------------------------------------------------
    def define_and_run(template)
        vmid = cli_create("onevm create", template)

        vm = VM.new(vmid)

        vm.running?

        return vmid, vm
    end

    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        h0_id = cli_create("onehost create host01 --im dummy --vm dummy")
        h1_id = cli_create("onehost create host02 --im dummy --vm dummy")

        h0 = Host.new(h0_id)
        h1 = Host.new(h1_id)

        h0.monitored?
        h1.monitored?

        cli_update("onehost update host01", "PRIORITY = 5", true)
        cli_update("onehost update host02", "PRIORITY = 2", true)

        mads = "TM_MAD=dummy\nDS_MAD=dummy"

        cli_update("onedatastore update system", mads, false)
        cli_update("onedatastore update default", mads, false)

        @template_1 = <<-EOF
            NAME = testvm1
            CPU  = 1
            MEMORY = 128
            SCHED_RANK=PRIORITY
            PCI = [ DEVICE="0863" ]
            PCI = [ DEVICE="0aa9" ]
        EOF

        @template_2 = <<-EOF
            NAME = testvm2
            CPU  = 1
            MEMORY = 128
            SCHED_RANK=PRIORITY
            PCI = [ DEVICE="0aa9" ]
        EOF

        @template_3 = <<-EOF
            NAME = testvm3
            CPU  = 1
            MEMORY = 128
            SCHED_RANK=PRIORITY
            PCI = [ SHORT_ADDRESS = "00:06.1" ]
        EOF
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should deploy a VM with PCI devices in the highest ranked host" do
        vmid, vm = define_and_run(@template_1)

        expect(vm.hostname).to eq("host01")

        vm.terminate_hard

        vm.done?
    end

    it "should avoid hosts with used PCI devices" do
        vmid1 = cli_create("onevm create", @template_1)
        vmid2 = cli_create("onevm create", @template_2)

        vm1 = VM.new(vmid1)
        vm2 = VM.new(vmid2)

        vm1.running?
        vm2.running?

        expect(vm1.hostname).to eq("host01")
        expect(vm2.hostname).to eq("host02")

        vm1.terminate_hard
        vm2.terminate_hard

        vm1.done?
        vm2.done?
    end

    it "should not deploy until PCI devices are free" do
        vmid1 = cli_create("onevm create", @template_1)
        vmid2 = cli_create("onevm create", @template_2)

        vm1 = VM.new(vmid1)
        vm2 = VM.new(vmid2)

        vm1.running?
        vm2.running?

        expect(vm1.hostname).to eq("host01")
        expect(vm2.hostname).to eq("host02")

        vmid3 = cli_create("onevm create", @template_3)
        vm3   = VM.new(vmid3)

        wait_loop(:success => false, :timeout => 30) {
            vm3.info['USER_TEMPLATE/SCHED_MESSAGE'].nil?
        }

        vm2.terminate_hard

        vm2.done?

        vm3.running?

        expect(vm3.hostname).to eq("host02")

        vm1.terminate_hard
        vm3.terminate_hard

        vm1.done?
        vm3.done?
    end
=begin
    it "should resched to hosts with free PCI devices" do
        vmid1 = cli_create("onevm create", @template_1)
        vmid2 = cli_create("onevm create", @template_2)

        vm1 = VM.new(vmid1)
        vm2 = VM.new(vmid2)

        vm1.running?
        vm2.running?

        expect(vm1.hostname).to eq("host01")
        expect(vm2.hostname).to eq("host02")

        vm1.terminate_hard

        cli_action("onevm resched #{vmid2}")

        wait_loop(:success => "host01", :timeout => 5) {
            vm2.info
            vm2.hostname
        }

        vm2.running?

        vm2.terminate_hard

        vm2.done?
    end

    it "should not resched to hosts with used PCI devices" do
        vmid1 = cli_create("onevm create", @template_1)
        vmid2 = cli_create("onevm create", @template_2)

        vm1 = VM.new(vmid1)
        vm2 = VM.new(vmid2)

        vm1.running?
        vm2.running?

        expect(vm1.hostname).to eq("host01")
        expect(vm2.hostname).to eq("host02")

        expect(vm2.info['USER_TEMPLATE/SCHED_MESSAGE']).to be_nil

        cli_action("onevm resched #{vmid2}")

        wait_loop(:success => false, :timeout => 5) {
            vm2.info['USER_TEMPLATE/SCHED_MESSAGE'].nil?
        }

        expect(vm2.hostname).to eq("host02")

        vm2.terminate_hard
        vm1.terminate_hard
    end
=end
end

