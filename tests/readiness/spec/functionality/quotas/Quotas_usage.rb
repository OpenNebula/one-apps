#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

DEFAULT_LIMIT = "-1"

require 'init_functionality'
require 'image'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Check quotas usage records" do
  #---------------------------------------------------------------------------
  # OpenNebula bootstraping:
  #   - Define infrastructure: hosts, datastore, users, networks,...
  #   - Common instance variables: templates,...
  #---------------------------------------------------------------------------
  before(:all) do
    @dummy_rm = nil

    cli_create_user("uA", "abc")
    cli_create_user("uB", "abc")
    cli_create_user("uC", "abc")

    gA_id = cli_create("onegroup create gA")
    cli_create("onegroup create gB")

    cli_create("onevdc create test_vdc")
    cli_action("onevdc addgroup test_vdc gA")
    cli_action("onevdc addgroup test_vdc gB")
    cli_action("onevdc addcluster test_vdc 0 ALL")

    cli_action("oneuser chgrp uA gA")
    cli_action("oneuser chgrp uB gA")
    cli_action("oneuser chgrp uC gB")

    cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy", false)
    cli_update("onedatastore update system", "TM_MAD=dummy\nDS_MAD=dummy", false)

    wait_loop() do
      xml = cli_action_xml("onedatastore show -x default")
      xml['FREE_MB'].to_i > 0
    end

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

    as_user("uB") do
      @net_uB_id = cli_create("onevnet create", vnet_tmpl)
    end

    as_user("uC") do
      @net_uC_id = cli_create("onevnet create", vnet_tmpl)
    end

    @img_tmpl = <<-EOF
      NAME = test_img
      PATH = /tmp/none
      PERSISTENT = yes
    EOF

    @vm_tmpl = <<-EOF
      NAME = test_vm
      MEMORY = 1024
      CPU = 1
      NIC = [ NETWORK = test_vnet ]
      DISK = [ IMAGE = test_img ]
      DISK = [
        TYPE = fs,
        SIZE = 2048
      ]
    EOF
  end

  def delete_image(img_id_name)
    cli_action("oneimage delete #{img_id_name}")

    wait_loop do
        cmd = cli_action("oneimage show #{img_id_name}", nil, true)
        !cmd.success?
    end
  end

  def check_quota(cmd,
                  leases: '0',
                  mem: '0',
                  cpu: '0',
                  vms: '0',
                  disk_size: '0',
                  image_id: '-1',
                  image_used: '0',
                  running: true)
    xml = cli_action_xml(cmd)

    expect(xml["NETWORK_QUOTA/NETWORK[ID='#{@net_uA_id}']/LEASES"]).to eql(DEFAULT_LIMIT)
    expect(xml["NETWORK_QUOTA/NETWORK[ID='#{@net_uA_id}']/LEASES_USED"]).to eql(leases)
    expect(xml["VM_QUOTA/VM/MEMORY"]).to eql(DEFAULT_LIMIT)
    expect(xml["VM_QUOTA/VM/MEMORY_USED"]).to eql(mem)
    expect(xml["VM_QUOTA/VM/RUNNING_MEMORY_USED"]).to eql(running ? mem : '0')
    expect(xml["VM_QUOTA/VM/CPU"]).to eql(DEFAULT_LIMIT)
    expect(xml["VM_QUOTA/VM/CPU_USED"]).to eql(cpu)
    expect(xml["VM_QUOTA/VM/RUNNING_CPU_USED"]).to eql(running ? cpu : '0')
    expect(xml["VM_QUOTA/VM/VMS"]).to eql(DEFAULT_LIMIT)
    expect(xml["VM_QUOTA/VM/VMS_USED"]).to eql(vms)
    expect(xml["VM_QUOTA/VM/RUNNING_VMS_USED"]).to eql(running ? vms : '0')
    expect(xml["VM_QUOTA/VM/SYSTEM_DISK_SIZE"]).to eql(DEFAULT_LIMIT)
    expect(xml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql(disk_size)
    expect(xml["IMAGE_QUOTA/IMAGE[ID='#{image_id}']/RVMS"]).to eql(DEFAULT_LIMIT)
    expect(xml["IMAGE_QUOTA/IMAGE[ID='#{image_id}']/RVMS_USED"]).to eql(image_used)
  end

  def check_quota_empty(cmd, ds_empty: true)
    xml = cli_action_xml(cmd)

    expect(xml["DATASTORE_QUOTA"]).to eql('') if ds_empty
    expect(xml["NETWORK_QUOTA"]).to eql('')
    expect(xml["VM_QUOTA"]).to eql('')
    expect(xml["IMAGE_QUOTA"]).to eql('')
  end

  def check_ds_quota(cmd, ds_id: 1, used: '0', size: '0')
    xml = cli_action_xml(cmd)

    expect(xml["DATASTORE_QUOTA/DATASTORE[ID='#{ds_id}']/IMAGES"]).to eql(DEFAULT_LIMIT)
    expect(xml["DATASTORE_QUOTA/DATASTORE[ID='#{ds_id}']/IMAGES_USED"]).to eql(used)
    expect(xml["DATASTORE_QUOTA/DATASTORE[ID='#{ds_id}']/SIZE"]).to eql(DEFAULT_LIMIT)
    expect(xml["DATASTORE_QUOTA/DATASTORE[ID='#{ds_id}']/SIZE_USED"]).to eql(size)
  end

  def check_ds_empty(cmd)
    xml = cli_action_xml(cmd)

    expect(xml["DATASTORE_QUOTA"]).to eql('')
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  it "should create and delete a VM as oneadmin and no quota is updated for oneadmin" do
    tmpl = <<-EOT
    NAME = "test_vm"
    MEMORY = 1024
    CPU = 1
    NIC = [ NETWORK = test_vnet ]
    EOT

    cli_create("onevm create", tmpl)

    check_quota_empty('oneuser show -x')
    check_quota_empty('onegroup show -x')
  end

  it "should create and delete an Image as oneadmin and no quota is updated for oneadmin" do
    id2 = cli_create("oneimage create -d 1", @img_tmpl)

    check_quota_empty('oneuser show -x')
    check_quota_empty('onegroup show -x')

    delete_image(id2)

    check_quota_empty('oneuser show -x')
    check_quota_empty('onegroup show -x')
  end

  it "should create and delete VM as user A and quota should be updated" do
    as_user("uA") do
      id2 = cli_create("oneimage create -d 1", @img_tmpl)

      wait_loop() do
        xml = cli_action_xml("oneimage show -x test_img")
        Image::IMAGE_STATES[xml['STATE'].to_i] == "READY"
      end

      vm = VM.new(cli_create("onevm create", @vm_tmpl))

      check_quota('oneuser show -x', leases: '1', mem: '1024', cpu: '1', vms: '1',
                  disk_size: '2048', image_id: id2, image_used: '1')
      check_quota('onegroup show -x', leases: '1', mem: '1024', cpu: '1', vms: '1',
                  disk_size: '2048', image_id: id2, image_used: '1')

      vm.terminate_hard

      delete_image(id2)

      check_quota_empty('oneuser show -x')
      check_quota_empty('onegroup show -x')
    end
  end

  it "should create and shutdown a VM as user A and quota should be updated" do
    vm = nil
    id2 = nil

    as_user("uA") do
      id2 = cli_create("oneimage create -d 1", @img_tmpl)

      wait_loop() do
        xml = cli_action_xml("oneimage show -x test_img")
        Image::IMAGE_STATES[xml['STATE'].to_i] == "READY"
      end

      vm = VM.new(cli_create("onevm create", @vm_tmpl))

      check_quota('oneuser show -x', leases: '1', mem: '1024', cpu: '1', vms: '1',
                  disk_size: '2048', image_id: id2, image_used: '1')
      check_quota('onegroup show -x', leases: '1', mem: '1024', cpu: '1', vms: '1',
                  disk_size: '2048', image_id: id2, image_used: '1')
    end

    cli_action("onevm deploy #{vm.id} 0")

    as_user("uA") do
      vm.running?

      vm.terminate

      delete_image(id2)

      check_quota_empty('oneuser show -x')
      check_quota_empty('onegroup show -x')
    end
  end

  it "should create and delete an Image as user A and quota should be updated" do
    as_user("uA") do
      id1 = cli_create("oneimage create -d 1", @img_tmpl)

      img2 = CLIImage.create('test_img2', 1, '--path /tmp/none')

      check_ds_quota('oneuser show -x', ds_id: 1, used: '2', size: '2048')
      check_ds_quota('onegroup show -x', ds_id: 1, used: '2', size: '2048')

      # Delete first image
      delete_image(id1)

      check_ds_quota('oneuser show -x', ds_id: 1, used: '1', size: '1024')
      check_ds_quota('onegroup show -x', ds_id: 1, used: '1', size: '1024')

      # Fail to delete second image
      dummy_rm = "#{ONE_VAR_LOCATION}/remotes/datastore/dummy/rm"

      FileUtils.mv(dummy_rm, "#{dummy_rm}.orig")
      File.open(dummy_rm, File::CREAT|File::TRUNC|File::RDWR, 0744) { |f|
        f.write("#!/bin/bash\n")
        f.write("exit 1\n")
      }

      img2.delete

      img2.error?

      # Restore the driver action
      FileUtils.cp("#{dummy_rm}.orig", dummy_rm)

      # Check quotas were not changed
      check_ds_quota('oneuser show -x', ds_id: 1, used: '1', size: '1024')
      check_ds_quota('onegroup show -x', ds_id: 1, used: '1', size: '1024')

      # Delete second image
      img2.delete
      img2.deleted?

      check_quota_empty('oneuser show -x')
      check_quota_empty('onegroup show -x')
    end # as_user
  end

  it "should update group quotas when different users from the group create resources" do
    $vms = Array.new
    $imgs= Array.new

    ["uA", "uB", "uC"].each do |user|
      as_user(user) do
        $imgs << cli_create("oneimage create -d 1", @img_tmpl)

        wait_loop() do
          xml = cli_action_xml("oneimage show -x test_img")
          Image::IMAGE_STATES[xml['STATE'].to_i] == "READY"
        end

        $vms << cli_create("onevm create", @vm_tmpl)
      end
    end

    gxml = cli_action_xml("onegroup show -x gA")

    expect(gxml["DATASTORE_QUOTA/DATASTORE[ID='1']/IMAGES"]).to eql(DEFAULT_LIMIT)
    expect(gxml["DATASTORE_QUOTA/DATASTORE[ID='1']/IMAGES_USED"]).to eql("2")
    expect(gxml["DATASTORE_QUOTA/DATASTORE[ID='1']/SIZE"]).to eql(DEFAULT_LIMIT)
    expect(gxml["DATASTORE_QUOTA/DATASTORE[ID='1']/SIZE_USED"]).to eql("2048")

    expect(gxml["NETWORK_QUOTA/NETWORK[ID='#{@net_uA_id}']/LEASES"]).to eql(DEFAULT_LIMIT)
    expect(gxml["NETWORK_QUOTA/NETWORK[ID='#{@net_uA_id}']/LEASES_USED"]).to eql("1")
    expect(gxml["NETWORK_QUOTA/NETWORK[ID='#{@net_uB_id}']/LEASES"]).to eql(DEFAULT_LIMIT)
    expect(gxml["NETWORK_QUOTA/NETWORK[ID='#{@net_uB_id}']/LEASES_USED"]).to eql("1")

    expect(gxml["VM_QUOTA/VM/MEMORY"]).to eql(DEFAULT_LIMIT)
    expect(gxml["VM_QUOTA/VM/MEMORY_USED"]).to eql("2048")
    expect(gxml["VM_QUOTA/VM/CPU"]).to eql(DEFAULT_LIMIT)
    expect(gxml["VM_QUOTA/VM/CPU_USED"]).to eql("2")
    expect(gxml["VM_QUOTA/VM/SYSTEM_DISK_SIZE"]).to eql(DEFAULT_LIMIT)
    expect(gxml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql("4096")
    expect(gxml["VM_QUOTA/VM/VMS"]).to eql(DEFAULT_LIMIT)
    expect(gxml["VM_QUOTA/VM/VMS_USED"]).to eql("2")

    expect(gxml["IMAGE_QUOTA/IMAGE[ID='#{$imgs[0]}']/RVMS"]).to eql(DEFAULT_LIMIT)
    expect(gxml["IMAGE_QUOTA/IMAGE[ID='#{$imgs[0]}']/RVMS_USED"]).to eql("1")
    expect(gxml["IMAGE_QUOTA/IMAGE[ID='#{$imgs[1]}']/RVMS"]).to eql(DEFAULT_LIMIT)
    expect(gxml["IMAGE_QUOTA/IMAGE[ID='#{$imgs[1]}']/RVMS_USED"]).to eql("1")

    gxml = cli_action_xml("onegroup show -x gB")

    expect(gxml["DATASTORE_QUOTA/DATASTORE[ID='1']/IMAGES"]).to eql(DEFAULT_LIMIT)
    expect(gxml["DATASTORE_QUOTA/DATASTORE[ID='1']/IMAGES_USED"]).to eql("1")
    expect(gxml["DATASTORE_QUOTA/DATASTORE[ID='1']/SIZE"]).to eql(DEFAULT_LIMIT)
    expect(gxml["DATASTORE_QUOTA/DATASTORE[ID='1']/SIZE_USED"]).to eql("1024")

    expect(gxml["NETWORK_QUOTA/NETWORK[ID='#{@net_uC_id}']/LEASES"]).to eql(DEFAULT_LIMIT)
    expect(gxml["NETWORK_QUOTA/NETWORK[ID='#{@net_uC_id}']/LEASES_USED"]).to eql("1")

    expect(gxml["VM_QUOTA/VM/MEMORY"]).to eql(DEFAULT_LIMIT)
    expect(gxml["VM_QUOTA/VM/MEMORY_USED"]).to eql("1024")
    expect(gxml["VM_QUOTA/VM/CPU"]).to eql(DEFAULT_LIMIT)
    expect(gxml["VM_QUOTA/VM/CPU_USED"]).to eql("1")
    expect(gxml["VM_QUOTA/VM/SYSTEM_DISK_SIZE"]).to eql(DEFAULT_LIMIT)
    expect(gxml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql("2048")
    expect(gxml["VM_QUOTA/VM/VMS"]).to eql(DEFAULT_LIMIT)
    expect(gxml["VM_QUOTA/VM/VMS_USED"]).to eql("1")

    expect(gxml["IMAGE_QUOTA/IMAGE[ID='#{$imgs[2]}']/RVMS"]).to eql(DEFAULT_LIMIT)
    expect(gxml["IMAGE_QUOTA/IMAGE[ID='#{$imgs[2]}']/RVMS_USED"]).to eql("1")

    $vms.each { |i|
      cli_action("onevm recover --delete #{i}")
    }

    $imgs.each { |i|
      delete_image(i)
    }

    gxml = cli_action_xml("onegroup show -x gA")

    expect(gxml["DATASTORE_QUOTA/DATASTORE[ID='1']/IMAGES"]).to eql(nil)
    expect(gxml["DATASTORE_QUOTA/DATASTORE[ID='1']/IMAGES_USED"]).to eql(nil).or eql("0")
    expect(gxml["DATASTORE_QUOTA/DATASTORE[ID='1']/SIZE"]).to eql(nil)
    expect(gxml["DATASTORE_QUOTA/DATASTORE[ID='1']/SIZE_USED"]).to eql(nil).or eql("0")

    expect(gxml["NETWORK_QUOTA/NETWORK[ID='#{@net_uA_id}']/LEASES"]).to eql(nil)
    expect(gxml["NETWORK_QUOTA/NETWORK[ID='#{@net_uA_id}']/LEASES_USED"]).to eql(nil).or eql("0")
    expect(gxml["NETWORK_QUOTA/NETWORK[ID='#{@net_uB_id}']/LEASES"]).to eql(nil)
    expect(gxml["NETWORK_QUOTA/NETWORK[ID='#{@net_uB_id}']/LEASES_USED"]).to eql(nil).or eql("0")

    expect(gxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
    expect(gxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
    expect(gxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
    expect(gxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
    expect(gxml["VM_QUOTA/VM/SYSTEM_DISK_SIZE"]).to eql(nil).or eql(DEFAULT_LIMIT)
    expect(gxml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql(nil).or eql("0")
    expect(gxml["VM_QUOTA/VM/VMS"]).to eql(nil).or eql(DEFAULT_LIMIT)
    expect(gxml["VM_QUOTA/VM/VMS_USED"]).to eql(nil).or eql("0")

    expect(gxml["IMAGE_QUOTA/IMAGE[ID='#{$imgs[0]}']/RVMS"]).to eql(nil).or eql(DEFAULT_LIMIT)
    expect(gxml["IMAGE_QUOTA/IMAGE[ID='#{$imgs[0]}']/RVMS_USED"]).to eql(nil).or eql("0")
    expect(gxml["IMAGE_QUOTA/IMAGE[ID='#{$imgs[1]}']/RVMS"]).to eql(nil).or eql(DEFAULT_LIMIT)
    expect(gxml["IMAGE_QUOTA/IMAGE[ID='#{$imgs[1]}']/RVMS_USED"]).to eql(nil).or eql("0")

    gxml = cli_action_xml("onegroup show -x gB")

    expect(gxml["DATASTORE_QUOTA/DATASTORE[ID='1']/IMAGES"]).to eql(nil)
    expect(gxml["DATASTORE_QUOTA/DATASTORE[ID='1']/IMAGES_USED"]).to eql(nil).or eql("0")
    expect(gxml["DATASTORE_QUOTA/DATASTORE[ID='1']/SIZE"]).to eql(nil)
    expect(gxml["DATASTORE_QUOTA/DATASTORE[ID='1']/SIZE_USED"]).to eql(nil).or eql("0")

    expect(gxml["NETWORK_QUOTA/NETWORK[ID='#{@net_uC_id}']/LEASES"]).to eql(nil)
    expect(gxml["NETWORK_QUOTA/NETWORK[ID='#{@net_uC_id}']/LEASES_USED"]).to eql(nil).or eql("0")

    expect(gxml["VM_QUOTA/VM/MEMORY"]).to eql(nil).or eql(DEFAULT_LIMIT)
    expect(gxml["VM_QUOTA/VM/MEMORY_USED"]).to eql(nil).or eql("0")
    expect(gxml["VM_QUOTA/VM/CPU"]).to eql(nil).or eql(DEFAULT_LIMIT)
    expect(gxml["VM_QUOTA/VM/CPU_USED"]).to eql(nil).or eql("0")
    expect(gxml["VM_QUOTA/VM/SYSTEM_DISK_SIZE"]).to eql(nil).or eql(DEFAULT_LIMIT)
    expect(gxml["VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED"]).to eql(nil).or eql("0")
    expect(gxml["VM_QUOTA/VM/VMS"]).to eql(nil).or eql(DEFAULT_LIMIT)
    expect(gxml["VM_QUOTA/VM/VMS_USED"]).to eql(nil).or eql("0")

    expect(gxml["IMAGE_QUOTA/IMAGE[ID='#{$imgs[2]}']/RVMS"]).to eql(nil).or eql(DEFAULT_LIMIT)
    expect(gxml["IMAGE_QUOTA/IMAGE[ID='#{$imgs[2]}']/RVMS_USED"]).to eql(nil).or eql("0")
  end

  it "should chown a VM and Image and user and group quotas are updated " do
    vm = nil
    img_id = nil

    as_user("uA") do
      img_id = cli_create("oneimage create -d 1", @img_tmpl)

      wait_loop() do
        xml = cli_action_xml("oneimage show -x test_img")
        Image::IMAGE_STATES[xml['STATE'].to_i] == "READY"
      end

      vm = VM.new(cli_create("onevm create", @vm_tmpl))
    end

    check_quota('oneuser show -x uA', leases: '1', mem: '1024', cpu: '1', vms: '1',
                disk_size: '2048', image_id: img_id, image_used: '1')
    check_quota('onegroup show -x gA', leases: '1', mem: '1024', cpu: '1', vms: '1',
                disk_size: '2048', image_id: img_id, image_used: '1')

    check_ds_quota('oneuser show -x uA', ds_id: 1, used: '1', size: '1024')
    check_ds_quota('onegroup show -x gA', ds_id: 1, used: '1', size: '1024')

    # Chown to user in the same group: user quota changed, group quota remains
    cli_action("onevm chown #{vm.id} uB")

    check_quota_empty('oneuser show -x uA', ds_empty: false)
    check_quota('oneuser show -x uB', leases: '1', mem: '1024', cpu: '1', vms: '1',
                disk_size: '2048', image_id: img_id, image_used: '1')

    check_quota('onegroup show -x gA', leases: '1', mem: '1024', cpu: '1', vms: '1',
                disk_size: '2048', image_id: img_id, image_used: '1')

    check_ds_quota('oneuser show -x uA', ds_id: 1, used: '1', size: '1024')
    check_ds_quota('onegroup show -x gA', ds_id: 1, used: '1', size: '1024')

    # Chown to user in other group: User quota changed, group quota remains
    cli_action("onevm chown #{vm.id} uC")

    check_quota_empty('oneuser show -x uA', ds_empty: false)
    check_quota_empty('oneuser show -x uB')
    check_quota('oneuser show -x uC', leases: '1', mem: '1024', cpu: '1', vms: '1',
                disk_size: '2048', image_id: img_id, image_used: '1')

    check_quota('onegroup show -x gA', leases: '1', mem: '1024', cpu: '1', vms: '1',
                disk_size: '2048', image_id: img_id, image_used: '1')
    check_quota_empty('onegroup show -x gB')

    check_ds_quota('oneuser show -x uA', ds_id: 1, used: '1', size: '1024')
    check_ds_quota('onegroup show -x gA', ds_id: 1, used: '1', size: '1024')

    # Chgrp: User quota remains, group quota changed
    cli_action("onevm chgrp #{vm.id} gB")

    check_quota_empty('onegroup show -x gA', ds_empty: false)
    check_quota('onegroup show -x gB', leases: '1', mem: '1024', cpu: '1', vms: '1',
                disk_size: '2048', image_id: img_id, image_used: '1')

    check_ds_quota('onegroup show -x gA', ds_id: 1, used: '1', size: '1024')
    check_ds_empty('onegroup show -x gB')

    # VM in poweroff, chown
    cli_action("onevm deploy #{vm.id} 0")

    vm.running?

    vm.poweroff

    cli_action("onevm chown #{vm.id} uB")

    check_quota('oneuser show -x uB', leases: '1', mem: '1024', cpu: '1', vms: '1',
                disk_size: '2048', image_id: img_id, image_used: '1', running: false)
    check_quota_empty('oneuser show -x uC')

    # VM in undeploy, chown
    vm.safe_undeploy

    check_quota('oneuser show -x uB', leases: '1', mem: '1024', cpu: '1', vms: '1',
                disk_size: '2048', image_id: img_id, image_used: '1', running: false)
    check_quota_empty('oneuser show -x uC')

    cli_action("onevm chown #{vm.id} uC")

    check_quota_empty('oneuser show -x uB')
    check_quota('oneuser show -x uC', leases: '1', mem: '1024', cpu: '1', vms: '1',
                disk_size: '2048', image_id: img_id, image_used: '1', running: false)

    # VM in suspend, chown
    cli_action("onevm deploy #{vm.id} 0")

    vm.running?

    cli_action("onevm suspend #{vm.id}")

    vm.state?('SUSPENDED')

    cli_action("onevm chown #{vm.id} uB")

    check_quota('oneuser show -x uB', leases: '1', mem: '1024', cpu: '1', vms: '1',
                disk_size: '2048', image_id: img_id, image_used: '1', running: false)
    check_quota_empty('oneuser show -x uC')

    # VM in stop, chown
    cli_action("onevm stop #{vm.id}")

    vm.state?('STOPPED')

    check_quota('oneuser show -x uB', leases: '1', mem: '1024', cpu: '1', vms: '1',
                disk_size: '2048', image_id: img_id, image_used: '1', running: false)
    check_quota_empty('oneuser show -x uC')

    cli_action("onevm chown #{vm.id} uC")

    check_quota_empty('oneuser show -x uB')
    check_quota('oneuser show -x uC', leases: '1', mem: '1024', cpu: '1', vms: '1',
                disk_size: '2048', image_id: img_id, image_used: '1', running: false)

    vm.terminate_hard

    delete_image(img_id)
  end

  it "should chown an Image and user and group quotas are updated " do
    $vms.clear
    $imgs.clear

    as_user("uA") do
      $imgs << cli_create("oneimage create -d 1", @img_tmpl)
    end

    check_ds_quota('oneuser show -x uA', ds_id: 1, used: '1', size: '1024')
    check_ds_quota('onegroup show -x gA', ds_id: 1, used: '1', size: '1024')

    # Chown to user in the same group: user quota changed, group quota remains
    cli_action("oneimage chown test_img uB")

    check_ds_empty('oneuser show -x uA')
    check_ds_quota('oneuser show -x uB', ds_id: 1, used: '1', size: '1024')
    check_ds_quota('onegroup show -x gA', ds_id: 1, used: '1', size: '1024')

    # Chown to user in other group: User quota changed, group quota remains
    cli_action("oneimage chown #{$imgs[0]} uC")

    check_ds_empty('oneuser show -x uA')
    check_ds_empty('oneuser show -x uB')
    check_ds_quota('oneuser show -x uC', ds_id: 1, used: '1', size: '1024')
    check_ds_quota('onegroup show -x gA', ds_id: 1, used: '1', size: '1024')
    check_ds_empty('onegroup show -x gB')

    $imgs.each { |i|
      delete_image(i)
    }
  end

  it "should save_as a VM and user and group Image quotas are updated " do
    vm = nil
    id2 = nil

    as_user("uA") do
      id2 = cli_create("oneimage create -d 1", @img_tmpl)

      wait_loop() do
        xml = cli_action_xml("oneimage show -x test_img")
        Image::IMAGE_STATES[xml['STATE'].to_i] == "READY"
      end

      vm = VM.new(cli_create("onevm create", @vm_tmpl))

      check_quota('oneuser show -x', leases: '1', mem: '1024', cpu: '1', vms: '1',
                  disk_size: '2048', image_id: id2, image_used: '1')
      check_quota('onegroup show -x', leases: '1', mem: '1024', cpu: '1', vms: '1',
                  disk_size: '2048', image_id: id2, image_used: '1')

      check_ds_quota('oneuser show -x', ds_id: 1, used: '1', size: '1024')
      check_ds_quota('onegroup show -x', ds_id: 1, used: '1', size: '1024')
    end

    cli_action("onevm deploy #{vm.id} 0")

    as_user("uA") do
      vm.running?

      cli_action("onevm disk-saveas #{vm.id} 0 other_image")

      check_quota('oneuser show -x', leases: '1', mem: '1024', cpu: '1', vms: '1',
                  disk_size: '2048', image_id: id2, image_used: '1')
      check_quota('onegroup show -x', leases: '1', mem: '1024', cpu: '1', vms: '1',
                  disk_size: '2048', image_id: id2, image_used: '1')

      check_ds_quota('oneuser show -x', ds_id: 1, used: '2', size: '2048')
      check_ds_quota('onegroup show -x', ds_id: 1, used: '2', size: '2048')

      vm.running?

      vm.terminate

      check_quota_empty('oneuser show -x', ds_empty: false)
      check_quota_empty('onegroup show -x', ds_empty: false)

      check_ds_quota('oneuser show -x', ds_id: 1, used: '2', size: '2048')
      check_ds_quota('onegroup show -x', ds_id: 1, used: '2', size: '2048')
    end
  end

  it "should run fsck" do
    # Keep this as last test
    run_fsck
  end

end
