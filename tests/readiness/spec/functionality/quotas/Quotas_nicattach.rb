#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

DUMMY_ACTIONS_DIR = "/tmp/opennebula_dummy_actions"

TMP_FILENAME = "/tmp/quotas_nicattach_test_template.txt"

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Check quotas when attaching nics to a VM" do
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
    gC_id = cli_create("onegroup create gC")

    cli_action("oneuser chgrp uA gA")
    cli_action("oneuser chgrp uB gA")
    cli_action("oneuser chgrp uC gC")


    cli_create("onehost create host0 --im dummy --vm dummy")

    cli_action("onedatastore chgrp default gA")

    cli_action("oneacl create '* NET/* CREATE'")
    cli_action("oneacl create '* CLUSTER/#0 ADMIN'")

    cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy", false)
    cli_update("onedatastore update system", "TM_MAD=dummy\nDS_MAD=dummy", false)

    wait_loop() do
      xml = cli_action_xml("onedatastore show -x default")
      xml['FREE_MB'].to_i > 0
    end

    as_user("uA") do
      tmpl = <<-EOF
      NAME = test_vnet1
      BRIDGE = br0
      VN_MAD = dummy
      AR=[TYPE = "IP4", IP = "10.0.0.10", SIZE = "100" ]
      EOF

      @vnet1_id = cli_create("onevnet create", tmpl)

      tmpl = <<-EOF
      NAME = test_vnet2
      BRIDGE = br0
      VN_MAD = dummy
      AR=[TYPE = "IP4", IP = "10.0.0.10", SIZE = "100" ]
      EOF

      @vnet2_id = cli_create("onevnet create", tmpl)

      tmpl = <<-EOT
      NAME = "test_img1"
      PATH = /tmp/none
      EOT

      @img1_id = cli_create("oneimage create -d 1", tmpl)
      wait_loop() do
        xml = cli_action_xml("oneimage show -x #{@img1_id}")
        Image::IMAGE_STATES[xml['STATE'].to_i] == "READY"
      end
    end

    #@id = -1
  end

  before(:each) do
    as_user("uA") do
      tmpl = <<-EOT
      NAME = test_vm
      MEMORY = 1024
      CPU = 1
      NIC = [
        NETWORK = test_vnet1
      ]
      DISK = [
        IMAGE = test_img1
      ]
      DISK = [
        TYPE = fs,
        SIZE = 20
      ]
      EOT

      @id = cli_create("onevm create", tmpl)

      cli_action("onevm chmod #{@id} 660")
      cli_action("onevnet chmod #{@vnet2_id} 660")
    end

    cli_action("onevm deploy #{@id} 0")

    wait_loop() do
      xml = cli_action_xml("onevm show #{@id} -x")
      OpenNebula::VirtualMachine::LCM_STATE[xml['LCM_STATE'].to_i] == 'RUNNING'
    end

    quota_file = <<-EOT
    NETWORK = [
      ID = #{@vnet1_id},
      LEASES = -1
    ]

    NETWORK = [
      ID = #{@vnet2_id},
      LEASES = -1
    ]

    VM = [
      VMS             = -1,
      MEMORY          = -1,
      CPU             = -1,
      SYSTEM_DISK_SIZE   = -1
    ]
    EOT

    cli_update("oneuser quota uA", quota_file, false)
    cli_update("oneuser quota uB", quota_file, false)
    cli_update("onegroup quota gA", quota_file, false)
  end

  after(:each) do
    cli_action("onevm recover --delete #{@id}")

    wait_loop() do
      xml = cli_action_xml("onevm show #{@id} -x")
      OpenNebula::VirtualMachine::VM_STATE[xml['STATE'].to_i] == 'DONE'
    end

    `rm #{DUMMY_ACTIONS_DIR}/* 2> /dev/null`
  end

  #---------------------------------------------------------------------------
  # HELPERS
  #---------------------------------------------------------------------------

  def check_initial_quotas()
    uA_xml = cli_action_xml("oneuser show -x uA")

    expect(uA_xml["VM_QUOTA/VM/VMS_USED"]).to eql("1")
    expect(uA_xml["VM_QUOTA/VM/CPU_USED"]).to eql("1")
    expect(uA_xml["VM_QUOTA/VM/MEMORY_USED"]).to eql("1024")

    expect(uA_xml["NETWORK_QUOTA/NETWORK[ID='#{@vnet1_id}']/LEASES_USED"]).to eql("1")
    expect(uA_xml["NETWORK_QUOTA/NETWORK[ID='#{@vnet2_id}']/LEASES_USED"]).to eql(nil).or eql("0")

    uB_xml = cli_action_xml("oneuser show -x uB")

    expect(uB_xml["VM_QUOTA/VM/VMS_USED"]).to eql(nil).or eql("0")
    expect(uB_xml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
    expect(uB_xml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")

    expect(uB_xml["NETWORK_QUOTA/NETWORK[ID='#{@vnet1_id}']/LEASES_USED"]).to eql(nil).or eql("0")
    expect(uB_xml["NETWORK_QUOTA/NETWORK[ID='#{@vnet2_id}']/LEASES_USED"]).to eql(nil).or eql("0")

    uC_xml = cli_action_xml("oneuser show -x uC")

    expect(uC_xml["VM_QUOTA/VM/VMS_USED"]).to eql(nil).or eql("0")
    expect(uC_xml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
    expect(uC_xml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")

    expect(uC_xml["NETWORK_QUOTA/NETWORK[ID='#{@vnet1_id}']/LEASES_USED"]).to eql(nil).or eql("0")
    expect(uC_xml["NETWORK_QUOTA/NETWORK[ID='#{@vnet2_id}']/LEASES_USED"]).to eql(nil).or eql("0")

    gA_xml = cli_action_xml("onegroup show -x gA")

    expect(gA_xml["VM_QUOTA/VM/VMS_USED"]).to eql("1")
    expect(gA_xml["VM_QUOTA/VM/CPU_USED"]).to eql("1")
    expect(gA_xml["VM_QUOTA/VM/MEMORY_USED"]).to eql("1024")

    expect(gA_xml["NETWORK_QUOTA/NETWORK[ID='#{@vnet1_id}']/LEASES_USED"]).to eql("1")
    expect(gA_xml["NETWORK_QUOTA/NETWORK[ID='#{@vnet2_id}']/LEASES_USED"]).to eql(nil).or eql("0")
  end

  def check_quotas_nic_attach()
    uA_xml = cli_action_xml("oneuser show -x uA")

    expect(uA_xml["VM_QUOTA/VM/VMS_USED"]).to eql("1")
    expect(uA_xml["VM_QUOTA/VM/CPU_USED"]).to eql("1")
    expect(uA_xml["VM_QUOTA/VM/MEMORY_USED"]).to eql("1024")

    expect(uA_xml["NETWORK_QUOTA/NETWORK[ID='#{@vnet1_id}']/LEASES_USED"]).to eql("1")
    expect(uA_xml["NETWORK_QUOTA/NETWORK[ID='#{@vnet2_id}']/LEASES_USED"]).to eql("1")

    uB_xml = cli_action_xml("oneuser show -x uB")

    expect(uB_xml["VM_QUOTA/VM/VMS_USED"]).to eql(nil).or eql("0")
    expect(uB_xml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
    expect(uB_xml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")

    expect(uB_xml["NETWORK_QUOTA/NETWORK[ID='#{@vnet1_id}']/LEASES_USED"]).to eql(nil).or eql("0")
    expect(uB_xml["NETWORK_QUOTA/NETWORK[ID='#{@vnet2_id}']/LEASES_USED"]).to eql(nil).or eql("0")

    uC_xml = cli_action_xml("oneuser show -x uC")

    expect(uC_xml["VM_QUOTA/VM/VMS_USED"]).to eql(nil).or eql("0")
    expect(uC_xml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
    expect(uC_xml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")

    expect(uC_xml["NETWORK_QUOTA/NETWORK[ID='#{@vnet1_id}']/LEASES_USED"]).to eql(nil).or eql("0")
    expect(uC_xml["NETWORK_QUOTA/NETWORK[ID='#{@vnet2_id}']/LEASES_USED"]).to eql(nil).or eql("0")

    gA_xml = cli_action_xml("onegroup show -x gA")

    expect(gA_xml["VM_QUOTA/VM/VMS_USED"]).to eql("1")
    expect(gA_xml["VM_QUOTA/VM/CPU_USED"]).to eql("1")
    expect(gA_xml["VM_QUOTA/VM/MEMORY_USED"]).to eql("1024")

    expect(gA_xml["NETWORK_QUOTA/NETWORK[ID='#{@vnet1_id}']/LEASES_USED"]).to eql("1")
    expect(gA_xml["NETWORK_QUOTA/NETWORK[ID='#{@vnet2_id}']/LEASES_USED"]).to eql("1")
  end

  def check_empy_quotas()
    uA_xml = cli_action_xml("oneuser show -x uA")

    expect(uA_xml["VM_QUOTA/VM/VMS_USED"]).to eql(nil).or eql("0").or eql("0")
    expect(uA_xml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0").or eql("0")
    expect(uA_xml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0").or eql("0")

    expect(uA_xml["IMAGE_QUOTA/IMAGE[ID='#{@img1_id}']/RVMS_USED"]).to eql(nil).or eql("0").or eql("0")
    expect(uA_xml["IMAGE_QUOTA/IMAGE[ID='#{@img2_id}']/RVMS_USED"]).to eql(nil).or eql("0").or eql("0")
    expect(uA_xml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql(nil).or eql("0").or eql("0")

    uB_xml = cli_action_xml("oneuser show -x uB")

    expect(uB_xml["VM_QUOTA/VM/VMS_USED"]).to eql(nil).or eql("0").or eql("0")
    expect(uB_xml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0").or eql("0")
    expect(uB_xml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0").or eql("0")

    expect(uB_xml["IMAGE_QUOTA/IMAGE[ID='#{@img1_id}']/RVMS_USED"]).to eql(nil).or eql("0").or eql("0")
    expect(uB_xml["IMAGE_QUOTA/IMAGE[ID='#{@img2_id}']/RVMS_USED"]).to eql(nil).or eql("0").or eql("0")
    expect(uB_xml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql(nil).or eql("0").or eql("0")

    uC_xml = cli_action_xml("oneuser show -x uC")

    expect(uC_xml["VM_QUOTA/VM/VMS_USED"]).to eql(nil).or eql("0").or eql("0")
    expect(uC_xml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0").or eql("0")
    expect(uC_xml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0").or eql("0")

    expect(uC_xml["IMAGE_QUOTA/IMAGE[ID='#{@img1_id}']/RVMS_USED"]).to eql(nil).or eql("0").or eql("0")
    expect(uC_xml["IMAGE_QUOTA/IMAGE[ID='#{@img2_id}']/RVMS_USED"]).to eql(nil).or eql("0").or eql("0")
    expect(uC_xml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql(nil).or eql("0").or eql("0")

    gA_xml = cli_action_xml("onegroup show -x gA")

    expect(gA_xml["VM_QUOTA/VM/VMS_USED"]).to eql(nil).or eql("0").or eql("0")
    expect(gA_xml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0").or eql("0")
    expect(gA_xml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0").or eql("0")

    expect(gA_xml["IMAGE_QUOTA/IMAGE[ID='#{@img1_id}']/RVMS_USED"]).to eql(nil).or eql("0").or eql("0")
    expect(gA_xml["IMAGE_QUOTA/IMAGE[ID='#{@img2_id}']/RVMS_USED"]).to eql(nil).or eql("0").or eql("0")
    expect(gA_xml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql(nil).or eql("0").or eql("0")
  end

  def wait_vm_state(state)
    wait_loop() do
      xml = cli_action_xml("onevm show #{@id} -x")
      OpenNebula::VirtualMachine::VM_STATE[xml['STATE'].to_i] == state
    end
  end

  def wait_vm_lcm_state(state)
    wait_loop() do
      xml = cli_action_xml("onevm show #{@id} -x")
      OpenNebula::VirtualMachine::LCM_STATE[xml['LCM_STATE'].to_i] == state
    end
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  it "should check initial quotas" do
    check_initial_quotas()
  end

  it "should check empty quotas" do
    as_user("uA") do
      cli_action("onevm terminate --hard #{@id}")

      wait_loop() do
        xml = cli_action_xml("onevm show #{@id} -x")
        OpenNebula::VirtualMachine::VM_STATE[xml['STATE'].to_i] == 'DONE'
      end
    end

    check_empy_quotas()
  end


  ################################################################################
  # Failed attach operations
  ################################################################################

  it "should fail to attach a nic if it exceeds user limits " do
    quota_file = <<-EOT
    NETWORK = [
      ID = #{@vnet1_id},
      LEASES = 1
    ]
    EOT

    file = Tempfile.new('qtest')
    file << quota_file
    file.flush
    file.close

    cli_action("oneuser quota uA #{file.path}")

    file.unlink

    as_user("uA") do
      cli_action("onevm nic-attach #{@id} --network #{@vnet1_id}", false)

      wait_vm_lcm_state("RUNNING")
    end

    check_initial_quotas()
  end

  it "should fail to attach a nic if it exceeds group limits " do
    quota_file = <<-EOT
    NETWORK = [
      ID = #{@vnet1_id},
      LEASES = 1
    ]
    EOT

    file = Tempfile.new('qtest')
    file << quota_file
    file.flush
    file.close

    cli_action("onegroup quota gA #{file.path}")

    file.unlink

    as_user("uB") do
      cli_action("onevm nic-attach #{@id} --network #{@vnet1_id}", false)

      wait_vm_lcm_state("RUNNING")
    end

    check_initial_quotas()
  end

  it "should fail to attach a nic if the user is not authorized" do
    as_user("uC") do
      cli_action("onevm nic-attach #{@id} --network #{@vnet1_id}", false)
    end

    wait_vm_lcm_state("RUNNING")

    check_initial_quotas()
  end

  it "should fail to attach a nic if the template is invalid" do

    `echo "NIC = [ NETWORK_ID = #{@vnet2_id}, IP = "192.168.192.168.192" ]" > #{TMP_FILENAME}`

    as_user("uA") do
      cli_action("onevm nic-attach #{@id} --file #{TMP_FILENAME}", false)

      wait_vm_lcm_state("RUNNING")
    end

    check_initial_quotas()
  end

  it "should fail to attach a nic if the driver fails" do
    `echo "failure" > #{DUMMY_ACTIONS_DIR}/attach_nic`

    as_user("uA") do
      cli_action("onevm nic-attach #{@id} --network #{@vnet1_id}")

      wait_vm_lcm_state("RUNNING")
    end

    check_initial_quotas()
  end

  it "should run fsck" do
    run_fsck
  end

  ################################################################################
  # Successful attach operations
  ################################################################################

  it "should attach a nic to a VM and update user & group quotas" do
    as_user("uA") do
      cli_action("onevm nic-attach #{@id} --network #{@vnet2_id}")

      wait_vm_lcm_state("RUNNING")
    end

    check_quotas_nic_attach()
  end

  it "should attach a nic to a VM owned by other user, "<<
  "and update user & group quotas" do

    as_user("uB") do
      cli_action("onevm nic-attach #{@id} --network #{@vnet2_id}")

      wait_vm_lcm_state("RUNNING")
    end

    check_quotas_nic_attach()
  end

  it "should run fsck" do
    run_fsck
  end

  ################################################################################
  # Successful attach operations + detach
  ################################################################################

  it "should attach + detach a nic to a VM and update user & group quotas" do
    as_user("uA") do
      cli_action("onevm nic-attach #{@id} --network #{@vnet2_id}")

      wait_vm_lcm_state("RUNNING")
    end

    as_user("uA") do
      cli_action("onevm nic-detach #{@id} 1")

      wait_vm_lcm_state("RUNNING")
    end

    check_initial_quotas()
  end

  it "should attach + detach a nic to a VM owned by other user, "<<
  "and update user & group quotas" do

    as_user("uB") do
      cli_action("onevm nic-attach #{@id} --network #{@vnet2_id}")

      wait_vm_lcm_state("RUNNING")
    end

    as_user("uA") do
      cli_action("onevm nic-detach #{@id} 1")

      wait_vm_lcm_state("RUNNING")
    end

    check_initial_quotas()
  end

  it "should run fsck" do
    run_fsck
  end

  ################################################################################
  # Successful attach operations + failed detach (auth)
  ################################################################################

  it "should attach + fail detach (auth) a nic to a VM and update user & group quotas" do
    as_user("uA") do
      cli_action("onevm nic-attach #{@id} --network #{@vnet2_id}")

      wait_vm_lcm_state("RUNNING")
    end

    as_user("uC") do
      cli_action("onevm nic-detach #{@id} 1", false)
    end

    wait_vm_lcm_state("RUNNING")
    check_quotas_nic_attach()
  end

  it "should attach + fail detach (auth) a nic to a VM owned by other user, "<<
  "and update user & group quotas" do

    as_user("uB") do
      cli_action("onevm nic-attach #{@id} --network #{@vnet2_id}")

      wait_vm_lcm_state("RUNNING")
    end

    as_user("uC") do
      cli_action("onevm nic-detach #{@id} 1", false)
    end

    wait_vm_lcm_state("RUNNING")
    check_quotas_nic_attach()
  end

  it "should run fsck" do
    run_fsck
  end

  ################################################################################
  # Successful attach operations + failed detach (wrong nic id)
  ################################################################################

  it "should attach + fail detach (wrong nic id) a nic to a VM and update user & group quotas" do
    as_user("uA") do
      cli_action("onevm nic-attach #{@id} --network #{@vnet2_id}")

      wait_vm_lcm_state("RUNNING")
    end

    as_user("uA") do
      cli_action("onevm nic-detach #{@id} 75", false)

      wait_vm_lcm_state("RUNNING")
    end

    check_quotas_nic_attach()
  end

  it "should attach + fail detach (wrong nic id) a nic to a VM owned by other user, "<<
  "and update user & group quotas" do

    as_user("uB") do
      cli_action("onevm nic-attach #{@id} --network #{@vnet2_id}")

      wait_vm_lcm_state("RUNNING")
    end

    as_user("uA") do
      cli_action("onevm nic-detach #{@id} 75", false)

      wait_vm_lcm_state("RUNNING")
    end

    check_quotas_nic_attach()
  end

  it "should run fsck" do
    run_fsck
  end

  ################################################################################
  # Successful attach operations + failed detach (driver)
  ################################################################################

  it "should attach + fail detach (driver) a nic to a VM and update user & group quotas" do
    as_user("uA") do
      cli_action("onevm nic-attach #{@id} --network #{@vnet2_id}")

      wait_vm_lcm_state("RUNNING")
    end

    `echo "failure" > #{DUMMY_ACTIONS_DIR}/detach_nic`

    as_user("uA") do
      cli_action("onevm nic-detach #{@id} 1")

      wait_vm_lcm_state("RUNNING")
    end

    check_quotas_nic_attach()
  end

  it "should attach + fail detach (driver) a nic to a VM owned by other user, "<<
  "and update user & group quotas" do

    as_user("uB") do
      cli_action("onevm nic-attach #{@id} --network #{@vnet2_id}")

      wait_vm_lcm_state("RUNNING")
    end

    `echo "failure" > #{DUMMY_ACTIONS_DIR}/detach_nic`

    as_user("uA") do
      cli_action("onevm nic-detach #{@id} 1")

      wait_vm_lcm_state("RUNNING")
    end

    check_quotas_nic_attach()
  end

  it "should run fsck" do
    run_fsck
  end

  ################################################################################
  # Successful attach operations + shutdown
  ################################################################################

  it "should attach + shutdown a nic to a VM and update user & group quotas" do
    as_user("uA") do
      cli_action("onevm nic-attach #{@id} --network #{@vnet2_id}")

      wait_vm_lcm_state("RUNNING")
    end

    as_user("uA") do
      cli_action("onevm terminate --hard #{@id}")

      wait_vm_state("DONE")
    end

    check_empy_quotas()
  end

  it "should attach + shutdown a nic to a VM owned by other user, "<<
  "and update user & group quotas" do

    as_user("uB") do
      cli_action("onevm nic-attach #{@id} --network #{@vnet2_id}")

      wait_vm_lcm_state("RUNNING")
    end

    as_user("uA") do
      cli_action("onevm terminate --hard #{@id}")

      wait_vm_state("DONE")
    end

    check_empy_quotas()
  end

  it "should run fsck" do
    run_fsck
  end
end