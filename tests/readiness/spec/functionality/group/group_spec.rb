#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Group operations test" do
  before(:all) do
    @gid = -1
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  it "should create a non existing Group" do
    @gid = cli_create("onegroup create first_group")
    cli_action("onegroup show first_group")
  end

  it "should try to create an existing Group and check the failure" do
    cli_create("onegroup create first_group", nil, false)
  end

  it "should delete a Group and check that, now, it doesn't exist" do
    cli_action("onegroup delete first_group")
    cli_action("onegroup show first_group", false)
    cli_action("onegroup show #{@gid}", false)
  end

  it "should try to delete a non existing Group and check the failure" do
    cli_action("onegroup delete 160", false)
  end

  it "should try to delete a system Group and check the failure" do
    cli_action("onegroup delete 1", false)
    cli_action("onegroup show 1")
  end
end