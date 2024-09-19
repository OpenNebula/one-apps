
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "NUMA scheduling tests" do
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

        cli_update("onehost update host01", "PIN_POLICY = PINNED", true)
        cli_update("onehost update host02", "PRIORITY = 2", true)

        mads = "TM_MAD=dummy\nDS_MAD=dummy"

        cli_update("onedatastore update system", mads, false)
        cli_update("onedatastore update default", mads, false)

        @template_1 = <<-EOF
            NAME = testvm1
            CPU  = 1
            MEMORY = 2048
            VCPU = 8
            TOPOLOGY = [ PIN_POLICY = "thread" ]
        EOF

        @template_2 = <<-EOF
            NAME = testvm2
            CPU  = 1
            MEMORY = 2048
            VCPU = 8
            TOPOLOGY = [ PIN_POLICY = "core", SOCKETS = 2 ]
        EOF

        @template_3 = <<-EOF
            NAME = testvm3
            CPU  = 1
            MEMORY = 1024
            VCPU = 4
            TOPOLOGY = [ PIN_POLICY = "thread" ]
        EOF

        @template_4 = <<-EOF
            NAME = testvm4
            CPU  = 1
            MEMORY = 1024
            VCPU = 2
            TOPOLOGY = [ PIN_POLICY = "core", SOCKETS = 2 ]
        EOF

        @template_5 = <<-EOF
            NAME = testvm5
            CPU  = 1
            MEMORY = 2048
            VCPU = 8
            TOPOLOGY = [ NODE_AFFINITY = "1" ]
        EOF

        @template_6 = <<-EOF
            NAME = testvm6
            CPU  = 1
            MEMORY = 1024
            VCPU = 8
            TOPOLOGY = [ NODE_AFFINITY = "1", HUGEPAGE_SIZE = 2 ]
        EOF

        @template_7 = <<-EOF
            NAME = testvm7
            CPU  = 1
            MEMORY = 1024
            VCPU = 8
            TOPOLOGY = [ HUGEPAGE_SIZE = 2 ]
        EOF
    end

    def expect_empty(hostname)
        host = cli_action_xml("onehost show #{hostname} -x")

        cores = host.retrieve_xmlelements('HOST_SHARE/NUMA_NODES/NODE/CORE')

        cores.each do |c|
            expect(c['FREE'].to_i).to eql 4
        end
    end

    after(:each) do
        expect_empty("host01")
        expect_empty("host02")
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should deploy a VM with a single NUMA_NODE" do
        vmid, vm = define_and_run(@template_1)

        expect(vm.hostname).to eq("host01")

        vm_xml = cli_action_xml("onevm show #{vmid} -x")

        nodes = vm_xml.retrieve_xmlelements('TEMPLATE/NUMA_NODE')

        expect(nodes.size).to eql 1

        expect(nodes[0]['MEMORY'].to_i).to eql 2048 * 1024
        expect(nodes[0]['TOTAL_CPUS'].to_i).to eql 8
        expect(nodes[0]['MEMORY_NODE_ID'].to_i).to eql 1
        expect(nodes[0]['NODE_ID'].to_i).to eql 1
        expect(nodes[0]['CPUS']).to eql "8,24,40,56,9,25,41,57"

        host = cli_action_xml("onehost show host01 -x")

        cores = host.retrieve_xmlelements('HOST_SHARE/NUMA_NODES/NODE/CORE')

        expect(cores[8]['CPUS']).to eql "8:0,24:0,40:0,56:0"
        expect(cores[8]['FREE'].to_i).to eql 0
        expect(cores[9]['CPUS']).to eql "9:0,25:0,41:0,57:0"
        expect(cores[9]['FREE'].to_i).to eql 0

        vm.terminate_hard

        vm.done?
    end

    it "should deploy a VM with multiple NUMA_NODEs" do
        vmid, vm = define_and_run(@template_2)

        expect(vm.hostname).to eq("host01")

        vm_xml = cli_action_xml("onevm show #{vmid}  -x")

        nodes = vm_xml.retrieve_xmlelements('TEMPLATE/NUMA_NODE')

        expect(nodes.size).to eql 2

        expect(nodes[0]['MEMORY'].to_i).to eql 1024 * 1024
        expect(nodes[0]['TOTAL_CPUS'].to_i).to eql 4
        expect(nodes[0]['MEMORY_NODE_ID'].to_i).to eql 1
        expect(nodes[0]['NODE_ID'].to_i).to eql 1
        expect(nodes[0]['CPUS']).to eql "8,9,10,11"

        expect(nodes[1]['MEMORY'].to_i).to eql 1024 * 1024
        expect(nodes[1]['TOTAL_CPUS'].to_i).to eql 4
        expect(nodes[1]['MEMORY_NODE_ID'].to_i).to eql 0
        expect(nodes[1]['NODE_ID'].to_i).to eql 0
        expect(nodes[1]['CPUS']).to eql "0,1,2,3"

        host = cli_action_xml("onehost show host01 -x")

        cores = host.retrieve_xmlelements('HOST_SHARE/NUMA_NODES/NODE/CORE')

        expect(cores[0]['CPUS']).to eql "0:1,16:-1,32:-1,48:-1"
        expect(cores[0]['FREE'].to_i).to eql 0
        expect(cores[1]['CPUS']).to eql "1:1,17:-1,33:-1,49:-1"
        expect(cores[1]['FREE'].to_i).to eql 0
        expect(cores[2]['CPUS']).to eql "2:1,18:-1,34:-1,50:-1"
        expect(cores[2]['FREE'].to_i).to eql 0
        expect(cores[3]['CPUS']).to eql "3:1,19:-1,35:-1,51:-1"
        expect(cores[3]['FREE'].to_i).to eql 0

        expect(cores[8]['CPUS']).to eql "8:1,24:-1,40:-1,56:-1"
        expect(cores[8]['FREE'].to_i).to eql 0
        expect(cores[9]['CPUS']).to eql "9:1,25:-1,41:-1,57:-1"
        expect(cores[9]['FREE'].to_i).to eql 0
        expect(cores[10]['CPUS']).to eql "10:1,26:-1,42:-1,58:-1"
        expect(cores[10]['FREE'].to_i).to eql 0
        expect(cores[11]['CPUS']).to eql "11:1,27:-1,43:-1,59:-1"
        expect(cores[11]['FREE'].to_i).to eql 0

        nodes = host.retrieve_xmlelements('HOST_SHARE/NUMA_NODES/NODE')

        expect(nodes[0]['MEMORY/USAGE']).to eql "1048576"
        expect(nodes[1]['MEMORY/USAGE']).to eql "1048576"

        vm.terminate_hard

        vm.done?
    end

    it "should deploy multiple NUMA VMs" do
        vmid1, vm1 = define_and_run(@template_4)

        expect(vm1.hostname).to eq("host01")

        vmid2, vm2 = define_and_run(@template_3)

        expect(vm2.hostname).to eq("host01")

        vmid3, vm3 = define_and_run(@template_4)

        expect(vm3.hostname).to eq("host01")

        host = cli_action_xml("onehost show host01 -x")

        cores = host.retrieve_xmlelements('HOST_SHARE/NUMA_NODES/NODE/CORE')

        expect(cores[0]['CPUS']).to eql "0:#{vmid1},16:-1,32:-1,48:-1"
        expect(cores[0]['FREE'].to_i).to eql 0
        expect(cores[1]['CPUS']).to eql "1:#{vmid3},17:-1,33:-1,49:-1"
        expect(cores[1]['FREE'].to_i).to eql 0
        expect(cores[2]['CPUS']).to eql "2:-1,18:-1,34:-1,50:-1"
        expect(cores[2]['FREE'].to_i).to eql 4
        expect(cores[3]['CPUS']).to eql "3:-1,19:-1,35:-1,51:-1"
        expect(cores[3]['FREE'].to_i).to eql 4

        expect(cores[8]['CPUS']).to eql "8:#{vmid1},24:-1,40:-1,56:-1"
        expect(cores[8]['FREE'].to_i).to eql 0
        expect(cores[9]['CPUS']).to eql "9:#{vmid2},25:#{vmid2},41:#{vmid2},57:#{vmid2}"
        expect(cores[9]['FREE'].to_i).to eql 0
        expect(cores[10]['CPUS']).to eql "10:#{vmid3},26:-1,42:-1,58:-1"
        expect(cores[10]['FREE'].to_i).to eql 0
        expect(cores[11]['CPUS']).to eql "11:-1,27:-1,43:-1,59:-1"
        expect(cores[11]['FREE'].to_i).to eql 4

        nodes = host.retrieve_xmlelements('HOST_SHARE/NUMA_NODES/NODE')

        expect(nodes[0]['MEMORY/USAGE'].to_i).to eql (512 + 512) * 1024
        expect(nodes[1]['MEMORY/USAGE'].to_i).to eql (1024 + 512 + 512) * 1024

        vm1.terminate_hard
        vm1.done?

        vm2.terminate_hard
        vm2.done?

        vm3.terminate_hard
        vm3.done?
    end

    it "should deploy VMs pinned and overcommit CPU threads" do
        cli_update("onehost update host01", "VMS_THREAD = 2", true)
        cli_update("onehost update host01", "ISOLCPUS = \"0,16,32,48,1,17,33,49,2,18,34,50,3,19,35,51,4,20,36,52,5,21,37,53,6,22,38,54,7,23,39,55,10,26,42,58,11,27,43,59\"", true)
        cli_update("onehost update host01", "RESERVED_CPU = \"-2400\"", true)

        ids_d = []
        vms_d = []

        2.times do |i|
            ids_d[i], vms_d[i] = define_and_run(@template_4)
        end

        ids_th = []
        vms_th = []

        4.times do |i|
            ids_th[i], vms_th[i] = define_and_run(@template_3)
        end

        (vms_d + vms_th).each do |vm|
            expect(vm.hostname).to eq("host01")
        end

        host = cli_action_xml("onehost show host01 -x")

        cores = host.retrieve_xmlelements('HOST_SHARE/NUMA_NODES/NODE/CORE')

        expect(host['HOST_SHARE/CPU_USAGE'].to_i).to eql 2000
        expect(host['HOST_SHARE/TOTAL_CPU'].to_i).to eql 800

        expect(cores[0]['CPUS']).to eql "0:-2,16:-2,32:-2,48:-2"
        expect(cores[0]['FREE'].to_i).to eql 0
        expect(cores[1]['CPUS']).to eql "1:-2,17:-2,33:-2,49:-2"
        expect(cores[1]['FREE'].to_i).to eql 0
        expect(cores[2]['CPUS']).to eql "2:-2,18:-2,34:-2,50:-2"
        expect(cores[2]['FREE'].to_i).to eql 0
        expect(cores[3]['CPUS']).to eql "3:-2,19:-2,35:-2,51:-2"
        expect(cores[3]['FREE'].to_i).to eql 0

        expect(cores[8]['CPUS']).to eql "8:#{ids_d[0]},24:-1,40:-1,56:-1"
        expect(cores[8]['FREE'].to_i).to eql 0
        expect(cores[8]['DEDICATED']).to eql "YES"
        expect(cores[9]['CPUS']).to eql "9:#{ids_d[0]},25:-1,41:-1,57:-1"
        expect(cores[9]['FREE'].to_i).to eql 0
        expect(cores[9]['DEDICATED']).to eql "YES"

        expect(cores[10]['CPUS']).to eql "10:-2,26:-2,42:-2,58:-2"
        expect(cores[10]['FREE'].to_i).to eql 0
        expect(cores[10]['DEDICATED']).to eql "NO"
        expect(cores[11]['CPUS']).to eql "11:-2,27:-2,43:-2,59:-2"
        expect(cores[11]['FREE'].to_i).to eql 0
        expect(cores[11]['DEDICATED']).to eql "NO"

        expect(cores[12]['CPUS']).to eql "12:#{ids_d[1]},28:-1,44:-1,60:-1"
        expect(cores[12]['FREE'].to_i).to eql 0
        expect(cores[12]['DEDICATED']).to eql "YES"
        expect(cores[13]['CPUS']).to eql "13:#{ids_d[1]},29:-1,45:-1,61:-1"
        expect(cores[13]['FREE'].to_i).to eql 0
        expect(cores[13]['DEDICATED']).to eql "YES"

        expect(cores[14]['CPUS']).to eql "14:#{ids_th[0]},14:#{ids_th[1]},30:#{ids_th[0]},30:#{ids_th[1]},46:#{ids_th[0]},46:#{ids_th[1]},62:#{ids_th[0]},62:#{ids_th[1]}"
        expect(cores[14]['FREE'].to_i).to eql 0
        expect(cores[14]['DEDICATED']).to eql "NO"
        expect(cores[15]['CPUS']).to eql "15:#{ids_th[2]},15:#{ids_th[3]},31:#{ids_th[2]},31:#{ids_th[3]},47:#{ids_th[2]},47:#{ids_th[3]},63:#{ids_th[2]},63:#{ids_th[3]}"
        expect(cores[15]['FREE'].to_i).to eql 0
        expect(cores[15]['DEDICATED']).to eql "NO"

        (vms_d + vms_th).each do |vm|
            vm.terminate_hard
            vm.done?
        end

        cli_update("onehost update host01", "VMS_THREAD = 1", true)
        cli_update("onehost update host01", "ISOLCPUS = \"\"", true)
    end

    it "should deploy a VM with a NUMA affinity" do
        vmid, vm = define_and_run(@template_5)

        expect(vm.hostname).to eq("host02")

        vm_xml = cli_action_xml("onevm show #{vmid} -x")

        nodes = vm_xml.retrieve_xmlelements('TEMPLATE/NUMA_NODE')

        expect(nodes.size).to eql 1

        expect(nodes[0]['MEMORY'].to_i).to eql 2048 * 1024
        expect(nodes[0]['TOTAL_CPUS'].to_i).to eql 8
        expect(nodes[0]['NODE_ID'].to_i).to eql 1
        expect(nodes[0]['MEMORY_NODE_ID'].to_i).to eql 1
        expect(nodes[0]['CPUS']).to eql "8,24,40,56,9,25,41,57,10,26,42,58,11,27,43,59,12,28,44,60,13,29,45,61,14,30,46,62,15,31,47,63"

        host = cli_action_xml("onehost show host02 -x")

        memory = host.retrieve_xmlelements('HOST_SHARE/NUMA_NODES/NODE/MEMORY')
        expect(memory[1]['USAGE'].to_i).to eql 2097152

        vm.terminate_hard

        vm.done?

        host = cli_action_xml("onehost show host02 -x")

        memory = host.retrieve_xmlelements('HOST_SHARE/NUMA_NODES/NODE/MEMORY')
        expect(memory[1]['USAGE'].to_i).to eql 0
    end


    it "should deploy a VM with a NUMA affinity and huge pages" do
        vmid, vm = define_and_run(@template_6)

        expect(vm.hostname).to eq("host02")

        vm_xml = cli_action_xml("onevm show #{vmid} -x")

        nodes = vm_xml.retrieve_xmlelements('TEMPLATE/NUMA_NODE')

        expect(nodes.size).to eql 1

        expect(nodes[0]['MEMORY'].to_i).to eql 1024 * 1024
        expect(nodes[0]['TOTAL_CPUS'].to_i).to eql 8
        expect(nodes[0]['NODE_ID'].to_i).to eql 1
        expect(nodes[0]['MEMORY_NODE_ID'].to_i).to eql 1
        expect(nodes[0]['CPUS']).to eql "8,24,40,56,9,25,41,57,10,26,42,58,11,27,43,59,12,28,44,60,13,29,45,61,14,30,46,62,15,31,47,63"

        host = cli_action_xml("onehost show host02 -x")

        memory = host.retrieve_xmlelements('HOST_SHARE/NUMA_NODES/NODE[NODE_ID=1]/HUGEPAGE[SIZE=2048]')
        expect(memory[0]['USAGE'].to_i).to eql 512

        vm.terminate_hard

        vm.done?

        host = cli_action_xml("onehost show host02 -x")

        memory = host.retrieve_xmlelements('HOST_SHARE/NUMA_NODES/NODE[NODE_ID=1]/HUGEPAGE[SIZE=2048]')
        expect(memory[0]['USAGE'].to_i).to eql 0
    end

    it "should deploy a VM with huge pages and schedule NUMA affinity" do
        vmid1, vm1 = define_and_run(@template_7)

        expect(vm1.hostname).to eq("host02")

        vm_xml = cli_action_xml("onevm show #{vmid1} -x")

        nodes = vm_xml.retrieve_xmlelements('TEMPLATE/NUMA_NODE')

        expect(nodes.size).to eql 1

        expect(nodes[0]['MEMORY'].to_i).to eql 1024 * 1024
        expect(nodes[0]['TOTAL_CPUS'].to_i).to eql 8
        expect(nodes[0]['NODE_ID'].to_i).to eql 0
        expect(nodes[0]['MEMORY_NODE_ID'].to_i).to eql 0
        expect(nodes[0]['CPUS']).to eql "0,16,32,48,1,17,33,49,2,18,34,50,3,19,35,51,4,20,36,52,5,21,37,53,6,22,38,54,7,23,39,55"

        host = cli_action_xml("onehost show host02 -x")

        memory = host.retrieve_xmlelements('HOST_SHARE/NUMA_NODES/NODE[NODE_ID=0]/HUGEPAGE[SIZE=2048]')
        expect(memory[0]['USAGE'].to_i).to eql 512

        vmid2, vm2 = define_and_run(@template_7)

        expect(vm2.hostname).to eq("host02")

        vm_xml = cli_action_xml("onevm show #{vmid2} -x")

        nodes = vm_xml.retrieve_xmlelements('TEMPLATE/NUMA_NODE')

        expect(nodes.size).to eql 1

        expect(nodes[0]['MEMORY'].to_i).to eql 1024 * 1024
        expect(nodes[0]['TOTAL_CPUS'].to_i).to eql 8
        expect(nodes[0]['NODE_ID'].to_i).to eql 1
        expect(nodes[0]['MEMORY_NODE_ID'].to_i).to eql 1
        expect(nodes[0]['CPUS']).to eql "8,24,40,56,9,25,41,57,10,26,42,58,11,27,43,59,12,28,44,60,13,29,45,61,14,30,46,62,15,31,47,63"

        host = cli_action_xml("onehost show host02 -x")

        memory = host.retrieve_xmlelements('HOST_SHARE/NUMA_NODES/NODE[NODE_ID=1]/HUGEPAGE[SIZE=2048]')
        expect(memory[0]['USAGE'].to_i).to eql 512

        vmid3, vm3 = define_and_run(@template_7)

        expect(vm3.hostname).to eq("host02")

        vm_xml = cli_action_xml("onevm show #{vmid3} -x")

        nodes = vm_xml.retrieve_xmlelements('TEMPLATE/NUMA_NODE')

        expect(nodes.size).to eql 1

        expect(nodes[0]['MEMORY'].to_i).to eql 1024 * 1024
        expect(nodes[0]['TOTAL_CPUS'].to_i).to eql 8
        expect(nodes[0]['NODE_ID'].to_i).to eql 0
        expect(nodes[0]['MEMORY_NODE_ID'].to_i).to eql 0
        expect(nodes[0]['CPUS']).to eql "0,16,32,48,1,17,33,49,2,18,34,50,3,19,35,51,4,20,36,52,5,21,37,53,6,22,38,54,7,23,39,55"

        host = cli_action_xml("onehost show host02 -x")

        memory = host.retrieve_xmlelements('HOST_SHARE/NUMA_NODES/NODE[NODE_ID=0]/HUGEPAGE[SIZE=2048]')
        expect(memory[0]['USAGE'].to_i).to eql 1024

        memory = host.retrieve_xmlelements('HOST_SHARE/NUMA_NODES/NODE[NODE_ID=1]/HUGEPAGE[SIZE=2048]')
        expect(memory[0]['USAGE'].to_i).to eql 512

        vm1.terminate_hard
        vm1.done?

        vm2.terminate_hard
        vm2.done?

        vm3.terminate_hard
        vm3.done?

        host = cli_action_xml("onehost show host02 -x")

        memory = host.retrieve_xmlelements('HOST_SHARE/NUMA_NODES/NODE[NODE_ID=1]/HUGEPAGE[SIZE=2048]')
        expect(memory[0]['USAGE'].to_i).to eql 0

        memory = host.retrieve_xmlelements('HOST_SHARE/NUMA_NODES/NODE[NODE_ID=0]/HUGEPAGE[SIZE=2048]')
        expect(memory[0]['USAGE'].to_i).to eql 0
    end

end

