#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Check quotas with disk resize" do

  def image_state?(image_id, state)
      wait_loop do
        xml = cli_action_xml("oneimage show -x #{image_id}")
        Image::IMAGE_STATES[xml['STATE'].to_i] == state
      end
  end

  def is_image_ready?(image_id)
      image_state?(image_id, "READY")
  end

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
      @img_pers_id = cli_create("oneimage create -d 1 --name img_pers "\
          "--type datablock --size #{@disk_size} --persistent")
      wait_loop() {
        xml = cli_action_xml("oneimage show -x #{@img_pers_id}")
        xml['STATE'] == '1'
      }

      cli_action("oneimage chtype #{@img_pers_id} OS")
      cli_action("oneimage chmod #{@img_pers_id} 660")

      is_image_ready? @img_pers_id

      @img_non_pers_id = cli_create("oneimage clone #{@img_pers_id} img_non_pers")

      wait_loop() do
        xml = cli_action_xml("oneimage show -x #{@img_non_pers_id}")
        Image::IMAGE_STATES[xml['STATE'].to_i] == "READY"
      end

      cli_action("oneimage nonpersistent #{@img_non_pers_id}")

      is_image_ready? @img_non_pers_id
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
      @vm    = VM.new(@vm_id)
    end

    cli_action("onevm deploy #{@vm_id} host0")

    @vm.state? "RUNNING"

    cli_action("onevm poweroff --hard #{@vm_id}")

    @vm.state? "POWEROFF"
  end

  after(:all) do
    FileUtils.rm_r(Dir['/tmp/opennebula_dummy_actions/*'])

    run_fsck
  end

  def check_quotas(user, dsz, ssz)
    uA_xml = cli_action_xml("oneuser show -x #{user}")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql(dsz.to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eql(ssz.to_s)
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  it "verify starting quotas" do
      check_quotas("uA", 2*@disk_size, @disk_size)
  end

  it "resize pers images" do
    as_user("uA") do
      cli_action("onevm disk-resize #{@vm_id} 0 200")
    end

    check_quotas("uA", 3*@disk_size, @disk_size)

    @vm.state? "POWEROFF"

    cli_action("onevm resume #{@vm_id}")

    @vm.state? "RUNNING"

    as_user("uA") do
      cli_action("onevm disk-resize #{@vm_id} 0 300")
    end

    @vm.state? "RUNNING"

    check_quotas("uA", 4*@disk_size, @disk_size)

    as_user("uA") do
      cli_action("onevm disk-resize #{@vm_id} 0 400")
    end

    @vm.state? "RUNNING"

    check_quotas("uA", 5*@disk_size, @disk_size)

    cli_action("onevm poweroff --hard #{@vm_id}")
    @vm.state? "POWEROFF"

    as_user("uA") do
      cli_action("onevm disk-resize #{@vm_id} 0 500")
    end

    @vm.state? "POWEROFF"

    check_quotas("uA", 6*@disk_size, @disk_size)
  end

  it "resize non-pers images" do
    as_user("uA") do
      cli_action("onevm disk-resize #{@vm_id} 1 200")
    end

    @vm.state? "POWEROFF"

    check_quotas("uA", 6*@disk_size, 2*@disk_size)

    cli_action("onevm resume #{@vm_id}")

    @vm.state? "RUNNING"

    as_user("uA") do
      cli_action("onevm disk-resize #{@vm_id} 1 300")
    end

    @vm.state? "RUNNING"

    check_quotas("uA", 6*@disk_size, 3*@disk_size)

    as_user("uA") do
      cli_action("onevm disk-resize #{@vm_id} 1 400")
    end

    @vm.state? "RUNNING"

    check_quotas("uA", 6*@disk_size, 4*@disk_size)

    cli_action("onevm poweroff --hard #{@vm_id}")

    @vm.state? "POWEROFF"

    as_user("uA") do
      cli_action("onevm disk-resize #{@vm_id} 1 500")
    end

    @vm.state? "POWEROFF"

    check_quotas("uA", 6*@disk_size, 5*@disk_size)
  end

  it "change VM owner" do
    cli_action("onevm chown #{@vm_id} uB")

    check_quotas("uA", 6*@disk_size, 0)

    check_quotas("uB", 0, 5*@disk_size)

    cli_action("onevm chown #{@vm_id} uA")

    check_quotas("uA", 6*@disk_size, 5*@disk_size)

    check_quotas("uB", 0, 0)
  end

  it "change Image owner" do
    cli_action("oneimage chown #{@img_pers_id} uB")

    check_quotas("uA", 1*@disk_size, 5*@disk_size)

    check_quotas("uB", 5*@disk_size, 0)

    cli_action("oneimage chown #{@img_pers_id} uA")

    check_quotas("uA", 6*@disk_size, 5*@disk_size)

    check_quotas("uB", 0, 0)
  end

  it "failure in driver should rollback quotas" do
    #  Set the resize action to fail
    File.write('/tmp/opennebula_dummy_actions/resize_disk', 'failure');

    cli_action("onevm resume #{@vm_id}")

    @vm.running?

    cli_action("onevm disk-resize #{@vm_id} 0 600")

    @vm.running?

    cli_action("onevm disk-resize #{@vm_id} 1 600")

    @vm.running?

    # Check disk, image size and quotas doesn't change
    check_quotas("uA", 6*@disk_size, 5*@disk_size)
  end
end