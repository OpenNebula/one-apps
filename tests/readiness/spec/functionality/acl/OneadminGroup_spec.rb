#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "ACL Oneadmin group test" do
  #---------------------------------------------------------------------------
  # OpenNebula bootstraping:
  #   - Define infrastructure: hosts, datastore, users, networks,...
  #   - Common instance variables: templates,...
  #---------------------------------------------------------------------------
  before(:all) do
    cli_create_user("userA", "passwordA")
    cli_create_user("userB", "passwordB")

    as_user("userA") do
      @tid = cli_create("onetemplate create", "NAME = test_template")
    end
  end


  it "should try to perform a privileged operation as a regular user and"<<
      " check the failure" do

    as_user("userB") do
      cli_action("onetemplate delete #{@tid}", false)
    end
  end

  it "should add a regular user to the oneadmin group and check that he can"<<
      " perform a privileged operation" do

    cli_action("oneuser chgrp userB oneadmin")

    as_user("userB") do
      cli_action("onetemplate delete #{@tid}")
    end
  end
end