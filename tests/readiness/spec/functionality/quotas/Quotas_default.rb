#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Check default quotas limits" do
  #---------------------------------------------------------------------------
  # OpenNebula bootstraping:
  #   - Define infrastructure: hosts, datastore, users, networks,...
  #   - Common instance variables: templates,...
  #---------------------------------------------------------------------------
  before(:all) do
    cli_create_user("uA", "abc")
    cli_create_user("uB", "abc")

    gA_id = cli_create("onegroup create gA")
    cli_action("oneuser chgrp uA gA")
    cli_action("oneuser chgrp uB gA")

    cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy", false)
    cli_update("onedatastore update system", "TM_MAD=dummy\nDS_MAD=dummy", false)

    wait_loop() do
      xml = cli_action_xml("onedatastore show -x default")
      xml['FREE_MB'].to_i > 0
    end

    @info = {}

    if @main_defaults && @main_defaults[:db]
      @sqlite = @main_defaults[:db]['BACKEND'] == 'sqlite'
    end

    if @main_defaults && @main_defaults[:build_components]
        @info[:ee] = @main_defaults[:build_components].include?('enterprise')
    else
        @info[:ee] = false
    end
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  it "should try to set -1 limits in default quotas and fail" do
    quota_file = <<-EOT
    VM = [
      VMS = -2,
      MEMORY = -1,
      CPU = 3,
      SYSTEM_DISK_SIZE = -2
    ]
    EOT

    out = cli_update("oneuser defaultquota", quota_file, false, false).stdout
    expect(out).to match(/Negative limits/)
  end


  it "should set limits to 0 in the default quotas, and delete the quota" do
    quota_file = <<-EOT
    VM = [
      VMS     = -2,
      MEMORY  = 5,
      CPU     = 3,
      SYSTEM_DISK_SIZE = -2
    ]
    EOT

    cli_update("oneuser defaultquota", quota_file, false)

    client = Client.new()
    system = System.new(client)

    uquotas = system.get_user_quotas()
    expect(uquotas['VM_QUOTA/VM/MEMORY']).to eql("5")


    quota_file = <<-EOT
    VM = [
      VMS     = -2,
      MEMORY  = -2,
      CPU     = -2,
      SYSTEM_DISK_SIZE = -2
    ]
    EOT

    cli_update("oneuser defaultquota", quota_file, false)

    uquotas = system.get_user_quotas()

    expect(uquotas['VM_QUOTA/VM']).to eql(nil)
    expect(uquotas['VM_QUOTA/VM/MEMORY']).to eql(nil)
  end


  it "should set default quotas, restart oned, and have the same quotas loaded" do
    quota_file = <<-EOT
    VM = [
      VMS     = 1,
      MEMORY  = -2,
      CPU     = -2,
      SYSTEM_DISK_SIZE = 20
    ]
    DATASTORE = [
      ID      = 1,
      SIZE    = 123,
      IMAGES  = 10
    ]
    EOT

    cli_update("oneuser defaultquota", quota_file, false)

    client = Client.new()
    system = System.new(client)

    uquotas = system.get_user_quotas()

    expect(uquotas['VM_QUOTA/VM/VMS']).to eql("1")
    expect(uquotas['VM_QUOTA/VM/MEMORY']).to eql("-2")
    expect(uquotas['VM_QUOTA/VM/CPU']).to eql("-2")
    expect(uquotas['VM_QUOTA/VM/SYSTEM_DISK_SIZE']).to eql("20")

    expect(uquotas['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE']).to eql("123")
    expect(uquotas['DATASTORE_QUOTA/DATASTORE[ID=1]/IMAGES']).to eql("10")

    @one_test.stop_one
    @one_test.start_one

    uquotas = system.get_user_quotas()

    expect(uquotas['VM_QUOTA/VM/VMS']).to eql("1")
    expect(uquotas['VM_QUOTA/VM/MEMORY']).to eql("-2")
    expect(uquotas['VM_QUOTA/VM/CPU']).to eql("-2")
    expect(uquotas['VM_QUOTA/VM/SYSTEM_DISK_SIZE']).to eql("20")

    expect(uquotas['DATASTORE_QUOTA/DATASTORE[ID=1]/SIZE']).to eql("123")
    expect(uquotas['DATASTORE_QUOTA/DATASTORE[ID=1]/IMAGES']).to eql("10")

  end


  it "should not allow a user to create an image if default SIZE is exceeded" do
    quota_file = <<-EOT
    DATASTORE = [
      ID = 1,
      SIZE = 1500,
      IMAGES = 10
    ]
    EOT

    cli_update("oneuser defaultquota", quota_file, false)

    as_user("uA") do
      tmpl = <<-EOF
      NAME = test_img
      PATH = /tmp/none
      EOF

      id1 = cli_create("oneimage create -d 1", tmpl)
      wait_loop() do
        xml = cli_action_xml("oneimage show -x #{id1}")
        Image::IMAGE_STATES[xml['STATE'].to_i] == "READY"
      end

      tmpl = <<-EOF
      NAME = test_img2
      PATH = /tmp/none
      EOF

      out = cli_create("oneimage create -d 1", tmpl, false).stderr

      expect(out).to match(/limit of .* reached/)

      cli_action("oneimage delete #{id1}")
    end
  end

  it "should allow a user to create an image if default SIZE is exceeded, but individual SIZE is not" do
    quota_file = <<-EOT
    DATASTORE = [
      ID = 1,
      SIZE = 1500,
      IMAGES = 10
    ]
    EOT

    cli_update("oneuser defaultquota", quota_file, false)

    quota_file = <<-EOT
    DATASTORE = [
      ID = 1,
      SIZE = -2,
      IMAGES = -2
    ]
    EOT

    cli_update("oneuser quota uA", quota_file, false)

    as_user("uA") do
      tmpl = <<-EOF
      NAME = test_img3
      PATH = /tmp/none
      EOF

      id1 = cli_create("oneimage create -d 1", tmpl)

      wait_loop() do
        xml = cli_action_xml("oneimage show -x #{id1}")
        Image::IMAGE_STATES[xml['STATE'].to_i] == "READY"
      end

      tmpl = <<-EOF
      NAME = test_img4
      PATH = /tmp/none
      EOF

      id2 = cli_create("oneimage create -d 1", tmpl)
      wait_loop() do
        xml = cli_action_xml("oneimage show -x #{id2}")
        Image::IMAGE_STATES[xml['STATE'].to_i] == "READY"
      end

      cli_action("oneimage delete #{id1}")
      cli_action("oneimage delete #{id2}")
    end
  end

  it "should not allow a user to create an image if default limit is not exceeded, but individual limit is" do
    quota_file = <<-EOT
    DATASTORE = [
      ID = 1,
      SIZE = -2,
      IMAGES = -2
    ]
    EOT

    cli_update("oneuser defaultquota", quota_file, false)

    quota_file = <<-EOT
    DATASTORE = [
      ID = 1,
      SIZE = -2,
      IMAGES = 1
    ]
    EOT

    cli_update("oneuser quota uA", quota_file, false)

    as_user("uA") do
      tmpl = <<-EOF
      NAME = test_img
      PATH = /tmp/none
      EOF

      id1 = cli_create("oneimage create -d 1", tmpl)
      wait_loop() do
        xml = cli_action_xml("oneimage show -x #{id1}")
        Image::IMAGE_STATES[xml['STATE'].to_i] == "READY"
      end

      tmpl = <<-EOF
      NAME = test_img2
      PATH = /tmp/none
      EOF

      out = cli_create("oneimage create -d 1", tmpl, false).stderr

      expect(out).to match(/limit of .* reached/)

      cli_action("oneimage delete #{id1}")
    end
  end

  it "should run fsck" do
    run_fsck(0)
  end

  it "should copy the broken DB" do
    skip 'only for sqlite' unless @sqlite
    skip 'only for EE' unless @info[:ee]

    @one_test.stop_one

    system("cp #{Dir.getwd}/spec/functionality/fsck/databases/one.db.quotas #{ONE_DB_LOCATION}/one.db")
  end

  it "should upgrade the DB" do
    skip 'only for sqlite' unless @sqlite
    skip 'only for EE' unless @info[:ee]

    expect(@one_test.upgrade_db).to be(true)
  end

  it "should run fsck and fix errors" do
    skip 'only for sqlite' unless @sqlite
    skip 'only for EE' unless @info[:ee]

    run_fsck(6)
  end

  it "should run fsck" do
    skip 'only for sqlite' unless @sqlite
    skip 'only for EE' unless @info[:ee]

    run_fsck(0)
  end
end
