#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Non existing Host operations test" do

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  it "should try to disable/enable a non existing Host and check the failure" do
    cli_action("onehost show 60", false)
    cli_action("onehost disable 60", false)
    cli_action("onehost enable 60", false)
  end
  
  it "should try to delete a non existing Host and check the failure" do
    cli_action("onehost delete 60", false)
  end
end