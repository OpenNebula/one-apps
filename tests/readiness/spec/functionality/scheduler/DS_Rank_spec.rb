
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Datastore scheduling rank tests" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    #---------------------------------------------------------------------------
    # Helper functions for the tests
    #---------------------------------------------------------------------------
    def build_template(rank, reqs)
        template = <<-EOF
            NAME = testvm
            CPU  = 0.1
            MEMORY = 128
            SCHED_DS_RANK = "#{rank}"
        EOF

        template << "\nSCHED_DS_REQUIREMENTS = \"#{reqs}\"\n" if !reqs.empty?

        return template
    end

    def vm_with_rank_reqs(rank, reqs)
        vmid = cli_create("onevm create", build_template(rank, reqs))

        vm = VM.new(vmid)

        vm.running?

        return vmid, vm
    end

    def datastore(vm)
        vm.xml['HISTORY_RECORDS/HISTORY[last()]/DS_ID']
    end

    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        ids     = []
        @ds_ids = {}

        5.times { |i|
            ids << cli_create("onehost create host#{i} --im dummy --vm dummy")

            template=<<-EOF
              NAME   = ds#{i}
              TM_MAD = dummy
              TYPE   = system_ds
            EOF

            @ds_ids["ds#{i}"] = cli_create("onedatastore create", template)
        }

        mads = "TM_MAD=dummy\nDS_MAD=dummy"

        cli_update("onedatastore update system", mads, false)
        cli_update("onedatastore update default", mads, false)

        wait_loop() {
                xml = cli_action_xml("onedatastore show -x 0")
                xml['FREE_MB'].to_i > 0
        }

        ids.each { |i|
            wait_loop() {
                xml = cli_action_xml("onedatastore show -x ds#{i}")
                xml['FREE_MB'].to_i > 0
            }
            host = Host.new(i)
            host.monitored?
        }
    end

    # after(:all) do
    #     5.times { |i|
    #         cli_action("onehost delete host#{i}")
    #         cli_action("onedatastore delete ds#{i}")
    #     }
    # end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should allocate a VM in a suitable resource using base attributes" do
        vmid, vm = vm_with_rank_reqs("-ID", "")

        expect(datastore(vm)).to eq("0")

        vm.terminate_hard
    end

    it "should allocate a VM using template integer attributes" do
        cli_update("onedatastore update ds2", "CUSTOM_NUM=5", true)
        cli_update("onedatastore update ds4", "CUSTOM_NUM=2", true)

        vmid1, vm1 = vm_with_rank_reqs("CUSTOM_NUM", "CUSTOM_NUM != 0")
        vmid2, vm2 = vm_with_rank_reqs("-CUSTOM_NUM", "CUSTOM_NUM != 0")

        expect(datastore(vm1)).to eq("102")
        expect(datastore(vm2)).to eq("104")

        vm1.terminate_hard
        vm2.terminate_hard
    end

    it "should allocate a VM using integer attributes, when types do not match" do
        cli_update("onedatastore update ds2", "TYPE_TEST=something", true)
        cli_update("onedatastore update ds4", "TYPE_TEST=0.5", true)

        vmid1, vm1 = vm_with_rank_reqs("TYPE_TEST", "")

        expect(datastore(vm1)).to eq("104")

        vm1.terminate_hard
    end

    it "should allocate a VM using float attributes" do
        cli_update("onedatastore update ds3", "CUSTOM_FLOAT=0.5", true)
        cli_update("onedatastore update ds0", "CUSTOM_FLOAT=2", true)

        vmid1, vm1 = vm_with_rank_reqs("-CUSTOM_FLOAT", "CUSTOM_FLOAT!=0.0")
        vmid2, vm2 = vm_with_rank_reqs("CUSTOM_FLOAT", "CUSTOM_FLOAT!=0.0")

        expect(datastore(vm1)).to eq("103")
        expect(datastore(vm2)).to eq("100")

        vm1.terminate_hard
        vm2.terminate_hard
    end
end

