
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Restricted Attributes for VM test" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end


  before(:all) do
    cli_create_user("userA", "passwordA")
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------
  it "should try to create an VM with a custom restricted attribute, and fail" do
    template_text = "CPU = 1\n"<<
    "MEMORY = 64\n"<<
    "CUSTOM_RESTRICTED = 17"

    as_user("userA") do
      cli_create("onevm create", template_text, false)
    end

    cli_create("onevm create", template_text)
  end
end