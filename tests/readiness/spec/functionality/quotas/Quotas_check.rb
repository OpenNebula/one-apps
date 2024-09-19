#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Check quotas usage records" do
  #---------------------------------------------------------------------------
  # OpenNebula bootstraping:
  #   - Define infrastructure: hosts, datastore, users, networks,...
  #   - Common instance variables: templates,...
  #---------------------------------------------------------------------------
  before(:all) do
    cli_create_user("uA", "abc")
    cli_create_user("uB", "abc")
    cli_create_user("uC", "abc")
    cli_create_user("uD", "abc")
    cli_create_user("uE", "abc")
    cli_create_user("uG", "abc")
    cli_create_user("unet", "abc")

    gA_id = cli_create("onegroup create gA")
    cli_action("oneuser chgrp uA gA")
    cli_action("oneuser chgrp uB gA")

    cli_create("onehost create host0 --im dummy --vm dummy")


    cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy", false)
    cli_update("onedatastore update system", "TM_MAD=dummy\nDS_MAD=dummy", false)

    wait_loop() do
      xml = cli_action_xml("onedatastore show -x default")
      xml['FREE_MB'].to_i > 0
    end

    tmpl = <<-EOT
    NAME = "test_img"
    PATH = /tmp/none
    EOT

    @img_id = cli_create("oneimage create -d 1", tmpl)

    cli_action("oneimage chmod #{@img_id} 664" )

    cli_action("onedatastore chgrp default gA")

    cli_action("oneacl create '* NET/* CREATE'")
    cli_action("oneacl create '* CLUSTER/#0 ADMIN'")

    as_user("uA") do
      tmpl = <<-EOF
      NAME = test_vnet
      BRIDGE = br0
      VN_MAD = dummy
      AR=[TYPE = "IP4", IP = "10.0.0.10", SIZE = "100" ]
      EOF

      @net_uA_id = cli_create("onevnet create", tmpl)
    end
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  it "should not allow a user to change its own quotas" do
    as_user("uA") do
      quota_file = "DATASTORE = [ ID = 0, SIZE = 1024 ]"

      cli_update("oneuser quota uA", quota_file, false, false)
    end
  end


  it "should not allow to set a quota with a wrong limit" do
    quota_file = <<-EOT
    DATASTORE = [
      ID = 8,
      SIZE   = -1,
      IMAGES = 10,
    ]
    EOT

    cli_update("oneuser quota uA", quota_file, false, false)

    quota_file = <<-EOT
    NETWORK = [
      LEASES = -1
    ]
    EOT

    cli_update("oneuser quota uA", quota_file, false, false)
  end

  it "should not allow to set a quota with bad syntax" do
    quota_file = <<-EOT
    DATASTORE = [
      ID = 8,
      SIZE = 1
      IMAGES = 10,
    ]
    EOT

    cli_update("oneuser quota uA", quota_file, false, false)
  end

  it "should not allow a user to create an image if SIZE are exceeded" do
    quota_file = <<-EOT
    DATASTORE = [
      ID = 1,
      SIZE = 1500,
      IMAGES = 10
    ]
    EOT

    cli_update("oneuser quota uA", quota_file, false)

    as_user("uA") do
      tmpl = <<-EOT
      NAME = "test_img"
      PATH = /tmp/none
      EOT

      id1 = cli_create("oneimage create -d 1", tmpl)

      tmpl = <<-EOT
      NAME = "test_img2"
      PATH = /tmp/none
      EOT

      cli_create("oneimage create -d 1", tmpl, false)

      cli_action("oneimage delete #{id1}")
    end
  end

  it "should not allow a user to create an image if IMAGE/RVMS are exceeded" do
    quota_file = <<-EOT
    DATASTORE = [
      ID = 1,
      SIZE = -2,
      IMAGES = -2
    ]

    IMAGE = [
      ID = 0,
      RVMS = 1
    ]
    EOT

    cli_update("oneuser quota uA", quota_file, false)

    as_user("uA") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1024
      CPU = 1
      NIC = [
        NETWORK = test_vnet
      ]
      DISK = [
        IMAGE_ID = 0
      ]
      EOT

      id2 = cli_create("onevm create", tmpl)

      cli_create("onevm create", tmpl, false)

      cli_action("onevm terminate --hard #{id2}")
    end
  end

  it "should not allow a user to create an image if NET/LEASES are exceeded" do
    quota_file = <<-EOT
    IMAGE = [
      ID = 1,
      RVMS = -2
    ]

    NETWORK = [
      ID = 0,
      LEASES = 2
    ]
    EOT

    cli_update("oneuser quota uA", quota_file, false)

    as_user("uA") do

      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1024
      CPU = 1
      NIC = [
        NETWORK = test_vnet
      ]
      EOT

      id2 = cli_create("onevm create", tmpl)
      id3 = cli_create("onevm create", tmpl)
      cli_create("onevm create", tmpl, false)

      cli_action("onevm terminate --hard #{id2}")
      cli_action("onevm terminate --hard #{id3}")
    end
  end

  it "should not allow a user to create a VM if VM/MEMORY is exceeded" do
    quota_file = <<-EOT
    NETWORK = [
      ID = 0,
      LEASES = -2
    ]

    VM = [
      VMS = 3,
      MEMORY = 1500,
      CPU = -2,
      SYSTEM_DISK_SIZE = -2
    ]
    EOT

    cli_update("oneuser quota uA", quota_file, false)

    as_user("uA") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1024
      CPU = 1
      NIC = [
        NETWORK = test_vnet
      ]
      EOT

      id2 = cli_create("onevm create", tmpl)
      cli_create("onevm create", tmpl, false)

      cli_action("onevm terminate --hard #{id2}")
    end
  end

  it "should not allow a user to create a VM if VM/SYSTEM_DISK_SIZE is exceeded" do
    quota_file = <<-EOT
    VM = [
      VMS = -2,
      MEMORY = -2,
      CPU = -2,
      SYSTEM_DISK_SIZE = 20
    ]
    EOT

    cli_update("oneuser quota uA", quota_file, false)

    as_user("uA") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1024
      CPU = 1
      DISK = [
        TYPE = fs,
        SIZE = 15
      ]
      EOT

      id2 = cli_create("onevm create", tmpl)
      cli_create("onevm create", tmpl, false)

      cli_action("onevm terminate --hard #{id2}")
    end
  end

  it "should not allow a user to change its group quotas" do
    as_user("uA") do
      quota_file = "DATASTORE = [ ID = 0, SIZE = 1024 ]"

      cli_update("onegroup quota gA", quota_file, false, false)
    end
  end


  it "should not allow to set a group quota with a wrong limit" do
    quota_file = <<-EOT
    DATASTORE = [
      ID = 8,
      SIZE   = -1,
      IMAGES = 10,
    ]
    EOT

    cli_update("onegroup quota gA", quota_file, false, false)

    quota_file = <<-EOT
    NETWORK = [
      LEASES = -1
    ]
    EOT

    cli_update("onegroup quota gA", quota_file, false, false)
  end

  it "should not allow to set a group quota with bad syntax" do
    quota_file = <<-EOT
    DATASTORE = [
      ID = 8,
      SIZE = 1
      IMAGES = 10,
    ]
    EOT

    cli_update("onegroup quota gA", quota_file, false, false)
  end

  it "should not allow a user to create an image if IMAGES group are exceeded" do
    quota_file = <<-EOT
    DATASTORE = [
      ID = 1,
      SIZE = -2,
      IMAGES  = 2
    ]
    EOT

    cli_update("onegroup quota gA", quota_file, false)

    as_user("uA") do
      tmpl = <<-EOT
      NAME = "test_img"
      PATH = /tmp/none
      EOT

      id1 = cli_create("oneimage create -d 1", tmpl)

      tmpl = <<-EOT
      NAME = "test_img2"
      PATH = /tmp/none
      EOT

      id2 = cli_create("oneimage create -d 1", tmpl)
    end

    as_user("uB") do
      tmpl = <<-EOT
      NAME = "test_img"
      PATH = /tmp/none
      EOT

      cli_create("oneimage create -d 1", tmpl, false)
    end
  end

  it "should not allow a user to create an image if VMS group are exceeded" do
    quota_file = <<-EOT
    DATASTORE = [
      ID = 1,
      SIZE = -2,
      IMAGES = -2
    ]

    VM = [
      MEMORY = -2,
      VMS = 2
    ]
    EOT

    cli_update("onegroup quota gA", quota_file, false)

    as_user("uA") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 10
      CPU = 1
      NIC = [
        NETWORK = test_vnet
      ]
      EOT

      id2 = cli_create("onevm create", tmpl)
      id3 = cli_create("onevm create", tmpl)
    end

    as_user("uB") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 10
      CPU = 1
      NIC = [
        NETWORK = test_vnet
      ]
      EOT

      cli_create("onevm create", tmpl, false)
    end
  end

  it "should not allow a user to create an image if RUNNING_MEMORY for a user is exceeded" do
    quota_file = <<-EOT
    VM = [
      RUNNING_MEMORY = 4,
      MEMORY = -2,
      VMS = 4
    ]
    EOT

    cli_update("oneuser quota uC", quota_file, false)

    as_user("uC") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1
      CPU = 1
      EOT

      id1 = cli_create("onevm create", tmpl)
      id2 = cli_create("onevm create", tmpl)
      id3 = cli_create("onevm create", tmpl)
      id4 = cli_create("onevm create", tmpl)
      id5 = cli_create("onevm create", tmpl, false)

      xml_user = cli_action_xml("oneuser show uC -x")

      expect(xml_user["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eq("4")
      expect(xml_user["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eq("4")
      expect(xml_user["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eq("4")

      cli_action("onevm terminate --hard #{id1}")
    end

    xml_user = cli_action_xml("oneuser show uC -x")

    expect(xml_user["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eq("3")
    expect(xml_user["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eq("3")
    expect(xml_user["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eq("3")
  end

  it "should check the transition between RUNNING to POWEROFF and POWEROFF to RUNNING" do

    as_user("uD") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1
      CPU = 2
      EOT

      @id1 = cli_create("onevm create", tmpl)
      @id2 = cli_create("onevm create", tmpl)
    end

    xml_user = cli_action_xml("oneuser show uD -x")

    expect(xml_user["VM_QUOTA/VM/MEMORY_USED"]).to eq("2")
    expect(xml_user["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eq("2")
    expect(xml_user["VM_QUOTA/VM/CPU_USED"]).to eq("4")
    expect(xml_user["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eq("4")
    expect(xml_user["VM_QUOTA/VM/VMS_USED"]).to eq("2")
    expect(xml_user["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eq("2")

    cli_action("onevm deploy #{@id1} host0")
    cli_action("onevm deploy #{@id2} host0")

    vm = VM.new(@id1)

    vm.running?

    cli_action("onevm poweroff --hard #{@id1}")

    vm.state?("POWEROFF")

    xml_user = cli_action_xml("oneuser show uD -x")

    expect(xml_user["VM_QUOTA/VM/MEMORY_USED"]).to eq("2")
    expect(xml_user["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eq("1")
    expect(xml_user["VM_QUOTA/VM/CPU_USED"]).to eq("4")
    expect(xml_user["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eq("2")
    expect(xml_user["VM_QUOTA/VM/VMS_USED"]).to eq("2")
    expect(xml_user["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eq("1")

    cli_action("onevm resume #{@id1}")

    vm.running?

    xml_user = cli_action_xml("oneuser show uD -x")

    expect(xml_user["VM_QUOTA/VM/MEMORY_USED"]).to eq("2")
    expect(xml_user["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eq("2")
    expect(xml_user["VM_QUOTA/VM/CPU_USED"]).to eq("4")
    expect(xml_user["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eq("4")
    expect(xml_user["VM_QUOTA/VM/VMS_USED"]).to eq("2")
    expect(xml_user["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eq("2")

    cli_action("onevm terminate --hard #{@id1}")
    cli_action("onevm terminate --hard #{@id2}")

    vm.done?
  end

  it "should check the transition between RUNNING to SUSPEND and SUSPEND to RUNNING" do
    as_user("uD") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1
      CPU = 2
      EOT

      @id1 = cli_create("onevm create", tmpl)
      @id2 = cli_create("onevm create", tmpl)
    end

    xml_user = cli_action_xml("oneuser show uD -x")

    expect(xml_user["VM_QUOTA/VM/MEMORY_USED"]).to eq("2")
    expect(xml_user["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eq("2")
    expect(xml_user["VM_QUOTA/VM/CPU_USED"]).to eq("4")
    expect(xml_user["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eq("4")
    expect(xml_user["VM_QUOTA/VM/VMS_USED"]).to eq("2")
    expect(xml_user["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eq("2")

    cli_action("onevm deploy #{@id1} host0")
    cli_action("onevm deploy #{@id2} host0")

    vm = VM.new(@id1)

    vm.running?

    cli_action("onevm suspend #{@id1}")

    vm.state?("SUSPENDED")

    xml_user = cli_action_xml("oneuser show uD -x")

    expect(xml_user["VM_QUOTA/VM/MEMORY_USED"]).to eq("2")
    expect(xml_user["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eq("1")
    expect(xml_user["VM_QUOTA/VM/CPU_USED"]).to eq("4")
    expect(xml_user["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eq("2")
    expect(xml_user["VM_QUOTA/VM/VMS_USED"]).to eq("2")
    expect(xml_user["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eq("1")

    cli_action("onevm resume #{@id1}")

    vm.running?

    xml_user = cli_action_xml("oneuser show uD -x")

    expect(xml_user["VM_QUOTA/VM/MEMORY_USED"]).to eq("2")
    expect(xml_user["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eq("2")
    expect(xml_user["VM_QUOTA/VM/CPU_USED"]).to eq("4")
    expect(xml_user["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eq("4")
    expect(xml_user["VM_QUOTA/VM/VMS_USED"]).to eq("2")
    expect(xml_user["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eq("2")

    cli_action("onevm terminate --hard #{@id1}")
    cli_action("onevm terminate --hard #{@id2}")

    vm.done?
  end

  it "should check the transition between RUNNING to UNDEPLOY and UNDEPLOY to RUNNING" do
    as_user("uE") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1
      CPU = 2
      EOT

      @id1 = cli_create("onevm create", tmpl)
      @id2 = cli_create("onevm create", tmpl)
    end

    xml_user_uE = cli_action_xml("oneuser show uE -x")

    expect(xml_user_uE["VM_QUOTA/VM/MEMORY_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/CPU_USED"]).to eq("4")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eq("4")
    expect(xml_user_uE["VM_QUOTA/VM/VMS_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eq("2")

    cli_action("onevm deploy #{@id1} host0")
    cli_action("onevm deploy #{@id2} host0")

    vm = VM.new(@id1)

    vm.running?

    cli_action("onevm undeploy #{@id1}")

    vm.undeployed?

    xml_user_uE = cli_action_xml("oneuser show uE -x")

    expect(xml_user_uE["VM_QUOTA/VM/MEMORY_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eq("1")
    expect(xml_user_uE["VM_QUOTA/VM/CPU_USED"]).to eq("4")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/VMS_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eq("1")

    cli_action("onevm resume #{@id1}")

    xml_user_uE = cli_action_xml("oneuser show uE -x")

    expect(xml_user_uE["VM_QUOTA/VM/MEMORY_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/CPU_USED"]).to eq("4")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eq("4")
    expect(xml_user_uE["VM_QUOTA/VM/VMS_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eq("2")

    cli_action("onevm terminate --hard #{@id1}")
    cli_action("onevm terminate --hard #{@id2}")

    vm.done?
  end

  it "should check the transition between RUNNING to STOP and STOP to RUNNING" do
    as_user("uE") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1
      CPU = 2
      EOT

      @id1 = cli_create("onevm create", tmpl)
      @id2 = cli_create("onevm create", tmpl)
    end

    xml_user_uE = cli_action_xml("oneuser show uE -x")

    expect(xml_user_uE["VM_QUOTA/VM/MEMORY_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/CPU_USED"]).to eq("4")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eq("4")
    expect(xml_user_uE["VM_QUOTA/VM/VMS_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eq("2")

    cli_action("onevm deploy #{@id1} host0")
    cli_action("onevm deploy #{@id2} host0")

    vm = VM.new(@id1)

    vm.running?

    cli_action("onevm stop #{@id1}")

    vm.state?("STOPPED")

    xml_user_uE = cli_action_xml("oneuser show uE -x")

    expect(xml_user_uE["VM_QUOTA/VM/MEMORY_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eq("1")
    expect(xml_user_uE["VM_QUOTA/VM/CPU_USED"]).to eq("4")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/VMS_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eq("1")

    cli_action("onevm resume #{@id1}")

    xml_user_uE = cli_action_xml("oneuser show uE -x")

    expect(xml_user_uE["VM_QUOTA/VM/MEMORY_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/CPU_USED"]).to eq("4")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eq("4")
    expect(xml_user_uE["VM_QUOTA/VM/VMS_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eq("2")

    cli_action("onevm terminate --hard #{@id1}")
    cli_action("onevm terminate --hard #{@id2}")

    vm.done?
  end

  it "should check the transition between RUNNING to POWEROFF and POWEROFF to TERMINATE" do
    as_user('uD') do
      tmpl = <<-EOT
        NAME = "test_vm"
        MEMORY = 1
        CPU = 2
      EOT

      @id1 = cli_create('onevm create', tmpl)
    end

    xml_user = cli_action_xml('oneuser show uD -x')

    expect(xml_user['VM_QUOTA/VM/MEMORY_USED']).to eq('1')
    expect(xml_user['VM_QUOTA/VM/RUNNING_MEMORY_USED']).to eq('1')
    expect(xml_user['VM_QUOTA/VM/CPU_USED']).to eq('2')
    expect(xml_user['VM_QUOTA/VM/RUNNING_CPU_USED']).to eq('2')
    expect(xml_user['VM_QUOTA/VM/VMS_USED']).to eq('1')
    expect(xml_user['VM_QUOTA/VM/RUNNING_VMS_USED']).to eq('1')

    cli_action("onevm deploy #{@id1} host0")

    vm = VM.new(@id1)

    vm.running?

    cli_action("onevm poweroff --hard #{@id1}")

    vm.state?('POWEROFF')

    xml_user = cli_action_xml('oneuser show uD -x')

    expect(xml_user['VM_QUOTA/VM/MEMORY_USED']).to eq('1')
    expect(xml_user['VM_QUOTA/VM/RUNNING_MEMORY_USED']).to eq('0')
    expect(xml_user['VM_QUOTA/VM/CPU_USED']).to eq('2')
    expect(xml_user['VM_QUOTA/VM/RUNNING_CPU_USED']).to eq('0')
    expect(xml_user['VM_QUOTA/VM/VMS_USED']).to eq('1')
    expect(xml_user['VM_QUOTA/VM/RUNNING_VMS_USED']).to eq('0')

    # During transition from poweroff->terminate the quota is temporary exceeded
    quota_file = <<-EOT
      VM = [
        RUNNING_CPU = 1
      ]
    EOT

    cli_update('oneuser quota uD', quota_file, false)

    cli_action("onevm terminate --hard #{@id1}")

    vm.done?

    xml_user = cli_action_xml('oneuser show uD -x')

    expect(xml_user['VM_QUOTA/VM/MEMORY_USED']).to eq('0')
    expect(xml_user['VM_QUOTA/VM/RUNNING_MEMORY_USED']).to eq('0')
    expect(xml_user['VM_QUOTA/VM/CPU_USED']).to eq('0')
    expect(xml_user['VM_QUOTA/VM/RUNNING_CPU_USED']).to eq('0')
    expect(xml_user['VM_QUOTA/VM/VMS_USED']).to eq('0')
    expect(xml_user['VM_QUOTA/VM/RUNNING_VMS_USED']).to eq('0')
  end

  it "should check the transition between RUNNING to STOPPED and STOPPED to TERMINATE" do
    quota_file = <<-EOT
      VM = [
        RUNNING_CPU = -1
      ]
    EOT

    cli_update('oneuser quota uD', quota_file, false)

    as_user('uD') do
      tmpl = <<-EOT
        NAME = "test_vm"
        MEMORY = 1
        CPU = 2
      EOT

      @id1 = cli_create('onevm create', tmpl)
    end

    xml_user = cli_action_xml('oneuser show uD -x')

    expect(xml_user['VM_QUOTA/VM/MEMORY_USED']).to eq('1')
    expect(xml_user['VM_QUOTA/VM/RUNNING_MEMORY_USED']).to eq('1')
    expect(xml_user['VM_QUOTA/VM/CPU_USED']).to eq('2')
    expect(xml_user['VM_QUOTA/VM/RUNNING_CPU_USED']).to eq('2')
    expect(xml_user['VM_QUOTA/VM/VMS_USED']).to eq('1')
    expect(xml_user['VM_QUOTA/VM/RUNNING_VMS_USED']).to eq('1')

    cli_action("onevm deploy #{@id1} host0")

    vm = VM.new(@id1)

    vm.running?

    cli_action("onevm stop #{@id1}")

    vm.state?('STOPPED')

    xml_user = cli_action_xml('oneuser show uD -x')

    expect(xml_user['VM_QUOTA/VM/MEMORY_USED']).to eq('1')
    expect(xml_user['VM_QUOTA/VM/RUNNING_MEMORY_USED']).to eq('0')
    expect(xml_user['VM_QUOTA/VM/CPU_USED']).to eq('2')
    expect(xml_user['VM_QUOTA/VM/RUNNING_CPU_USED']).to eq('0')
    expect(xml_user['VM_QUOTA/VM/VMS_USED']).to eq('1')
    expect(xml_user['VM_QUOTA/VM/RUNNING_VMS_USED']).to eq('0')

    # During transition from stopped->terminate the quota is temporary exceeded
    quota_file = <<-EOT
      VM = [
        RUNNING_CPU = 1
      ]
    EOT

    cli_update('oneuser quota uD', quota_file, false)

    cli_action("onevm terminate --hard #{@id1}")

    vm.done?

    xml_user = cli_action_xml('oneuser show uD -x')

    expect(xml_user['VM_QUOTA/VM/MEMORY_USED']).to eq('0')
    expect(xml_user['VM_QUOTA/VM/RUNNING_MEMORY_USED']).to eq('0')
    expect(xml_user['VM_QUOTA/VM/CPU_USED']).to eq('0')
    expect(xml_user['VM_QUOTA/VM/RUNNING_CPU_USED']).to eq('0')
    expect(xml_user['VM_QUOTA/VM/VMS_USED']).to eq('0')
    expect(xml_user['VM_QUOTA/VM/RUNNING_VMS_USED']).to eq('0')
  end

  it "should check the transition between RUNNING to SUSPEND and SUSPEND to TERMINATE" do
    quota_file = <<-EOT
      VM = [
        RUNNING_CPU = -1
      ]
    EOT

    cli_update('oneuser quota uD', quota_file, false)

    as_user('uD') do
      tmpl = <<-EOT
        NAME = "test_vm"
        MEMORY = 1
        CPU = 2
      EOT

      @id1 = cli_create('onevm create', tmpl)
    end

    xml_user = cli_action_xml('oneuser show uD -x')

    expect(xml_user['VM_QUOTA/VM/MEMORY_USED']).to eq('1')
    expect(xml_user['VM_QUOTA/VM/RUNNING_MEMORY_USED']).to eq('1')
    expect(xml_user['VM_QUOTA/VM/CPU_USED']).to eq('2')
    expect(xml_user['VM_QUOTA/VM/RUNNING_CPU_USED']).to eq('2')
    expect(xml_user['VM_QUOTA/VM/VMS_USED']).to eq('1')
    expect(xml_user['VM_QUOTA/VM/RUNNING_VMS_USED']).to eq('1')

    cli_action("onevm deploy #{@id1} host0")

    vm = VM.new(@id1)

    vm.running?

    cli_action("onevm suspend #{@id1}")

    vm.state?('SUSPENDED')

    xml_user = cli_action_xml('oneuser show uD -x')

    expect(xml_user['VM_QUOTA/VM/MEMORY_USED']).to eq('1')
    expect(xml_user['VM_QUOTA/VM/RUNNING_MEMORY_USED']).to eq('0')
    expect(xml_user['VM_QUOTA/VM/CPU_USED']).to eq('2')
    expect(xml_user['VM_QUOTA/VM/RUNNING_CPU_USED']).to eq('0')
    expect(xml_user['VM_QUOTA/VM/VMS_USED']).to eq('1')
    expect(xml_user['VM_QUOTA/VM/RUNNING_VMS_USED']).to eq('0')

    # During transition from suspended->terminate the quota is temporary exceeded
    quota_file = <<-EOT
      VM = [
        RUNNING_CPU = 1
      ]
    EOT

    cli_update('oneuser quota uD', quota_file, false)

    cli_action("onevm terminate --hard #{@id1}")

    vm.done?

    xml_user = cli_action_xml('oneuser show uD -x')

    expect(xml_user['VM_QUOTA/VM/MEMORY_USED']).to eq('0')
    expect(xml_user['VM_QUOTA/VM/RUNNING_MEMORY_USED']).to eq('0')
    expect(xml_user['VM_QUOTA/VM/CPU_USED']).to eq('0')
    expect(xml_user['VM_QUOTA/VM/RUNNING_CPU_USED']).to eq('0')
    expect(xml_user['VM_QUOTA/VM/VMS_USED']).to eq('0')
    expect(xml_user['VM_QUOTA/VM/RUNNING_VMS_USED']).to eq('0')
  end

  it "should check the transition between RUNNING to UNDEPLOY and UNDEPLOY to TERMINATE" do
    quota_file = <<-EOT
      VM = [
        RUNNING_CPU = -1
      ]
    EOT

    cli_update('oneuser quota uD', quota_file, false)

    as_user('uD') do
      tmpl = <<-EOT
        NAME = "test_vm"
        MEMORY = 1
        CPU = 2
      EOT

      @id1 = cli_create('onevm create', tmpl)
    end

    xml_user = cli_action_xml('oneuser show uD -x')

    expect(xml_user['VM_QUOTA/VM/MEMORY_USED']).to eq('1')
    expect(xml_user['VM_QUOTA/VM/RUNNING_MEMORY_USED']).to eq('1')
    expect(xml_user['VM_QUOTA/VM/CPU_USED']).to eq('2')
    expect(xml_user['VM_QUOTA/VM/RUNNING_CPU_USED']).to eq('2')
    expect(xml_user['VM_QUOTA/VM/VMS_USED']).to eq('1')
    expect(xml_user['VM_QUOTA/VM/RUNNING_VMS_USED']).to eq('1')

    cli_action("onevm deploy #{@id1} host0")

    vm = VM.new(@id1)

    vm.running?

    vm.undeploy

    xml_user = cli_action_xml('oneuser show uD -x')

    expect(xml_user['VM_QUOTA/VM/MEMORY_USED']).to eq('1')
    expect(xml_user['VM_QUOTA/VM/RUNNING_MEMORY_USED']).to eq('0')
    expect(xml_user['VM_QUOTA/VM/CPU_USED']).to eq('2')
    expect(xml_user['VM_QUOTA/VM/RUNNING_CPU_USED']).to eq('0')
    expect(xml_user['VM_QUOTA/VM/VMS_USED']).to eq('1')
    expect(xml_user['VM_QUOTA/VM/RUNNING_VMS_USED']).to eq('0')

    # During transition from poweroff->terminate the quota is temporary exceeded
    quota_file = <<-EOT
      VM = [
        RUNNING_CPU = 1
      ]
    EOT

    cli_update('oneuser quota uD', quota_file, false)

    cli_action("onevm terminate --hard #{@id1}")

    vm.done?

    xml_user = cli_action_xml('oneuser show uD -x')

    expect(xml_user['VM_QUOTA/VM/MEMORY_USED']).to eq('0')
    expect(xml_user['VM_QUOTA/VM/RUNNING_MEMORY_USED']).to eq('0')
    expect(xml_user['VM_QUOTA/VM/CPU_USED']).to eq('0')
    expect(xml_user['VM_QUOTA/VM/RUNNING_CPU_USED']).to eq('0')
    expect(xml_user['VM_QUOTA/VM/VMS_USED']).to eq('0')
    expect(xml_user['VM_QUOTA/VM/RUNNING_VMS_USED']).to eq('0')
  end

  it "should check the transition between RUNNING to UNDEPLOY and UNDEPLOY to RUNNING to check if user can exceed the quota" do
    quota_file = <<-EOT
    VM = [
      RUNNING_MEMORY = 2,
      MEMORY = -2,
      VMS = 4
    ]
    EOT

    cli_update("oneuser quota uE", quota_file, false)

    as_user("uE") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1
      CPU = 2
      EOT

      @id1 = cli_create("onevm create", tmpl)
      @id2 = cli_create("onevm create", tmpl)
    end

    xml_user_uE = cli_action_xml("oneuser show uE -x")

    expect(xml_user_uE["VM_QUOTA/VM/MEMORY_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/CPU_USED"]).to eq("4")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eq("4")
    expect(xml_user_uE["VM_QUOTA/VM/VMS_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eq("2")

    cli_action("onevm deploy #{@id1} host0")
    cli_action("onevm deploy #{@id2} host0")

    vm = VM.new(@id1)

    vm.running?

    cli_action("onevm undeploy #{@id1}")

    vm.state?("UNDEPLOYED")

    xml_user_uE = cli_action_xml("oneuser show uE -x")

    expect(xml_user_uE["VM_QUOTA/VM/MEMORY_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eq("1")
    expect(xml_user_uE["VM_QUOTA/VM/CPU_USED"]).to eq("4")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/VMS_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eq("1")

    quota_file = <<-EOT
    VM = [
      RUNNING_MEMORY = 1,
      MEMORY = -2,
      VMS = 4
    ]
    EOT

    cli_update("oneuser quota uE", quota_file, false)

    cli_action("onevm resume #{@id1}", false)

    quota_file = <<-EOT
    VM = [
      RUNNING_MEMORY = 2,
      MEMORY = -2,
      VMS = 4
    ]
    EOT

    cli_update("oneuser quota uE", quota_file, false)

    cli_action("onevm terminate --hard #{@id1}")
    cli_action("onevm terminate --hard #{@id2}")
  end

  it "should try to assign only one VM quota" do
    quota_file = <<-EOT

    VM = [
      VMS = 10
    ]
    EOT

    cli_create_user("uF", "abc")

    cli_update("oneuser quota uF", quota_file, false)

    user_xml = cli_action_xml("oneuser show uF -x")

    expect(user_xml["VM_QUOTA/VM/CPU"]).to eq("-1")
    expect(user_xml["VM_QUOTA/VM/MEMORY"]).to eq("-1")
    expect(user_xml["VM_QUOTA/VM/VMS"]).to eq("10")
  end

  it "should check the transition between RUNNING to UNDEPLOY and UNDEPLOY to Recover-recreate" do
    as_user("uE") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1
      CPU = 2
      EOT

      @id1 = cli_create("onevm create", tmpl)
      @id2 = cli_create("onevm create", tmpl)
    end

    xml_user_uE = cli_action_xml("oneuser show uE -x")

    expect(xml_user_uE["VM_QUOTA/VM/MEMORY_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/CPU_USED"]).to eq("4")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eq("4")
    expect(xml_user_uE["VM_QUOTA/VM/VMS_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eq("2")

    cli_action("onevm deploy #{@id1} host0")
    cli_action("onevm deploy #{@id2} host0")

    vm = VM.new(@id1)

    vm.running?

    cli_action("onevm undeploy #{@id1}")

    vm.undeployed?

    xml_user_uE = cli_action_xml("oneuser show uE -x")

    expect(xml_user_uE["VM_QUOTA/VM/MEMORY_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eq("1")
    expect(xml_user_uE["VM_QUOTA/VM/CPU_USED"]).to eq("4")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/VMS_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eq("1")

    cli_action("onevm recover --recreate #{@id1}")

    xml_user_uE = cli_action_xml("oneuser show uE -x")

    expect(xml_user_uE["VM_QUOTA/VM/MEMORY_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/CPU_USED"]).to eq("4")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eq("4")
    expect(xml_user_uE["VM_QUOTA/VM/VMS_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eq("2")

    cli_action("onevm terminate --hard #{@id1}")
    cli_action("onevm terminate --hard #{@id2}")

    vm.done?
  end

  it "should check the transition between RUNNING to UNDEPLOY and UNDEPLOY to RUNNING with DEPLOY action" do
    as_user("uE") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1
      CPU = 2
      EOT

      @id1 = cli_create("onevm create", tmpl)
      @id2 = cli_create("onevm create", tmpl)
    end

    xml_user_uE = cli_action_xml("oneuser show uE -x")

    expect(xml_user_uE["VM_QUOTA/VM/MEMORY_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/CPU_USED"]).to eq("4")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eq("4")
    expect(xml_user_uE["VM_QUOTA/VM/VMS_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eq("2")

    cli_action("onevm deploy #{@id1} host0")
    cli_action("onevm deploy #{@id2} host0")

    vm = VM.new(@id1)

    vm.running?

    cli_action("onevm undeploy #{@id1}")

    vm.undeployed?

    xml_user_uE = cli_action_xml("oneuser show uE -x")

    expect(xml_user_uE["VM_QUOTA/VM/MEMORY_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eq("1")
    expect(xml_user_uE["VM_QUOTA/VM/CPU_USED"]).to eq("4")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/VMS_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eq("1")

    cli_action("onevm deploy #{@id1} host0")

    xml_user_uE = cli_action_xml("oneuser show uE -x")

    expect(xml_user_uE["VM_QUOTA/VM/MEMORY_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/CPU_USED"]).to eq("4")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eq("4")
    expect(xml_user_uE["VM_QUOTA/VM/VMS_USED"]).to eq("2")
    expect(xml_user_uE["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eq("2")

    vm.running?

    cli_action("onevm terminate --hard #{@id1}")
    cli_action("onevm terminate --hard #{@id2}")

    vm.done?
  end

  it "should check the transition between RUNNING to UNDEPLOY and UNDEPLOY to RUNNING to check if user can exceed your group quota" do
    `onevm list -l ID|tail -n +2`.split().each do |id|
      `onevm recover --delete #{id}`
    end
    wait_loop { `onevm list -x` == "<VM_POOL/>\n" }

    quota_file = <<-EOT
    VM = [
      RUNNING_MEMORY = 2,
      MEMORY = -2,
      VMS = 10
    ]
    EOT

    cli_update("onegroup quota users", quota_file, false)

    as_user("uE") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1
      CPU = 2
      EOT

      @id1 = cli_create("onevm create", tmpl)
      @id2 = cli_create("onevm create", tmpl)
      cli_create("onevm create", tmpl, false)
    end

    xml_group = cli_action_xml("onegroup show users -x")

    expect(xml_group["VM_QUOTA/VM/MEMORY_USED"]).to eq("2")
    expect(xml_group["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eq("2")
    expect(xml_group["VM_QUOTA/VM/CPU_USED"]).to eq("4")
    expect(xml_group["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eq("4")
    expect(xml_group["VM_QUOTA/VM/VMS_USED"]).to eq("2")
    expect(xml_group["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eq("2")

    cli_action("onevm deploy #{@id1} host0")
    cli_action("onevm deploy #{@id2} host0")

    vm = VM.new(@id1)

    vm.running?

    cli_action("onevm undeploy #{@id1}")

    vm.undeployed?

    xml_group = cli_action_xml("onegroup show users -x")

    expect(xml_group["VM_QUOTA/VM/MEMORY_USED"]).to eq("2")
    expect(xml_group["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eq("1")
    expect(xml_group["VM_QUOTA/VM/CPU_USED"]).to eq("4")
    expect(xml_group["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eq("2")
    expect(xml_group["VM_QUOTA/VM/VMS_USED"]).to eq("2")
    expect(xml_group["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eq("1")

    quota_file = <<-EOT
    VM = [
      RUNNING_MEMORY = 1,
      MEMORY = -2,
      VMS = 4
    ]
    EOT

    cli_update("onegroup quota users", quota_file, false)

    cli_action("onevm resume #{@id1}", false)

    quota_file = <<-EOT
    VM = [
      RUNNING_MEMORY = 2,
      MEMORY = -2,
      VMS = 4
    ]
    EOT

    cli_update("onegroup quota users", quota_file, false)

    cli_action("onevm terminate --hard #{@id1}")
    cli_action("onevm terminate --hard #{@id2}")

      quota_file = <<-EOT
      VM = [
        RUNNING_MEMORY = -1,
        MEMORY = -1,
        VMS = -1
      ]
      EOT

      cli_update("onegroup quota users", quota_file, false)
  end

  it "should check running quotas with float" do
    as_user("uG") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1
      CPU = 1.2
      EOT

      @id1 = cli_create("onevm create", tmpl)
      @id2 = cli_create("onevm create", tmpl)
    end

    xml_user_uG = cli_action_xml("oneuser show uG -x")

    expect(xml_user_uG["VM_QUOTA/VM/CPU_USED"]).to eq("2.40")
    expect(xml_user_uG["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eq("2.40")

    cli_action("onevm deploy #{@id1} host0")
    cli_action("onevm deploy #{@id2} host0")

    vm = VM.new(@id1)

    vm.running?

    cli_action("onevm undeploy #{@id1}")

    vm.undeployed?

    xml_user_uG = cli_action_xml("oneuser show uG -x")

    expect(xml_user_uG["VM_QUOTA/VM/CPU_USED"]).to eq("2.40")
    expect(xml_user_uG["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eq("1.20")

    cli_action("onevm deploy #{@id1} host0")

    vm.running?

    xml_user_uG = cli_action_xml("oneuser show uG -x")

    expect(xml_user_uG["VM_QUOTA/VM/CPU_USED"]).to eq("2.40")
    expect(xml_user_uG["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eq("2.40")

    cli_action("onevm terminate --hard #{@id1}")
    cli_action("onevm terminate --hard #{@id2}")
  end

  it "should create a NIC & CONTEXT with VNET and NETWORK_MODE = auto and a user without networks" do
    cli_action("onevnet chown test_vnet unet")

    as_user("unet") do
        template=<<-EOF
        NAME   = "vmtest"
        CPU    = 1
        MEMORY = 128
        NIC    = [ NETWORK_MODE = "auto" ]
        CONTEXT= [ NETWORK = "YES" ]
        EOF

        vm_id  = cli_create("onevm create", template)
        user_xml = cli_action_xml("oneuser show -x unet")

        expect(user_xml["NETWORK_QUOTA/NETWORK"]).to be_nil

        template=<<-EOF
        NAME   = "vmtest"
        CPU    = 1
        MEMORY = 128
        NIC    = [ NETWORK = "test_vnet" ]
        NIC    = [ NETWORK_MODE = "auto" ]
        CONTEXT= [ NETWORK = "YES" ]
        EOF

        vm_id  = cli_create("onevm create", template)
        user_xml = cli_action_xml("oneuser show -x unet")

        expect(user_xml["NETWORK_QUOTA/NETWORK/LEASES_USED"]).to eq("1")
    end
  end

  it "should create a NIC & CONTEXT with VNET and NETWORK_MODE = auto and a user without networks" do
    quota_file = <<-EOT
      NETWORK = [
        ID = #{@net_uA_id},
        LEASES = 3
      ]
      EOT

    cli_update("oneuser quota unet", quota_file, false)

    as_user("unet") do
        template=<<-EOF
        NAME   = "vmtest"
        CPU    = 1
        MEMORY = 128
        NIC    = [ NETWORK_MODE = "auto" ]
        CONTEXT= [ NETWORK = "YES" ]
        EOF

        @vm_id_2  = cli_create("onevm create", template)
        user_xml = cli_action_xml("oneuser show -x unet")

        expect(user_xml["NETWORK_QUOTA/NETWORK/LEASES_USED"]).to eq("1")

        template=<<-EOF
        NAME   = "vmtest"
        CPU    = 1
        MEMORY = 128
        NIC    = [ NETWORK = "test_vnet" ]
        NIC    = [ NETWORK = "test_vnet" ]
        NIC    = [ NETWORK_MODE = "auto" ]
        CONTEXT= [ NETWORK = "YES" ]
        EOF

        @vm_id  = cli_create("onevm create", template)
        user_xml = cli_action_xml("oneuser show -x unet")

        expect(user_xml["NETWORK_QUOTA/NETWORK/LEASES_USED"]).to eq("3")
    end

    template_deploy=<<-EOF
      NIC    = [ NIC_ID = 1, NETWORK_MODE = "auto", NETWORK_ID = #{@net_uA_id} ]
    EOF

    cli_update("onevm deploy #{@vm_id} host0 -f", template_deploy, false, false)

    user_xml = cli_action_xml("oneuser show -x unet")

    expect(user_xml["NETWORK_QUOTA/NETWORK/LEASES_USED"]).to eq("3")

    template_deploy=<<-EOF
      NIC    = [ NIC_ID = 2, NETWORK_MODE = "auto", NETWORK_ID = #{@net_uA_id} ]
    EOF

    cli_update("onevm deploy #{@vm_id} host0 -f", template_deploy, false, false)

    quota_file = <<-EOT
      NETWORK = [
        ID = #{@net_uA_id},
        LEASES = 5
      ]
      EOT

    cli_update("oneuser quota unet", quota_file, false)

    cli_update("onevm deploy #{@vm_id} host0 -f", template_deploy, false)

    user_xml = cli_action_xml("oneuser show -x unet")

    expect(user_xml["NETWORK_QUOTA/NETWORK/LEASES_USED"]).to eq("4")
  end

  it "should run fsck" do
    run_fsck
  end
end
