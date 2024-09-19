#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Host PCI devices test" do
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
        MEMORY = 128
        SCHED_RANK=PRIORITY
        PCI = [ DEVICE="0863" ]
        PCI = [ DEVICE="0aa9" ]
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
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  it "should check the dummy drivers report PCI devices" do
    host = cli_action_xml("onehost show host01 -x")

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

  it "should deploy a VM with PCI devices and check host share usage" do
    vmid = cli_create("onevm create", @template_1).to_s

    cli_action("onevm deploy testvm host01")

    vm = VM.new(vmid)

    vm.running?

    host = cli_action_xml("onehost show host01 -x")

    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:02:00:0"]/VMID']).to eql vmid
    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:0"]/VMID']).to eql "-1"
    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:1"]/VMID']).to eql vmid
  end

  it "should deploy and shutdown a VM with PCI devices and check host share usage" do
    vmid = cli_create("onevm create", @template_1).to_s

    cli_action("onevm deploy testvm host01")

    vm = VM.new(vmid)

    vm.running?

    cli_action("onevm recover --delete testvm")

    vm.done?

    host = cli_action_xml("onehost show host01 -x")

    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:02:00:0"]/VMID']).to eql "-1"
    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:0"]/VMID']).to eql "-1"
    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:1"]/VMID']).to eql "-1"
  end

  it "should deploy and stop a VM with PCI devices and check host share usage" do
    vmid = cli_create("onevm create", @template_1).to_s

    cli_action("onevm deploy testvm host01")

    vm = VM.new(vmid)

    vm.running?

    cli_action("onevm stop testvm")

    vm.state?('STOPPED')

    host = cli_action_xml("onehost show host01 -x")

    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:02:00:0"]/VMID']).to eql "-1"
    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:0"]/VMID']).to eql "-1"
    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:1"]/VMID']).to eql "-1"

    cli_action("onevm deploy testvm host01")

    vm.running?

    host = cli_action_xml("onehost show host01 -x")

    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:02:00:0"]/VMID']).to eql vmid
    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:0"]/VMID']).to eql "-1"
    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:1"]/VMID']).to eql vmid
  end

  it "should deploy and poweroff a VM with PCI devices and check host share usage" do
    vmid = cli_create("onevm create", @template_1).to_s

    cli_action("onevm deploy testvm host01")

    vm = VM.new(vmid)

    vm.running?

    cli_action("onevm poweroff testvm")

    vm.poweroff?

    host = cli_action_xml("onehost show host01 -x")

    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:02:00:0"]/VMID']).to eql vmid
    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:0"]/VMID']).to eql "-1"
    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:1"]/VMID']).to eql vmid

    cli_action("onevm resume testvm")

    vm.running?

    host = cli_action_xml("onehost show host01 -x")

    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:02:00:0"]/VMID']).to eql vmid
    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:0"]/VMID']).to eql "-1"
    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:1"]/VMID']).to eql vmid
  end

  it "should try to migrate a VM with PCI devices without poweroff flags and fail" do
    cli_create("onevm create", @template_1)
    cli_action("onevm deploy testvm host01")

    cli_action("onevm migrate testvm host02", false)
  end

  it "should try to migrate a VM with PCI devices" do
    template = <<-EOF
        NAME = testvm
        CPU  = 1
        MEMORY = 128
        SCHED_RANK=PRIORITY
        PCI = [ CLASS="0c03" ]
    EOF

    #Lock the first PCI device in target host
    vmid = cli_create("onevm create", template).to_s
    cli_action("onevm deploy #{vmid} host02")

    vm = VM.new(vmid)

    vm.running?

    host = cli_action_xml("onehost show host02 -x")

    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:02:00:0"]/VMID']).to eql "-1"
    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:0"]/VMID']).to eql vmid
    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:1"]/VMID']).to eql "-1"

    #Create VM
    vmid = cli_create("onevm create", template).to_s
    cli_action("onevm deploy #{vmid} host01")

    vm = VM.new(vmid)

    vm.running?

    host = cli_action_xml("onehost show host01 -x")

    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:02:00:0"]/VMID']).to eql "-1"
    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:0"]/VMID']).to eql vmid
    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:1"]/VMID']).to eql "-1"

    #Migrate VM
    cli_action("onevm migrate #{vmid} host02 --poff")

    vm.running?

    #Check source host
    host = cli_action_xml("onehost show host01 -x")

    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:02:00:0"]/VMID']).to eql "-1"
    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:0"]/VMID']).to eql "-1"
    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:1"]/VMID']).to eql "-1"

    #Check target host
    host = cli_action_xml("onehost show host02 -x")

    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:02:00:0"]/VMID']).to eql "-1"
    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:0"]/VMID']).not_to eql "-1"
    expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:1"]/VMID']).to eql vmid

    cli_action("onevm recover --delete #{vmid}")
  end
end