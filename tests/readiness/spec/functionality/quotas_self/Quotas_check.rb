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
  prepend_before(:all) do
    @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
  end

  before(:all) do
    cli_create_user("uA", "abc")
    cli_create_user("uB", "abc")

    gA_id = cli_create("onegroup create gA")
    cli_action("oneuser chgrp uA gA")
    cli_action("oneuser chgrp uB gA")

    cli_create("onehost create host0 --im dummy --vm dummy")


    cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy", false)
    cli_update("onedatastore update system", "TM_MAD=dummy\nDS_MAD=dummy", false)
    cli_create("onedatastore create", "NAME = ds_A\nTM_MAD=dummy\nDS_MAD=dummy")

    # Dummy driver image size is 1024
    @ip  = cli_create("oneimage create -d 1 --name ip --path /etc/passwd --persistent")
    @ip2  = cli_create("oneimage create -d 1 --name ip2 --path /etc/passwd --persistent")
    @inp = cli_create("oneimage create -d 1 --name inp --path /etc/passwd")
    @inp1= cli_create("oneimage create -d ds_A --name inp1 --path /etc/passwd")

    @id = []
    @vm = []

    cli_action("oneimage chown #{@ip} uB" )
    cli_action("oneimage chgrp #{@ip} gA" )
    cli_action("oneimage chmod #{@ip} 664")

    cli_action("oneimage chmod #{@ip2} 664")

    cli_action("oneimage chown #{@inp} uB" )
    cli_action("oneimage chgrp #{@inp} gA" )
    cli_action("oneimage chmod #{@inp} 664")

    cli_action("oneimage chown #{@inp1} uB" )
    cli_action("oneimage chgrp #{@inp1} gA" )
    cli_action("oneimage chmod #{@inp1} 664")
  end


  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------
  it "should verify initial quota status" do
    uA = cli_action_xml("oneuser show -x uA")
    uB = cli_action_xml("oneuser show -x uB")

    expect(uB['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql("2048")
    expect(uA['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql(nil)
  end

  # LN_TARGET    = NONE
  # CLONE_TARGET = SELF
  it "should allocate quota usage to the right user" do
    as_user("uA") do
      @id[0] = cli_create("onevm create --name test_vm --cpu 1 --memory 1 "\
                       "--disk #{@ip},#{@inp}")
    end

    @vm[0] = VM.new(@id[0])

    uA = cli_action_xml("oneuser show -x uA")
    uB = cli_action_xml("oneuser show -x uB")

    expect(uB['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql("2048")
    expect(uA['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql("1024")
  end

  it "should resize a disk and allocate usage to the right user" do
    cli_action("onevm deploy #{@id[0]} 0")

    @vm[0].running?

    as_user("uA") do
      cli_action("onevm disk-resize #{@id[0]} 0 2048")
      @vm[0].running?
      cli_action("onevm disk-resize #{@id[0]} 1 2048")
    end

    uA = cli_action_xml("oneuser show -x uA")
    uB = cli_action_xml("oneuser show -x uB")

    expect(uB['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql("3072")
    expect(uA['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql("2048")
  end

  it "should snapshot a disk and allocate usage to the right user" do
    @vm[0].running?

    as_user("uA") do
      cli_action("onevm disk-snapshot-create #{@id[0]} 0 s1")
      @vm[0].running?
      cli_action("onevm disk-snapshot-create #{@id[0]} 1 s2")
    end

    uA = cli_action_xml("oneuser show -x uA")
    uB = cli_action_xml("oneuser show -x uB")

    expect(uB['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql("5120")
    expect(uA['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql("4096")
  end

  it "should delete non persistent snapshots" do
    @vm[0].running?

    cli_action("onevm recover --recreate #{@id[0]}")

    uA = cli_action_xml("oneuser show -x uA")
    uB = cli_action_xml("oneuser show -x uB")

    expect(uB['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql("5120")
    expect(uA['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql("2048")
  end

  # todo Add fail to attach, detach - it should fail in pending state
  it "fail to attach disk should not modify the quota" do
    # VM in pending state
    cli_action("onevm disk-attach #{@id[0]} --image #{@ip2}", false)
    cli_action("onevm disk-attach #{@id[0]} --image #{@inp}", false)

    uA = cli_action_xml("oneuser show -x uA")
    uB = cli_action_xml("oneuser show -x uB")

    expect(uB['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql("5120")
    expect(uA['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql("2048")
  end

  it "should attach disk to VM" do
    cli_action("onevm deploy #{@id[0]} 0")

    @vm[0].running?

    # Disk attach persistent snapshot doesn't change quota
    @vm[0].disk_attach(@ip2)

    uA = cli_action_xml("oneuser show -x uA")
    uB = cli_action_xml("oneuser show -x uB")

    expect(uB['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql("5120")
    expect(uA['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql("2048")

    # Disk attach non-persistent snapshot updates quota
    @vm[0].disk_attach(@inp)

    uA = cli_action_xml("oneuser show -x uA")
    uB = cli_action_xml("oneuser show -x uB")

    expect(uB['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql("5120")
    expect(uA['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql("3072")
  end

  it "should detach disk from VM" do
    @vm[0].running?

    # Detach non-persistent disk should update quota
    disk_id = @vm[0].disks[-1]["DISK_ID"]

    @vm[0].disk_detach(disk_id)

    uA = cli_action_xml("oneuser show -x uA")
    uB = cli_action_xml("oneuser show -x uB")

    expect(uB['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql("5120")
    expect(uA['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql("2048")

    # Detach persistent disk should not update quota
    disk_id = @vm[0].disks[-1]["DISK_ID"]

    @vm[0].disk_detach(disk_id)

    uA = cli_action_xml("oneuser show -x uA")
    uB = cli_action_xml("oneuser show -x uB")

    expect(uB['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql("5120")
    expect(uA['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql("2048")
  end

  it "should chownership of VM and move quota usage" do
    cli_action("onevm chown #{@id[0]} uB")

    uA = cli_action_xml("oneuser show -x uA")
    uB = cli_action_xml("oneuser show -x uB")

    expect(uB['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql("7168")
    expect(uA['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql(nil)
  end

  it "should reset all usage counters" do
    @vm[0].terminate_hard

    @vm[0].done?

    uA = cli_action_xml("oneuser show -x uA")
    uB = cli_action_xml("oneuser show -x uB")

    expect(uB['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql("5120")
    expect(uA['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql(nil)
    expect(uA['VM_QUOTA/VM/CPU_USED']).to be_nil
    expect(uA['VM_QUOTA/VM/MEMORY_USED']).to be_nil
    expect(uA['VM_QUOTA/VM/VMS_USED']).to be_nil
  end

  # LN_TARGET    = NONE
  # CLONE_TARGET = SELF
  it "should allocate quota usage to the right user with template instantiate" do
    vm_id = -1

    as_user("uA") do
        @id[0] = cli_create("onetemplate create --name test_vm --cpu 1 "\
                            "--memory 1 --disk #{@ip},#{@inp}")

        vm_id  = cli_create("onetemplate instantiate #{@id[0]}")
    end

    @vm[0] = VM.new(vm_id)

    uA = cli_action_xml("oneuser show -x uA")
    uB = cli_action_xml("oneuser show -x uB")

    expect(uB['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql("5120")
    expect(uA['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql("1024")
    expect(uA['VM_QUOTA/VM/CPU_USED']).to eql("1")
    expect(uA['VM_QUOTA/VM/MEMORY_USED']).to eql("1")
    expect(uA['VM_QUOTA/VM/VMS_USED']).to eql("1")
  end

  it "should rollback quotas with template instantiate" do
    vm_id = -1

    quota_file = <<-EOT
    DATASTORE = [
      ID = 100,
      SIZE = 512,
      IMAGES  = -1
    ]
    EOT

    cli_update("oneuser quota uA", quota_file, false)

    as_user("uA") do
        @id[0] = cli_create("onetemplate create --name test_vm1 --cpu 1 "\
                            "--memory 1 --disk #{@ip},#{@inp},#{@inp1}")

        cli_action("onetemplate instantiate #{@id[0]}", false)
    end

    uA = cli_action_xml("oneuser show -x uA")
    uB = cli_action_xml("oneuser show -x uB")

    expect(uB['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql("5120")
    expect(uA['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql("1024")
    expect(uA['DATASTORE_QUOTA/DATASTORE[ID=100]/SIZE_USED']).to eql("0")

    expect(uA['VM_QUOTA/VM/CPU_USED']).to eql("1")
    expect(uA['VM_QUOTA/VM/MEMORY_USED']).to eql("1")
    expect(uA['VM_QUOTA/VM/VMS_USED']).to eql("1")

    as_user("uA") do
        cli_action("onevm create --name test_vm1 --cpu 1 "\
                            "--memory 1 --disk #{@ip},#{@inp},#{@inp1}", false)
    end

    uA = cli_action_xml("oneuser show -x uA")
    uB = cli_action_xml("oneuser show -x uB")

    expect(uB['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql("5120")
    expect(uA['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE_USED']).to eql("1024")
    expect(uA['DATASTORE_QUOTA/DATASTORE[ID=100]/SIZE_USED']).to eql("0")

    expect(uA['VM_QUOTA/VM/CPU_USED']).to eql("1")
    expect(uA['VM_QUOTA/VM/MEMORY_USED']).to eql("1")
    expect(uA['VM_QUOTA/VM/VMS_USED']).to eql("1")
  end

  it "should run fsck" do
    run_fsck
  end
end