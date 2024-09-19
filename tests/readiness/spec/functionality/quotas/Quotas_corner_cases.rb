#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

DEFAULT_LIMIT = "-1"

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Check quotas corner cases" do
  #---------------------------------------------------------------------------
  # OpenNebula bootstraping:
  #   - Define infrastructure: hosts, datastore, users, networks,...
  #   - Common instance variables: templates,...
  #---------------------------------------------------------------------------
  before(:all) do
    cli_create_user("uA", "abc")
    cli_create_user("uB", "abc")
    cli_create_user("uC", "abc")

    gA_id = cli_create("onegroup create gA")
    cli_create("onegroup create gB")

    cli_action("oneuser chgrp uA gA")
    cli_action("oneuser chgrp uB gA")
    cli_action("oneuser chgrp uC gB")

    vnet_tmpl = <<-EOF
    NAME = test_vnet
    BRIDGE = br0
    VN_MAD = dummy
    AR=[TYPE = "IP4", IP = "10.0.0.10", SIZE = "100" ]
    EOF

    cli_create("onevnet create", vnet_tmpl)
    cli_create("onehost create host0 --im dummy --vm dummy")

    cli_action("oneacl create '* NET/* CREATE'")
    cli_action("oneacl create '* CLUSTER/#0 ADMIN'")

    as_user("uA") do
      @net_uA_id = cli_create("onevnet create", vnet_tmpl)
    end
  end

  before(:each) do
    `onevm list -l ID|tail -n +2`.split().each do |id|
      `onevm recover --delete #{id}`
    end

    wait_loop { `onevm list -x` == "<VM_POOL/>\n" }
  end

  after(:all) do
    run_fsck
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  ##############################################################################
  # CPU
  ##############################################################################

  it "should create a VM with float CPU" do
    as_user("uA") do

      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1024
      CPU = 0.25
      EOT

      id1 = cli_create("onevm create", tmpl)

      uxml = cli_action_xml("oneuser show -x")

      expect(uxml["VM_QUOTA/VM/MEMORY"]).to eql DEFAULT_LIMIT
      expect(uxml["VM_QUOTA/VM/MEMORY_USED"]).to eql "1024"
      expect(uxml["VM_QUOTA/VM/CPU"]).to eql DEFAULT_LIMIT
      expect(uxml["VM_QUOTA/VM/CPU_USED"]).to eql "0.25"
      expect(uxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql "1024"
      expect(uxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql "0.25"
      expect(uxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql "1"

      gxml = cli_action_xml("onegroup show -x")

      expect(gxml["VM_QUOTA/VM/MEMORY"]).to eql DEFAULT_LIMIT
      expect(gxml["VM_QUOTA/VM/MEMORY_USED"]).to eql "1024"
      expect(gxml["VM_QUOTA/VM/CPU"]).to eql DEFAULT_LIMIT
      expect(gxml["VM_QUOTA/VM/CPU_USED"]).to eql "0.25"
      expect(gxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql "1024"
      expect(gxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql "0.25"
      expect(gxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql "1"

      cli_action("onevm terminate --hard #{id1}")

      uxml = cli_action_xml("oneuser show -x")

      expect(uxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)

      gxml = cli_action_xml("onegroup show -x")

      expect(gxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)
    end
  end

  it "should try to create a VM with wrong alphanumeric CPU" do
    as_user("uA") do

      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1024
      CPU = 123potato
      EOT

      cli_create("onevm create", tmpl, false)

      uxml = cli_action_xml("oneuser show -x")

      expect(uxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)

      gxml = cli_action_xml("onegroup show -x")

      expect(gxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)
    end
  end

  it "should try to create a VM with wrong negative CPU" do
    as_user("uA") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1024
      CPU = -4
      EOT

      cli_create("onevm create", tmpl, false)

      uxml = cli_action_xml("oneuser show -x")

      expect(uxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)

      gxml = cli_action_xml("onegroup show -x")

      expect(gxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)
    end
  end

  it "should try to create a VM with wrong 0 CPU" do
    as_user("uA") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1024
      CPU = 0
      EOT

      cli_create("onevm create", tmpl, false)

      uxml = cli_action_xml("oneuser show -x")

      expect(uxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)

      gxml = cli_action_xml("onegroup show -x")

      expect(gxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)
    end
  end

  ##############################################################################
  # MEMORY
  ##############################################################################

  it "should try to create a VM with wrong alphanumeric MEMORY" do
    as_user("uA") do


      tmpl = <<-EOT
      NAME = "test_vm"
      CPU = 1
      MEMORY = 123potato
      EOT

      cli_create("onevm create", tmpl, false)

      uxml = cli_action_xml("oneuser show -x")

      expect(uxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)

      gxml = cli_action_xml("onegroup show -x")

      expect(gxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)
    end
  end

  it "should try to create a VM with wrong negative MEMORY" do
    as_user("uA") do

      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = -1024
      CPU = 1
      EOT

      cli_create("onevm create", tmpl, false)

      uxml = cli_action_xml("oneuser show -x")

      expect(uxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)

      gxml = cli_action_xml("onegroup show -x")

      expect(gxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)
    end
  end

  it "should try to create a VM with wrong float MEMORY" do
    as_user("uA") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1024.5
      CPU = 1
      EOT

      cli_create("onevm create", tmpl, false)

      uxml = cli_action_xml("oneuser show -x")

      expect(uxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)

      gxml = cli_action_xml("onegroup show -x")

      expect(gxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)
    end
  end

  it "should try to create a VM with wrong 0 MEMORY" do
    as_user("uA") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 0
      CPU = 1
      EOT

      cli_create("onevm create", tmpl, false)

      uxml = cli_action_xml("oneuser show -x")

      expect(uxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)

      gxml = cli_action_xml("onegroup show -x")

      expect(gxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)
    end
  end

  ##############################################################################
  # VCPU
  ##############################################################################

  it "should try to create a VM with wrong alphanumeric VCPU" do
    as_user("uA") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1024
      CPU = 1
      VCPU = 4potato
      EOT

      cli_create("onevm create", tmpl, false)

      uxml = cli_action_xml("oneuser show -x")

      expect(uxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)

      gxml = cli_action_xml("onegroup show -x")

      expect(gxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)
    end
  end

  it "should try to create a VM with wrong negative VCPU" do
    as_user("uA") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1024
      CPU = 1
      VCPU = -4
      EOT

      cli_create("onevm create", tmpl, false)

      uxml = cli_action_xml("oneuser show -x")

      expect(uxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)

      gxml = cli_action_xml("onegroup show -x")

      expect(gxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)
    end
  end

  it "should try to create a VM with wrong float VCPU" do
    as_user("uA") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1024
      CPU = 1
      VCPU = 1.5
      EOT

      cli_create("onevm create", tmpl, false)

      uxml = cli_action_xml("oneuser show -x")

      expect(uxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)

      gxml = cli_action_xml("onegroup show -x")

      expect(gxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)
    end
  end

  it "should try to create a VM with wrong 0 VCPU" do
    as_user("uA") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1024
      CPU = 1
      VCPU = 0
      EOT

      cli_create("onevm create", tmpl, false)

      uxml = cli_action_xml("oneuser show -x")

      expect(uxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)

      gxml = cli_action_xml("onegroup show -x")

      expect(gxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)
    end
  end

  ##############################################################################
  # VOLATILE SIZE
  ##############################################################################
=begin
  it "should create a VM with long long volatile size" do
    as_user("uA") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1024
      CPU = 1
      DISK = [
        TYPE = fs,
        SIZE = 922337203685477580
      ]
      EOT

      id1 = cli_create("onevm create", tmpl)

      uxml = cli_action_xml("oneuser show -x")

      expect(uxml["VM_QUOTA/VM/MEMORY"]).to eql DEFAULT_LIMIT
      expect(uxml["VM_QUOTA/VM/MEMORY_USED"]).to eql "1024"
      expect(uxml["VM_QUOTA/VM/CPU"]).to eql DEFAULT_LIMIT
      expect(uxml["VM_QUOTA/VM/CPU_USED"]).to eql "1"
      expect(uxml["VM_QUOTA/VM/SYSTEM_DISK_SIZE"]).to eql DEFAULT_LIMIT
      # Was disabled due to wrong conversion in core
      expect(uxml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql "922337203685477580"

      gxml = cli_action_xml("onegroup show -x")

      expect(gxml["VM_QUOTA/VM/MEMORY"]).to eql DEFAULT_LIMIT
      expect(gxml["VM_QUOTA/VM/MEMORY_USED"]).to eql "1024"
      expect(gxml["VM_QUOTA/VM/CPU"]).to eql DEFAULT_LIMIT
      expect(gxml["VM_QUOTA/VM/CPU_USED"]).to eql "1"
      expect(gxml["VM_QUOTA/VM/SYSTEM_DISK_SIZE"]).to eql DEFAULT_LIMIT
      # Was disabled due to wrong conversion in core
      expect(gxml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql "922337203685477580"

      cli_action("onevm terminate --hard #{id1}")

      uxml = cli_action_xml("oneuser show -x")

      expect(uxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/SYSTEM_DISK_SIZE"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql(nil).or eql("0")

      gxml = cli_action_xml("onegroup show -x")

      expect(gxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/SYSTEM_DISK_SIZE"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql(nil).or eql("0")
    end
  end
=end
  it "should try to create a VM with wrong alphanumeric volatile size" do
    as_user("uA") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1024
      CPU = 1
      DISK = [
        TYPE = fs,
        SIZE = 123potato
      ]
      EOT

      cli_create("onevm create", tmpl, false)

      uxml = cli_action_xml("oneuser show -x")

      expect(uxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/SYSTEM_DISK_SIZE"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)

      gxml = cli_action_xml("onegroup show -x")

      expect(gxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/SYSTEM_DISK_SIZE"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)
    end
  end

  it "should try to create a VM with wrong negative volatile size" do
    as_user("uA") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1024
      CPU = 1
      DISK = [
        TYPE = fs,
        SIZE = -4
      ]
      EOT

      cli_create("onevm create", tmpl, false)

      uxml = cli_action_xml("oneuser show -x")

      expect(uxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/SYSTEM_DISK_SIZE"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)

      gxml = cli_action_xml("onegroup show -x")

      expect(gxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/SYSTEM_DISK_SIZE"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)
    end
  end

  it "should try to create a VM with wrong 0 volatile size" do
    as_user("uA") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1024
      CPU = 1
      DISK = [
        TYPE = fs,
        SIZE = 0
      ]
      EOT

      cli_create("onevm create", tmpl, false)

      uxml = cli_action_xml("oneuser show -x")

      expect(uxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/SYSTEM_DISK_SIZE"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql(nil).or eql("0")
      expect(uxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(uxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)

      gxml = cli_action_xml("onegroup show -x")

      expect(gxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/SYSTEM_DISK_SIZE"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql(nil).or eql("0")
      expect(gxml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil)
      expect(gxml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil)
    end
  end

  ##############################################################################
  # SIZE
  ##############################################################################

  it "should try to create an Image with wrong alphanumeric SIZE" do
    as_user("uA") do
      tmpl = <<-EOF
      NAME = test_img
      TYPE = DATABLOCK
      fstype = ext3
      size = 123potato
      EOF

      cli_create("oneimage create -d 1", tmpl, false)

      uxml = cli_action_xml("oneuser show -x")

      expect(uxml["DATASTORE_QUOTA/DATASTORE[ID='1']/IMAGES"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["DATASTORE_QUOTA/DATASTORE[ID='1']/IMAGES_USED"]).to eql(nil).or eql("0")
      expect(uxml["DATASTORE_QUOTA/DATASTORE[ID='1']/SIZE"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["DATASTORE_QUOTA/DATASTORE[ID='1']/SIZE_USED"]).to eql(nil).or eql("0")

      gxml = cli_action_xml("onegroup show -x")

      expect(gxml["DATASTORE_QUOTA/DATASTORE[ID='1']/IMAGES"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["DATASTORE_QUOTA/DATASTORE[ID='1']/IMAGES_USED"]).to eql(nil).or eql("0")
      expect(gxml["DATASTORE_QUOTA/DATASTORE[ID='1']/SIZE"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["DATASTORE_QUOTA/DATASTORE[ID='1']/SIZE_USED"]).to eql(nil).or eql("0")

    end
  end

  it "should try to create an Image with wrong negative SIZE" do
    as_user("uA") do
      tmpl = <<-EOF
      NAME = test_img
      TYPE = DATABLOCK
      fstype = ext3
      size = -1024
      EOF

      cli_create("oneimage create -d 1", tmpl, false)

      uxml = cli_action_xml("oneuser show -x")

      expect(uxml["DATASTORE_QUOTA/DATASTORE[ID='1']/IMAGES"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["DATASTORE_QUOTA/DATASTORE[ID='1']/IMAGES_USED"]).to eql(nil).or eql("0")
      expect(uxml["DATASTORE_QUOTA/DATASTORE[ID='1']/SIZE"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["DATASTORE_QUOTA/DATASTORE[ID='1']/SIZE_USED"]).to eql(nil).or eql("0")

      gxml = cli_action_xml("onegroup show -x")

      expect(gxml["DATASTORE_QUOTA/DATASTORE[ID='1']/IMAGES"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["DATASTORE_QUOTA/DATASTORE[ID='1']/IMAGES_USED"]).to eql(nil).or eql("0")
      expect(gxml["DATASTORE_QUOTA/DATASTORE[ID='1']/SIZE"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["DATASTORE_QUOTA/DATASTORE[ID='1']/SIZE_USED"]).to eql(nil).or eql("0")

    end
  end

  it "should try to create an Image with wrong float SIZE" do
    as_user("uA") do
      tmpl = <<-EOF
      NAME = test_img
      TYPE = DATABLOCK
      fstype = ext3
      size = 1024.5
      EOF

      cli_create("oneimage create -d 1", tmpl, false)

      uxml = cli_action_xml("oneuser show -x")

      expect(uxml["DATASTORE_QUOTA/DATASTORE[ID='1']/IMAGES"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["DATASTORE_QUOTA/DATASTORE[ID='1']/IMAGES_USED"]).to eql(nil).or eql("0")
      expect(uxml["DATASTORE_QUOTA/DATASTORE[ID='1']/SIZE"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(uxml["DATASTORE_QUOTA/DATASTORE[ID='1']/SIZE_USED"]).to eql(nil).or eql("0")

      gxml = cli_action_xml("onegroup show -x")

      expect(gxml["DATASTORE_QUOTA/DATASTORE[ID='1']/IMAGES"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["DATASTORE_QUOTA/DATASTORE[ID='1']/IMAGES_USED"]).to eql(nil).or eql("0")
      expect(gxml["DATASTORE_QUOTA/DATASTORE[ID='1']/SIZE"]).to eql(nil).or eql(DEFAULT_LIMIT)
      expect(gxml["DATASTORE_QUOTA/DATASTORE[ID='1']/SIZE_USED"]).to eql(nil).or eql("0")

    end
  end
end