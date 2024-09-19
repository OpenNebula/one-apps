
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Scheduling requirements tests" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    def build_template(requirements)
        template = <<-EOF
            NAME = testvm
            CPU  = 0.1
            MEMORY = 128
            SCHED_REQUIREMENTS = "#{requirements}"
        EOF
    end

    def build_template_with_vnet(requirements)
        template = <<-EOF
            NAME = testvm
            CPU  = 0.1
            MEMORY = 128
            NIC = [
                NETWORK_MODE = "auto",
                SCHED_REQUIREMENTS = "#{requirements}"
            ]
        EOF
    end

    def build_vnet_template(name, size, extra_attributes)
        template = <<-EOF
            NAME = #{name}
            BRIDGE = br0
            VN_MAD = dummy
            AR=[TYPE = "IP4", IP = "10.0.0.10", SIZE = "#{size}" ]
            #{extra_attributes}
        EOF
    end

    def vm_with_requirements(requirements)
        vmid = cli_create("onevm create", build_template(requirements))

        vm = VM.new(vmid)

        vm.running?

        return vmid, vm
    end

    def vm_with_vnet_requirements(requirements)
        vmid = cli_create("onevm create", build_template_with_vnet(requirements))

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
        ids = []
        5.times { |i|
            ids << cli_create("onehost create host#{i} --im dummy --vm dummy")
            ids << cli_create("onehost create host#{i}.one.org --im dummy --vm dummy")
        }

        ids.each { |i|
            host = Host.new(i)
            host.monitored?
        }

        mads = "TM_MAD=dummy\nDS_MAD=dummy"

        cli_update("onedatastore update system", mads, false)
        cli_update("onedatastore update default", mads, false)

        @net_id_1 = cli_create("onevnet create", build_vnet_template("test_vnet", 3, "INBOUND_AVG_BW=1500"))
        @net_id_2 = cli_create("onevnet create", build_vnet_template("test_vnet_2", 1, "INBOUND_AVG_BW=1200"))
        @net_id_3 = cli_create("onevnet create", build_vnet_template("test_vnet_3", 4, "INBOUND_AVG_BW=1600"))
    end

    after(:all) do
        5.times { |i|
            cli_action("onehost delete host#{i}")
            cli_action("onehost delete host#{i}.one.org")
        }
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should allocate a VM using base attributes" do
        vmid, vm = vm_with_requirements("NAME=host4")

        expect(vm.hostname).to eq("host4")

        vm.terminate_hard
    end

    it "should allocate a VM using template attributes" do
        vmid1, vm1 = vm_with_requirements("HOSTNAME=host3")
        vmid2, vm2 = vm_with_requirements(
            "HOSTNAME=\\\"host3*\\\" & HOSTNAME!=\\\"*.one.org\\\"")

        expect(vm1.hostname).to eq("host3")
        expect(vm2.hostname).to eq("host3")

        vm1.terminate_hard
        vm2.terminate_hard
    end

    it "should allocate a VM using template integer attributes" do
        cli_update("onehost update host2", "CUSTOM_NUM=0", true)
        cli_update("onehost update host4", "CUSTOM_NUM=8", true)

        vmid1, vm1 = vm_with_requirements("CUSTOM_NUM=0")
        vmid2, vm2 = vm_with_requirements("CUSTOM_NUM>4")

        expect(vm1.hostname).to eq("host2")
        expect(vm2.hostname).to eq("host4")

        vm1.terminate_hard
        vm2.terminate_hard
    end

    it "should allocate a VM using integer attributes, when types do not match" do
        cli_update("onehost update host0", "TYPE_TEST=something", true)
        cli_update("onehost update host4.one.org", "TYPE_TEST=23.5", true)

        vmid1, vm1 = vm_with_requirements("TYPE_TEST!=12345")
        vmid2, vm2 = vm_with_requirements("TYPE_TEST!=12345")

        expect(vm1.hostname).to eq("host4.one.org")
        expect(vm2.hostname).to eq("host4.one.org")

        vm1.terminate_hard
        vm2.terminate_hard
    end

    it "should allocate a VM using template float attributes" do
        cli_update("onehost update host3", "CUSTOM_FLOAT=0.5", true)
        cli_update("onehost update host0", "CUSTOM_FLOAT=2", true)

        vmid1, vm1 = vm_with_requirements("CUSTOM_FLOAT=0.5")
        vmid2, vm2 = vm_with_requirements("CUSTOM_FLOAT>0.5")

        expect(vm1.hostname).to eq("host3")
        expect(vm2.hostname).to eq("host0")

        vm1.terminate_hard
        vm2.terminate_hard
    end

    it "should allocate a VM in using cluster template attributes" do
        # Host 0: HOST/TEMPLATE/CUSTOM_ATT_REQ = 1
        # Host 1 in cluster A: CLUSTER/TEMPLATE/CUSTOM_ATT_REQ = 2
        # Host 2 in cluster A, but with attribute in host template:
        # HOST/TEMPLATE/CUSTOM_ATT_REQ = 3

        cli_create("onecluster create a")

        template=<<-EOF
          NAME   = system_A
          TM_MAD = dummy
          TYPE   = system_ds
        EOF

        cli_create("onedatastore create --cluster a", template)

        cli_action("onecluster addhost a host1")
        cli_action("onecluster addhost a host2")

        cli_update("onehost update host0", "CUSTOM_ATT_REQ=1", true)
        cli_update("onehost update host2", "CUSTOM_ATT_REQ=3", true)
        cli_update("onecluster update a", "CUSTOM_ATT_REQ=2", true)

        vmid1, vm1 = vm_with_requirements("CUSTOM_ATT_REQ=1")
        vmid2, vm2 = vm_with_requirements("CUSTOM_ATT_REQ=2")
        vmid3, vm3 = vm_with_requirements("CUSTOM_ATT_REQ=3")

        expect(vm1.hostname).to eq("host0")
        expect(vm2.hostname).to eq("host1")
        expect(vm3.hostname).to eq("host2")

        vm1.terminate_hard
        vm2.terminate_hard
        vm3.terminate_hard
    end

    it "should reschedule a host" do
        vmid1, vm1 = vm_with_requirements("HOSTNAME=host3")

        expect(vm1.hostname).to eq("host3")

        vmid2, vm2 = vm_with_requirements("HOSTNAME=host3 | HOSTNAME=host4")

        expect(vm2.hostname).to eq("host4")

        cli_action("onevm resched #{vmid2}")

        wait_loop(:success => "host3", :timeout => 30) {
            vm2.info
            vm2.hostname
        }

        vm2.running?

        vm1.terminate_hard
        vm2.terminate_hard
    end

    it "should edit the requirements, and resched the VM" do

        cli_action("onecluster addhost a host2.one.org")
        cli_action("onecluster addvnet a test_vnet")
        cli_action("onecluster adddatastore a system")

        vmid1, vm1 = vm_with_requirements("NAME=host2")

        expect(vm1.hostname).to eq("host2")

        cli_update("onevm update #{vmid1}",
                   'SCHED_REQUIREMENTS="NAME=\\"host2.one.org\\""', true)

        cli_action("onevm resched #{vmid1}")

        wait_loop(:success => "host2.one.org", :timeout => 30) {
            vm1.info
            vm1.hostname
        }

        vm1.running?

        vm1.terminate_hard
    end

    it "should deploy a VM in the same Host where other one is running" do
        vmid1 = cli_create("onevm create --hold", build_template("NAME=host0"))
        vmid2 = cli_create("onevm create", build_template("CURRENT_VMS=#{vmid1}"))

        cli_action("onevm release #{vmid1}")

        vm1 = VM.new(vmid1)
        vm2 = VM.new(vmid2)

        vm1.running?
        vm2.running?

        expect(vm1.hostname).to eq("host0")
        expect(vm2.hostname).to eq("host0")

        vm1.terminate_hard
        vm2.terminate_hard
    end

    it "should deploy a VM in a Host different to where other one is running" do
        cli_update("onehost update host2", "CUSTOM_NUM=5", true)
        cli_update("onehost update host4", "CUSTOM_NUM=2", true)

        t = build_template("CUSTOM_NUM != 0")
        t << "\nSCHED_RANK=CUSTOM_NUM\n"

        vmid1 = cli_create("onevm create", t)

        t = build_template("CUSTOM_NUM != 0 & CURRENT_VMS != #{vmid1}")
        t << "\nSCHED_RANK=CUSTOM_NUM\n"

        vmid2 = cli_create("onevm create --hold", t)

        vm1 = VM.new(vmid1)
        vm2 = VM.new(vmid2)

        vm1.running?

        cli_action("onevm release #{vmid2}")

        vm2.running?

        expect(vm1.hostname).to eq("host2")
        expect(vm2.hostname).to eq("host4")

        vm1.terminate_hard
        vm2.terminate_hard
    end

    it "should check the scheduler sets a message on impossible requirements" do
        vmid = cli_create("onevm create --hold",
                          build_template("NAME = host0 & NAME != host0"))
        vm   = VM.new(vmid)

        expect(vm.info['USER_TEMPLATE/SCHED_MESSAGE']).to be_nil

        cli_action("onevm release #{vmid}")

        wait_loop(:success => false, :timeout => 5) {
            vm.info['USER_TEMPLATE/SCHED_MESSAGE'].nil?
        }

        vm.terminate_hard
    end

    it "should create a vms with differents requirements" do
        vm_id, vm = vm_with_vnet_requirements("INBOUND_AVG_BW>1500")

        expect(vm.vnet_id("0")).to eq("#{@net_id_3}") #this vnet has 1600

        vm.terminate_hard

        vm_id, vm = vm_with_vnet_requirements("INBOUND_AVG_BW<1500")

        expect(vm.vnet_id("0")).to eq("#{@net_id_2}") #this vnet has 1200

        vm.terminate_hard

        vm_id, vm = vm_with_vnet_requirements("INBOUND_AVG_BW<1600 & INBOUND_AVG_BW>1200")

        expect(vm.vnet_id("0")).to eq("#{@net_id_1}") #this vnet has 1500

        vm.terminate_hard
    end

    it "should create a vms with imposible requirements" do
        vmid = cli_create("onevm create --hold",
            build_template("INBOUND_AVG_BW < 1200"))
        vm   = VM.new(vmid)

        expect(vm.info['USER_TEMPLATE/SCHED_MESSAGE']).to be_nil

        cli_action("onevm release #{vmid}")

        wait_loop(:success => false, :timeout => 5) {
        vm.info['USER_TEMPLATE/SCHED_MESSAGE'].nil?
        }

        vm.terminate_hard

        vmid = cli_create("onevm create --hold",
            build_template("INBOUND_AVG_BW < 1500 & NAME != test_vnet_2"))
        vm   = VM.new(vmid)

        expect(vm.info['USER_TEMPLATE/SCHED_MESSAGE']).to be_nil

        cli_action("onevm release #{vmid}")

        wait_loop(:success => false, :timeout => 5) {
        vm.info['USER_TEMPLATE/SCHED_MESSAGE'].nil?
        }

        vm.terminate_hard
    end

    it "should create a vm with nics with differents modes" do
        template = <<-EOF
            NAME = testvm
            CPU  = 0.1
            MEMORY = 128
            NIC = [
                NETWORK_MODE = "auto"
            ]
            NIC = [
                NETWORK_ID = "#{@net_id_1}"
            ]
        EOF

        vmid = cli_create("onevm create", template)
        vm   = VM.new(vmid)

        vm.running?

        expect(vm.vnet_id("1")).to eq("#{@net_id_1}")

        vm.terminate_hard
    end

    it "should create a vm with nics with differents requirements" do
        template = <<-EOF
            NAME = testvm
            CPU  = 0.1
            MEMORY = 128
            NIC = [
                NETWORK_MODE = "auto",
                SCHED_REQUIREMENTS = "INBOUND_AVG_BW>1500"
            ]
            NIC = [
                NETWORK_MODE = "auto",
                SCHED_REQUIREMENTS = "INBOUND_AVG_BW<1500"
            ]
            NIC = [
                NETWORK_MODE = "auto",
                SCHED_REQUIREMENTS = "INBOUND_AVG_BW<1600 & INBOUND_AVG_BW>1200"
            ]
        EOF

        vmid = cli_create("onevm create", template)
        vm   = VM.new(vmid)

        vm.running?

        expect(vm.vnet_id("0")).to eq("#{@net_id_3}")

        expect(vm.vnet_id("1")).to eq("#{@net_id_2}")

        expect(vm.vnet_id("2")).to eq("#{@net_id_1}")

        vm.terminate_hard
    end


    it "should create a vm that can not be picket in a single vnet" do
        template = <<-EOF
            NAME = testvm
            CPU  = 0.1
            MEMORY = 128
            NIC = [
                NETWORK_MODE = "auto",
                SCHED_REQUIREMENTS = "INBOUND_AVG_BW<1600 & INBOUND_AVG_BW>1200"
            ]
            NIC = [
                NETWORK_MODE = "auto",
                SCHED_REQUIREMENTS = "INBOUND_AVG_BW<1600 & INBOUND_AVG_BW>1200"
            ]
            NIC = [
                NETWORK_MODE = "auto",
                SCHED_REQUIREMENTS = "INBOUND_AVG_BW<1600 & INBOUND_AVG_BW>1200"
            ]
            NIC = [NETWORK_MODE = "auto"]
            NIC = [NETWORK_MODE = "auto"]
            NIC = [NETWORK_MODE = "auto"]
            NIC = [NETWORK_MODE = "auto"]
            NIC = [NETWORK_MODE = "auto"]
        EOF

        vmid = cli_create("onevm create", template)
        vm   = VM.new(vmid)

        vm.running?

        expect(vm.vnet_id("0")).to eq("#{@net_id_1}")

        expect(vm.vnet_id("1")).to eq("#{@net_id_1}")

        expect(vm.vnet_id("2")).to eq("#{@net_id_1}")

        expect(vm.vnet_id("3")).not_to eq("#{@net_id_1}")

        expect(vm.vnet_id("4")).not_to eq("#{@net_id_1}")

        template = <<-EOF
            NAME = testvm
            CPU  = 0.1
            MEMORY = 128
            NIC = [NETWORK_MODE = "auto"]
            NIC = [NETWORK_MODE = "auto"]
            NIC = [NETWORK_MODE = "auto"]
        EOF

        vmid2 = cli_create("onevm create", template)
        vm2   = VM.new(vmid2)

        wait_loop(:success => false, :timeout => 30) {
            vm2.info['USER_TEMPLATE/SCHED_MESSAGE'].nil?
        }

        expect(vm2.info['USER_TEMPLATE/SCHED_MESSAGE']).to match(/Cannot dispatch VM/)

        vm2.terminate_hard

        vm.terminate_hard
    end


    it "should create a vm that can not be picket in a single vnet" do
        template = <<-EOF
            NAME = testvm
            CPU  = 0.1
            MEMORY = 128
            NIC = [
                NETWORK_MODE = "auto",
                SCHED_REQUIREMENTS = "INBOUND_AVG_BW<1600 & INBOUND_AVG_BW>1200"
            ]
            NIC = [
                NETWORK_MODE = "auto",
                SCHED_REQUIREMENTS = "INBOUND_AVG_BW<1600 & INBOUND_AVG_BW>1200"
            ]
            NIC = [
                NETWORK_MODE = "auto",
                SCHED_REQUIREMENTS = "INBOUND_AVG_BW<1600 & INBOUND_AVG_BW>1200"
            ]
            NIC = [
                NETWORK_MODE = "auto",
                SCHED_REQUIREMENTS = "INBOUND_AVG_BW<1600 & INBOUND_AVG_BW>1200"
            ]
        EOF

        vmid = cli_create("onevm create", template)
        vm   = VM.new(vmid)

        wait_loop(:success => false, :timeout => 30) {
            vm.info['USER_TEMPLATE/SCHED_MESSAGE'].nil?
        }

        expect(vm.info['USER_TEMPLATE/SCHED_MESSAGE']).to match(/Cannot dispatch VM/)

        template = <<-EOF
            NAME = testvm
            CPU  = 0.1
            MEMORY = 128
            NIC = [
                NETWORK_MODE = "auto",
                SCHED_REQUIREMENTS = "INBOUND_AVG_BW<1600 & INBOUND_AVG_BW>1200"
            ]
            NIC = [
                NETWORK_MODE = "auto",
                SCHED_REQUIREMENTS = "INBOUND_AVG_BW<1600 & INBOUND_AVG_BW>1200"
            ]
            NIC = [
                NETWORK_MODE = "auto",
                SCHED_REQUIREMENTS = "INBOUND_AVG_BW<1600 & INBOUND_AVG_BW>1200"
            ]
        EOF

        vmid2 = cli_create("onevm create", template)
        vm2   = VM.new(vmid2)

        vm2.running?

        vm.terminate_hard

        vm2.terminate_hard
    end
end

