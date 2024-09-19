
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Datastore scheduling requirements tests" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    #---------------------------------------------------------------------------
    # Helper functions for the tests
    #---------------------------------------------------------------------------
    def build_template(requirements)
        template = <<-EOF
            NAME = testvm
            CPU  = 0.1
            MEMORY = 128
            SCHED_DS_REQUIREMENTS = "#{requirements}"
        EOF
    end

    def vm_with_requirements(requirements)
        vmid = cli_create("onevm create", build_template(requirements))

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

        cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy", true)
        cli_update("onedatastore update system", "TM_MAD=dummy\nDS_MAD=dummy", true)

        5.times { |i|
            ids << cli_create("onehost create host#{i} --im dummy --vm dummy")

            template=<<-EOF
              NAME   = ds#{i}
              TM_MAD = dummy
              TYPE   = system_ds
            EOF

            @ds_ids["ds#{i}"] = cli_create("onedatastore create", template)
        }

        ids.each { |i|
            host = Host.new(i)
            host.monitored?
        }

        cli_update("onedatastore update 1","COMPATIBLE_SYS_DS=\"#{@ds_ids["ds2"]}\"", true)
    end

    after(:all) do
        5.times { |i|
            cli_action("onehost delete host#{i}")
            cli_action("onedatastore delete ds#{i}")
        }
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should allocate a VM using base attributes" do
        vmid, vm = vm_with_requirements("NAME=ds4")

        expect(datastore(vm)).to eq("104")

        vm.terminate_hard
    end

    it "should allocate a VM using template attributes" do
        cli_update("onedatastore update ds3", "VAR=abc", true)
        cli_update("onedatastore update ds4", "VAR=abcdef", true)

        vmid1, vm1 = vm_with_requirements("VAR=abc")
        vmid2, vm2 = vm_with_requirements("VAR=\\\"ab*\\\" & VAR!=\\\"*def\\\"")

        expect(datastore(vm1)).to eq("103")
        expect(datastore(vm2)).to eq("103")

        vm1.terminate_hard
        vm2.terminate_hard
    end

    it "should allocate a VM using template integer attributes" do
        cli_update("onedatastore update ds2", "CUSTOM_NUM=0", true)
        cli_update("onedatastore update ds4", "CUSTOM_NUM=8", true)

        vmid1, vm1 = vm_with_requirements("CUSTOM_NUM=0")
        vmid2, vm2 = vm_with_requirements("CUSTOM_NUM>4")

        expect(datastore(vm1)).to eq("102")
        expect(datastore(vm2)).to eq("104")

        vm1.terminate_hard
        vm2.terminate_hard
    end

    it "should allocate a VM using integer attributes, when types do not match" do
        cli_update("onedatastore update ds0", "TYPE_TEST=something", true)
        cli_update("onedatastore update ds4", "TYPE_TEST=23.5", true)

        vmid1, vm1 = vm_with_requirements("TYPE_TEST!=12345")
        vmid2, vm2 = vm_with_requirements("TYPE_TEST!=12345")

        expect(datastore(vm1)).to eq("104")
        expect(datastore(vm2)).to eq("104")

        vm1.terminate_hard
        vm2.terminate_hard
    end

    it "should allocate a VM using template float attributes" do
        cli_update("onedatastore update ds0", "CUSTOM_FLOAT=0.5", true)
        cli_update("onedatastore update ds4", "CUSTOM_FLOAT=2", true)

        vmid1, vm1 = vm_with_requirements("CUSTOM_FLOAT=0.5")
        vmid2, vm2 = vm_with_requirements("CUSTOM_FLOAT>0.5")

        expect(datastore(vm1)).to eq("100")
        expect(datastore(vm2)).to eq("104")

        vm1.terminate_hard
        vm2.terminate_hard
    end

    it "should check the scheduler sets a message on impossible requirements" do

        vmid = cli_create("onevm create",
                          build_template("NAME = ds0 & NAME != ds0"))
        vm = VM.new(vmid)

        wait_loop(:success => false, :timeout => 30) {
            vm.info['USER_TEMPLATE/SCHED_MESSAGE'].nil?
        }

        vm.terminate_hard
    end

    it "should schedule a datastore in multiple clusters" do
        cid1 = cli_create("onecluster create ds_cluster1")
        cid2 = cli_create("onecluster create ds_cluster2")
        cid3 = cli_create("onecluster create ds_cluster3")

        cli_action("onecluster adddatastore ds_cluster1 #{@ds_ids["ds0"]}")
        cli_action("onecluster adddatastore ds_cluster2 #{@ds_ids["ds0"]}")
        cli_action("onecluster adddatastore ds_cluster3 #{@ds_ids["ds0"]}")

        vmid1, vm1 = vm_with_requirements("\\\"CLUSTERS/ID\\\" @> #{cid2}")

        expect(datastore(vm1)).to eq("#{@ds_ids["ds0"]}")

        vm1.terminate_hard
    end

    it "should schedule a vm with restricted datastores" do
        iid = cli_create("oneimage create --name test_img --size 100 --type datablock -d default")

        template = <<-EOF
            NAME = testvm
            CPU  = 0.1
            MEMORY = 128
            DISK=[IMAGE_ID=#{iid}]
        EOF

        vmid = cli_create("onevm create", template)

        vm = VM.new(vmid)

        vm.running?

        expect(datastore(vm)).to eq("#{@ds_ids["ds2"]}")

        cli_action("onevm recover --delete #{vmid}")
    end

    it "should schedule a VM with disk exceeding DS size, using LIMIT_MB for DS" do
        vmid = cli_create('onevm create', <<-EOF)
            NAME = testvm_huge_disk
            CPU  = 0.1
            MEMORY = 128
            DISK = [ TYPE=FS, SIZE=5000000 ]
        EOF

        vm = VM.new(vmid)

        # Fail to deploy, not enough DS capacity
        wait_loop(:success => false, :timeout => 30) {
            vm.info['USER_TEMPLATE/SCHED_MESSAGE'].nil?
        }

        # Set LIMIT_MB to overcommit datastore
        cli_update('onedatastore update ds1', 'LIMIT_MB=9000000', true)

        vm.running?

        vm.terminate_hard
    end

end
