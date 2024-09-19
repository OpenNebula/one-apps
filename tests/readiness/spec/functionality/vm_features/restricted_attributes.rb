#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Restricted Attributes for VM test" do

  before(:all) do
    cli_create_user("userA", "passwordA")

    cli_create("onevnet create", "NAME = net0\nVN_MAD=dummy\nBRIDGE=vbr0")
    cli_create("onevnet create", "NAME = net1\nVN_MAD=dummy\nBRIDGE=vbr0")

    @hid = cli_create("onehost create host0 --im dummy --vm dummy")
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  it "should check that CONTEXT/FILES is restricted" do
    template_text = "CPU = 1\n"<<
    "MEMORY = 64\n"<<
    "CONTEXT = [ FILES = /etc/one/oned.conf ]"

    as_user("userA") do
      cli_create("onevm create", template_text, false)
    end

    cli_create("onevm create", template_text)
  end

  it "should check that NIC/MAC is restricted" do
    template_text = "CPU = 1\n"<<
    "MEMORY = 64\n"<<
    "NIC = [ MAC = 01:02:03:04:05:06 ]"

    as_user("userA") do
      cli_create("onevm create", template_text, false)
    end

    cli_create("onevm create", template_text)
  end

  it "should check that NIC/VLAN_ID is restricted" do
    template_text = "CPU = 1\n"<<
    "MEMORY = 64\n"<<
    "NIC = [ VLAN_ID = 0 ]"

    as_user("userA") do
      cli_create("onevm create", template_text, false)
    end

    cli_create("onevm create", template_text)
  end

  it "should check that CPU_COST is restricted" do
    template_text = "CPU = 1\n"<<
    "MEMORY = 64\n"<<
    "CPU_COST = 10"

    as_user("userA") do
      cli_create("onevm create", template_text, false)
    end

    cli_create("onevm create", template_text)
  end

  it "should check to update a vm with a restricted vector attribute" do
    template_base = <<-EOF
      CPU = 1
      MEMORY = 64
      USER_INPUTS = [
        CPU = "2"
      ]
    EOF

    template_update = <<-EOF
      USER_INPUTS = [
        CPU = "2",
        TEST = "test"
      ]
    EOF

    template_append = <<-EOF
      USER_INPUTS = [
        CPU="2",
        APP = "app"
      ]
    EOF

    template_update2 = <<-EOF
      USER_INPUTS = [CPU = "3"]
    EOF

    template_append_2 = <<-EOF
      USER_INPUTS = [
        CPU = "4",
        APP = "app2"
      ]
    EOF

    template_delete = <<-EOF
      USER_INPUTS = [
        APP = "app2"
      ]
    EOF

    vmid = cli_create("onevm create", template_base)
    cli_action("onevm chown #{vmid} userA" )

    as_user("userA") do
      cli_update("onevm update #{vmid}",template_append, true, true)
      cli_update("onevm update #{vmid}",template_append_2, true, false)
      cli_update("onevm update #{vmid}", template_update2, false, false)
      cli_update("onevm update #{vmid}", template_update, false, true)
      cli_update("onevm update #{vmid}", template_delete, false, false)
      xml = cli_action_xml("onevm show -x #{vmid}")

      #expect(xml['USER_TEMPLATE/USER_INPUTS/TEST']).to eq("test")
    end

    cli_update("onevm update #{vmid}", template_update, false, true)
    cli_update("onevm update #{vmid}",template_append_2, true, true)
    cli_update("onevm update #{vmid}",template_append,true, true)
    cli_update("onevm update #{vmid}", template_update2,false, true)
    xml = cli_action_xml("onevm show -x #{vmid}")
    expect(xml['USER_TEMPLATE/USER_INPUTS/CPU']).to eq("3")
  end

  it "should check to instantiate a vm with a restricted vector attribute" do
    template = <<-EOF
        NAME   = test_template
        CPU    = 2
        MEMORY = 128
        ATT1   = "VAL1"
        ATT2   = "VAL2"
        USER_INPUT = [
          CPU = "2"
        ]
    EOF

    @template_id = cli_create("onetemplate create", template)
    cli_action("onetemplate chown #{@template_id} userA" )

    template = <<-EOF
      CPU = 4
      MEMORY = 2048
      EXTRA = abc
    EOF
    template_restricted = <<-EOF
      CPU = 4
      MEMORY = 2048
      EXTRA = abc
      USER_INPUTS = [
        CPU = "3"
      ]
    EOF

    as_user("userA") do
      cli_create("onetemplate instantiate #{@template_id}", template)
      cli_create("onetemplate instantiate #{@template_id}", template_restricted, false)
    end

    cli_create("onetemplate instantiate #{@template_id}", template)
    cli_create("onetemplate instantiate #{@template_id}", template_restricted)
  end

  it "should check to attach a disk with restricted attributes" do

    template = <<-EOF
        NAME   = test_template_disk
        CPU    = 2
        MEMORY = 128
    EOF

    @template_id = cli_create("onetemplate create", template)

    @vm_id = cli_create("onetemplate instantiate #{@template_id}")

    cli_action("onevm deploy #{@vm_id} #{@hid}")

    vm = VM.new(@vm_id)

    vm.running?

    cli_action("onevm chmod #{@vm_id} 606" )

    iid = nil

    as_user("userA") do
      iid = cli_create("oneimage create --name test_img --size 100 --type datablock -d default")
    end

    wait_loop(:success => "READY", :break => "ERROR") {
      xml = cli_action_xml("oneimage show -x #{iid}")
      Image::IMAGE_STATES[xml['STATE'].to_i]
    }

    as_user("userA") do
      cli_update("onevm disk-attach #{@vm_id} --file", <<-EOT, false, false)
        DISK = [ IMAGE_ID = #{iid}, TOTAL_IOPS_SEC = "2048" ]
      EOT
    end

    cli_update("onevm disk-attach #{@vm_id} --file", <<-EOT, false, true)
        DISK = [ IMAGE_ID = #{iid}, TOTAL_IOPS_SEC = "2048" ]
    EOT
  end

  it "should check to attach a nic with restricted attributes" do
    template = <<-EOF
        NAME   = test_template_nic
        CPU    = 2
        MEMORY = 128
    EOF

    @template_id = cli_create("onetemplate create", template)
    cli_action("onetemplate chown #{@template_id} userA" )

    @net_id = cli_create("onevnet create", "NAME = net2\nVN_MAD=dummy\nBRIDGE=vbr0")

    @vm_id = cli_create("onetemplate instantiate #{@template_id}")

    cli_action("onevm deploy #{@vm_id} #{@hid}")

    vm = VM.new(@vm_id)

    vm.running?

    cli_action("onevm chmod #{@vm_id} 606" )

    as_user("userA") do
      cli_update("onevm nic-attach #{@vm_id} --file", <<-EOT, false, false)
        NIC = [ VNET_ID = #{@net_id}, INBOUND_AVG_BW = "2048" ]
      EOT
    end

    cli_update("onevm nic-attach #{@vm_id} --file", <<-EOT, false, true)
      NIC = [ VNET_ID = #{@net_id}, INBOUND_AVG_BW = "2048" ]
    EOT
  end

  it "multiple disk should update disk without restricted attribute" do
    # ORIGINAL_SIZE is restricted
    template = <<-EOF
      NAME="test_restricted1"
      CPU="1"
      DISK=[
        IMAGE="test_img",
        IMAGE_UNAME="userA",
        SIZE="20480" ]
      DISK=[
        IMAGE="test_img",
        IMAGE_UNAME="userA",
        ORIGINAL_SIZE="4096",
        SIZE="20480" ]
      MEMORY="128"
    EOF

    tid = cli_create('onetemplate create', template)

    cli_action("onetemplate chmod #{tid} 606")

    template_update = <<-EOF
      CPU="1"
      DISK=[
        IMAGE="test_img",
        IMAGE_UNAME="userA",
        SIZE="10240" ]
      DISK=[
        IMAGE="test_img",
        IMAGE_UNAME="userA",
        ORIGINAL_SIZE="4096",
        SIZE="20480" ]
      MEMORY="128"
    EOF

    as_user("userA") do
      cli_update("onetemplate update #{tid}", template_update, false)
      cli_update("onetemplate update #{tid}", "CPU=2", true)
    end

    xml = cli_action_xml("onetemplate show -x #{tid}")

    expect(xml['TEMPLATE/DISK[1]/SIZE']).to eq('10240')
    expect(xml['TEMPLATE/DISK[2]/SIZE']).to eq('20480')
  end

  it "multiple disk should remove disk without restricted attribute" do
    template = <<-EOF
      NAME="test_restricted2"
      CPU="1"
      DISK=[
        IMAGE="test_img",
        IMAGE_UNAME="userA",
        SIZE="20480" ]
      DISK=[
        IMAGE="test_img",
        IMAGE_UNAME="userA",
        ORIGINAL_SIZE="4096",
        SIZE="20480" ]
      MEMORY="128"
    EOF

    tid = cli_create('onetemplate create', template)

    cli_action("onetemplate chmod #{tid} 606")

    template_update = <<-EOF
      CPU="1"
      DISK=[
        IMAGE="test_img",
        IMAGE_UNAME="userA",
        ORIGINAL_SIZE="4096",
        SIZE="20480" ]
      MEMORY="128"
    EOF

    as_user("userA") do
      cli_update("onetemplate update #{tid}", template_update, false)
    end

    xml = cli_action_xml("onetemplate show -x #{tid}")

    expect(xml['TEMPLATE/DISK[1]/SIZE']).to eq('20480')
    expect(xml['TEMPLATE/DISK[2]']).to be_nil
  end

  it "multiple disk should not remove disk with restricted attribute" do
    template = <<-EOF
      NAME="test_restricted3"
      CPU="1"
      DISK=[
        IMAGE="test_img",
        IMAGE_UNAME="userA",
        SIZE="20480" ]
      DISK=[
        IMAGE="test_img",
        IMAGE_UNAME="userA",
        ORIGINAL_SIZE="4096",
        SIZE="20480" ]
      MEMORY="128"
    EOF

    tid = cli_create('onetemplate create', template)

    cli_action("onetemplate chmod #{tid} 606")

    template_update1 = <<-EOF
      CPU="1"
      DISK=[
        IMAGE="test_img",
        IMAGE_UNAME="userA",
        SIZE="20480" ]
      MEMORY="128"
    EOF

    template_update2 = <<-EOF
      CPU="1"
      MEMORY="128"
    EOF

    as_user("userA") do
      cli_update("onetemplate update #{tid}", template_update1, false, false)
      cli_update("onetemplate update #{tid}", template_update2, false, false)
    end
  end

end