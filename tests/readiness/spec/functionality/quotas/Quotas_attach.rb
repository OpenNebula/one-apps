#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

DUMMY_ACTIONS_DIR = "/tmp/opennebula_dummy_actions"

TMP_FILENAME = "/tmp/quotas_attach_test_template.txt"

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Check quotas when attaching disks to a VM" do
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
      tmpl = <<-EOT
      NAME = "test_img1"
      TYPE = "DATABLOCK"
      FSTYPE = "ext3"
      SIZE = 100
      EOT

      @img1_id = cli_create("oneimage create -d 1", tmpl)

      tmpl = <<-EOT
      NAME = "test_img2"
      TYPE = "DATABLOCK"
      FSTYPE = "ext3"
      SIZE = 1000
      EOT

      @img2_id = cli_create("oneimage create -d 1", tmpl)

      cli_action("oneimage chmod #{@img1_id} 660")
      cli_action("oneimage chmod #{@img2_id} 660")

      wait_loop() do
        xml = cli_action_xml("oneimage show -x #{@img2_id}")
        Image::IMAGE_STATES[xml['STATE'].to_i] == "READY"
      end

      tmpl = <<-EOF
      NAME = test_vnet
      BRIDGE = br0
      VN_MAD = dummy
      AR=[TYPE = "IP4", IP = "10.0.0.10", SIZE = "100" ]
      EOF

      @net_id = cli_create("onevnet create", tmpl)
    end
  end

  before(:each) do
    as_user("uA") do
      tmpl = <<-EOT
      NAME = test_vm
      MEMORY = 1024
      CPU = 1
      NIC = [
        NETWORK = test_vnet
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
      @vm = VM.new(@id)

      cli_action("onevm chmod #{@id} 660")
    end

    cli_action("onevm deploy #{@id} 0")

    quota_file = <<-EOT
    IMAGE = [
      ID = #{@img1_id},
      RVMS = -1
    ]

    IMAGE = [
      ID = #{@img2_id},
      RVMS = -1
    ]

    VM = [
      VMS             = -1,
      MEMORY          = -1,
      CPU             = -1,
      SYSTEM_DISK_SIZE= -1
    ]
    EOT

    cli_update("oneuser quota uA", quota_file, false)
    cli_update("oneuser quota uB", quota_file, false)
    cli_update("onegroup quota gA", quota_file, false)

    `echo "DISK = [ TYPE = fs, SIZE = 20 ]" > #{TMP_FILENAME}`

    @vm.running?
  end

  after(:each) do
    # Recover driver actions
    replace_in_file("#{ONE_VAR_LOCATION}/remotes/tm/dummy/clone", /exit 1/, 'exit 0')
    replace_in_file("#{ONE_VAR_LOCATION}/remotes/tm/dummy/delete", /exit 1/, 'exit 0')
    `rm #{DUMMY_ACTIONS_DIR}/* 2> /dev/null`

    # Cleanup VM
    cli_action("onevm recover --delete #{@id}")

    @vm.done?
  end

  #---------------------------------------------------------------------------
  # HELPERS
  #---------------------------------------------------------------------------

  def check_initial_quotas(running = true)
    uA_xml = cli_action_xml("oneuser show -x uA")

    expect(uA_xml["VM_QUOTA/VM/VMS_USED"]).to eql "1"
    expect(uA_xml["VM_QUOTA/VM/CPU_USED"]).to eql "1"
    expect(uA_xml["VM_QUOTA/VM/MEMORY_USED"]).to eql "1024"
    expect(uA_xml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql running ? "1" : "0"
    expect(uA_xml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql running ? "1" : "0"
    expect(uA_xml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql running ? "1024" : "0"

    expect(uA_xml["IMAGE_QUOTA/IMAGE[ID='#{@img1_id}']/RVMS_USED"]).to eql "1"
    expect(uA_xml["IMAGE_QUOTA/IMAGE[ID='#{@img2_id}']/RVMS_USED"]).to eql(nil).or eql("0")
    expect(uA_xml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql "120"

    uB_xml = cli_action_xml("oneuser show -x uB")

    expect(uB_xml["VM_QUOTA/VM/VMS_USED"]).to eql(nil).or eql("0")
    expect(uB_xml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
    expect(uB_xml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
    expect(uB_xml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil).or eql("0")
    expect(uB_xml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil).or eql("0")
    expect(uB_xml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil).or eql("0")

    expect(uB_xml["IMAGE_QUOTA/IMAGE[ID='#{@img1_id}']/RVMS_USED"]).to eql(nil).or eql("0")
    expect(uB_xml["IMAGE_QUOTA/IMAGE[ID='#{@img2_id}']/RVMS_USED"]).to eql(nil).or eql("0")
    expect(uB_xml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql(nil).or eql("0")

    uC_xml = cli_action_xml("oneuser show -x uC")

    expect(uC_xml["VM_QUOTA/VM/VMS_USED"]).to eql(nil).or eql("0")
    expect(uC_xml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
    expect(uC_xml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
    expect(uC_xml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil).or eql("0")
    expect(uC_xml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil).or eql("0")
    expect(uC_xml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil).or eql("0")

    expect(uC_xml["IMAGE_QUOTA/IMAGE[ID='#{@img1_id}']/RVMS_USED"]).to eql(nil).or eql("0")
    expect(uC_xml["IMAGE_QUOTA/IMAGE[ID='#{@img2_id}']/RVMS_USED"]).to eql(nil).or eql("0")
    expect(uC_xml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql(nil).or eql("0")

    gA_xml = cli_action_xml("onegroup show -x gA")

    expect(gA_xml["VM_QUOTA/VM/VMS_USED"]).to eql "1"
    expect(gA_xml["VM_QUOTA/VM/CPU_USED"]).to eql "1"
    expect(gA_xml["VM_QUOTA/VM/MEMORY_USED"]).to eql "1024"
    expect(gA_xml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql running ? "1" : "0"
    expect(gA_xml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql running ? "1" : "0"
    expect(gA_xml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql running ? "1024" : "0"

    expect(gA_xml["IMAGE_QUOTA/IMAGE[ID='#{@img1_id}']/RVMS_USED"]).to eql "1"
    expect(gA_xml["IMAGE_QUOTA/IMAGE[ID='#{@img2_id}']/RVMS_USED"]).to eql(nil).or eql("0")
    expect(gA_xml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql "120"
  end

  def check_quotas_image_attach()
    uA_xml = cli_action_xml("oneuser show -x uA")

    expect(uA_xml["VM_QUOTA/VM/VMS_USED"]).to eql "1"
    expect(uA_xml["VM_QUOTA/VM/CPU_USED"]).to eql "1"
    expect(uA_xml["VM_QUOTA/VM/MEMORY_USED"]).to eql "1024"

    expect(uA_xml["IMAGE_QUOTA/IMAGE[ID='#{@img1_id}']/RVMS_USED"]).to eql "1"
    expect(uA_xml["IMAGE_QUOTA/IMAGE[ID='#{@img2_id}']/RVMS_USED"]).to eql "1"
    expect(uA_xml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql "1120"

    uB_xml = cli_action_xml("oneuser show -x uB")

    expect(uB_xml["VM_QUOTA/VM/VMS_USED"]).to eql(nil).or eql("0")
    expect(uB_xml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
    expect(uB_xml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")

    expect(uB_xml["IMAGE_QUOTA/IMAGE[ID='#{@img1_id}']/RVMS_USED"]).to eql(nil).or eql("0")
    expect(uB_xml["IMAGE_QUOTA/IMAGE[ID='#{@img2_id}']/RVMS_USED"]).to eql(nil).or eql("0")
    expect(uB_xml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql(nil).or eql("0")

    uC_xml = cli_action_xml("oneuser show -x uC")

    expect(uC_xml["VM_QUOTA/VM/VMS_USED"]).to eql(nil).or eql("0")
    expect(uC_xml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
    expect(uC_xml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")

    expect(uC_xml["IMAGE_QUOTA/IMAGE[ID='#{@img1_id}']/RVMS_USED"]).to eql(nil).or eql("0")
    expect(uC_xml["IMAGE_QUOTA/IMAGE[ID='#{@img2_id}']/RVMS_USED"]).to eql(nil).or eql("0")
    expect(uC_xml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql(nil).or eql("0")

    gA_xml = cli_action_xml("onegroup show -x gA")

    expect(gA_xml["VM_QUOTA/VM/VMS_USED"]).to eql "1"
    expect(gA_xml["VM_QUOTA/VM/CPU_USED"]).to eql "1"
    expect(gA_xml["VM_QUOTA/VM/MEMORY_USED"]).to eql "1024"

    expect(gA_xml["IMAGE_QUOTA/IMAGE[ID='#{@img1_id}']/RVMS_USED"]).to eql "1"
    expect(gA_xml["IMAGE_QUOTA/IMAGE[ID='#{@img2_id}']/RVMS_USED"]).to eql "1"
    expect(gA_xml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql "1120"
  end

  def check_quotas_volatile_attach()
    uA_xml = cli_action_xml("oneuser show -x uA")

    expect(uA_xml["VM_QUOTA/VM/VMS_USED"]).to eql "1"
    expect(uA_xml["VM_QUOTA/VM/CPU_USED"]).to eql "1"
    expect(uA_xml["VM_QUOTA/VM/MEMORY_USED"]).to eql "1024"

    expect(uA_xml["IMAGE_QUOTA/IMAGE[ID='#{@img1_id}']/RVMS_USED"]).to eql "1"
    expect(uA_xml["IMAGE_QUOTA/IMAGE[ID='#{@img2_id}']/RVMS_USED"]).to eql(nil).or eql("0")
    expect(uA_xml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql "140"

    uB_xml = cli_action_xml("oneuser show -x uB")

    expect(uB_xml["VM_QUOTA/VM/VMS_USED"]).to eql(nil).or eql("0")
    expect(uB_xml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
    expect(uB_xml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")

    expect(uB_xml["IMAGE_QUOTA/IMAGE[ID='#{@img1_id}']/RVMS_USED"]).to eql(nil).or eql("0")
    expect(uB_xml["IMAGE_QUOTA/IMAGE[ID='#{@img2_id}']/RVMS_USED"]).to eql(nil).or eql("0")
    expect(uB_xml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql(nil).or eql("0")

    uC_xml = cli_action_xml("oneuser show -x uC")

    expect(uC_xml["VM_QUOTA/VM/VMS_USED"]).to eql(nil).or eql("0")
    expect(uC_xml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
    expect(uC_xml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")

    expect(uC_xml["IMAGE_QUOTA/IMAGE[ID='#{@img1_id}']/RVMS_USED"]).to eql(nil).or eql("0")
    expect(uC_xml["IMAGE_QUOTA/IMAGE[ID='#{@img2_id}']/RVMS_USED"]).to eql(nil).or eql("0")
    expect(uC_xml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql(nil).or eql("0")

    gA_xml = cli_action_xml("onegroup show -x gA")

    expect(gA_xml["VM_QUOTA/VM/VMS_USED"]).to eql "1"
    expect(gA_xml["VM_QUOTA/VM/CPU_USED"]).to eql "1"
    expect(gA_xml["VM_QUOTA/VM/MEMORY_USED"]).to eql "1024"

    expect(gA_xml["IMAGE_QUOTA/IMAGE[ID='#{@img1_id}']/RVMS_USED"]).to eql "1"
    expect(gA_xml["IMAGE_QUOTA/IMAGE[ID='#{@img2_id}']/RVMS_USED"]).to eql(nil).or eql("0")
    expect(gA_xml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql "140"
  end

  def check_empy_quotas()
    uA_xml = cli_action_xml("oneuser show -x uA")

    expect(uA_xml["VM_QUOTA/VM/VMS_USED"]).to eql(nil).or eql("0")
    expect(uA_xml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
    expect(uA_xml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
    expect(uA_xml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil).or eql("0")
    expect(uA_xml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil).or eql("0")
    expect(uA_xml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil).or eql("0")

    expect(uA_xml["IMAGE_QUOTA/IMAGE[ID='#{@img1_id}']/RVMS_USED"]).to eql(nil).or eql("0")
    expect(uA_xml["IMAGE_QUOTA/IMAGE[ID='#{@img2_id}']/RVMS_USED"]).to eql(nil).or eql("0")
    expect(uA_xml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql(nil).or eql("0")

    uB_xml = cli_action_xml("oneuser show -x uB")

    expect(uB_xml["VM_QUOTA/VM/VMS_USED"]).to eql(nil).or eql("0")
    expect(uB_xml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
    expect(uB_xml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
    expect(uB_xml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil).or eql("0")
    expect(uB_xml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil).or eql("0")
    expect(uB_xml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil).or eql("0")

    expect(uB_xml["IMAGE_QUOTA/IMAGE[ID='#{@img1_id}']/RVMS_USED"]).to eql(nil).or eql("0")
    expect(uB_xml["IMAGE_QUOTA/IMAGE[ID='#{@img2_id}']/RVMS_USED"]).to eql(nil).or eql("0")
    expect(uB_xml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql(nil).or eql("0")

    uC_xml = cli_action_xml("oneuser show -x uC")

    expect(uC_xml["VM_QUOTA/VM/VMS_USED"]).to eql(nil).or eql("0")
    expect(uC_xml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
    expect(uC_xml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
    expect(uC_xml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil).or eql("0")
    expect(uC_xml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil).or eql("0")
    expect(uC_xml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil).or eql("0")

    expect(uC_xml["IMAGE_QUOTA/IMAGE[ID='#{@img1_id}']/RVMS_USED"]).to eql(nil).or eql("0")
    expect(uC_xml["IMAGE_QUOTA/IMAGE[ID='#{@img2_id}']/RVMS_USED"]).to eql(nil).or eql("0")
    expect(uC_xml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql(nil).or eql("0")

    gA_xml = cli_action_xml("onegroup show -x gA")

    expect(gA_xml["VM_QUOTA/VM/VMS_USED"]).to eql(nil).or eql("0")
    expect(gA_xml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
    expect(gA_xml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
    expect(gA_xml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(nil).or eql("0")
    expect(gA_xml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(nil).or eql("0")
    expect(gA_xml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(nil).or eql("0")

    expect(gA_xml["IMAGE_QUOTA/IMAGE[ID='#{@img1_id}']/RVMS_USED"]).to eql(nil).or eql("0")
    expect(gA_xml["IMAGE_QUOTA/IMAGE[ID='#{@img2_id}']/RVMS_USED"]).to eql(nil).or eql("0")
    expect(gA_xml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql(nil).or eql("0")
  end

  def replace_in_file(filename, patern, replacement)
    text = File.read(filename)
    content = text.gsub(patern, replacement)
    File.open(filename, "w") { |file| file << content }
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  it "should check initial and empty quotas" do
    check_initial_quotas()

    as_user("uA") do
      cli_action("onevm terminate --hard #{@id}")

      @vm.done?
    end

    check_empy_quotas()
  end

  ################################################################################
  # Failed attach operations
  ################################################################################

  it "should fail to attach a disk Image if it exceeds user limits " do
    quota_file = <<-EOT
    IMAGE = [
      ID = #{@img1_id},
      RVMS = 1
    ]
    EOT

    cli_update("oneuser quota uA", quota_file, false)

    as_user("uA") do
      cli_action("onevm disk-attach #{@id} --image #{@img1_id}", false)

      @vm.running?
    end

    check_initial_quotas()
  end

  it "should fail to attach a volatile disk if it exceeds user limits " do
    quota_file = <<-EOT
    VM = [
      VMS             = -1,
      MEMORY          = -1,
      CPU             = -1,
      SYSTEM_DISK_SIZE= 130
    ]
    EOT

    cli_update("oneuser quota uA", quota_file, false)

    as_user("uA") do
      cli_action("onevm disk-attach #{@id} --file #{TMP_FILENAME}", false)

      @vm.running?
    end

    check_initial_quotas()
  end

  it "should fail to attach a disk Image if it exceeds group limits " do
    quota_file = <<-EOT
    IMAGE = [
      ID = #{@img1_id},
      RVMS = 1
    ]
    EOT

    cli_update("onegroup quota gA", quota_file, false)

    as_user("uB") do
      cli_action("onevm disk-attach #{@id} --image #{@img1_id}", false)

      @vm.running?
    end

    check_initial_quotas()
  end

  it "should fail to attach a volatile disk if it exceeds group limits " do
    quota_file = <<-EOT
    VM = [
      VMS             = -1,
      MEMORY          = -1,
      CPU             = -1,
      SYSTEM_DISK_SIZE= 130
    ]
    EOT

    cli_update("onegroup quota gA", quota_file, false)

    as_user("uB") do
      cli_action("onevm disk-attach #{@id} --file #{TMP_FILENAME}", false)

      @vm.running?
    end

    check_initial_quotas()
  end

  it "should fail to attach a disk Image if the user is not authorized" do
    as_user("uC") do
      cli_action("onevm disk-attach #{@id} --image #{@img1_id}", false)
    end

    @vm.running?

    check_initial_quotas()
  end

  it "should fail to attach a volatile disk if the user is not authorized" do
    as_user("uC") do
      cli_action("onevm disk-attach #{@id} --file #{TMP_FILENAME}", false)
    end

    @vm.running?

    check_initial_quotas()
  end

  it "should fail to attach a disk Image if the template is invalid" do

    `echo "DISK = [ IMAGE_IMAGE_ID = #{@img1_id} ]" > #{TMP_FILENAME}`

    as_user("uA") do
      cli_action("onevm disk-attach #{@id} --file #{TMP_FILENAME}", false)

      @vm.running?
    end

    check_initial_quotas()
  end

  it "should fail to attach a volatile disk if the template is invalid" do

    `echo "DISK = [ TYPE = fs, SIZE = -20 ]" > #{TMP_FILENAME}`

    as_user("uA") do
      cli_action("onevm disk-attach #{@id} --file #{TMP_FILENAME}", false)

      @vm.running?
    end

    check_initial_quotas()
  end

  it "should fail to attach a disk Image if the driver fails" do
    `echo "failure" > #{DUMMY_ACTIONS_DIR}/attach_disk`

    as_user("uA") do
      cli_action("onevm disk-attach #{@id} --image #{@img1_id}")

      @vm.running?
    end

    check_initial_quotas()
  end

  it "should fail to attach a volatile disk if the driver fails" do
    `echo "failure" > #{DUMMY_ACTIONS_DIR}/attach_disk`

    as_user("uA") do
      cli_action("onevm disk-attach #{@id} --file #{TMP_FILENAME}")

      @vm.running?
    end

    check_initial_quotas()
  end

  it "should fail to attach a disk Image if the driver fails in VM poweroff" do
    @vm.poweroff

    # Fail disk-attach in poweroff
    replace_in_file("#{ONE_VAR_LOCATION}/remotes/tm/dummy/clone", /exit 0/, 'exit 1')

    as_user("uA") do
      cli_action("onevm disk-attach #{@id} --image #{@img1_id}")

      @vm.poweroff?
    end

    check_initial_quotas(false)
  end

  it "should run fsck" do
    run_fsck
  end

  ################################################################################
  # Successful attach operations + detach
  ################################################################################

  it "should attach + detach a disk image to a VM and update user & group quotas" do
    as_user("uA") do
      cli_action("onevm disk-attach #{@id} --image #{@img2_id}")

      @vm.running?
    end

    check_quotas_image_attach()

    as_user("uA") do
      cli_action("onevm disk-detach #{@id} 2")

      @vm.running?
    end

    check_initial_quotas()
  end

  it "should attach + detach a volatile disk to a VM and update user & group quotas" do
    as_user("uA") do
      cli_action("onevm disk-attach #{@id} --file #{TMP_FILENAME}")

      @vm.running?
    end

    check_quotas_volatile_attach()

    as_user("uA") do
      cli_action("onevm disk-detach #{@id} 2")

      @vm.running?
    end

    check_initial_quotas()
  end

  it "should attach + detach a disk image to a VM owned by other user, "<<
  "and update user & group quotas" do

    as_user("uB") do
      cli_action("onevm disk-attach #{@id} --image #{@img2_id}")

      @vm.running?
    end

    check_quotas_image_attach()

    as_user("uB") do
      cli_action("onevm disk-detach #{@id} 2")

      @vm.running?
    end

    check_initial_quotas()
  end

  it "should attach + detach a volatile disk to a VM owned by other user, "<<
  "and update user & group quotas" do

    as_user("uB") do
      cli_action("onevm disk-attach #{@id} --file #{TMP_FILENAME}")

      @vm.running?
    end

    check_quotas_volatile_attach()

    as_user("uB") do
      cli_action("onevm disk-detach #{@id} 2")

      @vm.running?
    end

    check_initial_quotas()
  end

  it "should attach + detach a disk image to a VM in poweroff state and update user & group quotas" do
    @vm.poweroff

    as_user("uA") do
      cli_action("onevm disk-attach #{@id} --image #{@img2_id}")

      @vm.poweroff?
    end

    check_quotas_image_attach()

    as_user("uA") do
      cli_action("onevm disk-detach #{@id} 2")

      @vm.poweroff?
    end

    check_initial_quotas(false)
  end

  it "should run fsck" do
    run_fsck
  end

  ################################################################################
  # Successful attach operations + failed detach (auth)
  ################################################################################

  it "should attach + fail detach (auth) a disk image to a VM and update user & group quotas" do
    as_user("uA") do
      cli_action("onevm disk-attach #{@id} --image #{@img2_id}")

      @vm.running?
    end

    as_user("uC") do
      cli_action("onevm disk-detach #{@id} 2", false)
    end

    @vm.running?

    check_quotas_image_attach()
  end

  it "should attach + fail detach (auth) a volatile disk to a VM and update user & group quotas" do
    as_user("uA") do
      cli_action("onevm disk-attach #{@id} --file #{TMP_FILENAME}")

      @vm.running?
    end

    as_user("uC") do
      cli_action("onevm disk-detach #{@id} 2", false)
    end

    @vm.running?

    check_quotas_volatile_attach()
  end

  it "should attach + fail detach (auth) a disk image to a VM owned by other user, "<<
  "and update user & group quotas" do

    as_user("uB") do
      cli_action("onevm disk-attach #{@id} --image #{@img2_id}")

      @vm.running?
    end

    as_user("uC") do
      cli_action("onevm disk-detach #{@id} 2", false)
    end

    @vm.running?

    check_quotas_image_attach()
  end

  it "should attach + fail detach (auth) a volatile disk to a VM owned by other user, "<<
  "and update user & group quotas" do

    as_user("uB") do
      cli_action("onevm disk-attach #{@id} --file #{TMP_FILENAME}")

      @vm.running?
    end

    as_user("uC") do
      cli_action("onevm disk-detach #{@id} 2", false)
    end

    @vm.running?

    check_quotas_volatile_attach()
  end

  it "should run fsck" do
    run_fsck
  end

  ################################################################################
  # Successful attach operations + failed detach (wrong disk id)
  ################################################################################

  it "should attach + fail detach (wrong disk id) a disk image to a VM and update user & group quotas" do
    as_user("uA") do
      cli_action("onevm disk-attach #{@id} --image #{@img2_id}")

      @vm.running?
    end

    as_user("uA") do
      cli_action("onevm disk-detach #{@id} 75", false)

      @vm.running?
    end

    check_quotas_image_attach()
  end

  it "should attach + fail detach (wrong disk id) a volatile disk to a VM and update user & group quotas" do
    as_user("uA") do
      cli_action("onevm disk-attach #{@id} --file #{TMP_FILENAME}")

      @vm.running?
    end

    as_user("uA") do
      cli_action("onevm disk-detach #{@id} 75", false)

      @vm.running?
    end

    check_quotas_volatile_attach()
  end

  it "should attach + fail detach (wrong disk id) a disk image to a VM owned by other user, "<<
  "and update user & group quotas" do

    as_user("uB") do
      cli_action("onevm disk-attach #{@id} --image #{@img2_id}")

      @vm.running?
    end

    as_user("uA") do
      cli_action("onevm disk-detach #{@id} 75", false)

      @vm.running?
    end

    check_quotas_image_attach()
  end

  it "should attach + fail detach (wrong disk id) a volatile disk to a VM owned by other user, "<<
  "and update user & group quotas" do

    as_user("uB") do
      cli_action("onevm disk-attach #{@id} --file #{TMP_FILENAME}")

      @vm.running?
    end

    as_user("uA") do
      cli_action("onevm disk-detach #{@id} 75", false)

      @vm.running?
    end

    check_quotas_volatile_attach()
  end

  it "should run fsck" do
    run_fsck
  end

  ################################################################################
  # Successful attach operations + failed detach (driver)
  ################################################################################

  it "should attach + fail detach (driver) a disk image to a VM and update user & group quotas" do
    as_user("uA") do
      cli_action("onevm disk-attach #{@id} --image #{@img2_id}")

      @vm.running?
    end

    `echo "failure" > #{DUMMY_ACTIONS_DIR}/detach_disk`

    as_user("uA") do
      cli_action("onevm disk-detach #{@id} 2")

      @vm.running?
    end

    check_quotas_image_attach()
  end

  it "should attach + fail detach (driver) a volatile disk to a VM and update user & group quotas" do
    as_user("uA") do
      cli_action("onevm disk-attach #{@id} --file #{TMP_FILENAME}")

      @vm.running?
    end

    `echo "failure" > #{DUMMY_ACTIONS_DIR}/detach_disk`

    as_user("uA") do
      cli_action("onevm disk-detach #{@id} 2")

      @vm.running?
    end

    check_quotas_volatile_attach()
  end

  it "should attach + fail detach (driver) a disk image to a VM owned by other user, "<<
  "and update user & group quotas" do

    as_user("uB") do
      cli_action("onevm disk-attach #{@id} --image #{@img2_id}")

      @vm.running?
    end

    `echo "failure" > #{DUMMY_ACTIONS_DIR}/detach_disk`

    as_user("uA") do
      cli_action("onevm disk-detach #{@id} 2")

      @vm.running?
    end

    check_quotas_image_attach()
  end

  it "should attach + fail detach (driver) a volatile disk to a VM owned by other user, "<<
  "and update user & group quotas" do

    as_user("uB") do
      cli_action("onevm disk-attach #{@id} --file #{TMP_FILENAME}")

      @vm.running?
    end

    `echo "failure" > #{DUMMY_ACTIONS_DIR}/detach_disk`

    as_user("uA") do
      cli_action("onevm disk-detach #{@id} 2")

      @vm.running?
    end

    check_quotas_volatile_attach()
  end

  it "should attach + fail detach (driver) VM in poweroff" do
    @vm.poweroff

    as_user("uA") do
      cli_action("onevm disk-attach #{@id} --image #{@img2_id}")

      @vm.poweroff?

      # Fail disk-dettach in poweroff
      replace_in_file("#{ONE_VAR_LOCATION}/remotes/tm/dummy/delete", /exit 0/, 'exit 1')

      cli_action("onevm disk-detach #{@id} 2")

      @vm.poweroff?
    end

    check_quotas_image_attach()
  end

  it "should run fsck" do
    run_fsck
  end

  ################################################################################
  # Successful attach operations + shutdown
  ################################################################################

  it "should attach + shutdown a disk image to a VM and update user & group quotas" do
    as_user("uA") do
      cli_action("onevm disk-attach #{@id} --image #{@img2_id}")

      @vm.running?
    end

    as_user("uA") do
      cli_action("onevm terminate --hard #{@id}")

      @vm.done?
    end

    check_empy_quotas()
  end

  it "should attach + shutdown a volatile disk to a VM and update user & group quotas" do
    as_user("uA") do
      cli_action("onevm disk-attach #{@id} --file #{TMP_FILENAME}")

      @vm.running?
    end

    as_user("uA") do
      cli_action("onevm terminate --hard #{@id}")

      @vm.done?
    end

    check_empy_quotas()
  end

  it "should attach + shutdown a disk image to a VM owned by other user, "<<
  "and update user & group quotas" do

    as_user("uB") do
      cli_action("onevm disk-attach #{@id} --image #{@img2_id}")

      @vm.running?
    end

    as_user("uA") do
      cli_action("onevm terminate --hard #{@id}")

      @vm.done?
    end

    check_empy_quotas()
  end

  it "should attach + shutdown a volatile disk to a VM owned by other user, "<<
  "and update user & group quotas" do

    as_user("uB") do
      cli_action("onevm disk-attach #{@id} --file #{TMP_FILENAME}")

      @vm.running?
    end

    as_user("uA") do
      cli_action("onevm terminate --hard #{@id}")

      @vm.done?
    end

    check_empy_quotas()
  end

  it "should run fsck" do
    run_fsck
  end

end