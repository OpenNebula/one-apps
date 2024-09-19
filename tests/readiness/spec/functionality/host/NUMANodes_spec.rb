#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Host NUMA nodes test" do
  #---------------------------------------------------------------------------
  # OpenNebula bootstraping:
  #   - Define infrastructure: hosts, datastore, users, networks,...
  #   - Common instance variables: templates,...
  #---------------------------------------------------------------------------
  before(:all) do
    cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy", false)
    cli_update("onedatastore update system", "TM_MAD=dummy\nDS_MAD=dummy", false)

    cli_create("onehost create host01 --im dummy --vm dummy")
    cli_create("onehost create host02 --im dummy --vm dummy")

    wait_loop()do
      xml = cli_action_xml("onehost show host01 -x")
      OpenNebula::Host::HOST_STATES[xml['STATE'].to_i] == 'MONITORED'
    end

    wait_loop()do
      xml = cli_action_xml("onehost show host02 -x")
      OpenNebula::Host::HOST_STATES[xml['STATE'].to_i] == 'MONITORED'
    end

    @template_1 = <<-EOF
        NAME = testvm
        CPU  = 1
        VCPU = 8
        MEMORY = 2048

        TOPOLOGY = [ SOCKETS = 2 , PIN_POLICY = THREAD ]
    EOF
  end


  after(:each) do
    `onevm recover --delete testvm`

    wait_loop { `onevm list -x` == "<VM_POOL/>\n" }

    host = cli_action_xml("onehost show host01 -x")

    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:02:00:0"]/VMID']).to eql "-1"
    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:0"]/VMID']).to eql "-1"
    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:1"]/VMID']).to eql "-1"

    host = cli_action_xml("onehost show host02 -x")

    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:02:00:0"]/VMID']).to eql "-1"
    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:0"]/VMID']).to eql "-1"
    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:1"]/VMID']).to eql "-1"

    cores = host.retrieve_xmlelements('HOST_SHARE/NUMA_NODES/NODE/CORE')

    cores.each do |c|
        expect(c['FREE'].to_i).to eql 4
    end
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  it "should check the dummy drivers report PCI devices" do
    host = nil

    wait_loop()do
      host = cli_action_xml("onehost show host01 -x")
      OpenNebula::Host::HOST_STATES[host['STATE'].to_i] == 'MONITORED'
    end

    host['HOST_SHARE/PCI_DEVICES/PCI/ADDRESS']

    expect(host['HOST_SHARE/PCI_DEVICES/PCI/ADDRESS[.="0000:02:00:0"]']).to eql "0000:02:00:0"
    expect(host['HOST_SHARE/PCI_DEVICES/PCI/ADDRESS[.="0000:00:06:0"]']).to eql "0000:00:06:0"
    expect(host['HOST_SHARE/PCI_DEVICES/PCI/ADDRESS[.="0000:00:06:1"]']).to eql "0000:00:06:1"

    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:02:00:0"]/VMID']).to eql "-1"
    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:0"]/VMID']).to eql "-1"
    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:1"]/VMID']).to eql "-1"
  end

  ############################################################################
  # DEPLOYMENT
  ############################################################################

  it "should deploy a VM with NUMA nodes and check host share usage" do
    vmid   = cli_create("onevm create", @template_1).to_s
    vm_xml = ""

    cli_action("onevm deploy testvm host01")

    wait_loop()do
      vm_xml = cli_action_xml("onevm show testvm -x")
      OpenNebula::VirtualMachine::LCM_STATE[vm_xml['LCM_STATE'].to_i] == 'RUNNING'
    end

    nodes = vm_xml.retrieve_xmlelements('TEMPLATE/NUMA_NODE')

    expect(nodes.size).to eql 2

    expect(nodes[0]['MEMORY'].to_i).to eql 1024 * 1024
    expect(nodes[0]['TOTAL_CPUS'].to_i).to eql 4
    expect(nodes[0]['MEMORY_NODE_ID'].to_i).to eql 1
    expect(nodes[0]['NODE_ID'].to_i).to eql 1
    expect(nodes[0]['CPUS']).to eql "8,24,40,56"

    expect(nodes[1]['MEMORY'].to_i).to eql 1024 * 1024
    expect(nodes[1]['TOTAL_CPUS'].to_i).to eql 4
    expect(nodes[1]['MEMORY_NODE_ID'].to_i).to eql 0
    expect(nodes[1]['NODE_ID'].to_i).to eql 0
    expect(nodes[1]['CPUS']).to eql "0,16,32,48"

    host = cli_action_xml("onehost show host01 -x")

    cores = host.retrieve_xmlelements('HOST_SHARE/NUMA_NODES/NODE/CORE')

    expect(cores[0]['CPUS']).to eql "0:0,16:0,32:0,48:0"
    expect(cores[0]['FREE'].to_i).to eql 0
    expect(cores[8]['CPUS']).to eql "8:0,24:0,40:0,56:0"
    expect(cores[8]['FREE'].to_i).to eql 0

    monitoring = host.retrieve_xmlelements('MONITORING/NUMA_NODE')

    expect(monitoring.size).to be > 0

    # Dummy NUMA monitoring for hugepages reports constant values
    expect(monitoring[0]['HUGEPAGE[SIZE=2048]/FREE'].to_i).to eql 1024
    expect(monitoring[0]['HUGEPAGE[SIZE=1048576]/FREE'].to_i).to eql 1024
    expect(monitoring[1]['HUGEPAGE[SIZE=2048]/FREE'].to_i).to eql 1024
    expect(monitoring[1]['HUGEPAGE[SIZE=1048576]/FREE'].to_i).to eql 1024

    # Dummy NUMA monitoring for memory reports random numbers, check non zero
    expect(monitoring[0]['MEMORY/FREE'].to_i).to be > 0
    expect(monitoring[0]['MEMORY/USED'].to_i).to be > 0
    expect(monitoring[1]['MEMORY/FREE'].to_i).to be > 0
    expect(monitoring[1]['MEMORY/USED'].to_i).to be > 0
  end

  it "should deploy a VM with PCI closer to its NUMA node and check host usage" do
    template = @template_1 +"\nPCI = [ DEVICE=\"0863\" ]\n"

    vmid   = cli_create("onevm create", template).to_s
    vm_xml = ""

    cli_action("onevm deploy testvm host01")

    wait_loop()do
      vm_xml = cli_action_xml("onevm show testvm -x")
      OpenNebula::VirtualMachine::LCM_STATE[vm_xml['LCM_STATE'].to_i] == 'RUNNING'
    end

    nodes = vm_xml.retrieve_xmlelements('TEMPLATE/NUMA_NODE')

    expect(nodes[0]['MEMORY'].to_i).to eql 1024 * 1024
    expect(nodes[0]['TOTAL_CPUS'].to_i).to eql 4
    expect(nodes[0]['MEMORY_NODE_ID'].to_i).to eql 1
    expect(nodes[0]['NODE_ID'].to_i).to eql 1
    expect(nodes[0]['CPUS']).to eql "8,24,40,56"

    expect(nodes[1]['MEMORY'].to_i).to eql 1024 * 1024
    expect(nodes[1]['TOTAL_CPUS'].to_i).to eql 4
    expect(nodes[1]['MEMORY_NODE_ID'].to_i).to eql 1
    expect(nodes[1]['NODE_ID'].to_i).to eql 1
    expect(nodes[1]['CPUS']).to eql "9,25,41,57"
    expect(nodes.size).to eql 2

    host = cli_action_xml("onehost show host01 -x")

    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:02:00:0"]/VMID']).to eql vmid
    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:0"]/VMID']).to eql "-1"
    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:1"]/VMID']).to eql "-1"
  end
end
