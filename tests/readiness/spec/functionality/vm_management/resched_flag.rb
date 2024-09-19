
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

describe "Virtual Machine rescheduling test" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    #
    # Set up the Virtual Infrastructure
    #
    def create_host(name)
        cli_create("onehost create #{name} --im dummy --vm dummy --net test")
    end

    def is_resched?(name)
        command = "onevm show #{name} -x"
        vm_xml  = cli_action_xml(command)

        vm_xml['RESCHED'] == "1"
    end

    before(:all) do
        cli_update("onedatastore update system", "TM_MAD=dummy", false)
        cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy", false)
        wait_loop() {
            xml = cli_action_xml("onedatastore show -x default")
            xml['FREE_MB'].to_i > 0
        }

        @vmid = 0

        cli_create("onehost create test01 --im dummy --vm dummy")
        cli_create("onehost create test02 --im dummy --vm dummy")
    end

    after(:all) do
        VM.new(@vmid).terminate_hard
        sleep 0.1
        cli_action("onehost delete test01")
        cli_action("onehost delete test02")
    end

   #  * resched <range|vmid_list>
   #      Sets the rescheduling flag for the VM.
   #
   #      States: RUNNING

   # * unresched <range|vmid_list>
   #      Clears the rescheduling flag for the VM.
   #
   #      States: RUNNING

    it "should create a VM and set/unset the rescheduling flag" do
        @vmid = cli_create("onevm create --name testvm --memory 128 --cpu 1")
        vm = VM.new(@vmid)

        expect(is_resched?("testvm")).to eql(false)

        cli_action("onevm resched testvm", false)

        cli_action("onevm deploy #{@vmid} 0")

        vm.running?

        cli_action("onevm resched testvm")

        expect(is_resched?("testvm")).to eql(true)

        cli_action("onevm unresched testvm")

        expect(is_resched?("testvm")).to eql(false)
    end

    it "should clear resched flag after stop" do
        vm = VM.new(@vmid)
        cli_action("onevm resched testvm")

        cli_action("onevm stop testvm")
        vm.state?("STOPPED")

        expect(is_resched?("testvm")).to eql(false)
    end

    it "should clear resched flag after migration" do
        vm = VM.new(@vmid)

        cli_action("onevm resume testvm")
        vm.state?("PENDING")

        cli_action("onevm deploy #{@vmid} 0")
        vm.running?

        cli_action("onevm resched testvm")
        expect(is_resched?("testvm")).to eql(true)

        cli_action("onevm migrate testvm 1")
        vm.running?

        expect(is_resched?("testvm")).to eql(false)

        cli_action("onevm resched testvm")
        expect(is_resched?("testvm")).to eql(true)

        cli_action("onevm migrate --live testvm 0")
        vm.running?

        expect(is_resched?("testvm")).to eql(false)
    end

    it "should clear resched flag after suspend" do
        vm = VM.new(@vmid)

        cli_action("onevm resched testvm")
        expect(is_resched?("testvm")).to eql(true)

        cli_action("onevm suspend testvm")

        vm.state?("SUSPENDED")

        expect(is_resched?("testvm")).to eql(false)
    end

    it "should clear resched flag after reboot" do
        vm = VM.new(@vmid)

        cli_action("onevm resume testvm")
        vm.running?

        cli_action("onevm resched testvm")
        expect(is_resched?("testvm")).to eql(true)

        cli_action("onevm reboot testvm")
        expect(is_resched?("testvm")).to eql(false)
    end

    it "should not allow a regular user to change the resched attribute" do
        cli_create_user("uA", "abc")
        vid = 0

        as_user "uA" do
            vid = cli_create("onevm create --name uservm --memory 128 --cpu 1")
        end

        cli_action("onevm deploy #{vid} 0")

        vm = VM.new(vid)
        vm.running?

        as_user "uA" do
            cli_action("onevm resched uservm", false)

            expect(is_resched?("uservm")).to eql(false)

            cli_action("onevm unresched testvm", false)

            expect(is_resched?("uservm")).to eql(false)

            cli_action("onevm terminate --hard uservm")
        end
    end
end
