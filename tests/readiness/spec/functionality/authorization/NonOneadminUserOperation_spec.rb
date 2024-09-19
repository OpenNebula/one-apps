#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Non oneadmin User operations test" do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        cli_create_user("userA", "passwordA")
        cli_create_user("userB", "passwordB")
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------

    it "should try to add a new user as a non oneadmin user and check the" << 
        " failure." do
        as_user "userA" do
            cli_action("oneuser create userC pass", false)
        end
    end
    
    it "should update his own user password" do
        as_user "userB" do
            cli_action("oneuser show userB")
            cli_action("oneuser passwd userB abcd")
        end
    end
    
    it "should try to delete a user as a non oneadmin user and check the" << 
        " failure." do
        as_user "userA" do
            cli_action("oneuser delete userA", false)
        end
    end
end