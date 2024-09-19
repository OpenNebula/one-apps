
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Re-scheduling tests" do
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
        ids = []
        2.times { |i|
            ids << cli_create("onehost create host#{i} --im dummy --vm dummy")
        }

        ids.each { |i|
            host = Host.new(i)
            host.monitored?
        }

        mads = "TM_MAD=dummy\nDS_MAD=dummy"

        cli_update("onedatastore update system", mads, false)
        cli_update("onedatastore update default", mads, false)
    end

    after(:all) do
        2.times { |i|
            cli_action("onehost delete host#{i}")
        }

        system("sed -i -e 's/delete-recreate/resched/' #{ONE_ETC_LOCATION}/cli/onehost.yaml")
    end

    before(:each) do
        cli_update("onehost update host0", "CUSTOM=1", true)
        cli_update("onehost update host1", "CUSTOM=0", true)

        template = <<-EOF
            NAME = testvm
            CPU  = 0.1
            MEMORY = 128
            SCHED_RANK = "CUSTOM"
        EOF

        @vmid = cli_create("onevm create", template)

        @vm = VM.new(@vmid)

        @vm.running?
    end

    after(:each) do
        @vm.running?
        @vm.terminate
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should reschedule a VM to a better host" do
        expect(@vm.hostname).to eq("host0")

        cli_update("onehost update host1", "CUSTOM=2", true)

        cli_action("onevm resched #{@vmid}")

        wait_loop(:success => "host1", :timeout => 5) {
            @vm.info
            @vm.hostname
        }
    end

    it "should reschedule a VM in poweroff state" do
        expect(@vm.hostname).to eq("host0")

        cli_update("onehost update host1", "CUSTOM=2", true)

        cli_action("onevm poweroff #{@vmid}")

        wait_loop()do
            xml = cli_action_xml("onevm show #{@vmid} -x")
            OpenNebula::VirtualMachine::VM_STATE[xml['STATE'].to_i] == 'POWEROFF'
        end

        cli_action("onevm resched #{@vmid}")

        wait_loop(:success => "host1", :timeout => 5) {
            @vm.info
            @vm.hostname
        }
        cli_action("onevm resume #{@vmid}")
    end

    it "should flush a Host, and check the VM migration and Host state with the two options of flush" do
        sched_action = 1
        delete_recreate_action = 14

        expect(@vm.hostname).to eq("host0")

        cli_action("onehost flush host0")

        wait_loop(:success => "host1", :timeout => 60) {
            @vm.info
            @vm.hostname
        }

        xml = cli_action_xml("onehost show -x host0")
        expect(OpenNebula::Host::HOST_STATES[xml['STATE'].to_i]).to eq("DISABLED")

        # check the action done is right
        vm_xml = cli_action_xml("onevm show -x #{@vmid}")
        last_seq = vm_xml.retrieve_elements("/VM/HISTORY_RECORDS/HISTORY/SEQ").size - 2
        expect(vm_xml["/VM/HISTORY_RECORDS/HISTORY[SEQ=#{last_seq}]/ACTION"].to_i).to eq(sched_action)

        # change the default action
        system("sed -i -e 's/resched/delete-recreate/' #{ONE_ETC_LOCATION}/cli/onehost.yaml")

        cli_action("onehost enable host0")
        cli_action("onehost flush host1")

        wait_loop(:success => "host0", :timeout => 60) {
            @vm.info
            @vm.hostname
        }

        # check the action done is right
        vm_xml = cli_action_xml("onevm show -x #{@vmid}")
        last_seq = vm_xml.retrieve_elements("/VM/HISTORY_RECORDS/HISTORY/SEQ").size - 2
        expect(vm_xml["/VM/HISTORY_RECORDS/HISTORY[SEQ=#{last_seq}]/ACTION"].to_i).to eq(delete_recreate_action)

        # Return back the default action
        system("sed -i -e 's/delete-recreate/resched/' #{ONE_ETC_LOCATION}/cli/onehost.yaml")
    end

    it "should flush a Host, and check the migration state with respect to COLD_MIGRATION_MODE" do
        migrate_poweroff_action = 48
        migrate_poweroff_hard_action = 49

        expect(@vm.hostname).to eq("host0")

        # change the COLD_MIGRATION_MODE
        system("sed -i -e 's/COLD_MIGRATE_MODE = 0/COLD_MIGRATE_MODE = 1/' #{ONE_ETC_LOCATION}/sched.conf")

        @one_test.stop_sched()
        @one_test.start_sched()

        cli_action("onehost enable host1")
        cli_action("onehost flush host0")

        wait_loop(:success => "host1", :timeout => 60) {
            @vm.info
            @vm.hostname
        }

        xml = cli_action_xml("onehost show -x host0")
        expect(OpenNebula::Host::HOST_STATES[xml['STATE'].to_i]).to eq("DISABLED")

        # check the action done is right
        vm_xml = cli_action_xml("onevm show -x #{@vmid}")
        last_seq = vm_xml.retrieve_elements("/VM/HISTORY_RECORDS/HISTORY/SEQ").size - 2
        expect(vm_xml["/VM/HISTORY_RECORDS/HISTORY[SEQ=#{last_seq}]/ACTION"].to_i).to eq(migrate_poweroff_action)

        # change the COLD_MIGRATION_MODE
        system("sed -i -e 's/COLD_MIGRATE_MODE = 1/COLD_MIGRATE_MODE = 2/' #{ONE_ETC_LOCATION}/sched.conf")

        @one_test.stop_sched()
        @one_test.start_sched()

        cli_action("onehost enable host0")
        cli_action("onehost flush host1")

        wait_loop(:success => "host0", :timeout => 60) {
            @vm.info
            @vm.hostname
        }

        # check the action done is right
        vm_xml = cli_action_xml("onevm show -x #{@vmid}")
        last_seq = vm_xml.retrieve_elements("/VM/HISTORY_RECORDS/HISTORY/SEQ").size - 2
        expect(vm_xml["/VM/HISTORY_RECORDS/HISTORY[SEQ=#{last_seq}]/ACTION"].to_i).to eq(migrate_poweroff_hard_action)
    end

end
