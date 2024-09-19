#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Datastore permissions test" do
  #---------------------------------------------------------------------------
  # OpenNebula bootstraping:
  #   - Define infrastructure: hosts, datastore, users, networks,...
  #   - Common instance variables: templates,...
  #---------------------------------------------------------------------------
  before(:all) do
    cli_create_user("uA1", "abc")
    cli_create_user("uA2", "abc")
    cli_create_user("uB", "abc")

    # in group 'users'
    cli_create_user("uC", "abc")

    cli_create("onegroup create gA")
    cli_action("onevdc delgroup 0 gA")

    cli_create("onegroup create gB")
    cli_action("onevdc delgroup 0 gB")

    cli_action("oneuser chgrp uA1 gA")
    cli_action("oneuser chgrp uA2 gA")
    cli_action("oneuser chgrp uB  gB")

    @ds_id = cli_create("onedatastore create", "NAME = dsA\nTM_MAD=dummy\nDS_MAD=dummy")
    cli_action("onedatastore chgrp dsA gA")


    cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy", false)

    wait_loop() {
        xml = cli_action_xml("onedatastore show -x default")
        xml['FREE_MB'].to_i > 0
    }

    wait_loop() {
        xml = cli_action_xml("onedatastore show -x dsA")
        xml['FREE_MB'].to_i > 0
    }
  end

  after(:each) do
    `oneimage delete test_img`
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  it "should try to create a DS as a regular user, and fail" do
    as_user "uA1" do
      cli_create("onedatastore create", "NAME = dsB\nTM_MAD=dummy\nDS_MAD=dummy", false)
    end
  end

  it "should list the default datastore as a user from group users" do
    as_user("uC") do
      output = cli_action("onedatastore list").stdout
      expect(output).to match(/default/)
    end
  end

  it "should show the default datastore as a user from users" do
    as_user "uC" do
      cli_action("onedatastore show default")
    end
  end

  it "should list the datastore of the user's group" do
    as_user "uA1" do
      output = cli_action("onedatastore list").stdout
      expect(output).to match(/dsA/)
    end
  end

  it "should show the datastore of the user's group" do
    as_user "uA1" do
      cli_action("onedatastore show dsA")
    end
  end

  it "should try to list the datastore of another group, and fail" do
    as_user "uB" do
      output = cli_action("onedatastore list").stdout
      expect(output).not_to match(/dsA/)
    end
  end

  it "should try to show the datastore of another group, and fail" do
    as_user "uB" do
      cli_action("onedatastore show #{@ds_id}", false)
    end
  end

  it "should create a new image in the default DS" do
    as_user "uC" do
      cli_create("oneimage create --name test_img --size 100 --type datablock -d default")
      cli_create("onedatastore create", "NAME = dsB\nTM_MAD=dummy\nDS_MAD=dummy", false)

      img_xml = cli_action_xml("oneimage show test_img -x")
      expect(img_xml["DATASTORE"]).to eql("default")
    end
  end

  it "should create a new image in the group's DS" do
    as_user "uA1" do
      cli_create("oneimage create --name test_img --size 100 --type datablock -d dsA")

      img_xml = cli_action_xml("oneimage show test_img -x")
      expect(img_xml["DATASTORE"]).to eql("dsA")
    end
  end

  it "should try to create a new image in another group's DS, and fail" do
    as_user "uB" do
      cli_create("onedatastore create", "NAME = dsB\nTM_MAD=dummy\nDS_MAD=dummy", false)
    end
  end

  it "should set 'u' right to others, and create a new image as a user in another group" do
    cli_action("onedatastore chmod dsA 644")

    as_user "uB" do
      cli_create("oneimage create --name test_img --size 100 --type datablock -d dsA")

      img_xml = cli_action_xml("oneimage show test_img -x")
      expect(img_xml["DATASTORE"]).to eql("dsA")
    end

    cli_action("oneimage delete test_img")
    cli_action("onedatastore delete dsA")

    @ds_id = cli_create("onedatastore create", "NAME = dsA\nTM_MAD=dummy\nDS_MAD=dummy")
    cli_action("onedatastore chgrp dsA gA")
  end
end