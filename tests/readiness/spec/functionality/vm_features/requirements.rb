#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
require 'VN'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "VirtualMachine REQUIREMENTS section test" do
  #---------------------------------------------------------------------------
  # Defines test configuration and start OpenNebula
  #---------------------------------------------------------------------------
  prepend_before(:all) do
    @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
  end

  before(:all) do
    @hid = cli_create("onehost create host01 --im dummy --vm dummy")

    wait_loop() do
      xml = cli_action_xml("onehost show #{@hid} -x")
      OpenNebula::Host::HOST_STATES[xml['STATE'].to_i] == 'MONITORED'
    end

    cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy", false)
    cli_update("onedatastore update system", "TM_MAD=dummy\nDS_MAD=dummy", false)

    wait_loop() do
      xml = cli_action_xml("onedatastore show -x default")
      xml['FREE_MB'].to_i > 0
    end

    tmpl = <<-EOF
    NAME = testimage
    TYPE = OS
    TARGET = hda
    PATH = /tmp/none
    EOF

    @img_id = cli_create("oneimage create -d 1", tmpl)
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  it "should allocate a VirtualMachine that specifies requirements" do
    tmpl = <<-EOF
    NAME = test_vm
    CPU  = 1
    MEMORY = 128
    DISK = [
      IMAGE_ID = #{@img_id}
    ]
    SCHED_REQUIREMENTS = "NAME=\\\"mainhost\\\""
    EOF

    id = cli_create("onevm create", tmpl)

    xml = cli_action_xml("onevm show -x #{id}")
    expect(xml["USER_TEMPLATE/SCHED_REQUIREMENTS"]).to eql("NAME=\"mainhost\"")
  end

  it "should allocate a VirtualMachine that specifies requirements" <<
  " that defines an attribute using a template variable" do

    tmpl = <<-EOF
    NAME = test_vm
    CPU  = 1
    MEMORY = 128
    DISK = [
      IMAGE_ID = #{@img_id}
    ]
    SCHED_REQUIREMENTS = "IP_GEN=\\\"10.0.0.$VMID\\\""
    EOF

    id = cli_create("onevm create", tmpl)

    xml = cli_action_xml("onevm show -x #{id}")
    expect(xml["USER_TEMPLATE/SCHED_REQUIREMENTS"]).to eql("IP_GEN=\"10.0.0.#{id}\"")
  end

  it "should allocate a VirtualMachine that specifies requirements" <<
  " that defines an attribute using a template multiple value variable" do

    tmpl = <<-EOF
    NAME = test_vm
    CPU  = 1
    MEMORY = 128
    DISK = [
      IMAGE_ID = #{@img_id}
    ]
    SCHED_REQUIREMENTS = "TEST1=\\\"$DISK[IMAGE_ID]\\\""
    EOF

    id = cli_create("onevm create", tmpl)

    xml = cli_action_xml("onevm show -x #{id}")
    expect(xml["USER_TEMPLATE/SCHED_REQUIREMENTS"]).to eql("TEST1=\"#{@img_id}\"")
  end

  it "should allocate a VirtualMachine that specifies requirements" <<
  " that defines an attribute using a template multiple value variable" <<
  " setting one atribute to discern between multiple variables" do

    tmpl = <<-EOF
    NAME = secimage
    TYPE = CDROM
    TARGET = hdb
    PATH = /tmp/none
    EOF

    img_id2 = cli_create("oneimage create -d 1", tmpl)

    tmpl = <<-EOF
    NAME = test_vm
    CPU  = 1
    MEMORY = 128
    DISK = [
      IMAGE_ID = #{@img_id}
    ]
    DISK = [
      IMAGE_ID = #{img_id2}
    ]
    SCHED_REQUIREMENTS = "TEST2=\\\"$DISK[IMAGE_ID, TYPE=\\\"CDROM\\\"]\\\""
    EOF

    id = cli_create("onevm create", tmpl)

    xml = cli_action_xml("onevm show -x #{id}")
    expect(xml["USER_TEMPLATE/SCHED_REQUIREMENTS"]).to eql("TEST2=\"#{img_id2}\"")
  end

  it "should allocate a VirtualMachine that specifies requirements" <<
  " that defines an attribute using a VirtualNetwork value variable" do

    tmpl = <<-EOF
    NAME = test_vnet
    BRIDGE = br0
    VN_MAD = dummy
    AR = [
      TYPE = "IP4",
      IP = "10.0.0.10",
      SIZE = "100",
      GATEWAY = "10.0.0.1"
    ]
    EOF

    vnet = VN.create(tmpl)
    vnet.ready?

    tmpl = <<-EOF
    NAME = test_vm
    CPU  = 1
    MEMORY = 128
    DISK = [
      IMAGE_ID = #{@img_id}
    ]
    NIC = [
      NETWORK_ID= #{vnet.id}
    ]
    SCHED_REQUIREMENTS = "TEST3=\\\"$NETWORK[GATEWAY, NETWORK_ID=\\\"#{vnet.id}\\\"]\\\""
    EOF

    id = cli_create("onevm create", tmpl)

    xml = cli_action_xml("onevm show -x #{id}")
    expect(xml["USER_TEMPLATE/SCHED_REQUIREMENTS"]).to eql("TEST3=\"10.0.0.1\"")
  end
end
