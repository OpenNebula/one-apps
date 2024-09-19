#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Cluster permissions test" do
  #---------------------------------------------------------------------------
  # OpenNebula bootstraping:
  #   - Define infrastructure: hosts, datastore, users, networks,...
  #   - Common instance variables: templates,...
  #---------------------------------------------------------------------------
  before(:all) do
    cli_create_user("uA", "abc")
    cli_create_user("uB", "abc")

    gA_id = cli_create("onegroup create gA")
    cli_create("onegroup create gB")

    cli_action("oneuser chgrp uA gA")
    cli_action("oneuser chgrp uB gB")

    @cl_id = cli_create("onecluster create clA")
    cli_action("oneacl create '@#{gA_id} CLUSTER/##{@cl_id} USE'")
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  it "should try to create a Cluster as a regular user, and fail" do
    as_user "uA" do
      cli_action("onecluster create test", false)
    end
  end

  it "should try to list the system cluster as a user from group A, and fail" do
    as_user("uA") do
      output = cli_action("onecluster list").stdout
      expect(output).not_to match(/system/)
    end
  end

  it "should try to show the system cluster as a user from group A, and fail" do
    as_user "uA" do
      cli_action("onecluster show 0", false)
    end
  end

  it "should list the allowed cluster as a user from group A" do
    as_user("uA") do
      output = cli_action("onecluster list").stdout
      expect(output).to match(/clA/)
    end
  end

  it "should show the allowed cluster as a user from group A" do
    as_user "uA" do
      cli_action("onecluster show clA")
    end
  end

  it "should try to list the not-allowed cluster as a user from group B, and fail" do
    as_user("uB") do
      output = cli_action("onecluster list").stdout
      expect(output).not_to match(/clA/)
    end
  end

  it "should try to show the not-allowed cluster as a user from group B, and fail" do
    as_user "uB" do
      cli_action("onecluster show #{@cl_id}", false)
    end
  end
end