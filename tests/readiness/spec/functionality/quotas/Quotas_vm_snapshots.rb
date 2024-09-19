#-------------------------------------------------------------------------------
# Defines configuration and start OpenNebul[p]
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Check quotas with vm snapshots" do
  #---------------------------------------------------------------------------
  # OpenNebula bootstraping:
  #   - Define infrastructure: hosts, datastore, users, networks,...
  #   - Common instance variables: templates,...
  #---------------------------------------------------------------------------
  prepend_before(:all) do
    @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
  end

  before(:all) do
    @volatile_quota = 10000
    @image_quota    = 10000
    @disk_size      = 100
    @memory_size    = 1024

    cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy", false)
    cli_update("onedatastore update system", "TM_MAD=dummy\nDS_MAD=dummy", false)

    wait_loop() do
      xml = cli_action_xml("onedatastore show -x default")
      xml['FREE_MB'].to_i > 0
    end

    cli_create_user("uA", "abc")

    quota_file = <<-EOT
    VM = [
      VMS           = -1,
      MEMORY        = -1,
      CPU           = -1,
      SYSTEM_DISK_SIZE = #{@volatile_quota}
    ]
    EOT

    cli_update("oneuser quota uA", quota_file, false)

    cli_create("onehost create host0 --im dummy --vm dummy")

    as_user("uA") do
      @img_pers_id = cli_create("oneimage create -d 1 --name img_pers --type datablock --size #{@disk_size} --persistent")

      wait_loop() do
        xml = cli_action_xml("oneimage show -x #{@img_pers_id}")
        Image::IMAGE_STATES[xml['STATE'].to_i] == "READY"
      end

      cli_action("oneimage chtype #{@img_pers_id} OS")
      cli_action("oneimage chmod #{@img_pers_id} 660")

      @img_non_pers_id = cli_create("oneimage clone #{@img_pers_id} img_non_pers")
      wait_loop() do
        xml = cli_action_xml("oneimage show -x #{@img_non_pers_id}")
        Image::IMAGE_STATES[xml['STATE'].to_i] == "READY"
      end
      cli_action("oneimage nonpersistent #{@img_non_pers_id}")
    end

    wait_loop() do
      xml = cli_action_xml("oneimage show -x #{@img_pers_id}")
      Image::IMAGE_STATES[xml['STATE'].to_i] == "READY"
    end

    wait_loop() do
      xml = cli_action_xml("oneimage show -x #{@img_non_pers_id}")
      Image::IMAGE_STATES[xml['STATE'].to_i] == "READY"
    end

    @vm_tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = #{@memory_size}
      CPU = 0.25
      DISK = [ IMAGE = img_pers ]
      DISK = [ IMAGE = img_non_pers ]
      EOT

    as_user("uA") do
      @vm_id = cli_create("onevm create", @vm_tmpl)
    end

    @vm = VM.new(@vm_id)

    cli_action("onevm deploy #{@vm_id} host0")
    @vm.running?
  end

  after(:all) do
    FileUtils.rm_r(Dir['/tmp/opennebula_dummy_actions/*'])
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  it "verify starting quotas" do
    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*2).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq((@disk_size).to_s)
  end

  it "create snapshot" do
    as_user("uA") do
      cli_action("onevm snapshot-create #{@vm_id} sn0")
    end

    @vm.running?

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*2).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq(((@disk_size * 1.2).to_i + @memory_size).to_s)
  end

  it "delete snapshot" do
    as_user("uA") do
      cli_action("onevm snapshot-delete #{@vm_id} sn0")
    end

    @vm.running?

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*2).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq((@disk_size*1).to_s)
  end

  it "remove snapshot on recover recreate" do
    as_user("uA") do
      cli_action("onevm snapshot-create #{@vm_id} sn1")
    end

    @vm.running?

    cli_action("onevm recover --recreate #{@vm_id}")

    @vm.state?('PENDING')

    cli_action("onevm deploy #{@vm_id} host0")

    @vm.running?

    expect(@vm.xml['TEMPLATE/SNAPSHOT']).to eq(nil)

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*2).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq((@disk_size*1).to_s)
  end

  it "delete vm with snapshot" do
    as_user("uA") do
      cli_action("onevm snapshot-create #{@vm_id} sn2")

      @vm.running?

      cli_action("onevm terminate --hard #{@vm_id}")
    end

    @vm.done?

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*2).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq('0')
  end

  it "verify quota rollback" do
    as_user("uA") do
      # Fail to create snapshot as uA
      cli_action("onevm snapshot-create #{@vm_id} sn2", false)
    end

    # Fail to create snapshot as oneadmin
    cli_action("onevm snapshot-create #{@vm_id} sn2", false)

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*2).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq('0')
  end

  it "fail to create snapshot" do
    File.write("/tmp/opennebula_dummy_actions/snapshot_create", "failure");

    vm_id = nil

    as_user("uA") do
      vm_id = cli_create("onevm create", @vm_tmpl)
    end

    vm = VM.new(vm_id)

    cli_action("onevm deploy #{vm_id} host0")
    vm.running?

    as_user("uA") do
      cli_action("onevm snapshot-create #{vm_id} sn4")
    end

    vm.running?

    expect(vm.xml['TEMPLATE/SNAPSHOT']).to eq(nil)

    uA_xml = cli_action_xml("oneuser show -x uA")
    expect(uA_xml['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eq((@disk_size*2).to_s)
    expect(uA_xml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq((@disk_size*1).to_s)
  end

  it "should run fsck" do
    run_fsck
  end

end
