#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
require 'VM'
require 'image'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Check quotas with disk snapshots" do
  #---------------------------------------------------------------------------
  # OpenNebula bootstraping:
  #   - Define infrastructure: hosts, datastore, users, networks,...
  #   - Common instance variables: templates,...
  #---------------------------------------------------------------------------
  before(:all) do
    @volatile_quota = 10000
    @image_quota    = 10000
    @disk_size      = 100

    cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy", false)
    cli_update("onedatastore update system", "TM_MAD=dummy\nDS_MAD=dummy", false)

    wait_loop() do
      xml = cli_action_xml("onedatastore show -x default")
      xml['FREE_MB'].to_i > 0
    end

    cli_create_user("uA", "abc")
    cli_create_user("uB", "abc")

    quota_file = <<-EOT
    DATASTORE = [
      ID     = 1,
      IMAGES = -1,
      SIZE   = #{@image_quota}
    ]
    VM = [
      VMS           = -1,
      MEMORY        = -1,
      CPU           = -1,
      SYSTEM_DISK_SIZE = #{@volatile_quota}
    ]
    EOT

    cli_update("oneuser quota uA", quota_file, false)
    cli_update("oneuser quota uB", quota_file, false)

    cli_create("onehost create host0 --im dummy --vm dummy")

    as_user("uA") do
      @img_pers_id = cli_create("oneimage create -d 1 --name img_pers --type datablock --size #{@disk_size} --persistent")
      @img_pers = CLIImage.new(@img_pers_id)

      @img_pers.ready?

      cli_action("oneimage chtype #{@img_pers_id} OS")
      cli_action("oneimage chmod #{@img_pers_id} 660")

      @img_non_pers_id = cli_create("oneimage clone #{@img_pers_id} img_non_pers")
      @img_non_pers = CLIImage.new(@img_non_pers_id)

      @img_non_pers.ready?

      cli_action("oneimage nonpersistent #{@img_non_pers_id}")
    end

    as_user("uA") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1024
      CPU = 0.25
      DISK = [ IMAGE = img_pers ]
      DISK = [ IMAGE = img_non_pers ]
      EOT

      @vm_id = cli_create("onevm create", tmpl)
    end

    cli_action("onevm deploy #{@vm_id} host0")

    @vm = VM.new(@vm_id)

    @vm.running?

    @vm.poweroff_hard
  end

  after(:all) do
    run_fsck
  end

  after(:each) do
    FileUtils.rm_r(Dir['/tmp/opennebula_dummy_actions/*'])
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  it "verify starting quotas" do
    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*2).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq((@disk_size*1).to_s)
  end

  it "snapshot pers images" do
    as_user("uA") do
      cli_action("onevm disk-snapshot-create #{@vm_id} 0 sn0_0")

      @vm.poweroff?

      cli_action("onevm disk-snapshot-create #{@vm_id} 0 sn0_1")

      @vm.poweroff?

      cli_action("onevm disk-snapshot-create #{@vm_id} 0 sn0_2")

      @vm.poweroff?

      cli_action("onevm disk-snapshot-create #{@vm_id} 0 sn0_3")

      @vm.poweroff?
    end

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*6).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq((@disk_size*1).to_s)
  end

  it "snapshot non-pers images" do
    as_user("uA") do
      cli_action("onevm disk-snapshot-create #{@vm_id} 1 sn1_0")

      @vm.poweroff?

      cli_action("onevm disk-snapshot-create #{@vm_id} 1 sn1_1")

      @vm.poweroff?

      cli_action("onevm disk-snapshot-create #{@vm_id} 1 sn1_2")

      @vm.poweroff?

      cli_action("onevm disk-snapshot-create #{@vm_id} 1 sn1_3")

      @vm.poweroff?
    end

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*6).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq((@disk_size*5).to_s)
  end

  it "change VM owner" do
    cli_action("onevm chown #{@vm_id} uB")

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*6).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq('0')

    uB_xml = cli_action_xml("oneuser show -x uB")
    expect(uB_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq('0')
    expect(uB_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq((@disk_size*5).to_s)

    cli_action("onevm chown #{@vm_id} uA")

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*6).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq((@disk_size*5).to_s)

    uB_xml = cli_action_xml("oneuser show -x uB")
    expect(uB_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq('0')
    expect(uB_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq('0')
  end

  it "change Image owner" do
    cli_action("oneimage chown #{@img_pers_id} uB")

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*1).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq((@disk_size*5).to_s)

    uB_xml = cli_action_xml("oneuser show -x uB")
    expect(uB_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*5).to_s)
    expect(uB_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq('0')

    cli_action("oneimage chown #{@img_pers_id} uA")

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*6).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq((@disk_size*5).to_s)

    uB_xml = cli_action_xml("oneuser show -x uB")
    expect(uB_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq('0')
    expect(uB_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq('0')
  end

  it "change VM owner and perform disk snapshots on persistent image" do
    cli_action("onevm chown #{@vm_id} uB")

    as_user("uB") do
      cli_action("onevm disk-snapshot-create #{@vm_id} 0 sn0_4")
    end

    @vm.poweroff?

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*7).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq('0')

    uB_xml = cli_action_xml("oneuser show -x uB")
    expect(uB_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq('0')
    expect(uB_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq((@disk_size*5).to_s)

    cli_action("onevm chown #{@vm_id} uA")

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*7).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq((@disk_size*5).to_s)

    uB_xml = cli_action_xml("oneuser show -x uB")
    expect(uB_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq('0')
    expect(uB_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq('0')
  end

  it "change VM owner and perform disk snapshots on non-persistent image" do
    cli_action("onevm chown #{@vm_id} uB")

    as_user("uB") do
      cli_action("onevm disk-snapshot-create #{@vm_id} 1 sn1_4")
    end

    @vm.poweroff?

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*7).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq('0')

    uB_xml = cli_action_xml("oneuser show -x uB")
    expect(uB_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq('0')
    expect(uB_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq((@disk_size*6).to_s)

    cli_action("onevm chown #{@vm_id} uA")

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*7).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq((@disk_size*6).to_s)

    uB_xml = cli_action_xml("oneuser show -x uB")
    expect(uB_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq('0')
    expect(uB_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq('0')
  end

  it "revert snapshots" do
    as_user("uA") do
      cli_action("onevm disk-snapshot-revert #{@vm_id} 0 1")

      @vm.poweroff?

      cli_action("onevm disk-snapshot-revert #{@vm_id} 1 1")

      @vm.poweroff?
    end

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*7).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq((@disk_size*6).to_s)
  end

  it "delete snapshots" do
    as_user("uA") do
      cli_action("onevm disk-snapshot-delete #{@vm_id} 0 4")

      @vm.poweroff?

      cli_action("onevm disk-snapshot-delete #{@vm_id} 1 4")

      @vm.poweroff?
    end

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*6).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq((@disk_size*5).to_s)
  end

  it "change VM owner and perform delete snapshots" do
    cli_action("onevm chown #{@vm_id} uB")

    as_user("uB") do
      cli_action("onevm disk-snapshot-delete #{@vm_id} 0 3")

      @vm.poweroff?

      cli_action("onevm disk-snapshot-delete #{@vm_id} 1 3")

      @vm.poweroff?
    end

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*5).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq('0')

    uB_xml = cli_action_xml("oneuser show -x uB")
    expect(uB_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq('0')
    expect(uB_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq((@disk_size*4).to_s)

    cli_action("onevm chown #{@vm_id} uA")

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*5).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq((@disk_size*4).to_s)

    uB_xml = cli_action_xml("oneuser show -x uB")
    expect(uB_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq('0')
    expect(uB_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq('0')
  end

  it "resize disk, revert to snapshot with old size should update quotas" do
    # Resize the disk
    cli_action("onevm disk-resize #{@vm_id} 0 #{@disk_size*2}")

    @vm.poweroff?

    cli_action("onevm disk-resize #{@vm_id} 1 #{@disk_size*3}")

    @vm.poweroff?

    ixml = cli_action_xml("oneimage show -x #{@img_pers_id}")
    expect(ixml['SIZE']).to eq((@disk_size*2).to_s)

    # Take snapshot of the bigger image
    cli_action("onevm disk-snapshot-create #{@vm_id} 0 sn0_big")

    @vm.poweroff?

    cli_action("onevm disk-snapshot-create #{@vm_id} 1 sn1_big")

    @vm.poweroff?

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*8).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq((@disk_size*9).to_s)

    # Revert to snapshot with old disk size
    cli_action("onevm disk-snapshot-revert #{@vm_id} 0 0")

    @vm.poweroff?

    cli_action("onevm disk-snapshot-revert #{@vm_id} 1 0")

    @vm.poweroff?

    vm_xml = cli_action_xml("onevm show #{@vm_id} -x")

    expect(vm_xml['TEMPLATE/DISK[DISK_ID="0"]/SIZE']).to eq(@disk_size.to_s)
    expect(vm_xml['TEMPLATE/DISK[DISK_ID="1"]/SIZE']).to eq(@disk_size.to_s)

    ixml = cli_action_xml("oneimage show -x #{@img_pers_id}")
    expect(ixml['SIZE']).to eq(@disk_size.to_s)

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*7).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq((@disk_size*7).to_s)

    # Revert to big snapshot - to make sure the quotas works in oposite way
    cli_action("onevm disk-snapshot-revert #{@vm_id} 0 sn0_big")

    @vm.poweroff?

    cli_action("onevm disk-snapshot-revert #{@vm_id} 1 sn1_big")

    @vm.poweroff?

    vm_xml = cli_action_xml("onevm show #{@vm_id} -x")

    expect(vm_xml['TEMPLATE/DISK[DISK_ID="0"]/SIZE']).to eq((@disk_size*2).to_s)
    expect(vm_xml['TEMPLATE/DISK[DISK_ID="1"]/SIZE']).to eq((@disk_size*3).to_s)

    ixml = cli_action_xml("oneimage show -x #{@img_pers_id}")
    expect(ixml['SIZE']).to eq((@disk_size*2).to_s)

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*8).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq((@disk_size*9).to_s)

    # Clean up, revert back, remove big snapshot
    cli_action("onevm disk-snapshot-revert #{@vm_id} 0 0")

    @vm.poweroff?

    cli_action("onevm disk-snapshot-revert #{@vm_id} 1 0")

    @vm.poweroff?

    cli_action("onevm disk-snapshot-delete #{@vm_id} 0 sn0_big")

    @vm.poweroff?

    cli_action("onevm disk-snapshot-delete #{@vm_id} 1 sn1_big")

    @vm.poweroff?

    ixml = cli_action_xml("oneimage show -x #{@img_pers_id}")
    expect(ixml['SIZE']).to eq(@disk_size.to_s)

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*5).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq((@disk_size*4).to_s)
  end

  it "driver failure should revert quotas" do
    File.write('/tmp/opennebula_dummy_actions/disk_snapshot_create', 'failure');

    @vm.resume

    cli_action("onevm disk-snapshot-create #{@vm_id} 0 sn0_fail")

    @vm.running?

    cli_action("onevm disk-snapshot-create #{@vm_id} 1 sn1_fail")

    @vm.running?

    xml = @vm.xml

    expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn0_fail']"]).to be_nil
    expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn0_fail']"]).to be_nil

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*5).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq((@disk_size*4).to_s)
  end

  it "should run fsck" do
    run_fsck
  end

  it "delete vm" do
    # Resize the persistent disk, we need it for next test
    cli_action("onevm disk-resize #{@vm_id} 0 #{@disk_size*2}")

    @vm.running?

    as_user("uA") do
      cli_action("onevm terminate --hard #{@vm_id}")
    end

    @img_pers.ready?

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*6).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq('0')
  end

  it "persistent image restore snapshot should resize disk and update quota" do
    # Check the size of the image
    ixml = cli_action_xml("oneimage show -x #{@img_pers_id}")

    expect(ixml['SIZE']).to eq((@disk_size*2).to_s)

    # Revert to snapshot with smaller size
    cli_action("oneimage snapshot-revert #{@img_pers_id} 0")

    @img_pers.ready?

    ixml = cli_action_xml("oneimage show -x #{@img_pers_id}")

    expect(ixml['SIZE']).to eq((@disk_size).to_s)

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*5).to_s)
  end

  it "flatten image" do
    as_user("uA") do
      cli_action("oneimage snapshot-flatten #{@img_pers_id} 1")
    end

    @img_pers.ready?

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*2).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq('0')
  end

  it "should delete non-persistent & volatile snapshots and update quotas" do
    as_user("uA") do
      tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1024
      CPU = 1
      DISK = [ IMAGE = img_pers ]
      DISK = [ IMAGE = img_non_pers ]
      EOT

      @vm_id = cli_create("onevm create", tmpl)
      @vm = VM.new(@vm_id)
    end

    cli_action("onevm deploy #{@vm_id} host0")
    @vm.running?

    @vm.poweroff_hard

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*2).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq((@disk_size).to_s)

    as_user("uA") do
      cli_action("onevm disk-snapshot-create #{@vm_id} 0 sn0_0")

      @vm.poweroff?

      cli_action("onevm disk-snapshot-create #{@vm_id} 1 sn0_0")

      @vm.poweroff?
    end

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*3).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq((@disk_size*2).to_s)

    as_user("uA") do
      @vm.resume
    end

    cli_action("onevm recover --recreate #{@vm_id}")

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*3).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq((@disk_size).to_s)
  end
end
