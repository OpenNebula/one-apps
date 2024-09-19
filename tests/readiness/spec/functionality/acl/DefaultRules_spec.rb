#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "ACL Default rules test" do
  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  it "should check there is a default rule in the ACL pool" do
    # Header + 5 default rules
    expect(cli_action("oneacl list").stdout.split("\n").length).to eql(7)
  end
end