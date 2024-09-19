#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Non existing Image operations test" do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        cli_action("oneimage show 60", false)
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should try to make a non existing Image persistent/nonpersistent" <<
        " and check the failure" do
        cli_action("oneimage persistent 123", false)
        cli_action("oneimage nonpersistent 12", false)
    end

    it "should try to enable/disable a non existing Image and check" <<
        " the failure" do
        cli_action("oneimage disable 6123", false)
        cli_action("oneimage enable  412", false)
    end

    it "should try to delete a non existing Image and check the failure" do
        cli_action("oneimage delete 63", false)
    end

    it "should try to edit dynamically a non existing Image template " <<
        "and check the failure" do
        template =  "ATT2 = NEW_VAL\n" <<
                    "ATT3 = VAL3"
        cli_update("oneimage update 334", template, false, false)
    end
end
