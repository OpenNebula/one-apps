
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Scheduling rank tests" do
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
            SCHED_RANK = "#{rank}"
        EOF

        template << "\nSCHED_REQUIREMENTS = \"#{reqs}\"\n" if !reqs.empty?

        return template
    end

    def build_template_with_nic(nic_rank, nic_reqs)
        template = <<-EOF
            NAME = testvm
            CPU  = 0.1
            MEMORY = 128
            NIC = [ NETWORK_MODE = "auto"
        EOF

        template << ",\nSCHED_REQUIREMENTS = \"#{nic_reqs}\"" if !nic_reqs.empty?

        template << ",\nSCHED_RANK = \"#{nic_rank}\"" if !nic_rank.empty?

        template << "]"

        return template
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

    def vm_with_rank_reqs(rank, reqs)
        vmid = cli_create("onevm create", build_template(rank, reqs))

        vm = VM.new(vmid)

        vm.running?

        return vmid, vm
    end

    def vm_with_nic_rank_reqs(nic_rank, nic_reqs)
        vmid = cli_create("onevm create", build_template_with_nic(nic_rank, nic_reqs))

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
        @net_id_2 = cli_create("onevnet create", build_vnet_template("test_vnet_2", 2, "INBOUND_AVG_BW=1200"))
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
        vmid, vm = vm_with_rank_reqs("-ID","")

        expect(vm.hostname).to eq("host0")

        vm.terminate
    end

    it "should allocate a VM using template integer attributes" do
        cli_update("onehost update host2", "CUSTOM_NUM=5", true)
        cli_update("onehost update host4", "CUSTOM_NUM=2", true)

        vmid1, vm1 = vm_with_rank_reqs("CUSTOM_NUM", "CUSTOM_NUM != 0")
        vmid2, vm2 = vm_with_rank_reqs("-CUSTOM_NUM", "CUSTOM_NUM != 0")

        expect(vm1.hostname).to eq("host2")
        expect(vm2.hostname).to eq("host4")

        vm1.terminate
        vm2.terminate
    end

    it "should allocate a VM using integer attributes, when types do not match" do
        cli_update("onehost update host0", "TYPE_TEST=something", true)
        cli_update("onehost update host4.one.org", "TYPE_TEST=0.5", true)

        vmid1, vm1 = vm_with_rank_reqs("TYPE_TEST", "")

        expect(vm1.hostname).to eq("host4.one.org")

        vm1.terminate
    end

    it "should allocate a VM using template float attributes" do
        cli_update("onehost update host3", "CUSTOM_FLOAT=0.5", true)
        cli_update("onehost update host0", "CUSTOM_FLOAT=2", true)

        vmid1, vm1 = vm_with_rank_reqs("-CUSTOM_FLOAT", "CUSTOM_FLOAT!=0.0")
        vmid2, vm2 = vm_with_rank_reqs("CUSTOM_FLOAT", "CUSTOM_FLOAT!=0.0")

        expect(vm1.hostname).to eq("host3")
        expect(vm2.hostname).to eq("host0")

        vm1.terminate
        vm2.terminate
    end

    it "should allocate a VM using cluster template attributes" do
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


        vmid1, vm1 = vm_with_rank_reqs("-CUSTOM_ATT_REQ", "CUSTOM_ATT_REQ!=0")
        vmid2, vm2 = vm_with_rank_reqs("CUSTOM_ATT_REQ", "CUSTOM_ATT_REQ=2")
        vmid3, vm3 = vm_with_rank_reqs("CUSTOM_ATT_REQ", "CUSTOM_ATT_REQ!=0")

        expect(vm1.hostname).to eq("host0")
        expect(vm2.hostname).to eq("host1")
        expect(vm3.hostname).to eq("host2")

        vm1.terminate
        vm2.terminate
        vm3.terminate
    end

    it "should allocate a VM with nic using default policy" do
        tmpl_vm=<<-EOF
            NAME = testvm
            CPU  = 0.1
            MEMORY = 128
            NIC = [ NETWORK_MODE = "auto"]
        EOF

        vm_id1 = cli_create("onevm create", tmpl_vm)
        vm1 = VM.new(vm_id1)
        vm1.running?

        vm_id2 = cli_create("onevm create", tmpl_vm)
        vm2 = VM.new(vm_id2)
        vm2.running?

        vm_id3 = cli_create("onevm create", tmpl_vm)
        vm3 = VM.new(vm_id3)
        vm3.running?

        expect(vm1.vnet_id(0)).not_to eq(vm2.vnet_id(0))
        expect(vm1.vnet_id(0)).not_to eq(vm3.vnet_id(0))
        expect(vm2.vnet_id(0)).not_to eq(vm3.vnet_id(0))

        vm1.terminate
        vm2.terminate
        vm3.terminate
    end

    it "should allocate a VM with nic using USED_LEASES" do

        tmpl_vm=<<-EOF
            NAME = testvm
            CPU  = 0.1
            MEMORY = 128
            NIC = [ NETWORK_ID = #{@net_id_1}]
            NIC = [ NETWORK_ID = #{@net_id_1}]
            NIC = [ NETWORK_ID = #{@net_id_2}]
        EOF
        vm_id = cli_create("onevm create", tmpl_vm)

        vm = VM.new(vm_id)

        vm.running?

        vmid1, vm1 = vm_with_nic_rank_reqs("-USED_LEASES", "")
        vmid2, vm2 = vm_with_nic_rank_reqs("USED_LEASES", "")

        expect(vm1.vnet_id(0)).to eq("#{@net_id_3}")
        expect(vm2.vnet_id(0)).to eq("#{@net_id_1}")

        vm1.terminate
        vm2.terminate
        vm.terminate
    end

    it "should allocate a VM with mixed NICs (AUTO and Not AUTO)" do

        tmpl= <<-EOF
            NAME = testvm
            CPU  = 0.1
            MEMORY = 128
            NIC = [ NETWORK_MODE = "auto",
                SCHED_RANK = "-USED_LEASES"]
            NIC = [ NETWORK_ID = #{@net_id_2}]
            NIC = [ NETWORK_ID = #{@net_id_1}]
        EOF

        vm_id = cli_create("onevm create", tmpl)

        vm = VM.new(vm_id)

        vm.running?

        expect(vm.vnet_id(0)).to eq("#{@net_id_3}")

        vm.terminate
    end

    it "should allocate a VM with differents ranks" do

        tmpl= <<-EOF
            NAME = testvm
            CPU  = 0.1
            MEMORY = 128
            NIC = [ NETWORK_MODE = "auto",
                SCHED_RANK = "-INBOUND_AVG_BW"]
            NIC = [ NETWORK_MODE = "auto",
                SCHED_RANK = "INBOUND_AVG_BW"]
        EOF

        vm_id = cli_create("onevm create", tmpl)

        vm = VM.new(vm_id)

        vm.running?

        expect(vm.vnet_id(0)).to eq("#{@net_id_2}")
        expect(vm.vnet_id(1)).to eq("#{@net_id_3}")

        vm.terminate
    end
end
